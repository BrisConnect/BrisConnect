// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart'
    as cluster;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/business_profile_view_screen.dart';
import 'package:brisconnect/screens/food_business_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/map/map_bottom_sheet.dart';
import 'package:brisconnect/widgets/map/map_filter_sheets.dart';
import 'package:brisconnect/widgets/map/map_floating_controls.dart';
import 'package:brisconnect/widgets/map/map_legend.dart';
import 'package:brisconnect/widgets/map/map_marker_helper.dart';
import 'package:brisconnect/widgets/map/map_models.dart';
import 'package:brisconnect/widgets/map/map_search_bar.dart';
import 'package:brisconnect/widgets/map/map_selected_pin_card.dart';

/// Discovery map for BrisConnect+. Displays events, attractions and food
/// businesses with clustering, live status badges, responsive layouts and
/// modern Material 3 controls.
class MapEventsScreen extends StatefulWidget {
  const MapEventsScreen({
    super.key,
    this.embedded = false,
    this.onBackPressed,
  });

  final bool embedded;
  final VoidCallback? onBackPressed;

  @override
  State<MapEventsScreen> createState() => _MapEventsScreenState();
}

class _MapEventsScreenState extends State<MapEventsScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final MapMarkerHelper _markerHelper = MapMarkerHelper();
  cluster.ClusterManager<MapPin>? _clusterManager;
  Set<Marker> _clusterMarkers = {};
  Marker? _userLocationMarker;
  String? _lastClusterPinSignature;

  Timer? _searchDebounce;
  StreamSubscription<Position>? _positionSubscription;

  // Live data sources for the map pins.
  final BusinessProfileService _businessService = BusinessProfileService();
  final FirestoreService _firestoreService = FirestoreService();
  final StreamController<List<Map<String, dynamic>>> _discoverItemsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Business>? _latestBusinesses;
  List<Map<String, dynamic>>? _latestEvents;
  List<Map<String, dynamic>>? _latestFoodBusinesses;
  StreamSubscription<List<Business>>? _businessSub;
  StreamSubscription<List<Map<String, dynamic>>>? _eventsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _foodBusinessesSub;

  MapPin? _selectedPin;
  cluster.Cluster<MapPin>? _selectedCluster;
  LatLng? _userLocation;
  bool _followUser = true;
  bool _showResultsSheet = false;
  bool _nearMeMode = false;
  String? _locationStatus;
  String _searchQuery = '';
  MapPinType? _selectedType;
  bool _showOnlyFavourites = false;
  final Set<String> _selectedFoodCategories = <String>{};

  MapStyle _mapStyle = MapStyle.normal;
  double _bearing = 0;

  static const LatLng _defaultCenter = LatLng(-27.4698, 153.0251);

  /// Brisbane CBD centre for pin filtering.
  static const double _brisbaneLat = -27.4698;
  static const double _brisbaneLng = 153.0251;
  static const double _defaultRadiusKm = 30.0;

  static const List<double> _radiusOptions = [1, 3, 5, 10, 1000];

  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    _radiusKm = _profileRadiusKm();
    _markerHelper.preload();

    _businessSub = _businessService.getVerifiedBusinessesStream().listen(
          _onBusinessesReceived,
          onError: (_) => _loadAllBusinessesForDev(),
        );
    _eventsSub = _firestoreService.getEvents().listen(
      (events) {
        _latestEvents = events;
        _emitDiscoverItems();
      },
      onError: (_) {
        _latestEvents ??= <Map<String, dynamic>>[];
        _emitDiscoverItems();
      },
    );
    _foodBusinessesSub = _loadFoodBusinessesStream().listen(
      (items) {
        _latestFoodBusinesses = items;
        _emitDiscoverItems();
      },
      onError: (_) {
        _latestFoodBusinesses ??= <Map<String, dynamic>>[];
        _emitDiscoverItems();
      },
    );
  }

  void _onBusinessesReceived(List<Business> businesses) {
    if (businesses.isEmpty) {
      _loadAllBusinessesForDev();
      return;
    }
    _latestBusinesses = businesses;
    _emitDiscoverItems();
  }

  Stream<List<Map<String, dynamic>>> _loadFoodBusinessesStream() {
    final canonical =
        FirebaseFirestore.instance.collection('businesses').snapshots();
    final legacy =
        FirebaseFirestore.instance.collection('food_businesses').snapshots();

    return _combineLatest2(
      canonical,
      legacy,
      (QuerySnapshot<Map<String, dynamic>> canonicalSnap,
          QuerySnapshot<Map<String, dynamic>> legacySnap) {
        final merged = <String, Map<String, dynamic>>{};

        for (final doc in canonicalSnap.docs) {
          final data = doc.data();
          if (data['deletedAt'] != null) continue;
          if (data['isActive'] == false) continue;
          merged[doc.id] = _mapBusinessDocToMapItem(doc);
        }

        for (final doc in legacySnap.docs) {
          if (merged.containsKey(doc.id)) continue;
          merged[doc.id] = _mapFoodBusinessDocToMapItem(doc);
        }

        return merged.values.toList();
      },
    );
  }

  Map<String, dynamic> _mapBusinessDocToMapItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawCategories = data['cuisineTypes'];
    final category = data['category']?.toString();
    List<String> categories;
    if (rawCategories is List && rawCategories.isNotEmpty) {
      categories = rawCategories.map((v) => '$v').toList();
    } else if (category != null && category.isNotEmpty) {
      categories = [category];
    } else {
      categories = <String>[];
    }
    return <String, dynamic>{
      'id': doc.id,
      'section': 'food',
      'badge': category ?? 'Food',
      'title': data['businessName'] ?? data['name'] ?? 'Untitled',
      'description': data['description'] ?? '',
      'location': data['address'] ?? '',
      'imageUrl':
          data['coverImageUrl'] ?? data['logoUrl'] ?? data['imageUrl'] ?? '',
      'categories': categories,
      'category': categories.isNotEmpty ? categories.first : '',
      'rating': data['rating'] ?? data['averageRating'] ?? 0,
      'price': data['priceRange'] ?? '',
      'latitude': data['latitude'] ?? data['lat'],
      'longitude': data['longitude'] ?? data['lng'],
      ...data,
    };
  }

  Map<String, dynamic> _mapFoodBusinessDocToMapItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawCategories = data['cuisineTypes'];
    final category = data['category']?.toString();
    List<String> categories;
    if (rawCategories is List && rawCategories.isNotEmpty) {
      categories = rawCategories.map((v) => '$v').toList();
    } else if (category != null && category.isNotEmpty) {
      categories = [category];
    } else {
      categories = <String>[];
    }
    return <String, dynamic>{
      'id': doc.id,
      'section': 'food',
      'badge': category ?? 'Food',
      'title': data['name'] ?? data['businessName'] ?? 'Untitled',
      'description': data['description'] ?? '',
      'location': data['address'] ?? '',
      'imageUrl':
          data['imageUrl'] ?? data['logoUrl'] ?? data['coverImageUrl'] ?? '',
      'categories': categories,
      'category': categories.isNotEmpty ? categories.first : '',
      'rating': data['rating'] ?? data['averageRating'] ?? 0,
      'price': data['priceRange'] ?? '',
      'latitude': data['latitude'] ?? data['lat'],
      'longitude': data['longitude'] ?? data['lng'],
      ...data,
    };
  }

  Stream<R> _combineLatest2<T1, T2, R>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    R Function(T1, T2) combiner,
  ) {
    T1? latest1;
    T2? latest2;
    var has1 = false;
    var has2 = false;

    final controller = StreamController<R>.broadcast();

    void emit() {
      if (has1 && has2 && !controller.isClosed) {
        controller.add(combiner(latest1 as T1, latest2 as T2));
      }
    }

    stream1.listen(
      (value) {
        latest1 = value;
        has1 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    stream2.listen(
      (value) {
        latest2 = value;
        has2 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }

  static double _profileRadiusKm() {
    final local = LocalAuth.currentLocal;
    if (local != null) {
      return math.max(local.locationRadiusKm.toDouble(), _defaultRadiusKm);
    }
    return _defaultRadiusKm;
  }

  void _loadAllBusinessesForDev() {
    _businessSub?.cancel();
    _businessSub = _businessService.getAllBusinessesStream().listen(
      _onBusinessesReceived,
      onError: (_) {
        _latestBusinesses ??= <Business>[];
        _emitDiscoverItems();
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchDebounce?.cancel();
    _positionSubscription?.cancel();
    _businessSub?.cancel();
    _eventsSub?.cancel();
    _foodBusinessesSub?.cancel();
    _discoverItemsController.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startLiveTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Turn on location services to enable live tracking.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _locationStatus =
            'Location permission denied. Live GPS tracking is disabled.';
      });
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(current.latitude, current.longitude);
          _locationStatus = null;
        });
        await _updateUserLocationMarker();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Unable to get current location.';
      });
    }

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((position) async {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationStatus = null;
      });
      await _updateUserLocationMarker();

      if (_followUser) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_userLocation!),
        );
      }
    });
  }

  Future<void> _updateUserLocationMarker() async {
    final userLocation = _userLocation;
    if (userLocation == null) return;

    BitmapDescriptor icon;
    try {
      icon = await _markerHelper.bitmapForUserLocation();
    } catch (e) {
      debugPrint('Custom user-location marker failed: $e');
      icon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }

    if (!mounted) return;
    setState(() {
      _userLocationMarker = Marker(
        markerId: const MarkerId('__user_location__'),
        position: userLocation,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 100,
      );
    });
  }

  void _recenterOnUser() {
    final user = _userLocation;
    if (user == null) {
      _startLiveTracking();
      return;
    }

    setState(() => _followUser = true);
    _updateUserLocationMarker();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: user, zoom: 14),
      ),
    );
  }

  void _focusPin(MapPin pin) {
    setState(() {
      _selectedPin = pin;
      _followUser = false;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pin.latitude, pin.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;

      final nextQuery = value.trim().toLowerCase();
      if (nextQuery == _searchQuery) return;

      setState(() => _searchQuery = nextQuery);
    });
  }

  void _emitDiscoverItems() {
    final businesses = _latestBusinesses ?? <Business>[];
    final events = _latestEvents ?? <Map<String, dynamic>>[];
    final foodBusinesses = _latestFoodBusinesses ?? <Map<String, dynamic>>[];
    final items = _buildDiscoverItems(businesses, events, foodBusinesses);

    final categories = foodBusinesses
        .expand((food) {
          final list = food['categories'];
          if (list is List) {
            return list.map((v) => '$v'.trim()).where((c) => c.isNotEmpty);
          }
          final single = food['category'] as String? ?? '';
          return single.trim().isNotEmpty ? [single.trim()] : <String>[];
        })
        .toSet()
        .toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    _discoverItemsController.add(items);
  }

  List<Map<String, dynamic>> _buildDiscoverItems(
    List<Business> businesses,
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> foodBusinesses,
  ) {
    final items = <Map<String, dynamic>>[];

    for (final business in businesses) {
      var lat = business.lat;
      var lng = business.lng;
      if (lat == null || lng == null) {
        final jitter = (business.businessName.hashCode % 1000) / 10000 - 0.05;
        final jitterLng = (business.businessName.hashCode % 997) / 10000 - 0.05;
        lat = _brisbaneLat + jitter;
        lng = _brisbaneLng + jitterLng;
      }
      items.add({
        'section': 'food',
        'id': business.id ?? business.ownerId,
        'title': business.businessName.trim(),
        'latitude': lat,
        'longitude': lng,
        'location': business.address.trim(),
        'badge': business.category.trim(),
        'description': business.description.trim(),
        'imageUrl': business.logoUrl ?? business.coverImageUrl ?? '',
        'price': '',
        'rating': (business.rating as num?)?.toDouble() ?? 0.0,
        'categories': business.category.trim().isNotEmpty
            ? [business.category.trim()]
            : const <String>[],
        'phone': business.contactNumber,
        'website': business.website ?? '',
        '_business': business,
      });
    }

    for (final event in events) {
      final lat = _toDouble(event['latitude']) ?? _toDouble(event['lat']);
      final lng = _toDouble(event['longitude']) ?? _toDouble(event['lng']);
      if (lat == null || lng == null) continue;
      items.add({
        ...event,
        'section': 'events',
        'latitude': lat,
        'longitude': lng,
      });
    }

    for (final food in foodBusinesses) {
      var lat = _toDouble(food['latitude']) ?? _toDouble(food['lat']);
      var lng = _toDouble(food['longitude']) ?? _toDouble(food['lng']);
      if (lat == null || lng == null) {
        final jitter =
            ((food['title'] as String? ?? '').hashCode % 1000) / 10000 - 0.05;
        final jitterLng =
            ((food['title'] as String? ?? '').hashCode % 997) / 10000 - 0.05;
        lat = _brisbaneLat + jitter;
        lng = _brisbaneLng + jitterLng;
      }
      items.add({
        ...food,
        'section': 'food',
        'latitude': lat,
        'longitude': lng,
        'badge': (food['badge'] as String? ?? '').trim().isNotEmpty
            ? (food['badge'] as String? ?? '').trim()
            : (food['category'] as String? ?? 'Food').trim(),
      });
    }

    return items;
  }

  List<MapPin> _getAllPins(List<Map<String, dynamic>> discoverItems) {
    final combined = _discoverPins(discoverItems);

    final deduped = <String, MapPin>{};
    for (final pin in combined) {
      deduped[pin.key] = pin;
    }

    final pins = deduped.values
        .where((pin) => _isWithinRadius(pin.latitude, pin.longitude))
        .toList(growable: false);

    if (_nearMeMode) {
      // Sort by distance from the user (or Brisbane CBD if location unknown).
      final center = _nearMeCenter;
      pins.sort((a, b) {
        final distA = _distanceKm(
            center.latitude, center.longitude, a.latitude, a.longitude);
        final distB = _distanceKm(
            center.latitude, center.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    } else {
      pins.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return pins;
  }

  List<MapPin> _discoverPins(List<Map<String, dynamic>> items) {
    final pins = <MapPin>[];

    for (final item in items) {
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      final lat = _toDouble(item['latitude']);
      final lng = _toDouble(item['longitude']);
      if (lat == null || lng == null) continue;

      final id = (item['id'] as String? ?? '').trim();
      final title = (item['title'] as String? ?? '').trim();
      if (id.isEmpty || title.isEmpty) continue;

      final textBlob = [
        (item['badge'] as String? ?? ''),
        (item['description'] as String? ?? ''),
        (item['location'] as String? ?? ''),
      ].join(' ').toLowerCase();

      late final MapPinType type;
      switch (section) {
        case 'events':
          type = MapPinType.event;
          break;
        case 'stadiums':
          type = (textBlob.contains('olympic') || textBlob.contains('2032'))
              ? MapPinType.olympicVenue
              : MapPinType.stadium;
          break;
        case 'historical':
          type = textBlob.contains('cultur')
              ? MapPinType.culturalVenue
              : MapPinType.attraction;
          break;
        case 'food':
          type = MapPinType.food;
          break;
        default:
          continue;
      }

      final business = item['_business'] as Business?;
      final status = _computePinStatus(item, business);

      pins.add(
        MapPin(
          id: id,
          title: title,
          locationName: (item['location'] as String? ?? 'Location TBA').trim(),
          latitude: lat,
          longitude: lng,
          type: type,
          source: 'events',
          imageUrl: (item['imageUrl'] as String? ?? '').trim(),
          badge: (item['badge'] as String? ?? '').trim(),
          description: (item['description'] as String? ?? '').trim(),
          price: (item['price'] as String? ?? '').trim(),
          rating: (item['rating'] as num?)?.toDouble(),
          categories: (item['categories'] as List?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          phone: (item['phone'] as String? ?? '').trim(),
          website: (item['website'] as String? ?? '').trim(),
          rawItem: item,
          isOpenNow: status.isOpenNow,
          isClosingSoon: status.isClosingSoon,
          isVerified: status.isVerified,
          isPopular: status.isPopular,
          isPremium: status.isPremium,
          crowdLevel: status.crowdLevel,
          waitTime: status.waitTime,
        ),
      );
    }

    return pins;
  }

  _PinStatus _computePinStatus(Map<String, dynamic> item, Business? business) {
    final now = DateTime.now();

    bool? openNow;
    bool? closingSoon;
    if (business != null && business.businessHours != null) {
      final dayName = _dayName(now.weekday);
      final dayHours = business.businessHours!.hours[dayName];
      if (dayHours != null) {
        openNow = _isCurrentlyOpen(dayHours, now);
        closingSoon = openNow == true && _isClosingSoon(dayHours, now);
      }
    }

    final isVerified =
        business?.isVerified == true || item['isVerified'] == true;
    final buzz =
        (business?.buzzScore ?? (item['buzzScore'] as num?)?.toDouble() ?? 0.0);
    final savedCount =
        business?.savedCount ?? (item['savedCount'] as num?)?.toInt() ?? 0;
    final rating = (business?.rating ?? (item['rating'] as num?)?.toInt() ?? 0);
    final isTrending =
        business?.isTrending == true || item['isTrending'] == true;

    final isPopular = isTrending || buzz >= 60 || savedCount >= 20;
    final isPremium =
        isVerified && (rating >= 4 || savedCount >= 30 || buzz >= 75);

    final crowdLevel = item['crowdLevel']?.toString();
    final waitTime = item['waitTime']?.toString();

    return _PinStatus(
      isOpenNow: openNow,
      isClosingSoon: closingSoon,
      isVerified: isVerified,
      isPopular: isPopular,
      isPremium: isPremium,
      crowdLevel: crowdLevel,
      waitTime: waitTime,
    );
  }

  bool _isCurrentlyOpen(DayHours dayHours, DateTime now) {
    if (dayHours.isClosed) return false;
    if (dayHours.openTime == null || dayHours.closeTime == null) return false;
    final open = _parseTime(dayHours.openTime!, now);
    final close = _parseTime(dayHours.closeTime!, now);
    if (open == null || close == null) return false;
    return now.isAfter(open) && now.isBefore(close);
  }

  bool _isClosingSoon(DayHours dayHours, DateTime now) {
    if (dayHours.closeTime == null) return false;
    final close = _parseTime(dayHours.closeTime!, now);
    if (close == null) return false;
    return close.difference(now).inMinutes <= 30 &&
        close.difference(now).inMinutes >= 0;
  }

  DateTime? _parseTime(String time, DateTime now) {
    final parts = time.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  List<MapPin> _getFilteredPins(List<MapPin> allPins) {
    final query = _searchQuery;
    final savedBusinessIds = VisitorAuth.getSavedBusinessIds();

    return allPins.where((pin) {
      if (_selectedType != null && pin.type != _selectedType) return false;

      if (_showOnlyFavourites) {
        if (pin.type != MapPinType.food || !savedBusinessIds.contains(pin.id)) {
          return false;
        }
      }

      if (_selectedType == MapPinType.food &&
          _selectedFoodCategories.isNotEmpty) {
        final pinCategories = pin.categories ?? [];
        final matchesCategory = _selectedFoodCategories.any(
          (category) => pinCategories.any(
            (pinCat) => pinCat.toLowerCase() == category.toLowerCase(),
          ),
        );
        if (!matchesCategory) return false;
      }

      if (query.isEmpty) return true;

      return pin.title.toLowerCase().contains(query) ||
          pin.locationName.toLowerCase().contains(query) ||
          pin.type.label.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _updateClusterItems(List<MapPin> pins) {
    final signature = _pinsSignature(pins);
    if (_lastClusterPinSignature == signature) return;
    _lastClusterPinSignature = signature;
    _clusterManager?.setItems(pins);
  }

  String _pinsSignature(List<MapPin> pins) {
    var hash = pins.length;
    for (var i = 0; i < pins.length; i++) {
      hash = hash ^ pins[i].key.hashCode ^ i;
    }
    return '$hash';
  }

  Future<Marker> _buildClusterMarker(cluster.Cluster<MapPin> cluster) async {
    final zoom = await _mapController?.getZoomLevel() ?? 12;
    final icon = await _markerHelper.bitmapForCluster(cluster, zoom: zoom);
    final capturedCluster = cluster;
    return Marker(
      markerId: MarkerId(capturedCluster.getId()),
      position: capturedCluster.location,
      icon: icon,
      consumeTapEvents: false,
      onTap: () => _onClusterTap(capturedCluster, zoom),
    );
  }

  void _onClusterTap(cluster.Cluster<MapPin> tappedCluster, double zoom) {
    if (!tappedCluster.isMultiple) {
      _focusPin(tappedCluster.items.first);
      return;
    }

    setState(() {
      _selectedCluster = tappedCluster;
      _selectedPin = null;
      _followUser = false;
    });

    // On web, ensure the cluster popup is visible by zooming in slightly
    // so the cluster stays on screen while the popup renders.
    if (kIsWeb) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(tappedCluster.location, zoom + 1),
      );
    }
  }

  void _zoomIntoCluster() {
    final selected = _selectedCluster;
    final controller = _mapController;
    if (selected == null || controller == null) return;

    controller.animateCamera(
      CameraUpdate.newLatLngZoom(selected.location, 17),
    );
    setState(() => _selectedCluster = null);
  }

  void _viewClusterBusinesses() {
    final selected = _selectedCluster;
    if (selected == null) return;

    setState(() {
      _selectedCluster = null;
      _showResultsSheet = true;
    });
    // Focus the map on the cluster location so the surrounding pins remain
    // visible in the results sheet.
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(selected.location, 16),
      );
    }
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isWithinRadius(double lat, double lng) {
    final from = _nearMeCenter;
    return _distanceKm(from.latitude, from.longitude, lat, lng) <= _radiusKm;
  }

  LatLng get _nearMeCenter => _nearMeMode && _userLocation != null
      ? _userLocation!
      : const LatLng(_brisbaneLat, _brisbaneLng);

  static double _distanceKm(
      double fromLat, double fromLng, double toLat, double toLng) {
    const double toRad = math.pi / 180;
    final dLat = (toLat - fromLat) * toRad;
    final dLng = (toLng - fromLng) * toRad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(fromLat * toRad) *
            math.cos(toLat * toRad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    const double earthKm = 6371.0;
    return earthKm * c;
  }

  String _distanceLabel(double lat, double lng) {
    final fromLat = _userLocation?.latitude ?? _brisbaneLat;
    final fromLng = _userLocation?.longitude ?? _brisbaneLng;
    final km = _distanceKm(fromLat, fromLng, lat, lng);
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  void _openPinDetail(MapPin pin) {
    if (pin.type == MapPinType.event) {
      final raw = pin.rawItem;
      if (raw != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VisitorEventDetailScreen(event: raw),
          ),
        );
      }
      return;
    }

    if (pin.type == MapPinType.food) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FoodBusinessDetailScreen(businessId: pin.id),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessProfileViewScreen(
          businessId: pin.id,
          isOwnProfile: false,
        ),
      ),
    );
  }

  Future<void> _launchNavigation(MapPin pin) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => NavModeSheet(name: pin.title),
    );
    if (mode == null) return;

    final lat = pin.latitude;
    final lng = pin.longitude;

    final googleNativeUri =
        Uri.parse('google.navigation:q=$lat,$lng&mode=$mode');
    final googleWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=${_googleWebMode(mode)}',
    );
    final appleUri =
        Uri.parse('maps://?daddr=$lat,$lng&dirflg=${_appleDirFlag(mode)}');

    if (await canLaunchUrl(googleNativeUri)) {
      await launchUrl(googleNativeUri);
    } else if (await canLaunchUrl(appleUri)) {
      await launchUrl(appleUri);
    } else if (await canLaunchUrl(googleWebUri)) {
      await launchUrl(googleWebUri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open navigation.')),
      );
    }
  }

  String _googleWebMode(String mode) {
    switch (mode) {
      case 'w':
        return 'walking';
      case 'r':
        return 'transit';
      case 'b':
        return 'bicycling';
      default:
        return 'driving';
    }
  }

  String _appleDirFlag(String mode) {
    switch (mode) {
      case 'w':
        return 'w';
      case 'r':
        return 'r';
      default:
        return 'd';
    }
  }

  void _showFoodCategorySelector(List<MapPin> allPins) {
    final categories = allPins
        .where((pin) => pin.type == MapPinType.food)
        .expand((pin) => pin.categories ?? const <String>[])
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No food categories available.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FoodCategorySheet(
        categories: categories,
        selectedCategories: _selectedFoodCategories,
        onToggle: (category) {
          setState(() {
            if (_selectedFoodCategories.contains(category)) {
              _selectedFoodCategories.remove(category);
            } else {
              _selectedFoodCategories.add(category);
            }
          });
        },
        onClear: () => setState(() => _selectedFoodCategories.clear()),
      ),
    );
  }

  void _showRadiusSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MapRadiusSheet(
        selectedKm: _radiusKm,
        options: _radiusOptions,
        onSelected: (km) {
          setState(() => _radiusKm = km);
          _emitDiscoverItems();
        },
      ),
    );
  }

  void _showMapStyleSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MapStyleSheet(
        currentStyle: _mapStyle,
        onSelected: (style) => setState(() => _mapStyle = style),
      ),
    );
  }

  void _resetCompass() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _userLocation ?? _defaultCenter,
          zoom: 14,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  MapType get _googleMapType {
    switch (_mapStyle) {
      case MapStyle.satellite:
        return MapType.satellite;
      case MapStyle.terrain:
        return MapType.terrain;
      case MapStyle.normal:
      case MapStyle.dark:
        return MapType.normal;
    }
  }

  String? get _darkMapStyleJson =>
      _mapStyle == MapStyle.dark ? _darkStyle : null;

  void _applyMapStyle(GoogleMapController controller) {
    final style = _darkMapStyleJson;
    if (style != null) {
      controller.setMapStyle(style);
    } else {
      controller.setMapStyle(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverItemsController.stream,
      builder: (context, snapshot) {
        final discoverItems = snapshot.data ?? const <Map<String, dynamic>>[];
        final allPins = _getAllPins(discoverItems);
        final pins = _getFilteredPins(allPins);

        // Keep the cluster manager in sync with visible pins.
        _updateClusterItems(pins);

        if (pins.isEmpty && _showResultsSheet) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showResultsSheet = false);
          });
        }

        if (_selectedPin != null) {
          final selectedExists =
              pins.any((pin) => pin.key == _selectedPin!.key);
          if (!selectedExists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedPin = null);
            });
          }
        }

        if (_selectedCluster != null) {
          final clusterExists = pins.any(
            (pin) => _selectedCluster!.items.any((c) => c.key == pin.key),
          );
          if (!clusterExists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCluster = null);
            });
          }
        }

        return widget.embedded
            ? _buildBody(pins, allPins)
            : Scaffold(
                backgroundColor: AppPalette.background,
                appBar: AppBar(
                  title: const LogoAppBarTitle('Map Explorer'),
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                ),
                body: _buildBody(pins, allPins),
              );
      },
    );
  }

  Widget _buildBody(List<MapPin> pins, List<MapPin> allPins) {
    final useMapFallback = !kIsWeb && Platform.isMacOS;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1100;
        final isTablet = width >= 700 && !isDesktop;

        if (isDesktop) {
          return _buildDesktopLayout(pins, allPins, useMapFallback);
        }
        if (isTablet) {
          return _buildTabletLayout(pins, allPins, useMapFallback);
        }
        return _buildMobileLayout(pins, allPins, useMapFallback);
      },
    );
  }

  Widget _buildDesktopLayout(
      List<MapPin> pins, List<MapPin> allPins, bool useMapFallback) {
    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _buildSidebar(pins, allPins),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildMap(pins, useMapFallback),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _buildSearchBar(allPins),
              ),
              if (_locationStatus != null)
                Positioned(
                  top: 84,
                  left: 16,
                  right: 16,
                  child: _buildLocationStatusBanner(),
                ),
              Positioned(
                right: 16,
                bottom: 24,
                child: _buildFloatingButtons(),
              ),
              if (_selectedPin != null)
                Positioned(
                  right: 90,
                  bottom: 24,
                  width: 380,
                  child: _buildSelectedPinCard(),
                )
              else if (_selectedCluster != null)
                Positioned(
                  right: 90,
                  bottom: 24,
                  child: _buildClusterPopup(),
                ),
              const Positioned(
                left: 16,
                bottom: 24,
                child: MapLegend(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(
      List<MapPin> pins, List<MapPin> allPins, bool useMapFallback) {
    return Stack(
      children: [
        _buildMap(pins, useMapFallback),
        Positioned(
          top: 16,
          left: 16,
          right: 120,
          child: _buildSearchBar(allPins),
        ),
        if (_locationStatus != null)
          Positioned(
            top: 84,
            left: 16,
            right: 16,
            child: _buildLocationStatusBanner(),
          ),
        Positioned(
          right: 16,
          top: 80,
          child: _buildFloatingButtons(),
        ),
        if (_selectedPin != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 110,
            child: _buildSelectedPinCard(),
          )
        else if (_selectedCluster != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 110,
            child: _buildClusterPopup(),
          ),
        const Positioned(
          left: 16,
          bottom: 16,
          child: MapLegend(),
        ),
        Positioned(
          right: 16,
          left: 210,
          bottom: 16,
          child: Center(
            child: _buildBottomActionBar(pins, allPins),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
      List<MapPin> pins, List<MapPin> allPins, bool useMapFallback) {
    return Stack(
      children: [
        _buildMap(pins, useMapFallback),
        Positioned(
          top: 12,
          left: 12,
          right: 72,
          child: _buildSearchBar(allPins),
        ),
        if (_locationStatus != null)
          Positioned(
            top: 80,
            left: 12,
            right: 12,
            child: _buildLocationStatusBanner(),
          ),
        Positioned(
          right: 12,
          top: 12,
          child: _buildFloatingButtons(),
        ),
        if (pins.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _nearMeMode && _userLocation == null
                    ? 'Enable location services to see nearby food.'
                    : 'No places match your filters right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppPalette.mutedText),
              ),
            ),
          )
        else if (_showResultsSheet)
          MapResultsBottomSheet(
            pins: pins,
            selectedPin: _selectedPin,
            controller: ScrollController(),
            onPinTap: _focusPin,
            onDismiss: () => setState(() => _showResultsSheet = false),
            userLocationActive: _userLocation != null,
            subtitle: _radiusSubtitle(),
          ),
        if (_selectedPin != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: _showResultsSheet ? 230 : 100,
            top: 100,
            child: PointerInterceptor(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 560,
                  ),
                  child: _buildSelectedPinCard(),
                ),
              ),
            ),
          )
        else if (_selectedCluster != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: _showResultsSheet ? 230 : 100,
            top: 100,
            child: PointerInterceptor(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 560,
                  ),
                  child: _buildClusterPopup(),
                ),
              ),
            ),
          ),
        const Positioned(
          left: 12,
          bottom: 16,
          child: MapLegend(),
        ),
        Positioned(
          right: 12,
          left: 210,
          bottom: _showResultsSheet ? 240 : 16,
          child: Center(
            child: _buildBottomActionBar(pins, allPins),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(List<MapPin> pins, List<MapPin> allPins) {
    return Container(
      color: AppPalette.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSearchBar(allPins),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildBottomActionBar(pins, allPins),
          ),
          const SizedBox(height: 8),
          if (_locationStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLocationStatusBanner(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index];
                final selected = _selectedPin?.key == pin.key;
                final status = MapMarkerHelper().statusForPin(pin);
                final color = MapMarkerHelper.statusColor(status);

                return ListTile(
                  onTap: () => _focusPin(pin),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(pin.type.icon, color: color, size: 18),
                  ),
                  title: Text(
                    pin.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  subtitle: Text(
                    pin.type.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedText.withValues(alpha: 0.9),
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.my_location,
                          color: AppPalette.deepBlue)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(List<MapPin> allPins) {
    return PointerInterceptor(
      child: MapSearchBar(
        controller: _searchController,
        onChanged: _handleSearchChanged,
        onSubmitted: _handleSearchChanged,
        onFilterTap: () => _showFoodCategorySelector(allPins),
        onNearbyTap:
            LocalAuth.isLocalLoggedIn ? _showRadiusSelector : null,
        onClear: () => setState(() => _searchQuery = ''),
        onBackPressed: widget.onBackPressed,
        filterActive:
            _selectedFoodCategories.isNotEmpty || _selectedType != null,
        nearbyActive: _radiusKm != _defaultRadiusKm,
      ),
    );
  }

  Widget _buildLocationStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDEE3EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        _locationStatus!,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppPalette.mutedText),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return PointerInterceptor(
      child: MapFloatingButtons(
        followingUser: _followUser && _userLocation != null,
        onMyLocation: _recenterOnUser,
        onCompass: _resetCompass,
        onMapStyle: _showMapStyleSelector,
        bearing: _bearing,
      ),
    );
  }

  Widget _buildBottomActionBar(List<MapPin> pins, List<MapPin> allPins) {
    return PointerInterceptor(
      child: MapBottomActionBar(
        followingUser: _followUser && _userLocation != null,
        resultsVisible: _showResultsSheet,
        selectedType: _selectedType,
        showOnlyFavourites: _showOnlyFavourites,
        onMyLocation: _recenterOnUser,
        onNearby: () {
          if (pins.isEmpty && !_nearMeMode) return;
          setState(() {
            _nearMeMode = true;
            _showResultsSheet = true;
            _selectedType = MapPinType.food;
          });
          // If we don't have the user's location yet, try to fetch it.
          if (_userLocation == null) {
            _startLiveTracking().then((_) => _emitDiscoverItems());
          }
        },
        onFood: () {
          if (_selectedType == MapPinType.food) {
            setState(() {
              _selectedType = null;
              _selectedFoodCategories.clear();
            });
          } else {
            setState(() => _selectedType = MapPinType.food);
            _showFoodCategorySelector(allPins);
          }
        },
        onFavourites: () {
          if (!VisitorAuth.isVisitorLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Please log in as a Visitor to see your favourites.'),
              ),
            );
            return;
          }
          setState(() => _showOnlyFavourites = !_showOnlyFavourites);
        },
        resultCount: pins.length,
      ),
    );
  }

  Widget _buildSelectedPinCard() {
    final pin = _selectedPin!;
    return PointerInterceptor(
      child: MapSelectedPinCard(
        pin: pin,
        distanceLabel: _distanceLabel(pin.latitude, pin.longitude),
        onNavigate: () => _launchNavigation(pin),
        onViewDetails: () => _openPinDetail(pin),
        onClose: () => setState(() => _selectedPin = null),
      ),
    );
  }

  Widget _buildClusterPopup() {
    final selected = _selectedCluster!;
    final items = selected.items.toList();
    final type = items.isEmpty ? MapPinType.food : items.first.type;
    final topRated = items.where((p) => (p.rating ?? 0) >= 4.5).length;
    final openNow =
        items.where((p) => _statusForPin(p).isOpenNow == true).length;
    final trending = items.where((p) => _statusForPin(p).isPopular).length;

    return PointerInterceptor(
      child: ClusterInfoPopup(
        count: items.length,
        type: type,
        topRated: topRated,
        openNow: openNow,
        trending: trending,
        onViewBusinesses: _viewClusterBusinesses,
        onZoomIn: _zoomIntoCluster,
      ),
    );
  }

  _PinStatus _statusForPin(MapPin pin) {
    final status = MapMarkerHelper().statusForPin(pin);
    final isOpenNow = status == MapPinStatus.open;
    final isPopular = status == MapPinStatus.popular ||
        (pin.rawItem?['trending'] as bool? ?? false);
    final isPremium = status == MapPinStatus.premium ||
        (pin.rawItem?['isPremium'] as bool? ?? false);
    final isVerified = status == MapPinStatus.verified ||
        (pin.rawItem?['verified'] as bool? ?? false);
    return _PinStatus(
      isOpenNow: isOpenNow,
      isVerified: isVerified,
      isPopular: isPopular,
      isPremium: isPremium,
    );
  }

  Widget _buildMap(List<MapPin> pins, bool useMapFallback) {
    if (useMapFallback) {
      return _MacOSFallbackMap(
        pins: pins,
        userLocation: _userLocation,
        selectedPin: _selectedPin,
        onPinTap: (pin) => setState(() => _selectedPin = pin),
      );
    }

    return _DeferredWebMap(
      center: _userLocation ?? _defaultCenter,
      mapType: _googleMapType,
      darkStyleJson: _darkMapStyleJson,
      myLocationEnabled: false,
      markers: {
        ..._clusterMarkers,
        if (_userLocationMarker != null) _userLocationMarker!,
      },
      onCameraIdle: () => _clusterManager?.updateMap(),
      onMapCreated: (controller) {
        _mapController = controller;
        _applyMapStyle(controller);
        _clusterManager ??= cluster.ClusterManager<MapPin>(
          pins,
          (markers) {
            if (mounted) {
              setState(() => _clusterMarkers = markers);
            }
          },
          markerBuilder: _buildClusterMarker,
          levels: const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
          extraPercent: 0.2,
          stopClusteringZoom: 17,
        );
        _clusterManager!.setMapId(controller.mapId);
      },
      onCameraMove: (position) {
        _clusterManager?.onCameraMove(position, forceUpdate: false);
        setState(() => _bearing = position.bearing);
      },
      onTap: () => setState(() {
        _selectedPin = null;
        _followUser = false;
      }),
    );
  }

  String _radiusSubtitle() {
    if (_radiusKm >= 1000) return 'Entire Brisbane';
    if (_nearMeMode && _userLocation != null) {
      return 'Within ${_radiusKm.toStringAsFixed(0)} km of your location';
    }
    return 'Within ${_radiusKm.toStringAsFixed(0)} km of Brisbane CBD';
  }

  static const String _darkStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
]
''';
}

class _PinStatus {
  const _PinStatus({
    this.isOpenNow,
    this.isClosingSoon,
    required this.isVerified,
    required this.isPopular,
    required this.isPremium,
    this.crowdLevel,
    this.waitTime,
  });

  final bool? isOpenNow;
  final bool? isClosingSoon;
  final bool isVerified;
  final bool isPopular;
  final bool isPremium;
  final String? crowdLevel;
  final String? waitTime;
}

/// Defers building the GoogleMap web platform view until after the first
/// frame. This avoids an `IntersectionObserver` race where the Google Maps JS
/// SDK tries to observe the underlying HTML element before Flutter has
/// attached it to the DOM.
class _DeferredWebMap extends StatefulWidget {
  const _DeferredWebMap({
    required this.center,
    required this.mapType,
    required this.darkStyleJson,
    required this.myLocationEnabled,
    required this.markers,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onTap,
  });

  final LatLng center;
  final MapType mapType;
  final String? darkStyleJson;
  final bool myLocationEnabled;
  final Set<Marker> markers;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;
  final VoidCallback onTap;

  @override
  State<_DeferredWebMap> createState() => _DeferredWebMapState();
}

class _DeferredWebMapState extends State<_DeferredWebMap> {
  bool _ready = false;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(_DeferredWebMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapType != widget.mapType ||
        oldWidget.darkStyleJson != widget.darkStyleJson) {
      _applyStyle();
    }
  }

  Future<void> _applyStyle() async {
    final controller = _controller;
    if (controller == null) return;
    if (widget.darkStyleJson != null) {
      await controller.setMapStyle(widget.darkStyleJson);
    } else {
      await controller.setMapStyle(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.center,
        zoom: 11.6,
      ),
      onMapCreated: (controller) {
        _controller = controller;
        widget.onMapCreated(controller);
      },
      onCameraMove: widget.onCameraMove,
      onCameraIdle: widget.onCameraIdle,
      onTap: (_) => widget.onTap(),
      markers: widget.markers,
      myLocationButtonEnabled: false,
      myLocationEnabled: widget.myLocationEnabled,
      zoomControlsEnabled: true,
      mapType: widget.mapType,
    );
  }
}

/// macOS fallback for Google Maps, which is not supported on desktop.
/// Displays the same pins in a scrollable list with approximate distance
/// from the user (or Brisbane CBD if no location).
class _MacOSFallbackMap extends StatelessWidget {
  const _MacOSFallbackMap({
    required this.pins,
    this.userLocation,
    this.selectedPin,
    required this.onPinTap,
  });

  final List<MapPin> pins;
  final LatLng? userLocation;
  final MapPin? selectedPin;
  final ValueChanged<MapPin> onPinTap;

  double _distanceKm(MapPin pin) {
    final from = userLocation ?? const LatLng(-27.4698, 153.0251);
    const r = 6371.0;
    final dLat = _toRad(pin.latitude - from.latitude);
    final dLng = _toRad(pin.longitude - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(from.latitude)) *
            math.cos(_toRad(pin.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final sorted = List<MapPin>.from(pins)
      ..sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));

    return Container(
      color: AppPalette.background,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppPalette.ochre,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: const Text(
              'Map view is not available on macOS. Showing nearby places.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'No places found',
                      style: TextStyle(color: AppPalette.mutedText),
                    ),
                  )
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final pin = sorted[index];
                      final isSelected = selectedPin?.key == pin.key;
                      final status = MapMarkerHelper().statusForPin(pin);
                      final color = MapMarkerHelper.statusColor(status);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.14),
                          child: Icon(
                            pin.type.icon,
                            color: isSelected ? Colors.white : color,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          pin.title,
                          style: TextStyle(
                            color: AppPalette.charcoal,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${pin.locationName} · ${_distanceKm(pin).toStringAsFixed(1)} km',
                          style: TextStyle(color: AppPalette.mutedText),
                        ),
                        tileColor: isSelected
                            ? color.withValues(alpha: 0.08)
                            : Colors.transparent,
                        onTap: () => onPinTap(pin),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
