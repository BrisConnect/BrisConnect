import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/models/business.dart';

/// Snapshot of a metric trend: current-period count vs the previous period.
class MetricTrend {
  final int current;
  final int previous;
  final String periodLabel;

  const MetricTrend({
    required this.current,
    required this.previous,
    required this.periodLabel,
  });

  int get change => current - previous;

  bool get isUp => change >= 0;

  /// Builds a trend by splitting a daily historical series in half: the
  /// most recent half is "current", the older half is "previous". Returns
  /// null when there isn't enough real data to compare two full periods
  /// (never fabricates a trend from partial data).
  static MetricTrend? fromDailySeries(
    List<int> series, {
    required String periodLabel,
  }) {
    if (series.length < 2) return null;
    final half = series.length ~/ 2;
    final previous = series.sublist(0, half).fold<int>(0, (a, b) => a + b);
    final current = series.sublist(half).fold<int>(0, (a, b) => a + b);
    return MetricTrend(
      current: current,
      previous: previous,
      periodLabel: periodLabel,
    );
  }
}

/// Status badge values for recent users.
enum UserStatus {
  active,
  pending,
  suspended;

  String get label {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.suspended:
        return 'Suspended';
    }
  }

  Color get color {
    switch (this) {
      case UserStatus.active:
        return const Color(0xFF10B981);
      case UserStatus.pending:
        return const Color(0xFFF59E0B);
      case UserStatus.suspended:
        return const Color(0xFFEF4444);
    }
  }
}

/// A pending business approval item shown on the dashboard.
class PendingBusinessApproval {
  final String id;
  final String name;
  final String category;
  final String address;
  final String? logoUrl;
  final String ownerId;
  final DateTime? createdAt;

  const PendingBusinessApproval({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    this.logoUrl,
    required this.ownerId,
    this.createdAt,
  });
}

/// A recent user shown on the dashboard.
class RecentAdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final UserStatus status;
  final DateTime? createdAt;

  const RecentAdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.createdAt,
  });
}

/// Types of activity displayed in the admin feed.
enum AdminActivityType {
  businessSubmitted,
  businessApproved,
  reviewReported,
  userRegistered,
  promotionCreated,
  subscriptionActivated,
  photoUploaded,
  unknown;

  static AdminActivityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'business_submitted':
      case 'business_created':
        return AdminActivityType.businessSubmitted;
      case 'business_approved':
      case 'business_verified':
        return AdminActivityType.businessApproved;
      case 'review_reported':
      case 'reported_review':
        return AdminActivityType.reviewReported;
      case 'user_registered':
      case 'user_created':
        return AdminActivityType.userRegistered;
      case 'promotion_created':
      case 'promotion':
        return AdminActivityType.promotionCreated;
      case 'subscription_activated':
      case 'subscription':
        return AdminActivityType.subscriptionActivated;
      case 'photo_uploaded':
      case 'photo':
        return AdminActivityType.photoUploaded;
      default:
        return AdminActivityType.unknown;
    }
  }

  IconData get icon {
    switch (this) {
      case AdminActivityType.businessSubmitted:
        return Icons.business_rounded;
      case AdminActivityType.businessApproved:
        return Icons.verified_rounded;
      case AdminActivityType.reviewReported:
        return Icons.report_rounded;
      case AdminActivityType.userRegistered:
        return Icons.person_add_rounded;
      case AdminActivityType.promotionCreated:
        return Icons.campaign_rounded;
      case AdminActivityType.subscriptionActivated:
        return Icons.workspace_premium_rounded;
      case AdminActivityType.photoUploaded:
        return Icons.photo_camera_rounded;
      case AdminActivityType.unknown:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AdminActivityType.businessSubmitted:
        return const Color(0xFF3B82F6);
      case AdminActivityType.businessApproved:
        return const Color(0xFF10B981);
      case AdminActivityType.reviewReported:
        return const Color(0xFFEF4444);
      case AdminActivityType.userRegistered:
        return const Color(0xFF8B5CF6);
      case AdminActivityType.promotionCreated:
        return const Color(0xFFF59E0B);
      case AdminActivityType.subscriptionActivated:
        return const Color(0xFFEC4899);
      case AdminActivityType.photoUploaded:
        return const Color(0xFF06B6D4);
      case AdminActivityType.unknown:
        return const Color(0xFF64748B);
    }
  }
}

/// A single item in the admin recent activity feed.
class AdminActivityItem {
  final String id;
  final AdminActivityType type;
  final String message;
  final String? relatedId;
  final String? relatedCollection;
  final DateTime? createdAt;

  const AdminActivityItem({
    required this.id,
    required this.type,
    required this.message,
    this.relatedId,
    this.relatedCollection,
    this.createdAt,
  });
}

/// Snapshot of today’s key numbers for the dashboard.
class TodaySummary {
  final int newUsers;
  final int newBusinesses;
  final int pendingApprovals;
  final int newReports;
  final int activePromotions;
  final int expiringSubscriptions;

  const TodaySummary({
    required this.newUsers,
    required this.newBusinesses,
    required this.pendingApprovals,
    required this.newReports,
    required this.activePromotions,
    required this.expiringSubscriptions,
  });
}

/// Snapshot of revenue and subscription metrics for the dashboard.
class RevenueSummary {
  final int revenueTodayCents;
  final int monthlyRevenueCents;
  final int activeSubscribers;
  final int cancelledSubscriptions;
  final int monthlyRecurringRevenueCents;
  final int runningPromotions;

  const RevenueSummary({
    required this.revenueTodayCents,
    required this.monthlyRevenueCents,
    required this.activeSubscribers,
    required this.cancelledSubscriptions,
    required this.monthlyRecurringRevenueCents,
    required this.runningPromotions,
  });

  double get revenueToday => revenueTodayCents / 100;
  double get monthlyRevenue => monthlyRevenueCents / 100;
  double get monthlyRecurringRevenue => monthlyRecurringRevenueCents / 100;
}

/// Per-day counts for the current week (Mon–Sun) for the analytics chart.
class WeeklyAnalyticsSeries {
  final List<int> values;

  const WeeklyAnalyticsSeries({required this.values});
}

class AdminWeeklyAnalytics {
  final WeeklyAnalyticsSeries newUsers;
  final WeeklyAnalyticsSeries businessRegistrations;
  final WeeklyAnalyticsSeries eventsCreated;
  final WeeklyAnalyticsSeries reportsReceived;

  /// The calendar date each index in the series above corresponds to.
  /// Empty for the legacy fixed Mon–Sun [weeklyAnalytics] stream; populated
  /// for [rangeAnalytics] so charts can label arbitrary date ranges.
  final List<DateTime> bucketDates;

  const AdminWeeklyAnalytics({
    required this.newUsers,
    required this.businessRegistrations,
    required this.eventsCreated,
    required this.reportsReceived,
    this.bucketDates = const [],
  });

  int get maxValue {
    final all = [
      ...newUsers.values,
      ...businessRegistrations.values,
      ...eventsCreated.values,
      ...reportsReceived.values,
    ];
    return all.isEmpty ? 0 : all.reduce((a, b) => a > b ? a : b);
  }
}

class AdminDashboardService {
  AdminDashboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<int> totalEventsCount() {
    return _countStream(_firestore.collection('events'));
  }

  Stream<int> pendingEventsCount() {
    return _countStream(
      _firestore
          .collection('events')
          .where('reviewStatus', isEqualTo: 'pending'),
    );
  }

  Stream<int> totalLocalUsersCount() {
    return _countStream(_firestore.collection('local_users'));
  }

  Stream<int> totalUsersCount() {
    return _sumThreeStreams(
      totalLocalUsersCount(),
      totalVisitorsCount(),
      totalAdminsCount(),
    );
  }

  /// Total app users (local + visitor accounts).
  Stream<int> totalAppUsersCount() {
    return _sumTwoStreams(
      totalLocalUsersCount(),
      totalVisitorsCount(),
    );
  }

  Stream<int> pendingLocalUsersCount() {
    return _countStream(
      _firestore
          .collection('local_users')
          .where('approvalStatus', isEqualTo: 'pending'),
    );
  }

  Stream<int> totalVisitorsCount() {
    return _countStream(_firestore.collection('visitor_users'));
  }

  Stream<int> totalAdminsCount() {
    return _countStream(_firestore.collection('admins'));
  }

  Stream<int> pendingEventReportsCount() {
    return _countStream(
      _firestore
          .collection('event_reports')
          .where('status', isEqualTo: 'pending'),
    );
  }

  Stream<int> totalBusinessesCount() {
    return _countStream(_firestore.collection('businesses'));
  }

  Stream<int> pendingReviewReportsCount() {
    return _countStream(
      _firestore
          .collection('review_reports')
          .where('status', isEqualTo: 'pending'),
    );
  }

  Stream<int> pendingFeedbackCount() {
    return _countStream(
      _firestore
          .collection('app_feedback')
          .where('status', isEqualTo: 'pending_triage'),
    );
  }

  /// Total visible reviews across all businesses.
  Stream<int> totalReviewsCount() {
    return _countStream(
      _firestore.collection('reviews').where('visible', isEqualTo: true),
    );
  }

  /// Total profile views across all business listings.
  Stream<int> totalProfileViewsCount() {
    return _sumNumericFieldStream(
      _firestore.collection('businesses'),
      field: 'viewCount',
    );
  }

  /// Total saves/favourites across all business listings.
  Stream<int> totalSavesCount() {
    return _sumNumericFieldStream(
      _firestore.collection('businesses'),
      field: 'savedCount',
    );
  }

  /// Total crowd reports submitted.
  Stream<int> totalCrowdReportsCount() {
    return _countStream(_firestore.collection('crowd_reports'));
  }

  /// Total photo uploads across businesses.
  Stream<int> totalPhotoUploadsCount() {
    return _sumNumericFieldStream(
      _firestore.collection('businesses'),
      field: 'photoCount',
    );
  }

  /// Total social shares recorded in the social_shares collection.
  /// This is the source of truth for social media sharing activity.
  Stream<int> totalSharesCount() {
    return _countStream(_firestore.collection('social_shares'));
  }

  /// Total post engagements (likes, saves, buzz votes).
  Stream<int> totalPostEngagementsCount() {
    return _countStream(_firestore.collection('post_engagements'));
  }

  /// Total buzz votes (reviews with a non-zero buzzRating).
  Stream<int> totalBuzzVotesCount() {
    return _countStream(
      _firestore
          .collection('reviews')
          .where('visible', isEqualTo: true)
          .where('buzzRating', isGreaterThan: 0),
    );
  }

  Stream<int> _countStream(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) => snapshot.size).distinct();
  }

  /// Sums a numeric field across all documents in a collection in real-time.
  Stream<int> _sumNumericFieldStream(
    Query<Map<String, dynamic>> query, {
    required String field,
  }) {
    return query.snapshots().map((snapshot) {
      var sum = 0;
      for (final doc in snapshot.docs) {
        final value = doc.data()[field];
        if (value is num) {
          sum += value.toInt();
        }
      }
      return sum;
    }).distinct();
  }

  /// Trend of new reviews created today vs yesterday.
  Stream<MetricTrend> reviewsTrend() {
    return _trendStream(
      _firestore.collection('reviews').where('visible', isEqualTo: true),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of new crowd reports filed today vs yesterday.
  Stream<MetricTrend> crowdReportsTrend() {
    return _trendStream(
      _firestore.collection('crowd_reports'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of buzz votes submitted today vs yesterday.
  Stream<MetricTrend> buzzVotesTrend() {
    return _trendStream(
      _firestore
          .collection('reviews')
          .where('visible', isEqualTo: true)
          .where('buzzRating', isGreaterThan: 0),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Weekly per-day analytics (Mon–Sun) combining users, businesses, events and reports.
  Stream<AdminWeeklyAnalytics> weeklyAnalytics() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final users = _weeklyCountStream(
      _firestore.collection('local_users'),
      start: start,
      end: end,
    );
    final businesses = _weeklyCountStream(
      _firestore.collection('businesses'),
      start: start,
      end: end,
    );
    final events = _weeklyCountStream(
      _firestore.collection('events'),
      start: start,
      end: end,
    );
    final reports = _combineWeeklySeries(
      _weeklyCountStream(
        _firestore.collection('event_reports'),
        start: start,
        end: end,
      ),
      _weeklyCountStream(
        _firestore.collection('review_reports'),
        start: start,
        end: end,
      ),
    );

    return _combineFourWeeklySeries(
      users,
      businesses,
      events,
      reports,
    ).map(
      (values) => AdminWeeklyAnalytics(
        newUsers: WeeklyAnalyticsSeries(values: values.$1),
        businessRegistrations: WeeklyAnalyticsSeries(values: values.$2),
        eventsCreated: WeeklyAnalyticsSeries(values: values.$3),
        reportsReceived: WeeklyAnalyticsSeries(values: values.$4),
      ),
    );
  }

  Stream<List<int>> _weeklyCountStream(
    Query<Map<String, dynamic>> query, {
    required DateTime start,
    required DateTime end,
  }) {
    return query
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final counts = List<int>.filled(7, 0);
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final DateTime? date = _timestampToDateTime(createdAt);
        if (date != null) {
          final index = date.weekday - 1; // Mon=0, Sun=6
          counts[index]++;
        }
      }
      return counts;
    }).distinct();
  }

  /// Real-time per-day analytics for the trailing [days] days (today
  /// inclusive), bucketed by day-offset-from-start rather than weekday so
  /// any range (7/30/90/365 days) is represented correctly. Powers the
  /// dashboard's date-range filter, unlike the fixed current-week
  /// [weeklyAnalytics].
  Stream<AdminWeeklyAnalytics> rangeAnalytics({required int days}) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final bucketDates =
        List<DateTime>.generate(days, (i) => startDay.add(Duration(days: i)));

    final users = _dailyCountStream(
      _firestore.collection('local_users'),
      start: startDay,
      end: end,
      days: days,
    );
    final businesses = _dailyCountStream(
      _firestore.collection('businesses'),
      start: startDay,
      end: end,
      days: days,
    );
    final events = _dailyCountStream(
      _firestore.collection('events'),
      start: startDay,
      end: end,
      days: days,
    );
    final reports = _combineDailySeries(
      _dailyCountStream(
        _firestore.collection('event_reports'),
        start: startDay,
        end: end,
        days: days,
      ),
      _dailyCountStream(
        _firestore.collection('review_reports'),
        start: startDay,
        end: end,
        days: days,
      ),
      days: days,
    );

    return _combineFourWeeklySeries(users, businesses, events, reports).map(
      (values) => AdminWeeklyAnalytics(
        newUsers: WeeklyAnalyticsSeries(values: values.$1),
        businessRegistrations: WeeklyAnalyticsSeries(values: values.$2),
        eventsCreated: WeeklyAnalyticsSeries(values: values.$3),
        reportsReceived: WeeklyAnalyticsSeries(values: values.$4),
        bucketDates: bucketDates,
      ),
    );
  }

  Stream<List<int>> _dailyCountStream(
    Query<Map<String, dynamic>> query, {
    required DateTime start,
    required DateTime end,
    required int days,
  }) {
    return query
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final counts = List<int>.filled(days, 0);
      final startDay = DateTime(start.year, start.month, start.day);
      for (final doc in snapshot.docs) {
        final date = _timestampToDateTime(doc.data()['createdAt']);
        if (date == null) continue;
        final dayIndex = DateTime(date.year, date.month, date.day)
            .difference(startDay)
            .inDays;
        if (dayIndex >= 0 && dayIndex < days) {
          counts[dayIndex]++;
        }
      }
      return counts;
    }).distinct();
  }

  /// Daily new business_subscriptions signups for the trailing [days] days.
  /// Real historical trend source for the Premium/Active Subscriptions KPI
  /// sparklines (no composite index required - single field range on
  /// createdAt only).
  Stream<List<int>> dailySubscriptionSignups({int days = 14}) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _dailyCountStream(
      _firestore.collection('business_subscriptions'),
      start: startDay,
      end: end,
      days: days,
    );
  }

  /// Daily paid revenue (in cents) for the trailing [days] days, from
  /// business_payments.paidAt. Real historical trend source for the
  /// Monthly Revenue KPI sparkline.
  Stream<List<int>> dailyRevenueCents({int days = 14}) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _firestore
        .collection('business_payments')
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
        .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final sums = List<int>.filled(days, 0);
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = _timestampToDateTime(data['paidAt']);
        if (date == null) continue;
        final dayIndex = DateTime(date.year, date.month, date.day)
            .difference(startDay)
            .inDays;
        if (dayIndex < 0 || dayIndex >= days) continue;
        final amount = data['amountCents'] ?? data['amount'] ?? data['amountPaid'];
        if (amount is num) {
          sums[dayIndex] += amount.toInt();
        }
      }
      return sums;
    }).distinct();
  }

  Stream<List<int>> _combineDailySeries(
    Stream<List<int>> a,
    Stream<List<int>> b, {
    required int days,
  }) {
    return _combineTwoLists(a, b).map(
      (pair) => List<int>.generate(days, (i) => pair.$1[i] + pair.$2[i]),
    );
  }

  /// Businesses ranked by number of reviews received, for the "most
  /// reviewed businesses" analytics section.
  Stream<List<Business>> topReviewedBusinesses({int limit = 5}) {
    return _firestore
        .collection('businesses')
        .orderBy('reviewCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  Stream<List<int>> _combineWeeklySeries(
    Stream<List<int>> a,
    Stream<List<int>> b,
  ) {
    return _combineTwoLists(a, b).map(
      (pair) => List<int>.generate(
        7,
        (i) => pair.$1[i] + pair.$2[i],
      ),
    );
  }

  Stream<(List<int>, List<int>)> _combineTwoLists(
    Stream<List<int>> a,
    Stream<List<int>> b,
  ) {
    late StreamController<(List<int>, List<int>)> controller;
    StreamSubscription<List<int>>? subA;
    StreamSubscription<List<int>>? subB;

    List<int>? valueA;
    List<int>? valueB;

    void emitIfReady() {
      if (valueA == null || valueB == null) return;
      controller.add((valueA!, valueB!));
    }

    controller = StreamController<(List<int>, List<int>)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  Stream<(List<int>, List<int>, List<int>, List<int>)> _combineFourWeeklySeries(
    Stream<List<int>> a,
    Stream<List<int>> b,
    Stream<List<int>> c,
    Stream<List<int>> d,
  ) {
    late StreamController<(List<int>, List<int>, List<int>, List<int>)>
        controller;
    StreamSubscription<List<int>>? subA;
    StreamSubscription<List<int>>? subB;
    StreamSubscription<List<int>>? subC;
    StreamSubscription<List<int>>? subD;

    List<int>? valueA;
    List<int>? valueB;
    List<int>? valueC;
    List<int>? valueD;

    void emitIfReady() {
      if (valueA == null ||
          valueB == null ||
          valueC == null ||
          valueD == null) {
        return;
      }
      controller.add((valueA!, valueB!, valueC!, valueD!));
    }

    controller = StreamController<(List<int>, List<int>, List<int>, List<int>)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subD = d.listen(
          (value) {
            valueD = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
        await subD?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  /// Trend of new user registrations over the last 7 days vs the prior 7 days.
  Stream<MetricTrend> usersTrend() {
    return _trendStream(
      _firestore.collection('local_users'),
      period: const Duration(days: 7),
      periodLabel: 'this week',
    );
  }

  /// Trend of new business listings created today vs yesterday.
  Stream<MetricTrend> businessesTrend() {
    return _trendStream(
      _firestore.collection('businesses'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of new events created today vs yesterday.
  Stream<MetricTrend> eventsTrend() {
    return _trendStream(
      _firestore.collection('events'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of new event reports filed today vs yesterday.
  Stream<MetricTrend> eventReportsTrend() {
    return _trendStream(
      _firestore.collection('event_reports'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of new review reports filed today vs yesterday.
  Stream<MetricTrend> reviewReportsTrend() {
    return _trendStream(
      _firestore.collection('review_reports'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  /// Trend of new pending approvals created today vs yesterday.
  Stream<MetricTrend> approvalsTrend() {
    return _trendStream(
      _firestore
          .collection('local_users')
          .where('approvalStatus', isEqualTo: 'pending'),
      period: const Duration(days: 1),
      periodLabel: 'today',
    );
  }

  Stream<MetricTrend> _trendStream(
    Query<Map<String, dynamic>> query, {
    required Duration period,
    required String periodLabel,
  }) {
    final now = DateTime.now();
    final currentStart = now.subtract(period);
    final previousStart = currentStart.subtract(period);

    final currentQuery = query.where(
      'createdAt',
      isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart),
    );
    final previousQuery = query.where(
      'createdAt',
      isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart),
      isLessThan: Timestamp.fromDate(currentStart),
    );

    return _combineTwoCounts(
      _countStream(currentQuery),
      _countStream(previousQuery),
    ).map(
      (counts) => MetricTrend(
        current: counts.$1,
        previous: counts.$2,
        periodLabel: periodLabel,
      ),
    );
  }

  Stream<(int, int)> _combineTwoCounts(Stream<int> a, Stream<int> b) {
    late StreamController<(int, int)> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;

    int? valueA;
    int? valueB;

    void emitIfReady() {
      if (valueA == null || valueB == null) return;
      controller.add((valueA!, valueB!));
    }

    controller = StreamController<(int, int)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  // -------------------------------------------------------------------------
  // Premium / Subscription / Revenue helpers
  // -------------------------------------------------------------------------

  /// Businesses with an active subscription or explicit premium flag.
  Stream<int> premiumBusinessesCount() {
    return _combineTwoCounts(
      _countStream(
        _firestore.collection('businesses').where('isPremium', isEqualTo: true),
      ),
      _countStream(
        _firestore
            .collection('business_subscriptions')
            .where('status', whereIn: const ['active', 'trialing']),
      ),
    ).map((pair) => pair.$1 + pair.$2);
  }

  /// Active subscriptions from the business_subscriptions collection.
  Stream<int> activeSubscriptionsCount() {
    return _countStream(
      _firestore
          .collection('business_subscriptions')
          .where('status', whereIn: const ['active', 'trialing']),
    );
  }

  /// Cancelled (or past-due/cancelled) subscriptions.
  Stream<int> cancelledSubscriptionsCount() {
    return _countStream(
      _firestore.collection('business_subscriptions').where('status',
          whereIn: const ['canceled', 'cancelled', 'past_due']),
    );
  }

  /// Total revenue this month in cents from business_payments.
  Stream<int> monthlyRevenueCents() {
    return _revenueStream(period: const Duration(days: 30));
  }

  /// Total revenue today in cents from business_payments.
  Stream<int> todayRevenueCents() {
    return _revenueStream(period: const Duration(days: 1));
  }

  /// Monthly Recurring Revenue estimate (active subscriptions × price).
  /// Uses cached subscription price cents if available, otherwise A$19.90.
  Stream<int> monthlyRecurringRevenueCents() {
    return activeSubscriptionsCount().map(
      (subscriptionCount) => subscriptionCount * 1990,
    );
  }

  /// Active promotions (scheduled or running).
  Stream<int> activePromotionsCount() {
    return _countStream(
      _firestore.collection('promotions').where('status', isEqualTo: 'active'),
    );
  }

  /// Running promotions count (alias that includes any non-completed promotion).
  Stream<int> runningPromotionsCount() {
    return _countStream(
      _firestore
          .collection('promotions')
          .where('status', whereIn: const ['active', 'scheduled']),
    );
  }

  Stream<int> _revenueStream({required Duration period}) {
    final now = DateTime.now();
    final start = now.subtract(period);
    return _firestore
        .collection('business_payments')
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .snapshots()
        .map((snapshot) {
      var sum = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount =
            data['amountCents'] ?? data['amount'] ?? data['amountPaid'];
        if (amount is num) {
          sum += amount.toInt();
        }
      }
      return sum;
    }).distinct();
  }

  // -------------------------------------------------------------------------
  // Today’s summary
  // -------------------------------------------------------------------------

  Stream<TodaySummary> todaySummary() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final newUsers = _countStream(
      _firestore
          .collection('local_users')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay)),
    );
    final newBusinesses = _countStream(
      _firestore
          .collection('businesses')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay)),
    );
    final pendingApprovals = pendingLocalUsersCount();
    final newReports = _countStream(
      _firestore
          .collection('review_reports')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay)),
    );
    final activePromotions = activePromotionsCount();
    final expiringSubscriptions = _countStream(
      _firestore
          .collection('business_subscriptions')
          .where('status', isEqualTo: 'active')
          .where('currentPeriodEnd',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(now.add(const Duration(days: 7)))),
    );

    return _combineSixCounts(
      newUsers,
      newBusinesses,
      pendingApprovals,
      newReports,
      activePromotions,
      expiringSubscriptions,
    ).map(
      (values) => TodaySummary(
        newUsers: values.$1,
        newBusinesses: values.$2,
        pendingApprovals: values.$3,
        newReports: values.$4,
        activePromotions: values.$5,
        expiringSubscriptions: values.$6,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Pending business approvals
  // -------------------------------------------------------------------------

  Stream<List<PendingBusinessApproval>> pendingBusinessApprovals(
      {int limit = 3}) {
    return _firestore
        .collection('businesses')
        .where('isVerified', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PendingBusinessApproval(
          id: doc.id,
          name: (data['businessName'] as String? ?? '').trim(),
          category: (data['category'] as String? ?? '').trim(),
          address: (data['address'] as String? ?? '').trim(),
          logoUrl: data['logoUrl'] as String?,
          ownerId: (data['ownerId'] as String? ?? '').trim(),
          createdAt: _timestampToDateTime(data['createdAt']),
        );
      }).toList();
    });
  }

  /// Approve or reject a pending business.
  Future<void> setBusinessVerified(
    String businessId, {
    required bool verified,
    String? rejectionReason,
  }) async {
    final update = <String, dynamic>{
      'isVerified': verified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!verified && rejectionReason != null && rejectionReason.isNotEmpty) {
      update['rejectionReason'] = rejectionReason;
    } else {
      update['rejectionReason'] = FieldValue.delete();
    }

    await _firestore.collection('businesses').doc(businessId).update(update);
  }

  // -------------------------------------------------------------------------
  // Recent users
  // -------------------------------------------------------------------------

  Stream<List<RecentAdminUser>> recentUsers({int limit = 5}) {
    final visitors = _firestore
        .collection('visitor_users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _recentUserFromDoc(doc, 'visitor'))
            .toList());
    final locals = _firestore
        .collection('local_users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => _recentUserFromDoc(doc, 'local')).toList());
    final admins = _firestore
        .collection('admins')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => _recentUserFromDoc(doc, 'admin')).toList());

    return _combineThreeLists(visitors, locals, admins).map((triple) {
      final merged = [...triple.$1, ...triple.$2, ...triple.$3];
      merged.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return merged.take(limit).toList();
    });
  }

  RecentAdminUser _recentUserFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String role,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = (data['name'] as String? ?? '').trim();
    final businessName = (data['businessName'] as String? ?? '').trim();
    final username = (data['username'] as String? ?? '').trim();
    final email = (data['email'] as String? ?? doc.id).trim();
    final active = data['active'] == true;
    final approvalStatus =
        (data['approvalStatus'] as String? ?? '').toLowerCase();

    String displayName;
    if (businessName.isNotEmpty) {
      displayName = businessName;
    } else if (name.isNotEmpty) {
      displayName = name;
    } else if (username.isNotEmpty) {
      displayName = username;
    } else if (email.isNotEmpty) {
      displayName = 'Unnamed User';
    } else {
      displayName = 'Unnamed User';
    }

    UserStatus status;
    if (!active) {
      status = UserStatus.suspended;
    } else if (approvalStatus == 'pending') {
      status = UserStatus.pending;
    } else {
      status = UserStatus.active;
    }

    return RecentAdminUser(
      id: doc.id,
      name: displayName,
      email: email,
      role: role,
      status: status,
      createdAt: _timestampToDateTime(data['createdAt']),
    );
  }

  // -------------------------------------------------------------------------
  // Recent activity feed
  // -------------------------------------------------------------------------

  Stream<List<AdminActivityItem>> recentActivity({int limit = 10}) {
    return _firestore
        .collection('admin_activity')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AdminActivityItem(
          id: doc.id,
          type: AdminActivityType.fromString(data['type'] as String? ?? ''),
          message: (data['message'] as String? ?? '').trim(),
          relatedId: data['relatedId'] as String?,
          relatedCollection: data['relatedCollection'] as String?,
          createdAt: _timestampToDateTime(data['createdAt']),
        );
      }).toList();
    }).handleError((_) => <AdminActivityItem>[]);
  }

  // -------------------------------------------------------------------------
  // Revenue summary
  // -------------------------------------------------------------------------

  Stream<RevenueSummary> revenueSummary() {
    return _combineFiveCounts(
      todayRevenueCents(),
      monthlyRevenueCents(),
      activeSubscriptionsCount(),
      cancelledSubscriptionsCount(),
      runningPromotionsCount(),
    ).map(
      (values) => RevenueSummary(
        revenueTodayCents: values.$1,
        monthlyRevenueCents: values.$2,
        activeSubscribers: values.$3,
        cancelledSubscriptions: values.$4,
        monthlyRecurringRevenueCents: values.$3 * 1990,
        runningPromotions: values.$5,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Internal combinators
  // -------------------------------------------------------------------------

  Stream<(int, int, int, int, int)> _combineFiveCounts(
    Stream<int> a,
    Stream<int> b,
    Stream<int> c,
    Stream<int> d,
    Stream<int> e,
  ) {
    late StreamController<(int, int, int, int, int)> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;
    StreamSubscription<int>? subC;
    StreamSubscription<int>? subD;
    StreamSubscription<int>? subE;

    int? valueA;
    int? valueB;
    int? valueC;
    int? valueD;
    int? valueE;

    void emitIfReady() {
      if (valueA == null ||
          valueB == null ||
          valueC == null ||
          valueD == null ||
          valueE == null) {
        return;
      }
      controller.add((valueA!, valueB!, valueC!, valueD!, valueE!));
    }

    controller = StreamController<(int, int, int, int, int)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subD = d.listen(
          (value) {
            valueD = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subE = e.listen(
          (value) {
            valueE = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
        await subD?.cancel();
        await subE?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  Stream<(int, int, int, int, int, int)> _combineSixCounts(
    Stream<int> a,
    Stream<int> b,
    Stream<int> c,
    Stream<int> d,
    Stream<int> e,
    Stream<int> f,
  ) {
    late StreamController<(int, int, int, int, int, int)> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;
    StreamSubscription<int>? subC;
    StreamSubscription<int>? subD;
    StreamSubscription<int>? subE;
    StreamSubscription<int>? subF;

    int? valueA;
    int? valueB;
    int? valueC;
    int? valueD;
    int? valueE;
    int? valueF;

    void emitIfReady() {
      if (valueA == null ||
          valueB == null ||
          valueC == null ||
          valueD == null ||
          valueE == null ||
          valueF == null) {
        return;
      }
      controller.add((valueA!, valueB!, valueC!, valueD!, valueE!, valueF!));
    }

    controller = StreamController<(int, int, int, int, int, int)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subD = d.listen(
          (value) {
            valueD = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subE = e.listen(
          (value) {
            valueE = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subF = f.listen(
          (value) {
            valueF = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
        await subD?.cancel();
        await subE?.cancel();
        await subF?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  Stream<(List<A>, List<B>, List<C>)> _combineThreeLists<A, B, C>(
    Stream<List<A>> a,
    Stream<List<B>> b,
    Stream<List<C>> c,
  ) {
    late StreamController<(List<A>, List<B>, List<C>)> controller;
    StreamSubscription<List<A>>? subA;
    StreamSubscription<List<B>>? subB;
    StreamSubscription<List<C>>? subC;

    List<A>? valueA;
    List<B>? valueB;
    List<C>? valueC;

    void emitIfReady() {
      if (valueA == null || valueB == null || valueC == null) {
        return;
      }
      controller.add((valueA!, valueB!, valueC!));
    }

    controller = StreamController<(List<A>, List<B>, List<C>)>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  Stream<int> _sumTwoStreams(
    Stream<int> a,
    Stream<int> b,
  ) {
    late StreamController<int> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;

    int? valueA;
    int? valueB;

    void emitIfReady() {
      if (valueA == null || valueB == null) {
        return;
      }
      controller.add(valueA! + valueB!);
    }

    controller = StreamController<int>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );

        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  Stream<int> _sumThreeStreams(
    Stream<int> a,
    Stream<int> b,
    Stream<int> c,
  ) {
    late StreamController<int> controller;
    StreamSubscription<int>? subA;
    StreamSubscription<int>? subB;
    StreamSubscription<int>? subC;

    int? valueA;
    int? valueB;
    int? valueC;

    void emitIfReady() {
      if (valueA == null || valueB == null || valueC == null) {
        return;
      }
      controller.add(valueA! + valueB! + valueC!);
    }

    controller = StreamController<int>(
      onListen: () {
        subA = a.listen(
          (value) {
            valueA = value;
            emitIfReady();
          },
          onError: controller.addError,
        );

        subB = b.listen(
          (value) {
            valueB = value;
            emitIfReady();
          },
          onError: controller.addError,
        );

        subC = c.listen(
          (value) {
            valueC = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await subC?.cancel();
      },
    );

    return controller.stream.distinct();
  }
}
