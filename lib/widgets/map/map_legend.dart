import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/map/map_marker_helper.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Floating legend explaining map marker and cluster colours.
///
/// Designed to sit in a corner of the map and remain fully visible. On mobile
/// the legend is collapsed to a compact button that expands into a popup,
/// keeping it out of the way of map interactions.
class MapLegend extends StatefulWidget {
  const MapLegend({super.key});

  @override
  State<MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<MapLegend> {
  bool _expanded = false;

  static const List<_LegendItem> _items = [
    _LegendItem(
      color: Color(0xFF10B981),
      label: 'Open',
      icon: Icons.check_circle_rounded,
    ),
    _LegendItem(
      color: Color(0xFFF59E0B),
      label: 'Trending',
      icon: Icons.local_fire_department_rounded,
    ),
    _LegendItem(
      color: Color(0xFF8B5CF6),
      label: 'Premium',
      icon: Icons.workspace_premium_rounded,
    ),
    _LegendItem(
      color: AppPalette.deepBlue,
      label: 'Verified',
      icon: Icons.verified_rounded,
    ),
    _LegendItem(
      color: Color(0xFF9CA3AF),
      label: 'Closed',
      icon: Icons.cancel_rounded,
    ),
  ];

  static const List<_ClusterLegendItem> _clusterItems = [
    _ClusterLegendItem(
      color: Color(0xFF10B981),
      range: '1–10',
    ),
    _ClusterLegendItem(
      color: Color(0xFFFACC15),
      range: '11–30',
    ),
    _ClusterLegendItem(
      color: Color(0xFFF59E0B),
      range: '31–60',
    ),
    _ClusterLegendItem(
      color: Color(0xFFEF4444),
      range: '60+',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    if (!isMobile) {
      return _buildExpandedCard();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _expanded
          ? Stack(
              alignment: Alignment.bottomLeft,
              children: [
                _buildExpandedCard(),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _buildCollapseButton(),
                ),
              ],
            )
          : _buildExpandButton(),
    );
  }

  Widget _buildExpandButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => setState(() => _expanded = true),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppPalette.deepBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _expanded = false),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: AppPalette.mutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppPalette.mutedText,
                ),
                const SizedBox(width: 6),
                Text(
                  'Map Legend',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(item.icon, size: 14, color: item.color),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Text(
              'Clusters',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppPalette.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: _clusterItems
                  .map(
                    (item) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.range,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;
}

class _ClusterLegendItem {
  const _ClusterLegendItem({
    required this.color,
    required this.range,
  });

  final Color color;
  final String range;
}

/// A simple popup shown when a cluster is tapped.
///
/// Shows the number of items, a short breakdown and a call-to-action to zoom
/// or view the list.
class ClusterInfoPopup extends StatelessWidget {
  const ClusterInfoPopup({
    super.key,
    required this.count,
    required this.type,
    required this.topRated,
    required this.openNow,
    required this.trending,
    required this.onViewBusinesses,
    required this.onZoomIn,
  });

  final int count;
  final MapPinType type;
  final int topRated;
  final int openNow;
  final int trending;
  final VoidCallback onViewBusinesses;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 20,
                    color: AppPalette.ochre,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count ${type.label} ${count == 1 ? 'Business' : 'Businesses'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zoom in or view the list',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedText.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: '$topRated Top Rated',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF10B981),
              label: '$openNow Open Now',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: '$trending Trending',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onZoomIn,
                    icon: const Icon(Icons.zoom_in_rounded, size: 16),
                    label: const Text('Zoom In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.deepBlue,
                      side: const BorderSide(color: AppPalette.deepBlue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onViewBusinesses,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.ochre,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.charcoal,
          ),
        ),
      ],
    );
  }
}
