import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/map/map_live_badges.dart';
import 'package:brisconnect/widgets/map/map_marker_helper.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Draggable results sheet that lists the currently visible pins.
class MapResultsBottomSheet extends StatelessWidget {
  const MapResultsBottomSheet({
    super.key,
    required this.pins,
    required this.selectedPin,
    required this.controller,
    required this.onPinTap,
    required this.onDismiss,
    required this.userLocationActive,
    this.subtitle = 'Brisbane CBD + surroundings',
  });

  final List<MapPin> pins;
  final MapPin? selectedPin;
  final ScrollController controller;
  final ValueChanged<MapPin> onPinTap;
  final VoidCallback onDismiss;
  final bool userLocationActive;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: 0.12,
      initialChildSize: 0.12,
      maxChildSize: 0.6,
      snap: true,
      snapSizes: const [0.12, 0.35, 0.6],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppPalette.border.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pins.length} places nearby',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppPalette.charcoal,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppPalette.mutedText.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (userLocationActive)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gps_fixed_rounded,
                                size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Live GPS',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      tooltip: 'Hide results',
                      onPressed: onDismiss,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppPalette.mutedText),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: pins.length,
                  itemBuilder: (context, index) {
                    final pin = pins[index];
                    final selected = selectedPin?.key == pin.key;
                    final status = MapMarkerHelper().statusForPin(pin);
                    final color = MapMarkerHelper.statusColor(status);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: selected
                          ? color.withValues(alpha: 0.06)
                          : Colors.transparent,
                      child: ListTile(
                        onTap: () => onPinTap(pin),
                        leading: Hero(
                          tag: 'pin-avatar-${pin.key}',
                          child: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(pin.type.icon, color: color, size: 18),
                          ),
                        ),
                        title: Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: AppPalette.charcoal,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pin.type.label} • ${pin.locationName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppPalette.mutedText.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            MapLiveBadges(pin: pin, compact: true, spacing: 4),
                          ],
                        ),
                        isThreeLine: pin.crowdLevel != null ||
                            pin.waitTime != null ||
                            pin.isOpenNow != null ||
                            pin.isPremium ||
                            pin.isVerified ||
                            pin.isPopular,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        trailing: selected
                            ? const Icon(Icons.my_location,
                                color: AppPalette.deepBlue)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
