import 'dart:async';

import 'package:flutter/material.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';

/// Immutable state object for the admin dashboard.
class AdminDashboardState {
  final int totalUsers;
  final int totalBusinesses;
  final int totalEvents;
  final int pendingApprovals;
  final int pendingReports;
  final int premiumBusinesses;
  final int activeSubscriptions;
  final int monthlyRevenueCents;
  final TodaySummary? todaySummary;
  final List<PendingBusinessApproval> pendingBusinesses;
  final List<RecentAdminUser> recentUsers;
  final List<AdminActivityItem> recentActivity;
  final RevenueSummary? revenueSummary;
  final AdminWeeklyAnalytics? weeklyAnalytics;
  final MetricTrend? usersTrend;
  final MetricTrend? businessesTrend;
  final MetricTrend? eventsTrend;
  final MetricTrend? reportsTrend;
  final int selectedNavIndex;
  final bool isLoading;
  final String? error;

  const AdminDashboardState({
    this.totalUsers = 0,
    this.totalBusinesses = 0,
    this.totalEvents = 0,
    this.pendingApprovals = 0,
    this.pendingReports = 0,
    this.premiumBusinesses = 0,
    this.activeSubscriptions = 0,
    this.monthlyRevenueCents = 0,
    this.todaySummary,
    this.pendingBusinesses = const [],
    this.recentUsers = const [],
    this.recentActivity = const [],
    this.revenueSummary,
    this.weeklyAnalytics,
    this.usersTrend,
    this.businessesTrend,
    this.eventsTrend,
    this.reportsTrend,
    this.selectedNavIndex = 0,
    this.isLoading = true,
    this.error,
  });

  AdminDashboardState copyWith({
    int? totalUsers,
    int? totalBusinesses,
    int? totalEvents,
    int? pendingApprovals,
    int? pendingReports,
    int? premiumBusinesses,
    int? activeSubscriptions,
    int? monthlyRevenueCents,
    TodaySummary? todaySummary,
    List<PendingBusinessApproval>? pendingBusinesses,
    List<RecentAdminUser>? recentUsers,
    List<AdminActivityItem>? recentActivity,
    RevenueSummary? revenueSummary,
    AdminWeeklyAnalytics? weeklyAnalytics,
    MetricTrend? usersTrend,
    MetricTrend? businessesTrend,
    MetricTrend? eventsTrend,
    MetricTrend? reportsTrend,
    int? selectedNavIndex,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardState(
      totalUsers: totalUsers ?? this.totalUsers,
      totalBusinesses: totalBusinesses ?? this.totalBusinesses,
      totalEvents: totalEvents ?? this.totalEvents,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      pendingReports: pendingReports ?? this.pendingReports,
      premiumBusinesses: premiumBusinesses ?? this.premiumBusinesses,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      monthlyRevenueCents: monthlyRevenueCents ?? this.monthlyRevenueCents,
      todaySummary: todaySummary ?? this.todaySummary,
      pendingBusinesses: pendingBusinesses ?? this.pendingBusinesses,
      recentUsers: recentUsers ?? this.recentUsers,
      recentActivity: recentActivity ?? this.recentActivity,
      revenueSummary: revenueSummary ?? this.revenueSummary,
      weeklyAnalytics: weeklyAnalytics ?? this.weeklyAnalytics,
      usersTrend: usersTrend ?? this.usersTrend,
      businessesTrend: businessesTrend ?? this.businessesTrend,
      eventsTrend: eventsTrend ?? this.eventsTrend,
      reportsTrend: reportsTrend ?? this.reportsTrend,
      selectedNavIndex: selectedNavIndex ?? this.selectedNavIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Controller that keeps business logic out of UI widgets.
class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController({
    AdminDashboardService? service,
  }) : _service = service ?? AdminDashboardService();

  final AdminDashboardService _service;
  final _subscriptions = <StreamSubscription>[];
  AdminDashboardState _state = const AdminDashboardState();

  AdminDashboardState get state => _state;

  void selectNavIndex(int index) {
    if (_state.selectedNavIndex == index) return;
    _state = _state.copyWith(selectedNavIndex: index);
    notifyListeners();
  }

  void load() {
    // Start with UI showing "loading" state
    _state = const AdminDashboardState(isLoading: true);
    notifyListeners();

    // Load metrics with individual timeouts to prevent overall hang
    _loadMetricsWithTimeouts();
  }

  /// Load dashboard metrics with individual query timeouts (5 seconds each)
  Future<void> _loadMetricsWithTimeouts() async {
    try {
      // Use Future.wait with timeout for parallel metric queries
      // Each query has a 5-second timeout to prevent hanging
      final results = await Future.wait<dynamic>([
        _timeoutQuery(_service.totalUsersCount(), 'users', 0),
        _timeoutQuery(_service.totalBusinessesCount(), 'businesses', 0),
        _timeoutQuery(_service.totalEventsCount(), 'events', 0),
        _timeoutQuery(_service.pendingLocalUsersCount(), 'pending approvals', 0),
        _timeoutQuery(_service.pendingReviewReportsCount(), 'pending reports', 0),
        _timeoutQuery(_service.premiumBusinessesCount(), 'premium businesses', 0),
        _timeoutQuery(_service.activeSubscriptionsCount(), 'subscriptions', 0),
        _timeoutQuery(_service.monthlyRevenueCents(), 'revenue', 0),
      ], eagerError: false);

      if (mounted) {
        _state = _state.copyWith(
          totalUsers: results[0] as int? ?? 0,
          totalBusinesses: results[1] as int? ?? 0,
          totalEvents: results[2] as int? ?? 0,
          pendingApprovals: results[3] as int? ?? 0,
          pendingReports: results[4] as int? ?? 0,
          premiumBusinesses: results[5] as int? ?? 0,
          activeSubscriptions: results[6] as int? ?? 0,
          monthlyRevenueCents: results[7] as int? ?? 0,
          isLoading: false,
          error: null,
        );
        notifyListeners();
      }

      // Optionally load analytics in background after core metrics
      _loadAnalyticsInBackground();
    } catch (e) {
      if (mounted) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Failed to load metrics: ${e.toString().split('\n').first}',
        );
        notifyListeners();
      }
    }
  }

  /// Helper: Query a stream's first value with timeout
  Future<T?> _timeoutQuery<T>(Stream<T> stream, String name, T defaultValue) async {
    try {
      return await stream.first.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Dashboard] Timeout loading $name: $e');
      return defaultValue;
    }
  }

  bool get mounted => !_disposed;
  final bool _disposed = false;

  /// Load analytics in background (don't block UI if slow)
  Future<void> _loadAnalyticsInBackground() async {
    try {
      await Future.wait([
        _loadWeeklyAnalytics(),
        _loadTrendData(),
      ], eagerError: false);
    } catch (e) {
      debugPrint('[Dashboard] Background analytics load error: $e');
    }
  }

  Future<void> _loadWeeklyAnalytics() async {
    try {
      final analytics = await _service
          .rangeAnalytics(days: 7)
          .first
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        _state = _state.copyWith(weeklyAnalytics: analytics);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Dashboard] Weekly analytics timeout: $e');
    }
  }

  Future<void> _loadTrendData() async {
    try {
      // Placeholder: could add trend analysis here
      // For now, just ensure the state is valid
    } catch (e) {
      debugPrint('[Dashboard] Trend data error: $e');
    }
  }

  Future<void> approveBusiness(String businessId) async {
    await _service.setBusinessVerified(businessId, verified: true);
  }

  Future<void> rejectBusiness(String businessId) async {
    await _service.setBusinessVerified(businessId, verified: false);
  }

  Stream<int> totalProfileViewsCount() => _service.totalProfileViewsCount();
  Stream<int> totalSavesCount() => _service.totalSavesCount();
  Stream<int> totalReviewsCount() => _service.totalReviewsCount();
  Stream<int> totalBuzzVotesCount() => _service.totalBuzzVotesCount();
  Stream<int> totalCrowdReportsCount() => _service.totalCrowdReportsCount();
  Stream<int> totalPhotoUploadsCount() => _service.totalPhotoUploadsCount();
  Stream<int> totalSharesCount() => _service.totalSharesCount();
  Stream<int> totalPostEngagementsCount() => _service.totalPostEngagementsCount();
  Stream<int> totalAppUsersCount() => _service.totalAppUsersCount();


  void _clearSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }
}
