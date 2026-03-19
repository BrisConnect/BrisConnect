import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:brisconnect/models/map_location.dart';
import 'package:brisconnect/theme/app_palette.dart';

class MapEventsScreen extends StatefulWidget {
  const MapEventsScreen({super.key});

  @override
  State<MapEventsScreen> createState() => _MapEventsScreenState();
}

class _MapEventsScreenState extends State<MapEventsScreen> {
  // ─────────────────────────────────── constants ──────────────────────────────
  static const LatLng _brisbaneCenter = LatLng(-27.4698, 153.0251);
  static const double _radiusKm = 5.0;
  static const double _initialZoom = 13.5;

  // ─────────────────────────────────── state ──────────────────────────────────
  MapLocationCategory? _activeFilter; // null = All
  MapLocation? _selected;

  // ─────────────────────────────────── dummy data ─────────────────────────────
  // All coordinates verified within 5 km of Brisbane CBD (-27.4698, 153.0251).
  // Replace the list with an API call to integrate live data.
  static const List<MapLocation> _allLocations = [
    // ── Cultural ────────────────────────────────────────────────────────────
    MapLocation(
      id: 'cul_1',
      title: 'GOMA Art Exhibition',
      description:
          'Latest contemporary collection at Gallery of Modern Art, featuring Australian and international works.',
      address: 'Stanley Place, South Brisbane',
      lat: -27.4705,
      lng: 153.0198,
      category: MapLocationCategory.cultural,
      imageUrl:
          'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'cul_2',
      title: 'South Bank Festival Stage',
      description:
          "Annual multicultural festival celebrating Brisbane's diverse communities with performances and food.",
      address: 'South Bank Parklands, South Brisbane',
      lat: -27.4758,
      lng: 153.0207,
      category: MapLocationCategory.cultural,
      imageUrl:
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'cul_3',
      title: 'Fortitude Valley Art Walk',
      description:
          "Self-guided street art and gallery trail through the Valley's creative precinct.",
      address: 'Brunswick Street, Fortitude Valley',
      lat: -27.4582,
      lng: 153.0362,
      category: MapLocationCategory.cultural,
      imageUrl:
          'https://images.unsplash.com/photo-1499781350541-7783f6c6a0c8?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'cul_4',
      title: 'Kurilpa Community Space',
      description:
          'Regular community workshops, exhibitions, and creative gatherings in a welcoming venue.',
      address: 'Kurilpa Street, West End',
      lat: -27.4803,
      lng: 152.9989,
      category: MapLocationCategory.cultural,
      imageUrl:
          'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=800&q=80',
    ),

    // ── Events ──────────────────────────────────────────────────────────────
    MapLocation(
      id: 'evt_1',
      title: 'Brisbane Twilight Music in the Park',
      description:
          'Free live performances from local artists at Roma Street Parkland stage every Friday evening.',
      address: 'Roma Street Parkland, Brisbane City',
      lat: -27.4636,
      lng: 153.0185,
      category: MapLocationCategory.events,
      imageUrl:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'evt_2',
      title: 'South Bank Night Market',
      description:
          'Weekly cultural night market featuring artisan stalls and multicultural food experiences.',
      address: 'Little Stanley Street, South Brisbane',
      lat: -27.4774,
      lng: 153.0216,
      category: MapLocationCategory.events,
      imageUrl:
          'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'evt_3',
      title: 'Brisbane River Festival',
      description:
          'Family-friendly riverside activities, workshops, and entertainment on the CBD riverfront.',
      address: 'Riverside Precinct, Brisbane City',
      lat: -27.4676,
      lng: 153.0323,
      category: MapLocationCategory.events,
      imageUrl:
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'evt_4',
      title: 'Laneway Espresso Brunch Market',
      description:
          "Weekend brunch market and specialty coffee showcase in the Valley's iconic laneways.",
      address: 'Winn Lane, Fortitude Valley',
      lat: -27.4591,
      lng: 153.0340,
      category: MapLocationCategory.events,
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'evt_5',
      title: 'New Farm Farmers Market',
      description:
          'Saturday morning local produce, artisan goods, and community food stalls at New Farm Park.',
      address: 'New Farm Park, New Farm',
      lat: -27.4680,
      lng: 153.0551,
      category: MapLocationCategory.events,
      imageUrl:
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=800&q=80',
    ),

      // -- Olympic Venues ------------------------------------------------------
      MapLocation(
        id: 'oly_1',
        title: 'The Gabba Stadium',
        description:
          'Major Brisbane cricket and AFL venue planned as a key Brisbane 2032 competition and ceremony precinct.',
        address: 'Vulture Street, Woolloongabba',
        lat: -27.4850,
        lng: 153.0389,
        category: MapLocationCategory.olympicVenue,
        imageUrl:
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=80',
      ),
      MapLocation(
        id: 'oly_2',
        title: 'Suncorp Stadium',
        description:
          'Iconic rectangular stadium in Milton expected to host major football and rugby fixtures during Brisbane 2032.',
        address: 'Castlemaine Street, Milton',
        lat: -27.4649,
        lng: 152.9905,
        category: MapLocationCategory.olympicVenue,
        imageUrl:
          'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=800&q=80',
      ),
      MapLocation(
        id: 'oly_3',
        title: 'RNA Showgrounds',
        description:
          'Inner-city showgrounds precinct expected to be used as an event and venue cluster for Brisbane 2032.',
        address: 'Gregory Terrace, Bowen Hills',
        lat: -27.4522,
        lng: 153.0281,
        category: MapLocationCategory.olympicVenue,
        imageUrl:
          'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=800&q=80',
      ),
      MapLocation(
        id: 'oly_4',
        title: 'Ballymore Stadium',
        description:
          'Historic Brisbane rugby venue likely to support training and competition activities in the Olympic period.',
        address: 'Clyde Road, Herston',
        lat: -27.4460,
        lng: 153.0127,
        category: MapLocationCategory.olympicVenue,
        imageUrl:
          'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&w=800&q=80',
      ),
      MapLocation(
        id: 'oly_5',
        title: 'Victoria Park Venue Precinct',
        description:
          'Planned inner-Brisbane sport and entertainment precinct area linked to Brisbane 2032 venue planning.',
        address: 'Victoria Park, Herston',
        lat: -27.4538,
        lng: 153.0187,
        category: MapLocationCategory.olympicVenue,
        imageUrl:
          'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80',
      ),

    // ── Historical ──────────────────────────────────────────────────────────
    MapLocation(
      id: 'hist_1',
      title: 'Brisbane City Hall',
      description:
          'Iconic 1930s heritage building with a grand auditorium, clock tower, and Museum of Brisbane.',
      address: 'King George Square, Brisbane City',
      lat: -27.4678,
      lng: 153.0226,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1477512076069-d5746aa5b6f8?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'hist_2',
      title: 'Old Windmill Tower',
      description:
          "Queensland's oldest surviving building — a convict-era structure dating back to 1828.",
      address: 'Wickham Park, Spring Hill',
      lat: -27.4612,
      lng: 153.0234,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'hist_3',
      title: 'Commissariat Store',
      description:
          'Convict-built 1828 heritage store, now a museum of transportation history in Queensland.',
      address: 'William Street, Brisbane City',
      lat: -27.4700,
      lng: 153.0200,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'hist_4',
      title: 'Story Bridge',
      description:
          "Brisbane's iconic 1940s cantilever bridge — climb experiences available with panoramic city views.",
      address: 'Kangaroo Point / Fortitude Valley',
      lat: -27.4641,
      lng: 153.0398,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1517090504586-fde19ea6066f?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'hist_5',
      title: 'Queensland Parliament House',
      description:
          'Magnificent 1868 colonial-era building with free guided tours of the legislative chambers.',
      address: 'George Street, Brisbane City',
      lat: -27.4730,
      lng: 153.0215,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=800&q=80',
    ),
    MapLocation(
      id: 'hist_6',
      title: 'St Johns Anglican Cathedral',
      description:
          "One of Australia's finest examples of sacred Gothic-Revival architecture, completed in 2009.",
      address: 'Ann Street, Brisbane City',
      lat: -27.4631,
      lng: 153.0260,
      category: MapLocationCategory.historical,
      imageUrl:
          'https://images.unsplash.com/photo-1529154036614-a60975f5c760?auto=format&fit=crop&w=800&q=80',
    ),
  ];

  // ───────────────────────────── helpers ──────────────────────────────────────

  /// Haversine formula — returns distance in km between two lat/lng points.
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;

  List<MapLocation> get _visibleLocations {
    return _allLocations.where((loc) {
      final inRadius = _haversine(
            _brisbaneCenter.latitude,
            _brisbaneCenter.longitude,
            loc.lat,
            loc.lng,
          ) <=
          _radiusKm;
      final matchesFilter =
          _activeFilter == null || loc.category == _activeFilter;
      return inRadius && matchesFilter;
    }).toList();
  }

  // ───────────────────────────── marker helpers ────────────────────────────────

  Color _markerColor(MapLocationCategory cat) {
    switch (cat) {
      case MapLocationCategory.cultural:
        return const Color(0xFF9C27B0); // purple
      case MapLocationCategory.events:
        return AppPalette.deepBlue;
      case MapLocationCategory.historical:
        return const Color(0xFF8D6E26); // warm brown / gold
      case MapLocationCategory.olympicVenue:
        return const Color(0xFFB3261E); // olympic venue red
    }
  }

  IconData _markerIcon(MapLocationCategory cat) {
    switch (cat) {
      case MapLocationCategory.cultural:
        return Icons.palette_rounded;
      case MapLocationCategory.events:
        return Icons.event_rounded;
      case MapLocationCategory.historical:
        return Icons.account_balance_rounded;
      case MapLocationCategory.olympicVenue:
        return Icons.stadium_rounded;
    }
  }

  // ───────────────────────────── bottom sheet ──────────────────────────────────

  void _showDetailSheet(MapLocation loc) {
    final dist = _haversine(
      _brisbaneCenter.latitude,
      _brisbaneCenter.longitude,
      loc.lat,
      loc.lng,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // Image
              if (loc.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: loc.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: AppPalette.surfaceAlt,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: AppPalette.surfaceAlt,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppPalette.mutedText,
                        size: 32,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _markerColor(loc.category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        loc.categoryLabel,
                        style: TextStyle(
                          color: _markerColor(loc.category),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      loc.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 15, color: AppPalette.deepBlue),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            loc.address,
                            style: const TextStyle(
                              color: AppPalette.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded,
                            size: 15, color: AppPalette.ochre),
                        const SizedBox(width: 5),
                        Text(
                          '${dist.toStringAsFixed(1)} km from Brisbane CBD',
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      loc.description,
                      style: const TextStyle(
                        color: AppPalette.charcoal,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('View Details: ${loc.title}')),
                          );
                        },
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.deepBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────── filter chips ───────────────────────────────

  Widget _buildFilterChips() {
    const chips = [
      (label: 'All', value: null),
      (label: 'Cultural', value: MapLocationCategory.cultural),
      (label: 'Events', value: MapLocationCategory.events),
      (label: 'Historical', value: MapLocationCategory.historical),
      (label: 'Olympic Venues', value: MapLocationCategory.olympicVenue),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: chips.map((chip) {
          final selected = _activeFilter == chip.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = chip.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppPalette.deepBlue : AppPalette.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: selected ? AppPalette.deepBlue : AppPalette.border,
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: AppPalette.cardShadow,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppPalette.charcoal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────────────── category legend ───────────────────────────────

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: const Color(0xFF9C27B0), label: 'Cultural'),
          const SizedBox(width: 10),
          _LegendDot(color: AppPalette.deepBlue, label: 'Events'),
          const SizedBox(width: 10),
          _LegendDot(color: const Color(0xFF8D6E26), label: 'Historical'),
          const SizedBox(width: 10),
          _LegendDot(color: const Color(0xFFB3261E), label: 'Olympic'),
        ],
      ),
    );
  }

  // ─────────────────────────────── map markers ────────────────────────────────

  List<Marker> get _markers {
    return _visibleLocations.map((loc) {
      final isSelected = _selected?.id == loc.id;
      final color = _markerColor(loc.category);
      final icon = _markerIcon(loc.category);
      final size = isSelected ? 52.0 : 42.0;

      return Marker(
        point: LatLng(loc.lat, loc.lng),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = loc);
            _showDetailSheet(loc);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isSelected ? 40 : 32,
                height: isSelected ? 40 : 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon,
                    color: Colors.white, size: isSelected ? 22 : 18),
              ),
              // Tail
              Container(
                width: 2,
                height: 8,
                color: color,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ─────────────────────────────── radius circle ──────────────────────────────

  CircleMarker get _radiusCircle => CircleMarker(
        point: _brisbaneCenter,
        radius: _radiusKm * 1000, // flutter_map uses metres
        useRadiusInMeter: true,
        color: AppPalette.deepBlue.withValues(alpha: 0.07),
        borderColor: AppPalette.deepBlue.withValues(alpha: 0.28),
        borderStrokeWidth: 1.5,
      );

  // ─────────────────────────────── build ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Map ────────────────────────────────────────────────────────
            FlutterMap(
              options: MapOptions(
                initialCenter: _brisbaneCenter,
                initialZoom: _initialZoom,
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.brisconnect',
                ),
                CircleLayer(circles: [_radiusCircle]),
                MarkerLayer(markers: _markers),
              ],
            ),

            // ── Top overlay ────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Search bar row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppPalette.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppPalette.cardShadow,
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceAlt,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                              ),
                              color: AppPalette.deepBlue,
                              tooltip: 'Return',
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on_rounded,
                              color: AppPalette.ochre, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Explore Brisbane Nearby',
                              style: TextStyle(
                                color: AppPalette.charcoal,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceAlt,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.radio_button_checked_rounded,
                                    size: 13, color: AppPalette.deepBlue),
                                SizedBox(width: 4),
                                Text(
                                  '5 km radius',
                                  style: TextStyle(
                                    color: AppPalette.deepBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter chips
                  _buildFilterChips(),
                ],
              ),
            ),

            // ── Legend ────────────────────────────────────────────────────
            Positioned(
              bottom: 16,
              left: 12,
              child: _buildLegend(),
            ),

            // ── Count badge ───────────────────────────────────────────────
            Positioned(
              bottom: 16,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.deepBlue,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                    BoxShadow(
                      color: AppPalette.cardShadow,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '${_visibleLocations.length} location${_visibleLocations.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── sub-widgets ──────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppPalette.charcoal,
          ),
        ),
      ],
    );
  }
}
