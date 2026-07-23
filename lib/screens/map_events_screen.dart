import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firestore_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

enum _MapPinType {
  event,
  attraction,
  stadium,
  olympicVenue,
  culturalVenue,
  food,
}

class _MapPin {
  const _MapPin({
    required this.id,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.source,
  });

  final String id;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final _MapPinType type;
  final String source;
}

class MapEventsScreen extends StatefulWidget {
  const MapEventsScreen({super.key, this.embedded = false, this.onBackPressed});

  final bool embedded;
  final VoidCallback? onBackPressed;

  @override
  State<MapEventsScreen> createState() => _MapEventsScreenState();
}

class _MapEventsScreenState extends State<MapEventsScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  StreamSubscription<Position>? _positionSubscription;
  late final AnimationController _pulseController;
  List<_MapPin>? _cachedAllPins;
  String? _cachedAllPinsSignature;
  List<_MapPin>? _cachedFilteredPins;
  String? _cachedFilteredPinsSignature;
  Set<Marker>? _cachedMarkers;
  String? _cachedMarkersSignature;
  Timer? _markerThrottleTimer;
  DateTime _lastMarkerRebuildAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _pendingMarkerSignature;

  // Live data sources for the map pins.
  final BusinessProfileService _businessService = BusinessProfileService();
  final FirestoreService _firestoreService = FirestoreService();
  final StreamController<List<Map<String, dynamic>>> _discoverItemsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Business>? _latestBusinesses;
  List<Map<String, dynamic>>? _latestEvents;
  StreamSubscription<List<Business>>? _businessSub;
  StreamSubscription<List<Map<String, dynamic>>>? _eventsSub;

  _MapPin? _selectedPin;
  LatLng? _userLocation;
  bool _followUser = true;
  bool _showResultsSheet = false;
  bool _useVibrantMap = true;
  bool _use3dMode = false;
  String? _locationStatus;
  String _searchQuery = '';
  _MapPinType? _selectedType;

  static const LatLng _defaultCenter = LatLng(-27.4698, 153.0251);

  /// Brisbane CBD centre for pin filtering.
  static const double _brisbaneLat = -27.4698;
  static const double _brisbaneLng = 153.0251;
  static const double _defaultRadiusKm = 30.0;
  static const Duration _markerThrottleWindow = Duration(milliseconds: 140);

  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    _radiusKm = _profileRadiusKm();
    _selectedType = _MapPinType.food; // Default to food items only
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Don't auto-track GPS on emulator — start at Brisbane default.
    // Live tracking can be triggered by the user tapping the recenter button.

    // Listen to live Firestore data and rebuild pins as it changes.
    // For development, fall back to all businesses if none are verified so the
    // map is usable before admin verification is complete.
    _businessSub = _businessService.getVerifiedBusinessesStream().listen(
      (businesses) {
        debugPrint('[MapEventsScreen] Received ${businesses.length} verified businesses');
        if (businesses.isEmpty) {
          debugPrint('[MapEventsScreen] Falling back to all businesses');
          _loadAllBusinessesForDev();
          return;
        }
        for (final b in businesses) {
          debugPrint('  biz=${b.businessName} lat=${b.lat} lng=${b.lng} verified=${b.isVerified}');
        }
        _latestBusinesses = businesses;
        _emitDiscoverItems();
      },
      onError: (Object e) {
        debugPrint('[MapEventsScreen] Businesses stream error: $e');
        _loadAllBusinessesForDev();
      },
    );
    _eventsSub = _firestoreService.getEvents().listen(
      (events) {
        debugPrint('[MapEventsScreen] Received ${events.length} events');
        _latestEvents = events;
        _emitDiscoverItems();
      },
      onError: (Object e) {
        debugPrint('[MapEventsScreen] Events stream error: $e');
        _latestEvents ??= <Map<String, dynamic>>[];
        _emitDiscoverItems();
      },
    );
  }

  /// Read the user's profile locationRadiusKm (local or visitor).
  /// For development on macOS we cap the minimum at the default so the map
  /// is not accidentally filtered to an empty result.
  static double _profileRadiusKm() {
    final local = LocalAuth.currentLocal;
    if (local != null) return math.max(local.locationRadiusKm.toDouble(), _defaultRadiusKm);
    final visitor = VisitorAuth.currentVisitor;
    if (visitor != null) return math.max(visitor.locationRadiusKm.toDouble(), _defaultRadiusKm);
    return _defaultRadiusKm;
  }

  void _loadAllBusinessesForDev() {
    _businessSub?.cancel();
    _businessSub = _businessService.getAllBusinessesStream().listen(
      (businesses) {
        debugPrint('[MapEventsScreen] Received ${businesses.length} all businesses (dev fallback)');
        for (final b in businesses) {
          debugPrint('  biz=${b.businessName} lat=${b.lat} lng=${b.lng} verified=${b.isVerified}');
        }
        _latestBusinesses = businesses;
        _emitDiscoverItems();
      },
      onError: (Object e) {
        debugPrint('[MapEventsScreen] All businesses stream error: $e');
        _latestBusinesses ??= <Business>[];
        _emitDiscoverItems();
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pulseController.dispose();
    _searchDebounce?.cancel();
    _markerThrottleTimer?.cancel();
    _positionSubscription?.cancel();
    _businessSub?.cancel();
    _eventsSub?.cancel();
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
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationStatus = null;
      });

      if (_followUser) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_userLocation!),
        );
      }
    });
  }

  void _recenterOnUser() {
    final user = _userLocation;
    if (user == null) {
      _startLiveTracking();
      return;
    }

    setState(() => _followUser = true);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: user, zoom: 14),
      ),
    );
  }

  void _focusPin(_MapPin pin) {
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

  String _buildDataSignature({
    required List<Map<String, dynamic>> discoverItems,
    required List<dynamic> attractions,
  }) {
    return '${identityHashCode(discoverItems)}:${discoverItems.length}:${identityHashCode(attractions)}:${attractions.length}:${_radiusKm.toStringAsFixed(2)}';
  }

  String _selectedPinSignature() {
    final selected = _selectedPin;
    if (selected == null) {
      return 'none';
    }
    return '${selected.source}:${selected.id}:${selected.type.name}';
  }

  String _userLocationSignature() {
    final user = _userLocation;
    if (user == null) {
      return 'none';
    }
    return '${user.latitude.toStringAsFixed(3)},${user.longitude.toStringAsFixed(3)}';
  }

  List<_MapPin> _getAllPins({
    required List<Map<String, dynamic>> discoverItems,
    required List<dynamic> attractions,
  }) {
    final signature = _buildDataSignature(
      discoverItems: discoverItems,
      attractions: attractions,
    );
    if (_cachedAllPins != null && _cachedAllPinsSignature == signature) {
      return _cachedAllPins!;
    }

    final rebuilt = _buildPins(
      discoverItems: discoverItems,
      attractions: attractions,
    );
    _cachedAllPins = rebuilt;
    _cachedAllPinsSignature = signature;
    _cachedFilteredPins = null;
    _cachedFilteredPinsSignature = null;
    _cachedMarkers = null;
    _cachedMarkersSignature = null;
    return rebuilt;
  }

  /// Rebuild the discover-items stream whenever businesses or events update.
  void _emitDiscoverItems() {
    final businesses = _latestBusinesses;
    final events = _latestEvents;
    if (businesses == null || events == null) return;
    final items = _buildDiscoverItems(businesses, events);
    debugPrint('[MapEventsScreen] Built ${items.length} discover items (radiusKm=$_radiusKm)');
    _discoverItemsController.add(items);
  }

  /// Convert verified businesses and approved events into the discover-item
  /// shape expected by [_discoverPins].
  List<Map<String, dynamic>> _buildDiscoverItems(
    List<Business> businesses,
    List<Map<String, dynamic>> events,
  ) {
    final items = <Map<String, dynamic>>[];

    for (final business in businesses) {
      var lat = business.lat;
      var lng = business.lng;
      // Dev fallback: businesses saved before geocoding fixes get a default
      // Brisbane CBD coordinate with deterministic jitter based on name.
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

    return items;
  }

  List<_MapPin> _getFilteredPins(List<_MapPin> allPins) {
    final selectedTypeName = _selectedType?.name ?? 'all';
    final signature =
        '${_cachedAllPinsSignature ?? 'none'}:$_searchQuery:$selectedTypeName';
    if (_cachedFilteredPins != null && _cachedFilteredPinsSignature == signature) {
      return _cachedFilteredPins!;
    }

    final filtered = _filteredPins(allPins);
    _cachedFilteredPins = filtered;
    _cachedFilteredPinsSignature = signature;
    _cachedMarkers = null;
    _cachedMarkersSignature = null;
    return filtered;
  }

  Set<Marker> _getMarkers(List<_MapPin> pins) {
    final signature =
        '${_cachedFilteredPinsSignature ?? 'none'}:${_selectedPinSignature()}:${_userLocationSignature()}';
    if (_cachedMarkers != null && _cachedMarkersSignature == signature) {
      return _cachedMarkers!;
    }

    final elapsed = DateTime.now().difference(_lastMarkerRebuildAt);
    if (_cachedMarkers != null && elapsed < _markerThrottleWindow) {
      _pendingMarkerSignature = signature;
      _scheduleMarkerRefresh(_markerThrottleWindow - elapsed);
      return _cachedMarkers!;
    }

    final markers = _buildMarkers(pins);
    _cachedMarkers = markers;
    _cachedMarkersSignature = signature;
    _lastMarkerRebuildAt = DateTime.now();
    _pendingMarkerSignature = null;
    return markers;
  }

  void _scheduleMarkerRefresh(Duration delay) {
    if (_markerThrottleTimer?.isActive ?? false) {
      return;
    }

    _markerThrottleTimer = Timer(delay, () {
      _markerThrottleTimer = null;
      if (!mounted || _pendingMarkerSignature == null) {
        return;
      }
      _pendingMarkerSignature = null;
      setState(() {});
    });
  }

  List<_MapPin> _discoverPins(List<Map<String, dynamic>> items) {
    final pins = <_MapPin>[];

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

      late final _MapPinType type;
      switch (section) {
        case 'events':
          type = _MapPinType.event;
          break;
        case 'stadiums':
          type = (textBlob.contains('olympic') || textBlob.contains('2032'))
              ? _MapPinType.olympicVenue
              : _MapPinType.stadium;
          break;
        case 'historical':
          type = textBlob.contains('cultur')
              ? _MapPinType.culturalVenue
              : _MapPinType.attraction;
          break;
        case 'food':
          type = _MapPinType.food;
          break;
        default:
          continue;
      }

      pins.add(
        _MapPin(
          id: id,
          title: title,
          location: (item['location'] as String? ?? 'Location TBA').trim(),
          latitude: lat,
          longitude: lng,
          type: type,
          source: 'events',
        ),
      );
    }

    return pins;
  }


  List<_MapPin> _buildPins({
    required List<Map<String, dynamic>> discoverItems,
    required List<dynamic> attractions,
  }) {
    // Include all discover pins so the type filter can show food, events, etc.
    final combined = _discoverPins(discoverItems);

    final deduped = <String, _MapPin>{};
    for (final pin in combined) {
      final key = '${pin.source}:${pin.id}:${pin.type.name}';
      deduped[key] = pin;
    }

    final pins = deduped.values
        .where((pin) => _isWithinRadius(pin.latitude, pin.longitude))
        .toList(growable: false);
    pins.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    debugPrint('[MapEventsScreen] _buildPins returned ${pins.length} pins within radius');
    return pins;
  }

  List<_MapPin> _filteredPins(List<_MapPin> allPins) {
    final query = _searchQuery;
    return allPins.where((pin) {
      if (_selectedType != null && pin.type != _selectedType) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return pin.title.toLowerCase().contains(query) ||
          pin.location.toLowerCase().contains(query) ||
          _pinTypeLabel(pin.type).toLowerCase().contains(query);
    }).toList(growable: false);
  }

  /// Haversine distance from a reference point to a given lat/lng, in km.
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

  /// Returns true when the point is within [_radiusKm] of Brisbane CBD.
  bool _isWithinRadius(double lat, double lng) {
    return _distanceKm(_brisbaneLat, _brisbaneLng, lat, lng) <= _radiusKm;
  }

  /// Distance from the user (or Brisbane CBD) to a pin, formatted.
  String _distanceLabel(double lat, double lng) {
    final fromLat = _userLocation?.latitude ?? _brisbaneLat;
    final fromLng = _userLocation?.longitude ?? _brisbaneLng;
    final km = _distanceKm(fromLat, fromLng, lat, lng);
    if (km < 1) {
      return '${(km * 1000).round()} m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }

  Color _baseTypeColor(_MapPinType type) {
    switch (type) {
      case _MapPinType.event:
        return const Color(0xFFF2994A);
      case _MapPinType.food:
        return const Color(0xFFEB5757);
      case _MapPinType.stadium:
      case _MapPinType.olympicVenue:
        return const Color(0xFF9B51E0);
      case _MapPinType.attraction:
      case _MapPinType.culturalVenue:
        return const Color(0xFF2F80ED);
    }
  }

  Color _pinColor(_MapPinType type) {
    final base = _baseTypeColor(type);
    if (_selectedType == null || _selectedType == type) {
      return base;
    }
    return const Color(0xFF9FB0C0);
  }

  IconData _pinIcon(_MapPinType type) {
    switch (type) {
      case _MapPinType.event:
        return Icons.event;
      case _MapPinType.attraction:
        return Icons.place;
      case _MapPinType.stadium:
        return Icons.stadium;
      case _MapPinType.olympicVenue:
        return Icons.emoji_events;
      case _MapPinType.culturalVenue:
        return Icons.account_balance;
      case _MapPinType.food:
        return Icons.local_dining;
    }
  }

  String _pinTypeLabel(_MapPinType type) {
    switch (type) {
      case _MapPinType.event:
        return 'Event';
      case _MapPinType.attraction:
        return 'Attraction';
      case _MapPinType.stadium:
        return 'Stadium';
      case _MapPinType.olympicVenue:
        return 'Olympic Venue';
      case _MapPinType.culturalVenue:
        return 'Cultural History';
      case _MapPinType.food:
        return 'Food';
    }
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Future<void> _launchNavigation(_MapPin pin) async {
    // Show travel mode picker
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NavModeSheet(name: pin.title),
    );
    if (mode == null) return;

    final lat = pin.latitude;
    final lng = pin.longitude;

    // Google Maps native app (driving, walking, transit, bicycling)
    final googleNativeUri = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=$mode',
    );
    // Google Maps web fallback
    final googleWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=${_googleWebMode(mode)}',
    );
    // Apple Maps fallback (iOS)
    final appleUri = Uri.parse(
      'maps://?daddr=$lat,$lng&dirflg=${_appleDirFlag(mode)}',
    );

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
      case 'w': return 'walking';
      case 'r': return 'transit';
      case 'b': return 'bicycling';
      default:  return 'driving';
    }
  }

  String _appleDirFlag(String mode) {
    switch (mode) {
      case 'w': return 'w';
      case 'r': return 'r';
      default:  return 'd';
    }
  }

  Set<Marker> _buildMarkers(List<_MapPin> pins) {
    return pins
        .asMap()
        .entries
        .map((entry) => _buildMarker(entry.value, entry.key))
        .toSet();
  }

  Marker _buildMarker(_MapPin pin, int index) {
    final selected = _selectedPin != null &&
        _selectedPin!.id == pin.id &&
        _selectedPin!.source == pin.source &&
        _selectedPin!.type == pin.type;

    return Marker(
      markerId: MarkerId('${pin.source}-${pin.id}'),
      position: LatLng(pin.latitude, pin.longitude),
      infoWindow: InfoWindow(
        title: pin.title,
        snippet: '${_distanceLabel(pin.latitude, pin.longitude)} • ${pin.location}',
      ),
      onTap: () => _focusPin(pin),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _getHueForType(pin.type, selected),
      ),
    );
  }

  double _getHueForType(_MapPinType type, bool selected) {
    if (selected) {
      return BitmapDescriptor.hueYellow;
    }
    
    switch (type) {
      case _MapPinType.event:
        return BitmapDescriptor.hueOrange;
      case _MapPinType.food:
        return BitmapDescriptor.hueRed;
      case _MapPinType.stadium:
      case _MapPinType.olympicVenue:
        return BitmapDescriptor.hueMagenta;
      case _MapPinType.attraction:
      case _MapPinType.culturalVenue:
        return BitmapDescriptor.hueCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _discoverItemsController.stream,
      builder: (context, snapshot) {
        final discoverItems = snapshot.data ?? const <Map<String, dynamic>>[];
        final allPins = _getAllPins(
          discoverItems: discoverItems,
          attractions: const <dynamic>[],
        );
    final pins = _getFilteredPins(allPins);
    final markers = _getMarkers(pins);

    if (pins.isEmpty && _showResultsSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showResultsSheet = false);
        }
      });
    }

    if (_selectedPin != null) {
      final selectedExists = pins.any(
        (pin) => pin.id == _selectedPin!.id &&
            pin.source == _selectedPin!.source &&
            pin.type == _selectedPin!.type,
      );
      if (!selectedExists) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedPin = null);
          }
        });
      }
    }

    final mapCenter = _userLocation ?? _defaultCenter;

    // Google Maps is not supported on macOS. Show a fallback list view so
    // development on macOS still allows testing the rest of the feature.
    final isMacOS = !kIsWeb && Platform.isMacOS;

    final body = Stack(
                children: [
                  if (isMacOS)
                    _MacOSFallbackMap(
                      pins: pins,
                      userLocation: _userLocation,
                      selectedPin: _selectedPin,
                      onPinTap: (pin) => setState(() => _selectedPin = pin),
                    )
                  else
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: mapCenter,
                        zoom: 11.6,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: (_) => setState(() {
                        _selectedPin = null;
                        _followUser = false;
                      }),
                      markers: markers,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: _userLocation != null,
                      zoomControlsEnabled: true,
                      buildingsEnabled: _use3dMode,
                      tiltGesturesEnabled: true,
                      mapType: _useVibrantMap
                          ? MapType.normal
                          : MapType.terrain,
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0x0F0F2740),
                              Colors.transparent,
                              const Color(0x140F2740),
                            ],
                            stops: const [0, 0.32, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.96),
                                Colors.white.withValues(alpha: 0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFD4DBE4)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 12,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              if (widget.onBackPressed != null)
                                GestureDetector(
                                  onTap: widget.onBackPressed,
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.arrow_back_rounded,
                                        color: AppPalette.deepBlue, size: 22),
                                  ),
                                ),
                              const Icon(Icons.search,
                                  color: AppPalette.mutedText, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _handleSearchChanged,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Search places, categories, locations',
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: TextStyle(fontSize: 13),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _handleSearchChanged('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: SizedBox(
                            height: 34,
                            child: Center(
                              child: ChoiceChip(
                                selected: _selectedType == _MapPinType.food,
                                onSelected: (value) => setState(() =>
                                    _selectedType = value ? _MapPinType.food : null),
                                label: const Text('🍽️ Food Places'),
                                avatar: const Icon(
                                  Icons.restaurant_rounded,
                                  size: 14,
                                  color: AppPalette.deepBlue,
                                ),
                                selectedColor: const Color(0xFFDDE8F4),
                                side: BorderSide(
                                  color: _selectedType == _MapPinType.food
                                      ? AppPalette.deepBlue.withValues(alpha: 0.35)
                                      : const Color(0xFFD8DDE4),
                                ),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _selectedType == _MapPinType.food
                                      ? AppPalette.deepBlue
                                      : AppPalette.charcoal,
                                ),
                                backgroundColor: const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                showCheckmark: false,
                              ),
                            ),
                          ),
                        ),
                        if (_locationStatus != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(
                                12, 8, 12, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFDEE3EA)),
                            ),
                            child: Text(
                              _locationStatus!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pins.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No places match your filters right now.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppPalette.mutedText),
                        ),
                      ),
                    )
                  else if (_showResultsSheet)
                    DraggableScrollableSheet(
                      minChildSize: 0.1,
                      initialChildSize: 0.1,
                      maxChildSize: 0.55,
                      snap: true,
                      snapSizes: const [0.1, 0.3, 0.55],
                      builder: (context, controller) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: AppPalette.surface,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(22)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 14,
                                offset: Offset(0, -3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppPalette.border
                                      .withValues(alpha: 0.9),
                                  borderRadius:
                                      BorderRadius.circular(99),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 8, 14, 7),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            '${pins.length} places nearby',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: AppPalette
                                                  .charcoal,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Brisbane CBD + surroundings',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppPalette
                                                  .mutedText
                                                  .withValues(
                                                      alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_userLocation != null)
                                      const Text(
                                        'Live GPS on',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppPalette
                                              .deepBlue,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: 'Hide results',
                                      onPressed: () => setState(
                                          () =>
                                              _showResultsSheet =
                                                  false),
                                      icon: const Icon(
                                        Icons
                                            .keyboard_arrow_down_rounded,
                                        color:
                                            AppPalette.mutedText,
                                      ),
                                      visualDensity:
                                          VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.builder(
                                  controller: controller,
                                  itemCount: pins.length,
                                  itemBuilder: (context, index) {
                                    final pin = pins[index];
                                    final selected =
                                        _selectedPin !=
                                                null &&
                                            _selectedPin!.id ==
                                                pin.id &&
                                            _selectedPin!
                                                .source ==
                                                pin.source &&
                                            _selectedPin!.type ==
                                                pin.type;

                                    return ListTile(
                                      onTap: () =>
                                          _focusPin(pin),
                                      leading:
                                          CircleAvatar(
                                        backgroundColor:
                                            _pinColor(pin
                                                    .type)
                                                .withValues(
                                                    alpha:
                                                        0.14),
                                        child: Icon(
                                          _pinIcon(pin.type),
                                          color: _pinColor(
                                              pin.type),
                                          size: 16,
                                        ),
                                      ),
                                      title: Text(
                                        pin.title,
                                        maxLines: 1,
                                        overflow: TextOverflow
                                            .ellipsis,
                                        style: TextStyle(
                                          fontWeight: selected
                                              ? FontWeight
                                                  .w800
                                              : FontWeight
                                                  .w600,
                                          color: AppPalette
                                              .charcoal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${_pinTypeLabel(pin.type)} • ${_distanceLabel(pin.latitude, pin.longitude)}',
                                        maxLines: 1,
                                        overflow: TextOverflow
                                            .ellipsis,
                                      ),
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                            horizontal: 14,
                                            vertical: 2,
                                          ),
                                      trailing: selected
                                          ? const Icon(
                                              Icons
                                                  .my_location,
                                              color: AppPalette
                                                  .deepBlue)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (_selectedPin != null)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: _showResultsSheet ? 220 : 84,
                      child: Material(
                        color: Colors.white,
                        elevation: 7,
                        borderRadius:
                            BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () =>
                              _focusPin(_selectedPin!),
                          borderRadius:
                              BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 14,
                                vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration:
                                      BoxDecoration(
                                    color: _pinColor(
                                            _selectedPin!
                                                .type)
                                        .withValues(
                                            alpha: 0.16),
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _pinIcon(
                                        _selectedPin!
                                            .type),
                                    color: _pinColor(
                                        _selectedPin!
                                            .type),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedPin!
                                            .title,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight
                                                  .w700,
                                          color: AppPalette
                                              .charcoal,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 2),
                                      Text(
                                        '${_distanceLabel(_selectedPin!.latitude, _selectedPin!.longitude)} • ${_selectedPin!.location}',
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontSize: 12,
                                          color: AppPalette
                                              .mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      'Navigate',
                                  onPressed: () =>
                                      _launchNavigation(
                                          _selectedPin!),
                                  icon: const Icon(
                                      Icons
                                          .directions_rounded,
                                      color: AppPalette
                                          .deepBlue,
                                      size: 20),
                                  visualDensity:
                                      VisualDensity
                                          .compact,
                                ),
                                IconButton(
                                  tooltip:
                                      'Clear selection',
                                  onPressed: () =>
                                      setState(() =>
                                          _selectedPin =
                                              null),
                                  icon: const Icon(
                                      Icons
                                          .close_rounded,
                                      size: 18),
                                  visualDensity:
                                      VisualDensity
                                          .compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 82,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3D toggle
                        Material(
                          color: Colors.transparent,
                          child: Ink(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.97),
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: _use3dMode
                                    ? AppPalette.ochre.withValues(alpha: 0.6)
                                    : const Color(0xFFD4DAE2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x24000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: _use3dMode ? 'Flat view' : '3D buildings',
                              onPressed: () {
                                setState(() => _use3dMode = !_use3dMode);
                                final center = _userLocation ?? _defaultCenter;
                                _mapController?.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: center,
                                      zoom: _use3dMode ? 17 : 14,
                                      tilt: _use3dMode ? 45 : 0,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                _use3dMode
                                    ? Icons.view_in_ar_rounded
                                    : Icons.view_in_ar_outlined,
                                color: _use3dMode
                                    ? AppPalette.ochre
                                    : AppPalette.charcoal,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Map style toggle
                        Material(
                          color: Colors.transparent,
                          child: Ink(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin:
                                    Alignment.topCenter,
                                end: Alignment
                                    .bottomCenter,
                                colors: [
                                  Colors.white
                                      .withValues(
                                          alpha: 0.97),
                                  Colors.white
                                      .withValues(
                                          alpha: 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: _useVibrantMap
                                    ? AppPalette
                                        .deepBlue
                                        .withValues(
                                            alpha:
                                                0.34)
                                    : const Color(
                                        0xFFD4DAE2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      Color(0x24000000),
                                  blurRadius: 10,
                                  offset:
                                      Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip:
                                  _useVibrantMap
                                      ? 'Use clean map style'
                                      : 'Use vibrant map style',
                              onPressed: () => setState(
                                  () => _useVibrantMap =
                                      !_useVibrantMap),
                              icon: Icon(
                                _useVibrantMap
                                    ? Icons
                                        .layers_rounded
                                    : Icons
                                        .map_rounded,
                                color: _useVibrantMap
                                    ? AppPalette
                                        .deepBlue
                                    : AppPalette
                                        .charcoal,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.transparent,
                          child: Ink(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin:
                                    Alignment.topCenter,
                                end: Alignment
                                    .bottomCenter,
                                colors: [
                                  Colors.white
                                      .withValues(
                                          alpha: 0.97),
                                  Colors.white
                                      .withValues(
                                          alpha: 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: _followUser
                                    ? AppPalette
                                        .deepBlue
                                        .withValues(
                                            alpha:
                                                0.34)
                                    : const Color(
                                        0xFFD4DAE2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      Color(0x24000000),
                                  blurRadius: 10,
                                  offset:
                                      Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: _followUser
                                  ? 'Following GPS'
                                  : 'Track Me',
                              onPressed:
                                  _recenterOnUser,
                              icon: Icon(
                                _followUser
                                    ? Icons
                                        .my_location
                                    : Icons
                                        .gps_fixed,
                                color: _followUser
                                    ? AppPalette
                                        .deepBlue
                                    : AppPalette
                                        .charcoal,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.transparent,
                          child: Ink(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin:
                                    Alignment.topCenter,
                                end: Alignment
                                    .bottomCenter,
                                colors: [
                                  Colors.white
                                      .withValues(
                                          alpha: 0.97),
                                  Colors.white
                                      .withValues(
                                          alpha: 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: _showResultsSheet
                                    ? AppPalette
                                        .deepBlue
                                        .withValues(
                                            alpha:
                                                0.34)
                                    : const Color(
                                        0xFFD4DAE2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      Color(0x24000000),
                                  blurRadius: 10,
                                  offset:
                                      Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip:
                                  _showResultsSheet
                                      ? 'Hide results'
                                      : 'Show results (${pins.length})',
                              onPressed: () {
                                if (pins
                                    .isEmpty) {
                                  return;
                                }
                                setState(
                                    () =>
                                        _showResultsSheet =
                                            !_showResultsSheet);
                              },
                              icon: Icon(
                                _showResultsSheet
                                    ? Icons
                                        .expand_more
                                    : Icons
                                        .list_alt_rounded,
                                color: _showResultsSheet
                                    ? AppPalette
                                        .deepBlue
                                    : AppPalette
                                        .charcoal,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

        if (widget.embedded) return body;

        return Scaffold(
          backgroundColor: AppPalette.background,
          appBar: AppBar(
            title: const LogoAppBarTitle('Map Explorer'),
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
          ),
          body: body,
        );
      },
    );
  }
}

class _NavModeSheet extends StatelessWidget {
  const _NavModeSheet({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (icon: Icons.directions_car_rounded,  label: 'Drive',    mode: 'd'),
      (icon: Icons.directions_walk_rounded, label: 'Walk',     mode: 'w'),
      (icon: Icons.directions_bus_rounded,  label: 'Transit',  mode: 'r'),
      (icon: Icons.directions_bike_rounded, label: 'Bicycle',  mode: 'b'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Navigate to $name',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppPalette.deepBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Choose travel mode', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: modes.map((m) => _ModeButton(
              icon: m.icon,
              label: m.label,
              onTap: () => Navigator.pop(context, m.mode),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.ochre,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppPalette.deepBlue)),
        ],
      ),
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

  final List<_MapPin> pins;
  final LatLng? userLocation;
  final _MapPin? selectedPin;
  final ValueChanged<_MapPin> onPinTap;

  double _distanceKm(_MapPin pin) {
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

  IconData _iconForType(_MapPinType type) {
    return switch (type) {
      _MapPinType.food => Icons.restaurant_rounded,
      _MapPinType.event => Icons.event_rounded,
      _MapPinType.attraction => Icons.attractions_rounded,
      _MapPinType.culturalVenue => Icons.museum_rounded,
      _MapPinType.stadium => Icons.stadium_rounded,
      _MapPinType.olympicVenue => Icons.sports_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<_MapPin>.from(pins)
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
                      final isSelected = selectedPin?.id == pin.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppPalette.ochre
                              : AppPalette.deepBlue.withValues(alpha: 0.12),
                          child: Icon(
                            _iconForType(pin.type),
                            color: isSelected
                                ? Colors.white
                                : AppPalette.deepBlue,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          pin.title,
                          style: TextStyle(
                            color: AppPalette.charcoal,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${pin.location} · ${_distanceKm(pin).toStringAsFixed(1)} km',
                          style: TextStyle(color: AppPalette.mutedText),
                        ),
                        tileColor: isSelected
                            ? AppPalette.ochre.withValues(alpha: 0.08)
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
