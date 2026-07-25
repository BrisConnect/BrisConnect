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

  Stream<int> _countStream(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) => snapshot.size).distinct();
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
