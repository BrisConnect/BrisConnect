import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';

/// Compact analytics KPI card: icon + title, large value, trend text and a
/// mini sparkline built from real historical data only.
class DashboardKpiCard extends StatelessWidget {
  const DashboardKpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trend,
    this.trendPeriodLabel = 'vs last 7 days',
    this.sparklineValues,
    this.sparklineDates,
    this.sparklineValueFormatter,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  /// Real current-vs-previous period counts. Null means no trend data is
  /// available yet - never fabricated.
  final MetricTrend? trend;
  final String trendPeriodLabel;

  /// Real daily historical values powering the sparkline. Null while the
  /// stream is still connecting; empty/all-zero renders a flat neutral line.
  final List<int>? sparklineValues;
  final List<DateTime>? sparklineDates;
  final String Function(num rawValue)? sparklineValueFormatter;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tooltipMessage = '$label: $value${_trendAccessibleSuffix()}';

    return Semantics(
      label: tooltipMessage,
      button: onTap != null,
      child: MouseRegion(
        cursor:
            onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: AdminNeonTheme.glassCard(accent: iconColor, radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: iconColor, size: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminNeonTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AdminNeonTheme.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                ExcludeSemantics(child: _buildTrendRow()),
                const SizedBox(height: 6),
                ExcludeSemantics(child: _buildSparkline()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _trendAccessibleSuffix() {
    if (trend == null) return '';
    if (trend!.previous == 0 && trend!.current == 0) return '';
    if (trend!.previous == 0) return ', new activity $trendPeriodLabel';
    final percent = (trend!.change / trend!.previous) * 100;
    final direction = percent >= 0 ? 'up' : 'down';
    return ', $direction ${percent.abs().round()}% $trendPeriodLabel';
  }

  Widget _buildTrendRow() {
    const neutralStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AdminNeonTheme.textMuted,
    );

    if (trend == null) {
      return const Text('No trend data', style: neutralStyle);
    }

    if (trend!.previous == 0 && trend!.current == 0) {
      return const Text('No change', style: neutralStyle);
    }

    if (trend!.previous == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward_rounded,
              color: Color(0xFF10B981), size: 12),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              'New $trendPeriodLabel',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      );
    }

    final percent = (trend!.change / trend!.previous) * 100;
    final isUp = percent >= 0;
    final color = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            '${percent.abs().round()}% $trendPeriodLabel',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSparkline() {
    const height = 26.0;
    final values = sparklineValues;

    if (values == null) {
      return const SizedBox(height: height);
    }

    if (values.isEmpty || values.every((v) => v == 0)) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 2,
            width: double.infinity,
            color: AdminNeonTheme.textMuted.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    final maxY = values.reduce((a, b) => a > b ? a : b).toDouble();
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].toDouble()),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          lineBarsData: [
            // Soft glow underlay - wider, blurred, low opacity.
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: iconColor.withValues(alpha: 0.55),
              barWidth: 5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            // Crisp glowing line on top.
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: iconColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    iconColor.withValues(alpha: 0.22),
                    iconColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AdminNeonTheme.glassSurfaceAlt.withValues(alpha: 0.96),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              tooltipMargin: 8,
              getTooltipItems: (touchedSpots) {
                // Only tag the crisp foreground line (bar index 1) so the
                // glow underlay doesn't duplicate every tooltip entry.
                return touchedSpots.map((spot) {
                  if (spot.barIndex != 1) return null;
                  final index = spot.x.toInt();
                  final dates = sparklineDates;
                  final label = (dates != null && index < dates.length)
                      ? '${dates[index].day}/${dates[index].month}'
                      : 'Day ${index + 1}';
                  final formatted = sparklineValueFormatter != null
                      ? sparklineValueFormatter!(spot.y)
                      : spot.y.toInt().toString();
                  return LineTooltipItem(
                    '$label\n$formatted',
                    const TextStyle(
                      color: AdminNeonTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
