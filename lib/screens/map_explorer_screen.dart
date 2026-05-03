import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
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

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final DiscoverDataService _discoverDataService = DiscoverDataService();
  final ApprovedAttractionService _approvedAttractionService =
      ApprovedAttractionService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<Map<String, dynamic>>> _discoverStream =
      _discoverDataService.watchApprovedDiscoverItems();
  late final Stream<List<ApprovedAttraction>> _attractionsStream =
      _approvedAttractionService.watchApprovedAttractions();

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
  
  _MapPin? _selectedPin;
  LatLng? _userLocation;
  bool _followUser = true;
  bool _showResultsSheet = false;
  bool _useVibrantMap = true;
  String? _locationStatus;
  String _searchQuery = '';
  _MapPinType? _selectedType;

  static const LatLng _defaultCenter = LatLng(-27.4698, 153.0251);
  static const Duration _markerThrottleWindow = Duration(milliseconds: 140);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Don't auto-track GPS on emulator — start at Brisbane default.
    // Live tracking can be triggered by the user tapping the recenter button.
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pulseController.dispose();
    _searchDebounce?.cancel();
    _markerThrottleTimer?.cancel();
    _positionSubscription?.cancel();
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
    required List<ApprovedAttraction> attractions,
  }) {
    // Stream snapshots usually keep list identity stable across local setState
    // calls, so this avoids recomputing expensive pin and marker sets.
    return '${identityHashCode(discoverItems)}:${discoverItems.length}:${identityHashCode(attractions)}:${attractions.length}';
  }

  String _selectedPinSignature() {
    final selected = _selectedPin;
    if (selected == null) {
      return 'none';
    }
    return '${selected.source}:${selected.id}:${selected.type.name}';
  }

  List<_MapPin> _getAllPins({
    required List<Map<String, dynamic>> discoverItems,
    required List<ApprovedAttraction> attractions,
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

  List<_MapPin> _getFilteredPins(List<_MapPin> allPins) {
    final signature = '${_cachedAllPinsSignature ?? 'none'}:${_searchQuery}:${_selectedType?.name ?? 'all'}';
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
    final signature = '${_cachedFilteredPinsSignature ?? 'none'}:${_selectedPinSignature()}';
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
          source: 'discover_items',
        ),
      );
    }

    return pins;
  }

  List<_MapPin> _attractionPins(List<ApprovedAttraction> attractions) {
    return attractions.map((item) {
      final blob = [
        item.name,
        item.location,
        item.category ?? '',
        item.description,
      ].join(' ').toLowerCase();

      final isOlympicVenue = blob.contains('olympic') ||
          blob.contains('brisbane 2032') ||
          (blob.contains('venue') && blob.contains('sport'));
      final isCulturalVenue = blob.contains('cultur') ||
          blob.contains('museum') ||
          blob.contains('gallery') ||
          blob.contains('heritage');

      final type = isOlympicVenue
          ? _MapPinType.olympicVenue
          : (isCulturalVenue ? _MapPinType.culturalVenue : _MapPinType.attraction);

      return _MapPin(
        id: item.id,
        title: item.name,
        location: item.location,
        latitude: item.latitude,
        longitude: item.longitude,
        type: type,
        source: 'attractions',
      );
    }).toList(growable: false);
  }

  List<_MapPin> _buildPins({
    required List<Map<String, dynamic>> discoverItems,
    required List<ApprovedAttraction> attractions,
  }) {
    final combined = <_MapPin>[
      ..._discoverPins(discoverItems),
      ..._attractionPins(attractions),
    ];

    final deduped = <String, _MapPin>{};
    for (final pin in combined) {
      final key = '${pin.source}:${pin.id}:${pin.type.name}';
      deduped[key] = pin;
    }

    final pins = deduped.values.toList(growable: false);
    pins.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
        return 'Cultural Venue';
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
        snippet: pin.location,
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
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Map Explorer'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _discoverStream,
        builder: (context, discoverSnapshot) {
          if (discoverSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (discoverSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load map locations right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return StreamBuilder<List<ApprovedAttraction>>(
            stream: _attractionsStream,
            builder: (context, attractionSnapshot) {
              if (attractionSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (attractionSnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to load attraction locations right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.mutedText),
                    ),
                  ),
                );
              }

                final allPins = _getAllPins(
                discoverItems:
                    discoverSnapshot.data ?? const <Map<String, dynamic>>[],
                attractions:
                    attractionSnapshot.data ?? const <ApprovedAttraction>[],
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

              return Stack(
                children: [
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
                    myLocationButtonEnabled: true,
                    myLocationEnabled: _userLocation != null,
                    zoomControlsEnabled: true,
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
                          height: 48,
                          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppPalette.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: AppPalette.ochre, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _handleSearchChanged,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Search places, categories, locations',
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: TextStyle(
                                      fontSize: 13.5,
                                      color: AppPalette.mutedText,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppPalette.mutedText),
                                  onPressed: () {
                                    _searchController.clear();
                                    _handleSearchChanged('');
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    selected: _selectedType == null,
                                    onSelected: (_) => setState(
                                        () => _selectedType = null),
                                    label: const Text('All'),
                                    selectedColor:
                                        const Color(0xFFDDE8F4),
                                    backgroundColor:
                                        const Color(0xFFF8FAFC),
                                    side: BorderSide(
                                      color: _selectedType == null
                                          ? AppPalette.deepBlue
                                              .withValues(alpha: 0.35)
                                          : const Color(0xFFD8DDE4),
                                    ),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: _selectedType == null
                                          ? AppPalette.deepBlue
                                          : AppPalette.charcoal,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize
                                            .shrinkWrap,
                                    visualDensity:
                                        VisualDensity.compact,
                                    showCheckmark: false,
                                  ),
                                ),
                                ..._MapPinType.values
                                    .map((type) => Padding(
                                          padding:
                                              const EdgeInsets.only(
                                                  right: 8),
                                          child: ChoiceChip(
                                            selected:
                                                _selectedType == type,
                                            onSelected: (value) => setState(() =>
                                                _selectedType =
                                                    value ? type : null),
                                            label: Text(
                                                _pinTypeLabel(
                                                    type)),
                                            avatar: Icon(
                                              _pinIcon(type),
                                              size: 14,
                                              color: _selectedType ==
                                                      type
                                                  ? AppPalette
                                                      .deepBlue
                                                  : AppPalette
                                                      .mutedText,
                                            ),
                                            selectedColor:
                                                const Color(
                                                    0xFFDDE8F4),
                                            side: BorderSide(
                                              color: _selectedType ==
                                                      type
                                                  ? AppPalette
                                                      .deepBlue
                                                      .withValues(
                                                          alpha:
                                                              0.35)
                                                  : const Color(
                                                      0xFFD8DDE4),
                                            ),
                                            labelStyle: TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 12,
                                              color: _selectedType ==
                                                      type
                                                  ? AppPalette
                                                      .deepBlue
                                                  : AppPalette
                                                      .charcoal,
                                            ),
                                            backgroundColor:
                                                const Color(
                                                    0xFFF8FAFC),
                                            shape:
                                                RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          20),
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity
                                                    .compact,
                                            showCheckmark: false,
                                          ),
                                        ))
                              ],
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
                      minChildSize: 0.09,
                      initialChildSize: 0.09,
                      maxChildSize: 0.55,
                      snap: true,
                      snapSizes: const [0.09, 0.3, 0.55],
                      builder: (context, controller) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.brown.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppPalette.border,
                                  borderRadius:
                                      BorderRadius.circular(99),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 10, 14, 8),
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
                                        '${_pinTypeLabel(pin.type)} • ${pin.location}',
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
                      left: 16,
                      right: 16,
                      bottom: _showResultsSheet ? 220 : 84,
                      child: Material(
                        color: Colors.white,
                        elevation: 0,
                        borderRadius:
                            BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.brown.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                          onTap: () =>
                              _focusPin(_selectedPin!),
                          borderRadius:
                              BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 16,
                                vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration:
                                      BoxDecoration(
                                    color: _pinColor(
                                            _selectedPin!
                                                .type)
                                        .withValues(
                                            alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _pinIcon(
                                        _selectedPin!
                                            .type),
                                    color: _pinColor(
                                        _selectedPin!
                                            .type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                        _selectedPin!
                                            .location,
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
                    ),
                  Positioned(
                    right: 12,
                    bottom: 82,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
            },
          );
        },
      ),
    );
  }
}
