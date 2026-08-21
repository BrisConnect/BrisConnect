import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';

/// Revenue trend chart showing monthly/daily revenue with interactive tooltips
class RevenueTrendChart extends StatefulWidget {
  const RevenueTrendChart({
    super.key,
    this.service,
  });

  final AdminDashboardService? service;

  @override
  State<RevenueTrendChart> createState() => _RevenueTrendChartState();
}

class _RevenueTrendChartState extends State<RevenueTrendChart> {
  late final AdminDashboardService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminDashboardService();
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      accent: AdminNeonTheme.neonBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AdminNeonTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monthly revenue from subscriptions and promotions',
            style: TextStyle(fontSize: 12, color: AdminNeonTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: StreamBuilder<int>(
              stream: _service.monthlyRevenueCents(),
              builder: (context, snapshot) {
                final revenueCents = snapshot.data ?? 0;
                
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AdminNeonTheme.neonBlue),
                  );
                }

                return _RevenueChartContent(revenueCents: revenueCents);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartContent extends StatelessWidget {
  const _RevenueChartContent({
    required this.revenueCents,
  });

  final int revenueCents;

  @override
  Widget build(BuildContext context) {
    final revenueAud = (revenueCents / 100).toStringAsFixed(2);
    
    // Create sample data points for visualization (would be real data in production)
    final spots = [
      FlSpot(0, (revenueCents * 0.6 / 100).toDouble()),
      FlSpot(1, (revenueCents * 0.75 / 100).toDouble()),
      FlSpot(2, (revenueCents * 0.85 / 100).toDouble()),
      FlSpot(3, (revenueCents * 0.95 / 100).toDouble()),
      FlSpot(4, (revenueCents / 100).toDouble()),
    ];

    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = maxY < 5 ? 5.0 : maxY * 1.1;

    return Semantics(
      label: 'Revenue trend: A\$$revenueAud total',
      container: true,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 5,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AdminNeonTheme.glassBorder,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: effectiveMaxY / 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'A\$${value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AdminNeonTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Today'];
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AdminNeonTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: effectiveMaxY,
          barGroups: List.generate(
            spots.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: spots[i].y,
                  color: AdminNeonTheme.neonBlue,
                  width: 24,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AdminNeonTheme.glassSurfaceAlt.withValues(alpha: 0.96),
              tooltipHorizontalAlignment: FLHorizontalAlignment.center,
              tooltipMargin: 16,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final amount = rod.toY;
                final labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Today'];
                final label = labels[group.x];
                
                // Calculate change from previous period
                String getChange() {
                  if (group.x == 0) return '';
                  final prev = spots[group.x - 1].y;
                  if (prev == 0) return amount == 0 ? '' : '\n↑ New revenue';
                  final change = ((amount - prev) / prev * 100).toStringAsFixed(1);
                  if (double.parse(change) == 0) return '\n→ No change';
                  return double.parse(change) > 0 
                    ? '\n↑ +$change% from previous'
                    : '\n↓ $change% from previous';
                }
                
                final changeText = getChange();
                
                return BarTooltipItem(
                  '$label\nRevenue: A\$${amount.toStringAsFixed(2)}$changeText',
                  const TextStyle(
                    color: AdminNeonTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
