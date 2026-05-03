import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/approved_attractions_map_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/location_utilities.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/venue_image_fallback.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AttractionsScreen extends StatefulWidget {
  AttractionsScreen({
    super.key,
    ApprovedAttractionService? attractionService,
  }) : attractionService = attractionService ?? ApprovedAttractionService();

  final ApprovedAttractionService attractionService;

  @override
  State<AttractionsScreen> createState() => _AttractionsScreenState();
}

class _AttractionsScreenState extends State<AttractionsScreen> {
  late double _userLatitude;
  late double _userLongitude;
  late int _radiusKm;
  late bool _isUsingRadius;
  late final Stream<List<ApprovedAttraction>> _attractionsStream =
      widget.attractionService.watchApprovedAttractions();

  @override
  void initState() {
    super.initState();
    _updateUserPreferences();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Cultural Attractions'),
        actions: [
          IconButton(
            tooltip: 'Approved attractions map',
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApprovedAttractionsMapScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ApprovedAttraction>>(
        stream: _attractionsStream,
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
                      'Unable to load attractions right now. Please try again.',
                  type: InlineStatusType.error,
                  actionLabel: 'Retry',
                  onAction: () {},
                ),
              ),
            );
          }

          var attractions = snapshot.data ?? const <ApprovedAttraction>[];

          // Apply radius filtering if user has location enabled
          if (_isUsingRadius && attractions.isNotEmpty) {
            attractions = widget.attractionService.filterByRadius(
              attractions: attractions,
              userLatitude: _userLatitude,
              userLongitude: _userLongitude,
              radiusKm: _radiusKm,
            );
          }

          if (attractions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No approved attractions available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: attractions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final attraction = attractions[index];
              return Card(
                key: ValueKey(attraction.id),
                color: AppPalette.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttractionDetailScreen(
                          attraction: attraction,
                          allAttractions: attractions,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final fallback = VenueImageFallback.forVenue(
                            title: attraction.name,
                            section: 'historical',
                          );
                          final effectiveUrl =
                              (attraction.imageUrl ?? '').trim().isEmpty
                                  ? fallback
                                  : attraction.imageUrl!;

                          return CachedNetworkImage(
                            imageUrl: effectiveUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, _) => Container(
                              height: 160,
                              color: AppPalette.surfaceAlt,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.deepBlue,
                                ),
                              ),
                            ),
                            errorWidget: (context, _, __) => Image.network(
                              fallback,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Container(
                                height: 160,
                                color: AppPalette.surfaceAlt,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppPalette.mutedText,
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.place, color: AppPalette.ochre),
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
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppPalette.mutedText),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              attraction.category ?? 'Attraction',
                              style: const TextStyle(
                                color: AppPalette.deepBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        const SizedBox(height: 2),
                        Text(
                          attraction.location,
                          style: const TextStyle(color: AppPalette.mutedText),
                        ),
                        const SizedBox(height: 8),
                            Text(
                              attraction.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppPalette.charcoal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
