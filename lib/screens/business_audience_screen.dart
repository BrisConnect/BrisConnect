import 'package:flutter/material.dart';
import 'package:brisconnect/services/audience_analytics_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Audience analytics screen for business owners.
///
/// Shows anonymised, aggregated engagement data: new vs returning viewers,
/// time-of-day breakdown, and day-of-week breakdown.
class BusinessAudienceScreen extends StatefulWidget {
  /// Identifier for the business owner.
  final String ownerId;

  const BusinessAudienceScreen({
    super.key,
    required this.ownerId,
  });

  @override
  State<BusinessAudienceScreen> createState() => _BusinessAudienceScreenState();
}

class _BusinessAudienceScreenState extends State<BusinessAudienceScreen> {
  final _service = AudienceAnalyticsService();
  DateTimeRange _dateRange = _defaultRange();
  Future<AudienceAnalyticsData>? _dataFuture;

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (widget.ownerId.trim().isEmpty) return;
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<AudienceAnalyticsData> _fetchData() async {
    final breakdown = await _service.getAudienceBreakdown(
      widget.ownerId,
      start: _dateRange.start,
      end: _dateRange.end,
    );
    final distribution = await _service.getEngagementDistribution(
      widget.ownerId,
      start: _dateRange.start,
      end: _dateRange.end,
    );
    return AudienceAnalyticsData(
      breakdown: breakdown,
      distribution: distribution,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D1117)),
            colorScheme: const ColorScheme.dark(
              primary: AppPalette.ochre,
              onPrimary: Colors.white,
              surface: Color(0xFF1C1C2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _dateRange = DateTimeRange(
        start: picked.start,
        end: DateTime(picked.end.year, picked.end.month, picked.end.day,
            23, 59, 59),
      );
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerId.trim().isEmpty) {
      return const _AudienceErrorView(
        message: 'Sign in to view audience analytics.',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildDateRangeBar()),
            SliverToBoxAdapter(child: _buildBody()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audience',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Who is engaging',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar() {
    final startText = _formatDate(_dateRange.start);
    final endText = _formatDate(_dateRange.end);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded,
                color: AppPalette.ochre, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$startText – $endText',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                semanticsLabel:
                    'Selected date range from $startText to $endText',
              ),
            ),
            TextButton(
              onPressed: _pickDateRange,
              child: const Text(
                'Change',
                style: TextStyle(
                  color: AppPalette.ochre,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildBody() {
    return FutureBuilder<AudienceAnalyticsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppPalette.ochre),
            ),
          );
        }

        if (snapshot.hasError) {
          return _AudienceErrorCard(
            message: 'Unable to load audience data: ${snapshot.error}',
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const _AudienceErrorCard(
            message: 'No audience data available.',
          );
        }

        final total = data.breakdown.totalInteractions;
        final isMeaningful = AudienceAnalyticsService.isSampleMeaningful(total);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Overview'),
              const SizedBox(height: 10),
              _buildOverviewCards(data.breakdown),
              const SizedBox(height: 20),
              if (!isMeaningful) ...[
                _buildSampleWarning(total),
                const SizedBox(height: 20),
              ],
              _SectionLabel('New vs Returning'),
              const SizedBox(height: 10),
              _buildNewVsReturning(data.breakdown),
              const SizedBox(height: 20),
              _SectionLabel('Engagement by Time of Day'),
              const SizedBox(height: 10),
              _buildHourChart(data.distribution.byHour, total),
              const SizedBox(height: 20),
              _SectionLabel('Engagement by Day of Week'),
              const SizedBox(height: 10),
              _buildDayOfWeekChart(data.distribution.byDayOfWeek, total),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCards(AudienceBreakdown breakdown) {
    return Row(
      children: [
        _OverviewCard(
          label: 'Total Interactions',
          value: '${breakdown.totalInteractions}',
          color: const Color(0xFF4F8FFF),
        ),
        const SizedBox(width: 10),
        _OverviewCard(
          label: 'Unique Visitors',
          value: '${breakdown.newVisitors + breakdown.returningVisitors}',
          color: AppPalette.ochre,
        ),
      ],
    );
  }

  Widget _buildSampleWarning(int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.ochre.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppPalette.ochre.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only $total interaction${total == 1 ? '' : 's'} recorded in this range. '
              'Results may not yet be statistically meaningful.',
              style: const TextStyle(
                color: Color(0xFF8B8FA8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewVsReturning(AudienceBreakdown breakdown) {
    final totalVisitors = breakdown.newVisitors + breakdown.returningVisitors;
    if (totalVisitors == 0) {
      return const _AudienceEmptyCard(
        message: 'No viewer data for the selected range.',
      );
    }

    final newPct = (breakdown.newPercentage * 100).toStringAsFixed(0);
    final returningPct = (breakdown.returningPercentage * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendItem(
            color: const Color(0xFF4F8FFF),
            label: 'New viewers',
            value: '${breakdown.newVisitors} ($newPct%)',
          ),
          const SizedBox(height: 12),
          _LegendItem(
            color: AppPalette.ochre,
            label: 'Returning viewers',
            value: '${breakdown.returningVisitors} ($returningPct%)',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Semantics(
              label:
                  'New versus returning viewers: $newPct% new, $returningPct% returning',
              child: LinearProgressIndicator(
                value: breakdown.newPercentage,
                backgroundColor: AppPalette.ochre,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4F8FFF),
                ),
                minHeight: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourChart(Map<int, int> byHour, int total) {
    if (byHour.isEmpty || total == 0) {
      return const _AudienceEmptyCard(
        message: 'No time-of-day data for the selected range.',
      );
    }

    final maxValue = byHour.values.reduce((a, b) => a > b ? a : b);
    final sortedHours = List<int>.generate(24, (i) => i);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: sortedHours.map((hour) {
                final value = byHour[hour] ?? 0;
                final ratio = maxValue == 0 ? 0 : value / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '${_formatHour(hour)}: $value interactions',
                      child: Semantics(
                        label:
                            '${_formatHour(hour)}, $value interactions',
                        child: Container(
                          height: ratio * 120,
                          decoration: BoxDecoration(
                            color: value > 0
                                ? const Color(0xFF4F8FFF)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('12am',
                  style: TextStyle(color: Color(0xFF8B8FA8), fontSize: 10)),
              Text('12pm',
                  style: TextStyle(color: Color(0xFF8B8FA8), fontSize: 10)),
              Text('11pm',
                  style: TextStyle(color: Color(0xFF8B8FA8), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayOfWeekChart(Map<int, int> byDayOfWeek, int total) {
    if (byDayOfWeek.isEmpty || total == 0) {
      return const _AudienceEmptyCard(
        message: 'No day-of-week data for the selected range.',
      );
    }

    final days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final maxValue = byDayOfWeek.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final weekday = index + 1;
                final value = byDayOfWeek[weekday] ?? 0;
                final ratio = maxValue == 0 ? 0 : value / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Tooltip(
                      message: '${days[index]}: $value interactions',
                      child: Semantics(
                        label: '${days[index]}, $value interactions',
                        child: Container(
                          height: ratio * 120,
                          decoration: BoxDecoration(
                            color: value > 0
                                ? AppPalette.ochre
                                : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days
                .map((d) => Text(d,
                    style: const TextStyle(
                        color: Color(0xFF8B8FA8), fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'am' : 'pm';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$displayHour$period';
  }
}

/// Aggregated data loaded for the audience screen.
class AudienceAnalyticsData {
  final AudienceBreakdown breakdown;
  final EngagementDistribution distribution;

  const AudienceAnalyticsData({
    required this.breakdown,
    required this.distribution,
  });
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B8FA8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AudienceErrorCard extends StatelessWidget {
  final String message;
  const _AudienceErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE74C3C), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF8B8FA8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceEmptyCard extends StatelessWidget {
  final String message;
  const _AudienceEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: Color(0xFF8B8FA8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B8FA8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceErrorView extends StatelessWidget {
  final String message;
  const _AudienceErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: _AudienceErrorCard(message: message),
      ),
    );
  }
}
