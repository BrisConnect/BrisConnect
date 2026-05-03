import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

// ---------------------------------------------------------------------------
// Category enum
// ---------------------------------------------------------------------------

enum AttractionCategory {
  cultural('Cultural', Icons.museum_outlined),
  historical('Historical', Icons.account_balance_outlined),
  food('Food', Icons.restaurant_outlined),
  stadium('Stadium', Icons.stadium_outlined),
  nature('Nature', Icons.park_outlined);

  const AttractionCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

// ---------------------------------------------------------------------------
// Screen widget
// ---------------------------------------------------------------------------

class ApprovedAttractionsMapScreen extends StatefulWidget {
  ApprovedAttractionsMapScreen({
    super.key,
    ApprovedAttractionService? attractionService,
  }) : attractionService = attractionService ?? ApprovedAttractionService();

  final ApprovedAttractionService attractionService;

  @override
  State<ApprovedAttractionsMapScreen> createState() =>
      _ApprovedAttractionsMapScreenState();
}

class _ApprovedAttractionsMapScreenState
    extends State<ApprovedAttractionsMapScreen> {
  late GoogleMapController _mapController;
  static const LatLng _brisbaneCenter = LatLng(-27.4698, 153.0251);

  ApprovedAttraction? _selected;
  final Set<AttractionCategory> _selectedCategories = {};
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;

  @override
  void initState() {
    super.initState();
    _updateUserPreferences();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _updateUserPreferences() {
    final isLocal = LocalAuth.currentLocal != null;
    final isVisitor = VisitorAuth.currentVisitor != null;

    if (isLocal) {
      final local = LocalAuth.currentLocal;
      _radiusKm = local?.locationRadiusKm ?? 20;
      _isUsingRadius = local?.useCurrentLocation ?? true;
    } else if (isVisitor) {
      final visitor = VisitorAuth.currentVisitor;
      _radiusKm = visitor?.locationRadiusKm ?? 20;
      _isUsingRadius = visitor?.useCurrentLocation ?? true;
    } else {
      _radiusKm = 20;
      _isUsingRadius = false;
    }

    // Use default Brisbane location
    final (defaultLat, defaultLon) = LocationUtilities.getDefaultLocation();
    _userLatitude = defaultLat;
    _userLongitude = defaultLon;
  }

  // -------------------------------------------------------------------------
  // Filter helpers
  // -------------------------------------------------------------------------

  List<ApprovedAttraction> _applyFilter(List<ApprovedAttraction> all) {
    var filtered = all;

    // Apply category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((a) {
        final String? cat = a.category?.toLowerCase();
        return _selectedCategories.any((c) => cat == c.label.toLowerCase());
      }).toList();
    }

    // Apply radius filter if enabled
    if (_isUsingRadius && filtered.isNotEmpty) {
      filtered = widget.attractionService.filterByRadius(
        attractions: filtered,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
        radiusKm: _radiusKm,
      );
    }

    return filtered;
  }

  void _toggleCategory(AttractionCategory cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
      // Deselect the info card if the attraction is now filtered out.
      if (_selected != null && _selectedCategories.isNotEmpty) {
        final String? selCat = _selected!.category?.toLowerCase();
        final bool stillVisible =
            _selectedCategories.any((c) => selCat == c.label.toLowerCase());
        if (!stillVisible) _selected = null;
      }
    });
  }

  void _clearCategories() {
    setState(() => _selectedCategories.clear());
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Approved Attractions Map'),
      ),
      body: StreamBuilder<List<ApprovedAttraction>>(
        stream: widget.attractionService.watchApprovedAttractions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InlineStatusMessage(
                  message:
                      'Unable to load approved attractions right now. Please try again.',
                  type: InlineStatusType.error,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                ),
              ),
            );
          }

          final List<ApprovedAttraction> all =
              snapshot.data ?? const <ApprovedAttraction>[];

          // No data at all — show full-screen empty state (no chips yet).
          if (all.isEmpty) {
            return const _EmptyAttractionsState();
          }

          final List<ApprovedAttraction> filtered = _applyFilter(all);
          final bool hasFilter = _selectedCategories.isNotEmpty;

          return Stack(
            children: [
              // ----- Full-screen map ----------------------------------------
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selected != null
                      ? LatLng(_selected!.latitude, _selected!.longitude)
                      : _brisbaneCenter,
                  zoom: 12.8,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onTap: (_) => setState(() => _selected = null),
                markers: filtered
                    .asMap()
                    .entries
                    .map((e) => _buildMarker(e.value, e.key))
                    .toSet(),
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
              ),

              // ----- Top overlay: hint bar + category chips -----------------
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MapHint(
                      total: all.length,
                      filtered: filtered.length,
                      hasFilter: hasFilter,
                    ),
                    const SizedBox(height: 8),
                    _CategoryFilterRow(
                      selected: _selectedCategories,
                      onToggle: _toggleCategory,
                    ),
                  ],
                ),
              ),

              // ----- No-results overlay (filter active, nothing matches) ----
              if (filtered.isEmpty && hasFilter)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _NoFilterResultsCard(
                          key: const Key('no-filter-results'),
                          onClearFilter: _clearCategories,
                        ),
                      ),
                    ),
                  ),
                ),

              // ----- Bottom info card when a marker is tapped ---------------
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: _AttractionInfoCard(
                    attraction: _selected!,
                    allAttractions: all,
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Marker _buildMarker(ApprovedAttraction item, int index) {
    final bool isSelected = _selected?.id == item.id;

    return Marker(
      markerId: MarkerId('attraction-${item.id}'),
      position: LatLng(item.latitude, item.longitude),
      infoWindow: InfoWindow(
        title: item.name,
        snippet: item.location,
      ),
      onTap: () {
        setState(() => _selected = item);
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(item.latitude, item.longitude)),
        );
      },
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isSelected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueOrange,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hint bar
// ---------------------------------------------------------------------------

class _MapHint extends StatelessWidget {
  const _MapHint({
    required this.total,
    required this.filtered,
    required this.hasFilter,
  });

  final int total;
  final int filtered;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final String text = hasFilter
        ? 'Showing $filtered of $total approved attractions. Tap a marker for details.'
        : 'Showing $total admin-approved attractions. Tap a marker for details.';

    return Card(
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppPalette.deepBlue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppPalette.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter chip row
// ---------------------------------------------------------------------------

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.selected,
    required this.onToggle,
  });

  final Set<AttractionCategory> selected;
  final ValueChanged<AttractionCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AttractionCategory.values.map((cat) {
          final bool isSelected = selected.contains(cat);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: Key('category-chip-${cat.name}'),
              avatar: Icon(
                cat.icon,
                size: 16,
                color: isSelected ? Colors.white : AppPalette.deepBlue,
              ),
              label: Text(cat.label),
              selected: isSelected,
              onSelected: (_) => onToggle(cat),
              selectedColor: AppPalette.deepBlue,
              backgroundColor: AppPalette.surface,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppPalette.charcoal,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: isSelected ? AppPalette.deepBlue : AppPalette.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-results card (filter active but nothing matches)
// ---------------------------------------------------------------------------

class _NoFilterResultsCard extends StatelessWidget {
  const _NoFilterResultsCard({super.key, required this.onClearFilter});

  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 40, color: AppPalette.mutedText),
            const SizedBox(height: 10),
            const Text(
              'No attractions found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No approved attractions match the selected categories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.mutedText),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.filter_alt_off_outlined,
                  size: 16, color: AppPalette.deepBlue),
              label: const Text(
                'Clear filters',
                style: TextStyle(
                  color: AppPalette.deepBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attraction info card (bottom overlay on marker tap)
// ---------------------------------------------------------------------------

class _AttractionInfoCard extends StatelessWidget {
  const _AttractionInfoCard({
    required this.attraction,
    required this.allAttractions,
    required this.onClose,
  });

  final ApprovedAttraction attraction;
  final List<ApprovedAttraction> allAttractions;
  final VoidCallback onClose;

  Future<void> _launchNavigation(
      BuildContext context, ApprovedAttraction item) async {
    final googleMapsUri = Uri.parse(
      'google.navigation:q=${item.latitude},${item.longitude}&mode=d',
    );
    final fallbackUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${item.latitude},${item.longitude}'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
    } else if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open navigation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_rounded, color: AppPalette.ochre),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attraction.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close details',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    attraction.location,
                    style: const TextStyle(
                      color: AppPalette.deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (attraction.category != null)
                  Chip(
                    label: Text(
                      attraction.category!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.deepBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppPalette.surface,
                    side: const BorderSide(color: AppPalette.border),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              attraction.description,
              style: const TextStyle(color: AppPalette.charcoal),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchNavigation(context, attraction),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.deepBlue,
                      side: const BorderSide(color: AppPalette.deepBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttractionDetailScreen(
                            attraction: attraction,
                            allAttractions: allAttractions,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (no approved attractions in DB at all)
// ---------------------------------------------------------------------------

class _EmptyAttractionsState extends StatelessWidget {
  const _EmptyAttractionsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: AppPalette.surface,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, size: 42, color: AppPalette.mutedText),
                SizedBox(height: 12),
                Text(
                  'No approved attractions available yet.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Attractions will appear here once approved by admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
