import 'dart:math';
import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_dashboard_state.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_layout.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/dashboard_kpi_card.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/engagement_metrics_section.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/weekly_activity_chart.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/revenue_trend_chart.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/subscription_breakdown_chart.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_ai_alert_popup.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/admin_ai_alert_service.dart';
import 'package:brisconnect/services/notification_permission_service.dart';
import 'package:brisconnect/widgets/notification_permission_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.controller,
    this.selectedNavIndex = 0,
    this.onNavIndexChanged,
  });

  final AdminDashboardController? controller;
  final int selectedNavIndex;
  final ValueChanged<int>? onNavIndexChanged;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AdminDashboardController _controller;
  late final AdminAiAlertService _alertService;
  final AdminDashboardService _service = AdminDashboardService();
  
  bool _notificationPromptShown = false;
  bool _showNotificationDeniedBanner = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        AdminDashboardController(service: AdminDashboardService());
    _alertService = AdminAiAlertService();
    _controller.load();
    
    // Run AI alert checks on dashboard load (in background, non-blocking)
    _alertService.runAllChecks();
    
    // Check and show notification permission prompt after a short delay
    _checkNotificationPermission();
  }

  /// Checks if notification permission prompt should be shown and displays it.
  /// Waits for dashboard to load and then checks permission state.
  Future<void> _checkNotificationPermission() async {
    // Wait a moment for the UI to settle
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;

    // Check if we should show the permission prompt
    final shouldShow = await NotificationPermissionService.instance.shouldShowPrompt();
    if (!mounted) return;

    if (shouldShow && !_notificationPromptShown) {
      _notificationPromptShown = true;
      _showNotificationDialog();
    } else if (!shouldShow && !_notificationPromptShown) {
      // Check if permission was explicitly denied
      final isDenied = await NotificationPermissionService.instance.isPermissionDenied();
      if (isDenied && mounted) {
        setState(() => _showNotificationDeniedBanner = true);
      }
    }
  }

  /// Shows the notification permission dialog
  void _showNotificationDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NotificationPermissionDialog(
          onEnable: () {
            debugPrint('[AdminDashboard] Notifications enabled by user');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ Notifications enabled! You will receive important alerts.'),
                  backgroundColor: const Color(0xFF2FA8FF).withValues(alpha: 0.9),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          onDismiss: () {
            debugPrint('[AdminDashboard] User dismissed notification prompt');
            if (mounted) {
              setState(() => _showNotificationDeniedBanner = false);
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Stack(
          children: [
            AdminLayout(
              controller: _controller,
              selectedNavIndex: widget.selectedNavIndex,
              onNavIndexChanged: widget.onNavIndexChanged,
              body: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AdminNeonTheme.glassCard(
                            accent: AdminNeonTheme.neonRed,
                            radius: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AdminNeonTheme.neonRed),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    color: AdminNeonTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_showNotificationDeniedBanner)
                      NotificationDeniedBanner(
                        onDismiss: () {
                          setState(() => _showNotificationDeniedBanner = false);
                        },
                      ),
                    const SizedBox(height: 24),
                    _buildKpiGrid(state),
                    const SizedBox(height: 24),
                    EngagementMetricsSection(
                      controller: _controller,
                    ),
                    const SizedBox(height: 24),
                    WeeklyActivityChart(analytics: state.weeklyAnalytics),
                    const SizedBox(height: 24),
                    RevenueTrendChart(),
                    const SizedBox(height: 24),
                    SubscriptionBreakdownChart(
                      premiumCount: min(state.premiumBusinesses, state.activeSubscriptions),
                      basicCount: max(0, state.activeSubscriptions - state.premiumBusinesses),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // AI Alert popups in top-right corner
            AdminAiAlertPopupManager(
              alertService: _alertService,
              onNavigate: (route) {
                // Navigate to the alert action route
                Navigator.of(context).pushNamed(route);
              },
            ),
          ],
        );
      },
    );
  }

  /// Responsive column count per the KPI grid spec: 6 across on wide
  /// desktop, 3 on medium desktop/tablet, 2 on smaller tablet/mobile, 1 on
  /// the narrowest phones.
  int _kpiColumnsForWidth(double width) {
    if (width >= 1400) return 6;
    if (width >= 1000) return 3;
    if (width >= 680) return 2;
    if (width >= 420) return 2;
    return 1;
  }

  Widget _buildKpiGrid(AdminDashboardState state) {
    return StreamBuilder<AdminWeeklyAnalytics>(
      stream: _service.rangeAnalytics(days: 14),
      builder: (context, rangeSnap) {
        final range = rangeSnap.data;
        return StreamBuilder<List<int>>(
          stream: _service.dailySubscriptionSignups(days: 14),
          builder: (context, subsSnap) {
            final subs = subsSnap.data;
            return StreamBuilder<List<int>>(
              stream: _service.dailyRevenueCents(days: 14),
              builder: (context, revenueSnap) {
                final revenue = revenueSnap.data;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        _kpiColumnsForWidth(constraints.maxWidth);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 130,
                      ),
                      itemBuilder: (context, index) => _kpiCardAt(
                        index,
                        state,
                        range,
                        subs,
                        revenue,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _kpiCardAt(
    int index,
    AdminDashboardState state,
    AdminWeeklyAnalytics? range,
    List<int>? subs,
    List<int>? revenue,
  ) {
    final dates = range?.bucketDates;
    switch (index) {
      case 0:
        return DashboardKpiCard(
          icon: Icons.groups_rounded,
          iconColor: AdminNeonTheme.neonBlue,
          label: 'Total Users',
          value: state.totalUsers.toString(),
          trend: state.usersTrend,
          trendPeriodLabel: 'vs last week',
          sparklineValues: range?.newUsers.values,
          sparklineDates: dates,
        );
      case 1:
        return DashboardKpiCard(
          icon: Icons.business_rounded,
          iconColor: AdminNeonTheme.neonOrange,
          label: 'Total Businesses',
          value: state.totalBusinesses.toString(),
          trend: state.businessesTrend,
          trendPeriodLabel: 'vs yesterday',
          sparklineValues: range?.businessRegistrations.values,
          sparklineDates: dates,
        );
      case 2:
        return DashboardKpiCard(
          icon: Icons.workspace_premium_rounded,
          iconColor: AdminNeonTheme.neonPurple,
          label: 'Premium Businesses',
          value: state.premiumBusinesses.toString(),
          trend: subs == null
              ? null
              : MetricTrend.fromDailySeries(subs, periodLabel: 'vs prior week'),
          trendPeriodLabel: 'vs prior week',
          sparklineValues: subs,
          sparklineDates: dates,
        );
      case 3:
        return DashboardKpiCard(
          icon: Icons.subscriptions_rounded,
          iconColor: AdminNeonTheme.neonOrange,
          label: 'Active Subscriptions',
          value: state.activeSubscriptions.toString(),
          trend: subs == null
              ? null
              : MetricTrend.fromDailySeries(subs, periodLabel: 'vs prior week'),
          trendPeriodLabel: 'vs prior week',
          sparklineValues: subs,
          sparklineDates: dates,
        );
      case 4:
        return DashboardKpiCard(
          icon: Icons.attach_money_rounded,
          iconColor: AdminNeonTheme.neonBlue,
          label: 'Monthly Revenue',
          value: '\$${_formatCents(state.monthlyRevenueCents)}',
          trend: revenue == null
              ? null
              : MetricTrend.fromDailySeries(revenue,
                  periodLabel: 'vs prior week'),
          trendPeriodLabel: 'vs prior week',
          sparklineValues: revenue,
          sparklineDates: dates,
          sparklineValueFormatter: (v) => '\$${_formatCents(v.toInt())}',
        );
      case 5:
      default:
        return DashboardKpiCard(
          icon: Icons.report_rounded,
          iconColor: AdminNeonTheme.neonRed,
          label: 'Pending Reports',
          value: state.pendingReports.toString(),
          trend: state.reportsTrend,
          trendPeriodLabel: 'vs yesterday',
          sparklineValues: range?.reportsReceived.values,
          sparklineDates: dates,
        );
    }
  }

  String _formatCents(int cents) {
    final value = cents / 100;
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
}
