import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Reusable chart tooltip card that follows BrisConnect design language.
/// 
/// Displays rich information about a data point on hover.
class ChartTooltipCard extends StatelessWidget {
  const ChartTooltipCard({
    super.key,
    required this.items,
    this.title,
  });

  /// Title shown at the top of the tooltip (e.g., date, category)
  final String? title;

  /// List of label-value pairs to display in the tooltip
  final List<ChartTooltipItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.charcoal.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.ochre,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.color != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB0B0B0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.color ?? Colors.white,
                      ),
                    ),
                  ],
                ),
                if (!isLast) const SizedBox(height: 4),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// A single tooltip item (label-value pair)
class ChartTooltipItem {
  final String label;
  final String value;
  final Color? color; // Optional color indicator (for series colors)

  ChartTooltipItem({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Mobile-optimized tooltip overlay that appears on tap and closes on tap elsewhere
class MobileChartTooltip extends StatefulWidget {
  const MobileChartTooltip({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MobileChartTooltip> createState() => _MobileChartTooltipState();
}

class _MobileChartTooltipState extends State<MobileChartTooltip> {
  bool _showTooltip = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showTooltip = !_showTooltip);
      },
      child: Stack(
        children: [
          widget.child,
          if (_showTooltip)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() => _showTooltip = false);
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
