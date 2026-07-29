import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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

  const AdminWeeklyAnalytics({
    required this.newUsers,
    required this.businessRegistrations,
    required this.eventsCreated,
    required this.reportsReceived,
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
      if (valueA == null || valueB == null || valueC == null || valueD == null) {
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
