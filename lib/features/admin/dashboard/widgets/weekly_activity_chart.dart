import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';

enum _ChartRange { sevenDays, thirtyDays, threeMonths, oneYear }

extension on _ChartRange {
  int get days {
    switch (this) {
      case _ChartRange.sevenDays:
        return 7;
      case _ChartRange.thirtyDays:
        return 30;
      case _ChartRange.threeMonths:
        return 90;
      case _ChartRange.oneYear:
        return 365;
    }
  }

  String get label {
    switch (this) {
      case _ChartRange.sevenDays:
        return 'the last 7 days';
      case _ChartRange.thirtyDays:
        return 'the last 30 days';
      case _ChartRange.threeMonths:
        return 'the last 3 months';
      case _ChartRange.oneYear:
        return 'the last year';
    }
  }
}

class WeeklyActivityChart extends StatefulWidget {
  const WeeklyActivityChart({
    super.key,
    this.analytics,
    this.service,
  });

  /// Optional initial data (fixed current-week window) shown before the
  /// range-aware stream connects, so the chart isn't blank on first paint.
  final AdminWeeklyAnalytics? analytics;
  final AdminDashboardService? service;

  @override
  State<WeeklyActivityChart> createState() => _WeeklyActivityChartState();
}

class _WeeklyActivityChartState extends State<WeeklyActivityChart> {
  _ChartRange _range = _ChartRange.sevenDays;
  late final AdminDashboardService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminDashboardService();
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      accent: AdminNeonTheme.neonOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AdminNeonTheme.textPrimary,
                ),
              ),
              Semantics(
                label: 'Filter activity chart by date range',
                child: SegmentedButton<_ChartRange>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AdminNeonTheme.glassSurfaceAlt,
                    foregroundColor: AdminNeonTheme.textSecondary,
                    selectedBackgroundColor:
                        AdminNeonTheme.neonOrange.withValues(alpha: 0.22),
                    selectedForegroundColor: AdminNeonTheme.textPrimary,
                    side: BorderSide(
                        color: AdminNeonTheme.glassBorder.withValues(alpha: 0.7)),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _ChartRange.sevenDays,
                      label: Text('7D'),
                    ),
                    ButtonSegment(
                      value: _ChartRange.thirtyDays,
                      label: Text('30D'),
                    ),
                    ButtonSegment(
                      value: _ChartRange.threeMonths,
                      label: Text('3M'),
                    ),
                    ButtonSegment(
                      value: _ChartRange.oneYear,
                      label: Text('1Y'),
                    ),
                  ],
                  selected: {_range},
                  onSelectionChanged: (selected) {
                    setState(() => _range = selected.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'New users, business registrations, and reports',
            style: TextStyle(fontSize: 12, color: AdminNeonTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: StreamBuilder<AdminWeeklyAnalytics>(
              key: ValueKey(_range),
              stream: _service.rangeAnalytics(days: _range.days),
              initialData:
                  _range == _ChartRange.sevenDays ? widget.analytics : null,
              builder: (context, snapshot) {
                final analytics = snapshot.data;
                if (analytics == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AdminNeonTheme.neonOrange),
                  );
                }
                return _ChartContent(analytics: analytics, range: _range);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartContent extends StatelessWidget {
  const _ChartContent({
    required this.analytics,
    required this.range,
  });

  final AdminWeeklyAnalytics analytics;
  final _ChartRange range;

  /// Plain-text description of the chart data, read by screen readers as an
  /// accessible alternative to the visual line chart (WCAG 2.1 AA 1.1.1).
  String _accessibleSummary() {
    int sum(List<int> values) => values.fold(0, (a, b) => a + b);
    return 'Activity overview for ${range.label}: '
        '${sum(analytics.newUsers.values)} new users, '
        '${sum(analytics.businessRegistrations.values)} business registrations, '
        '${sum(analytics.reportsReceived.values)} reports received.';
  }

  @override
  Widget build(BuildContext context) {
    final values = [
      ...analytics.newUsers.values,
      ...analytics.businessRegistrations.values,
      ...analytics.reportsReceived.values,
    ];
    if (values.every((v) => v == 0)) {
      return Center(
        child: Semantics(
          label: 'No activity data for ${range.label}',
          child: const Text(
            'No activity data for this period',
            style: TextStyle(color: AdminNeonTheme.textSecondary),
          ),
        ),
      );
    }

    final maxY = values.reduce((a, b) => a > b ? a : b).toDouble();
    final effectiveMaxY = maxY < 5 ? 5.0 : maxY * 1.2;
    final pointCount = analytics.newUsers.values.length;

    return Semantics(
      label: _accessibleSummary(),
      container: true,
      child: Column(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: LineChart(
                LineChartData(
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
                        reservedSize: 32,
                        interval: effectiveMaxY / 5,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value.toInt().toString(),
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
                        interval: _labelInterval(pointCount).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final labels = _bottomLabels();
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
                  minX: 0,
                  maxX: (pointCount - 1).toDouble(),
                  minY: 0,
                  maxY: effectiveMaxY,
                  lineBarsData: [
                    _buildLineBarData(analytics.newUsers.values, AdminNeonTheme.neonBlue),
                    _buildLineBarData(
                      analytics.businessRegistrations.values,
                      AdminNeonTheme.neonOrange,
                    ),
                    _buildLineBarData(
                      analytics.reportsReceived.values,
                      AdminNeonTheme.neonRed,
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AdminNeonTheme.glassSurfaceAlt.withValues(alpha: 0.96),
                      tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                      tooltipMargin: 16,
                      getTooltipItems: (touchedSpots) {
                        if (touchedSpots.isEmpty) return [];
                        
                        // Get the x index from the first spot
                        final xIndex = touchedSpots.first.x.toInt();
                        final bucketDate = xIndex < analytics.bucketDates.length
                            ? analytics.bucketDates[xIndex]
                            : DateTime.now();
                        
                        // Collect values for this x position from all series
                        final newUsers = xIndex < analytics.newUsers.values.length
                            ? analytics.newUsers.values.toList()[xIndex]
                            : 0;
                        final businesses = xIndex < analytics.businessRegistrations.values.length
                            ? analytics.businessRegistrations.values.toList()[xIndex]
                            : 0;
                        final reports = xIndex < analytics.reportsReceived.values.length
                            ? analytics.reportsReceived.values.toList()[xIndex]
                            : 0;
                        
                        // Calculate change from previous period if available
                        String getUsersChange() {
                          if (xIndex == 0) return '';
                          final prev = analytics.newUsers.values.toList()[xIndex - 1];
                          if (prev == 0) return newUsers == 0 ? '' : '↑ New';
                          final change = newUsers - prev;
                          if (change == 0) return '→ No change';
                          return change > 0 ? '↑ $change from prev' : '↓ ${change.abs()} from prev';
                        }
                        
                        String getBusinessesChange() {
                          if (xIndex == 0) return '';
                          final prev = analytics.businessRegistrations.values.toList()[xIndex - 1];
                          if (prev == 0) return businesses == 0 ? '' : '↑ New';
                          final change = businesses - prev;
                          if (change == 0) return '→ No change';
                          return change > 0 ? '↑ $change from prev' : '↓ ${change.abs()} from prev';
                        }
                        
                        String getReportsChange() {
                          if (xIndex == 0) return '';
                          final prev = analytics.reportsReceived.values.toList()[xIndex - 1];
                          if (prev == 0) return reports == 0 ? '' : '↑ New';
                          final change = reports - prev;
                          if (change == 0) return '→ No change';
                          return change > 0 ? '↑ $change from prev' : '↓ ${change.abs()} from prev';
                        }
                        
                        // Format date like "19 Aug 2026"
                        final dateStr = '${bucketDate.day} ${_monthName(bucketDate.month)} ${bucketDate.year}';
                        
                        // Build richly formatted tooltip text
                        final usersChange = getUsersChange();
                        final businessesChange = getBusinessesChange();
                        final reportsChange = getReportsChange();
                        
                        final tooltipText = '$dateStr\n'
                            'Users: $newUsers ${usersChange.isNotEmpty ? '($usersChange)' : ''}\n'
                            'Businesses: $businesses ${businessesChange.isNotEmpty ? '($businessesChange)' : ''}\n'
                            'Reports: $reports ${reportsChange.isNotEmpty ? '($reportsChange)' : ''}';
                        
                        return [
                          LineTooltipItem(
                            tooltipText,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildChartLegend('New Users', AdminNeonTheme.neonBlue),
              _buildChartLegend('Businesses', AdminNeonTheme.neonOrange),
              _buildChartLegend('Reports', AdminNeonTheme.neonRed),
            ],
          ),
        ],
      ),
    );
  }

  /// Skips bottom-axis labels for longer ranges so they don't overlap.
  int _labelInterval(int pointCount) {
    if (pointCount <= 7) return 1;
    if (pointCount <= 30) return 5;
    if (pointCount <= 90) return 14;
    return 30;
  }

  List<String> _bottomLabels() {
    if (analytics.bucketDates.isEmpty) {
      // Legacy fixed Mon–Sun window with no bucket dates populated.
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
    return analytics.bucketDates
        .map((date) => '${date.day}/${date.month}')
        .toList();
  }

  LineChartBarData _buildLineBarData(List<int> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i].toDouble()),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: AdminNeonTheme.bgDeepNavy,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.10),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Semantics(
      label: '$label series',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminNeonTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
