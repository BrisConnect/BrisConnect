import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_state.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/analytics_tooltip.dart';

class EngagementMetricsSection extends StatefulWidget {
  const EngagementMetricsSection({
    super.key,
    required this.controller,
  });

  final AdminDashboardController controller;

  @override
  State<EngagementMetricsSection> createState() =>
      _EngagementMetricsSectionState();
}

class _EngagementMetricsSectionState extends State<EngagementMetricsSection> {
  late Future<Map<String, int>> _engagementData;

  @override
  void initState() {
    super.initState();
    _engagementData = _loadEngagementData();
  }

  Future<Map<String, int>> _loadEngagementData() async {
    final profileViews =
        await widget.controller.totalProfileViewsCount().first;
    final saves = await widget.controller.totalSavesCount().first;
    final reviews = await widget.controller.totalReviewsCount().first;
    final buzzVotes = await widget.controller.totalBuzzVotesCount().first;
    final crowdReports =
        await widget.controller.totalCrowdReportsCount().first;
    final photoUploads =
        await widget.controller.totalPhotoUploadsCount().first;
    final shares = await widget.controller.totalSharesCount().first;
    final postEngagements =
        await widget.controller.totalPostEngagementsCount().first;
    final appUsers = await widget.controller.totalAppUsersCount().first;

    return {
      'Profile Views': profileViews,
      'Saves': saves,
      'Reviews': reviews,
      'Buzz Votes': buzzVotes,
      'Crowd Reports': crowdReports,
      'Photo Uploads': photoUploads,
      'Social Shares': shares,
      'Post Engagements': postEngagements,
      'App Users': appUsers,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Engagement Overview'),
        const SizedBox(height: 12),
        AdminCard(
          accent: AdminNeonTheme.neonBlue,
          child: FutureBuilder<Map<String, int>>(
            future: _engagementData,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 400,
                  child: Center(
                    child: CircularProgressIndicator(color: AdminNeonTheme.neonBlue),
                  ),
                );
              }

              final data = snapshot.data!;
              final sortedEntries = data.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final maxValue =
                  sortedEntries.first.value.toDouble();

              const colors = [
                AdminNeonTheme.neonBlue, // Profile Views
                AdminNeonTheme.neonOrange, // Saves
                AdminNeonTheme.neonBlue, // Reviews
                AdminNeonTheme.neonOrange, // Buzz Votes
                AdminNeonTheme.neonBlue, // Crowd Reports
                AdminNeonTheme.neonOrange, // Photo Uploads
                AdminNeonTheme.neonCyan, // Social Shares
                AdminNeonTheme.neonBlue, // Post Engagements
                AdminNeonTheme.neonOrange, // App Users
              ];

              return SizedBox(
                height: 320,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      sortedEntries.length,
                      (index) {
                        final entry = sortedEntries[index];
                        final percentage = entry.value / maxValue;

                        final tooltipCard = AnalyticsTooltipCard(
                          title: entry.key,
                          primaryValue: entry.value.toString(),
                          primaryLabel: 'interactions',
                          dateRange: 'All time',
                          backgroundColor:
                              AdminNeonTheme.glassSurfaceAlt.withValues(alpha: 0.97),
                          titleColor: colors[index % colors.length],
                        );

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 0,
                                    child: SizedBox(
                                      width: 140,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AdminNeonTheme.textSecondary,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) {
                                        // Highlight effect on hover
                                        (context as Element).markNeedsBuild();
                                      },
                                      child: Tooltip(
                                        richMessage: WidgetSpan(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 200,
                                            ),
                                            child: tooltipCard,
                                          ),
                                        ),
                                        showDuration:
                                            const Duration(seconds: 5),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Container(
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: AdminNeonTheme.glassSurfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Stack(
                                              children: [
                                                FractionallySizedBox(
                                                  widthFactor: percentage,
                                                  child: Container(
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: colors[index %
                                                          colors.length],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: colors[index %
                                                                  colors.length]
                                                              .withValues(alpha: 0.45),
                                                          blurRadius: 8,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      entry.value.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colors[index % colors.length],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
