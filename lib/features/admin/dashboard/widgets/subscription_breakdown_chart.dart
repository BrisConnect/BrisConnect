import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';

/// Subscription breakdown pie chart showing subscription types distribution
class SubscriptionBreakdownChart extends StatelessWidget {
  const SubscriptionBreakdownChart({
    super.key,
    required this.premiumCount,
    required this.basicCount,
  });

  final int premiumCount;
  final int basicCount;

  @override
  Widget build(BuildContext context) {
    final total = premiumCount + basicCount;
    final isDesktop = MediaQuery.sizeOf(context).width > 1024;

    return AdminCard(
      accent: AdminNeonTheme.neonOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AdminNeonTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Active subscriptions by plan type',
            style: TextStyle(fontSize: 12, color: AdminNeonTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            Center(
              child: Semantics(
                label: 'No active subscriptions',
                child: const Text(
                  'No active subscriptions yet',
                  style: TextStyle(color: AdminNeonTheme.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: isDesktop ? 260 : 300,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: premiumCount.toDouble(),
                            color: AdminNeonTheme.neonOrange,
                            title: premiumCount.toString(),
                            radius: isDesktop ? 60 : 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            badgePositionPercentageOffset: 1.1,
                          ),
                          PieChartSectionData(
                            value: basicCount.toDouble(),
                            color: AdminNeonTheme.neonBlue,
                            title: basicCount.toString(),
                            radius: isDesktop ? 60 : 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            badgePositionPercentageOffset: 1.1,
                          ),
                        ],
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            // Tooltip handled by section data
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        color: AdminNeonTheme.neonOrange,
                        label: 'Premium',
                        count: premiumCount,
                        percentage: total > 0
                            ? ((premiumCount / total) * 100).toStringAsFixed(1)
                            : '0',
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        color: AdminNeonTheme.neonBlue,
                        label: 'Basic',
                        count: basicCount,
                        percentage: total > 0
                            ? ((basicCount / total) * 100).toStringAsFixed(1)
                            : '0',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total: $total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminNeonTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
    required String percentage,
  }) {
    return Tooltip(
      richMessage: WidgetSpan(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count subscriptions',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$percentage% of active subscriptions',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
      showDuration: const Duration(seconds: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminNeonTheme.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminNeonTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '$count ($percentage%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
