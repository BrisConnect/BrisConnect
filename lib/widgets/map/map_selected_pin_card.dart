import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/fallback_image.dart';
import 'package:brisconnect/widgets/map/map_live_badges.dart';
import 'package:brisconnect/widgets/map/map_marker_helper.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Card shown when a map pin is tapped.
///
/// Displays an image, name, category, live badges, distance, address,
/// description, rating and quick action buttons.
class MapSelectedPinCard extends StatelessWidget {
  const MapSelectedPinCard({
    super.key,
    required this.pin,
    required this.distanceLabel,
    required this.onNavigate,
    required this.onViewDetails,
    required this.onClose,
  });

  final MapPin pin;
  final String distanceLabel;
  final VoidCallback onNavigate;
  final VoidCallback onViewDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (pin.imageUrl ?? '').trim();
    final badge = (pin.badge ?? '').trim();
    final description = (pin.description ?? '').trim();
    final categories =
        pin.categories ?? (badge.isNotEmpty ? [badge] : const <String>[]);
    final status = MapMarkerHelper().statusForPin(pin);
    final statusColor = MapMarkerHelper.statusColor(status);

    return Hero(
      tag: 'pin-card-${pin.key}',
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onViewDetails,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: FallbackImage(
                  imageUrl: imageUrl,
                  height: 170,
                  width: double.infinity,
                  category: badge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(pin.type.icon, size: 13, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                pin.type.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (pin.rating != null && pin.rating! > 0) ...[
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppPalette.gold, size: 15),
                              const SizedBox(width: 2),
                              Text(
                                pin.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: onClose,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.black54, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pin.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$distanceLabel • ${pin.locationName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MapLiveBadges(pin: pin, compact: true),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categories
                            .take(3)
                            .map(
                              (cat) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppPalette.deepBlue
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  cat,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.deepBlue,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onNavigate,
                            icon:
                                const Icon(Icons.directions_rounded, size: 18),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.ochre,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onViewDetails,
                            icon: const Icon(Icons.info_outline_rounded,
                                size: 18),
                            label: const Text('Details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPalette.deepBlue,
                              side:
                                  const BorderSide(color: AppPalette.deepBlue),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
