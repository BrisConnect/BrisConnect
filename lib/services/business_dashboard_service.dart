import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/models/audience_interaction.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/audience_analytics_service.dart';

/// Aggregated metrics for a business owner's dashboard.
class BusinessDashboardMetrics {
  final int profileViews;
  final int saves;
  final int activePromotions;
  final int upcomingEvents;
  final int newReviews;
  final int totalReviews;
  final double averageRating;
  final double averageBuzzRating;
  final int totalBuzzVotes;
  final double profileViewsChange;
  final double savesChange;
  final double activePromotionsChange;
  final double upcomingEventsChange;
  final double newReviewsChange;
  final double buzzScore;
  final String? crowdLevel;
  final int crowdReportCount;

  const BusinessDashboardMetrics({
    this.profileViews = 0,
    this.saves = 0,
    this.activePromotions = 0,
    this.upcomingEvents = 0,
    this.newReviews = 0,
    this.totalReviews = 0,
    this.averageRating = 0.0,
    this.averageBuzzRating = 0.0,
    this.totalBuzzVotes = 0,
    this.profileViewsChange = 0,
    this.savesChange = 0,
    this.activePromotionsChange = 0,
    this.upcomingEventsChange = 0,
    this.newReviewsChange = 0,
    this.buzzScore = 0.0,
    this.crowdLevel,
    this.crowdReportCount = 0,
  });
}

/// Service for the business owner dashboard summary.
///
/// Aggregates views, saves, active promotions, upcoming events, reviews,
/// buzz votes, and live crowd reports. Trend percentages compare the current
/// rolling 7-day window to the previous 7-day window.
class BusinessDashboardService {
  final FirebaseFirestore _firestore;
  final AudienceAnalyticsService? _audienceAnalyticsService;

  BusinessDashboardService({
    FirebaseFirestore? firestore,
    AudienceAnalyticsService? audienceAnalyticsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _audienceAnalyticsService = audienceAnalyticsService;

  FirebaseFirestore get firestore => _firestore;

  static const String _businessesCollection = 'businesses';
  static const String _businessEventsCollection = 'business_events';
  static const String _reviewsCollection = 'reviews';
  static const String _promotionsCollection = 'promotions';
  static const String _crowdReportsCollection = 'crowd_reports';

  /// Real-time aggregated metrics for all businesses owned by [ownerId].
  ///
  /// The returned stream updates whenever any of the underlying collections
  /// change: businesses (views/saves), promotions, events, reviews, or crowd
  /// reports.
  Stream<BusinessDashboardMetrics> metricsStream(String ownerId) {
    return _businessesForOwner(ownerId)
        .asyncExpand((businesses) => _liveMetricsStreamForBusinesses(businesses));
  }

  /// One-time fetch of aggregated metrics.
  Future<BusinessDashboardMetrics> getMetrics(String ownerId) async {
    final businesses = await _businessesForOwner(ownerId).first;
    return _metricsForBusinesses(businesses);
  }

  /// Stream of the businesses owned by [ownerId].
  Stream<List<Business>> _businessesForOwner(String ownerId) {
    return _firestore
        .collection(_businessesCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Business.fromFirestore(doc))
              .toList(),
        );
  }

  /// Combines live snapshots from all relevant collections into a single
  /// real-time metrics stream.
  Stream<BusinessDashboardMetrics> _liveMetricsStreamForBusinesses(
    List<Business> initialBusinesses,
  ) {
    if (initialBusinesses.isEmpty) {
      return Stream.value(const BusinessDashboardMetrics());
    }

    final ownerId = initialBusinesses.first.ownerId;
    final businessIds = initialBusinesses.map((b) => b.id!).toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final since = now.subtract(const Duration(hours: 2));

    late StreamController<BusinessDashboardMetrics> controller;
    StreamSubscription<List<Business>>? businessesSub;
    StreamSubscription<int>? promotionsSub;
    StreamSubscription<int>? eventsSub;
    StreamSubscription<_ReviewsResult>? reviewsSub;
    StreamSubscription<_CrowdResult>? crowdSub;

    List<Business>? latestBusinesses;
    int? latestPromotions;
    int? latestEvents;
    _ReviewsResult? latestReviews;
    _CrowdResult? latestCrowd;

    void emitIfReady() {
      if (latestBusinesses == null ||
          latestPromotions == null ||
          latestEvents == null ||
          latestReviews == null ||
          latestCrowd == null) {
        return;
      }
      controller.add(
        _computeMetrics(
          latestBusinesses!,
          latestPromotions!,
          latestEvents!,
          latestReviews!,
          latestCrowd!,
          weekAgo,
          twoWeeksAgo,
        ),
      );
    }

    controller = StreamController<BusinessDashboardMetrics>(
      onListen: () {
        businessesSub = _businessesForOwner(ownerId).listen(
          (businesses) {
            latestBusinesses = businesses;
            emitIfReady();
          },
          onError: controller.addError,
        );
        promotionsSub = _activePromotionsStream(ownerId).listen(
          (value) {
            latestPromotions = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        eventsSub = _upcomingEventsStream(ownerId, now).listen(
          (value) {
            latestEvents = value;
            emitIfReady();
          },
          onError: controller.addError,
        );
        reviewsSub = _reviewsStream(businessIds, twoWeeksAgo).listen(
          (result) {
            latestReviews = result;
            emitIfReady();
          },
          onError: controller.addError,
        );
        crowdSub = _crowdReportsStream(businessIds, since).listen(
          (result) {
            latestCrowd = result;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await businessesSub?.cancel();
        await promotionsSub?.cancel();
        await eventsSub?.cancel();
        await reviewsSub?.cancel();
        await crowdSub?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  /// Computes metrics from the latest snapshot of each data source.
  BusinessDashboardMetrics _computeMetrics(
    List<Business> businesses,
    int activePromotions,
    int upcomingEvents,
    _ReviewsResult reviews,
    _CrowdResult crowd,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) {
    if (businesses.isEmpty) return const BusinessDashboardMetrics();

    final viewsResult = _profileViewsFromBusinesses(businesses, weekAgo, twoWeeksAgo);
    final savesResult = _savesFromBusinesses(businesses, weekAgo, twoWeeksAgo);
    final buzzScore = _averageBuzzScore(businesses);

    final currentViews = viewsResult['current'] ?? 0;
    final previousViews = viewsResult['previous'] ?? 0;
    final currentSaves = savesResult['current'] ?? 0;
    final previousSaves = savesResult['previous'] ?? 0;

    return BusinessDashboardMetrics(
      profileViews: currentViews,
      saves: currentSaves,
      activePromotions: activePromotions,
      upcomingEvents: upcomingEvents,
      newReviews: reviews.currentWeekCount,
      totalReviews: reviews.totalCount,
      averageRating: reviews.averageRating,
      averageBuzzRating: reviews.averageBuzz,
      totalBuzzVotes: reviews.totalBuzzVotes,
      profileViewsChange: _percentageChange(currentViews, previousViews),
      savesChange: _percentageChange(currentSaves, previousSaves),
      activePromotionsChange: 0,
      upcomingEventsChange: 0,
      newReviewsChange: _percentageChange(
        reviews.currentWeekCount,
        reviews.previousWeekCount,
      ),
      buzzScore: buzzScore,
      crowdLevel: crowd.level,
      crowdReportCount: crowd.reportCount,
    );
  }

  Future<BusinessDashboardMetrics> _metricsForBusinesses(
    List<Business> businesses,
  ) async {
    if (businesses.isEmpty) return const BusinessDashboardMetrics();

    final ownerId = businesses.first.ownerId;
    final businessIds = businesses.map((b) => b.id!).toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final viewsResult = _profileViewsFromBusinesses(businesses, weekAgo, twoWeeksAgo);
    final savesResult = _savesFromBusinesses(businesses, weekAgo, twoWeeksAgo);
    final activePromotions = await _activePromotions(ownerId);
    final upcomingEvents = await _upcomingEvents(ownerId, now);
    final reviewsResult = await _newReviews(businessIds, weekAgo, twoWeeksAgo);
    final allReviewsResult = await _allReviews(businessIds);
    final buzzScore = _averageBuzzScore(businesses);
    final crowdStatus = await _latestCrowdStatus(businessIds);

    final currentViews = viewsResult['current'] ?? 0;
    final previousViews = viewsResult['previous'] ?? 0;
    final currentSaves = savesResult['current'] ?? 0;
    final previousSaves = savesResult['previous'] ?? 0;
    final currentReviews = reviewsResult['current'] ?? 0;
    final previousReviews = reviewsResult['previous'] ?? 0;

    return BusinessDashboardMetrics(
      profileViews: currentViews,
      saves: currentSaves,
      activePromotions: activePromotions,
      upcomingEvents: upcomingEvents,
      newReviews: currentReviews,
      totalReviews: allReviewsResult.totalCount,
      averageRating: allReviewsResult.averageRating,
      averageBuzzRating: allReviewsResult.averageBuzz,
      totalBuzzVotes: allReviewsResult.totalBuzzVotes,
      profileViewsChange: _percentageChange(currentViews, previousViews),
      savesChange: _percentageChange(currentSaves, previousSaves),
      activePromotionsChange: 0,
      upcomingEventsChange: 0,
      newReviewsChange: _percentageChange(currentReviews, previousReviews),
      buzzScore: buzzScore,
      crowdLevel: crowdStatus?.level,
      crowdReportCount: crowdStatus?.reportCount ?? 0,
    );
  }

  Map<String, int> _profileViewsFromBusinesses(
    List<Business> businesses,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) {
    var current = 0;
    var previous = 0;
    for (final business in businesses) {
      final history = business.viewHistory;
      if (history.isNotEmpty) {
        current += _sumHistoryInRange(history, weekAgo, DateTime.now());
        previous += _sumHistoryInRange(history, twoWeeksAgo, weekAgo);
      } else {
        current += business.viewCount;
      }
    }
    return {'current': current, 'previous': previous};
  }

  Map<String, int> _savesFromBusinesses(
    List<Business> businesses,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) {
    var current = 0;
    var previous = 0;
    for (final business in businesses) {
      final history = business.saveHistory;
      if (history.isNotEmpty) {
        current += _sumHistoryInRange(history, weekAgo, DateTime.now());
        previous += _sumHistoryInRange(history, twoWeeksAgo, weekAgo);
      } else {
        current += business.savedCount;
      }
    }
    return {'current': current, 'previous': previous};
  }

  Future<int> _activePromotions(String ownerId) async {
    final snapshot = await _firestore
        .collection(_promotionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .where('endAt', isGreaterThanOrEqualTo: Timestamp.now())
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> _activePromotionsStream(String ownerId) {
    return _firestore
        .collection(_promotionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .where('endAt', isGreaterThanOrEqualTo: Timestamp.now())
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<int> _upcomingEvents(String ownerId, DateTime now) async {
    final snapshot = await _firestore
        .collection(_businessEventsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'published')
        .where('date', isGreaterThanOrEqualTo: _formatDate(now))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> _upcomingEventsStream(String ownerId, DateTime now) {
    return _firestore
        .collection(_businessEventsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('status', isEqualTo: 'published')
        .where('date', isGreaterThanOrEqualTo: _formatDate(now))
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<Map<String, int>> _newReviews(
    List<String> businessIds,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) async {
    var current = 0;
    var previous = 0;
    for (final businessId in businessIds) {
      final currentSnap = await _firestore
          .collection(_reviewsCollection)
          .where('businessId', isEqualTo: businessId)
          .where('visible', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .count()
          .get();
      final previousSnap = await _firestore
          .collection(_reviewsCollection)
          .where('businessId', isEqualTo: businessId)
          .where('visible', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twoWeeksAgo))
          .where('createdAt', isLessThan: Timestamp.fromDate(weekAgo))
          .count()
          .get();
      current += currentSnap.count ?? 0;
      previous += previousSnap.count ?? 0;
    }
    return {'current': current, 'previous': previous};
  }

  /// Live snapshot of visible reviews across [businessIds] created within the
  /// last [since] days. Includes per-review rating/buzz data so total and
  /// average metrics can be recomputed on every change.
  Stream<_ReviewsResult> _reviewsStream(
    List<String> businessIds,
    DateTime since,
  ) {
    if (businessIds.isEmpty) {
      return Stream.value(const _ReviewsResult());
    }

    final chunks = _chunk(businessIds, 10);
    final chunkStreams = chunks.map((chunk) {
      return _firestore
          .collection(_reviewsCollection)
          .where('businessId', whereIn: chunk)
          .where('visible', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .snapshots()
          .map(_ReviewsResult.fromSnapshot);
    }).toList();

    if (chunkStreams.length == 1) return chunkStreams.first;

    late StreamController<_ReviewsResult> controller;
    final subscriptions = <StreamSubscription<_ReviewsResult>>[];
    final latest = List<_ReviewsResult?>.filled(chunkStreams.length, null);

    void emitIfReady() {
      if (latest.every((r) => r != null)) {
        controller.add(
          latest.whereType<_ReviewsResult>().reduce((a, b) => a.merge(b)),
        );
      }
    }

    controller = StreamController<_ReviewsResult>(
      onListen: () {
        for (var i = 0; i < chunkStreams.length; i++) {
          subscriptions.add(
            chunkStreams[i].listen(
              (result) {
                latest[i] = result;
                emitIfReady();
              },
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream.distinct();
  }

  Future<_ReviewsResult> _allReviews(List<String> businessIds) async {
    if (businessIds.isEmpty) return const _ReviewsResult();

    final chunks = _chunk(businessIds, 10);
    final results = <_ReviewsResult>[];
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('businessId', whereIn: chunk)
          .where('visible', isEqualTo: true)
          .get();
      results.add(_ReviewsResult.fromSnapshot(snapshot));
    }
    return results.reduce((a, b) => a.merge(b));
  }

  /// Average [Business.buzzScore] across [businesses], weighted by review count.
  double _averageBuzzScore(List<Business> businesses) {
    if (businesses.isEmpty) return 0.0;
    var totalScore = 0.0;
    var totalWeight = 0;
    for (final b in businesses) {
      final weight = b.reviewCount > 0 ? b.reviewCount : 1;
      totalScore += b.buzzScore * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return 0.0;
    return totalScore / totalWeight;
  }

  /// Latest crowd status across all [businessIds] using reports from the last 2 hours.
  Future<_CrowdStatusSummary?> _latestCrowdStatus(List<String> businessIds) async {
    if (businessIds.isEmpty) return null;
    try {
      final since = DateTime.now().subtract(const Duration(hours: 2));
      final query = _firestore
          .collection(_crowdReportsCollection)
          .where('businessId', whereIn: businessIds)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true);
      final snap = await query.get();
      if (snap.docs.isEmpty) return null;

      var totalWeight = 0;
      for (final doc in snap.docs) {
        totalWeight += (doc['weight'] as num?)?.toInt() ?? 2;
      }
      final avg = totalWeight / snap.docs.length;
      String label;
      if (avg < 1.67) {
        label = 'Low';
      } else if (avg < 2.34) {
        label = 'Moderate';
      } else {
        label = 'High';
      }
      return _CrowdStatusSummary(
        level: label,
        reportCount: snap.docs.length,
        lastReported: (snap.docs.first['timestamp'] as Timestamp).toDate(),
      );
    } catch (e) {
      debugPrint('[BusinessDashboardService] crowd status aggregation failed: $e');
      return null;
    }
  }

  /// Live crowd status across all [businessIds] using reports since [since].
  Stream<_CrowdResult> _crowdReportsStream(
    List<String> businessIds,
    DateTime since,
  ) {
    if (businessIds.isEmpty) return Stream.value(const _CrowdResult());

    final chunks = _chunk(businessIds, 10);
    final chunkStreams = chunks.map((chunk) {
      return _firestore
          .collection(_crowdReportsCollection)
          .where('businessId', whereIn: chunk)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map(_CrowdResult.fromSnapshot);
    }).toList();

    if (chunkStreams.length == 1) return chunkStreams.first;

    late StreamController<_CrowdResult> controller;
    final subscriptions = <StreamSubscription<_CrowdResult>>[];
    final latest = List<_CrowdResult?>.filled(chunkStreams.length, null);

    void emitIfReady() {
      if (latest.every((r) => r != null)) {
        controller.add(
          latest.whereType<_CrowdResult>().reduce((a, b) => a.merge(b)),
        );
      }
    }

    controller = StreamController<_CrowdResult>(
      onListen: () {
        for (var i = 0; i < chunkStreams.length; i++) {
          subscriptions.add(
            chunkStreams[i].listen(
              (result) {
                latest[i] = result;
                emitIfReady();
              },
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      },
    );

    return controller.stream.distinct();
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  int _sumHistoryInRange(
    Map<String, int> history,
    DateTime start,
    DateTime end,
  ) {
    var sum = 0;
    history.forEach((key, value) {
      try {
        // Support both "dd-mm-yyyy" (service format) and "dd/mm/yyyy" (legacy).
        final separator = key.contains('-') ? '-' : (key.contains('/') ? '/' : '');
        if (separator.isEmpty) return;
        final parts = key.split(separator);
        if (parts.length != 3) return;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final parsed = DateTime(year, month, day);
        if (!parsed.isBefore(start) && parsed.isBefore(end)) {
          sum += value;
        }
      } catch (_) {
        // Ignore malformed history keys.
      }
    });
    return sum;
  }

  double _percentageChange(int current, int previous) {
    if (previous == 0) return current > 0 ? 1.0 : 0.0;
    return (current - previous) / previous;
  }

  /// Test-only helper to expose percentage change logic.
  double percentageChangeForTest(int current, int previous) =>
      _percentageChange(current, previous);

  String _formatDate(DateTime date) {
    final d = date;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    // Use hyphen separators because Firestore field paths cannot contain '/'.
    return '$day-$month-$year';
  }

  /// Records a profile view for [businessId] and updates daily view history.
  ///
  /// If [visitorId] is provided, an anonymised audience interaction is also
  /// recorded for new vs returning analytics.
  Future<void> recordProfileView(
    String businessId, {
    String? visitorId,
  }) async {
    final today = _formatDate(DateTime.now());
    try {
      final businessDoc = await _firestore
          .collection(_businessesCollection)
          .doc(businessId)
          .get();
      final ownerId = businessDoc.data()?['ownerId'] as String? ?? '';

      await _firestore.collection(_businessesCollection).doc(businessId).set({
        'viewCount': FieldValue.increment(1),
        'viewHistory.$today': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (visitorId != null &&
          visitorId.trim().isNotEmpty &&
          ownerId.isNotEmpty) {
        await _audienceAnalyticsService?.recordInteraction(
          businessId: businessId,
          ownerId: ownerId,
          visitorId: visitorId,
          type: AudienceInteractionType.view,
        );
      }
    } catch (e) {
      debugPrint('[BusinessDashboardService] recordProfileView failed: $e');
    }
  }

  /// Records a save/favourite for [businessId] and updates daily save history.
  ///
  /// If [visitorId] is provided, an anonymised audience interaction is also
  /// recorded for new vs returning analytics.
  Future<void> recordSave(
    String businessId, {
    String? visitorId,
  }) async {
    final today = _formatDate(DateTime.now());
    try {
      final businessDoc = await _firestore
          .collection(_businessesCollection)
          .doc(businessId)
          .get();
      final ownerId = businessDoc.data()?['ownerId'] as String? ?? '';

      await _firestore.collection(_businessesCollection).doc(businessId).set({
        'savedCount': FieldValue.increment(1),
        'saveHistory.$today': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (visitorId != null &&
          visitorId.trim().isNotEmpty &&
          ownerId.isNotEmpty) {
        await _audienceAnalyticsService?.recordInteraction(
          businessId: businessId,
          ownerId: ownerId,
          visitorId: visitorId,
          type: AudienceInteractionType.save,
        );
      }
    } catch (e) {
      debugPrint('[BusinessDashboardService] recordSave failed: $e');
    }
  }
}

class _CrowdStatusSummary {
  final String level;
  final int reportCount;
  final DateTime lastReported;

  const _CrowdStatusSummary({
    required this.level,
    required this.reportCount,
    required this.lastReported,
  });
}

/// Aggregated review data derived from a Firestore snapshot.
class _ReviewsResult {
  final int currentWeekCount;
  final int previousWeekCount;
  final int totalCount;
  final int totalBuzzVotes;
  final double averageBuzz;
  final double averageRating;

  const _ReviewsResult({
    this.currentWeekCount = 0,
    this.previousWeekCount = 0,
    this.totalCount = 0,
    this.totalBuzzVotes = 0,
    this.averageBuzz = 0.0,
    this.averageRating = 0.0,
  });

  factory _ReviewsResult.fromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    var currentWeekCount = 0;
    var previousWeekCount = 0;
    var totalRating = 0;
    var totalBuzz = 0;
    var buzzVoteCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        if (!createdAt.isBefore(weekAgo)) {
          currentWeekCount++;
        } else if (!createdAt.isBefore(twoWeeksAgo) && createdAt.isBefore(weekAgo)) {
          previousWeekCount++;
        }
      }
      totalRating += (data['rating'] as num?)?.toInt() ?? 0;
      final buzz = (data['buzzRating'] as num?)?.toInt() ?? 0;
      if (buzz > 0) {
        totalBuzz += buzz;
        buzzVoteCount++;
      }
    }

    final totalCount = snapshot.docs.length;
    return _ReviewsResult(
      currentWeekCount: currentWeekCount,
      previousWeekCount: previousWeekCount,
      totalCount: totalCount,
      totalBuzzVotes: buzzVoteCount,
      averageBuzz: buzzVoteCount > 0 ? totalBuzz / buzzVoteCount : 0.0,
      averageRating: totalCount > 0 ? totalRating / totalCount : 0.0,
    );
  }

  _ReviewsResult merge(_ReviewsResult other) {
    final newTotalCount = totalCount + other.totalCount;
    final newBuzzVoteCount = totalBuzzVotes + other.totalBuzzVotes;
    final newAverageRating = newTotalCount > 0
        ? ((averageRating * totalCount) + (other.averageRating * other.totalCount)) /
            newTotalCount
        : 0.0;
    final newAverageBuzz = newBuzzVoteCount > 0
        ? ((averageBuzz * totalBuzzVotes) +
                (other.averageBuzz * other.totalBuzzVotes)) /
            newBuzzVoteCount
        : 0.0;

    return _ReviewsResult(
      currentWeekCount: currentWeekCount + other.currentWeekCount,
      previousWeekCount: previousWeekCount + other.previousWeekCount,
      totalCount: newTotalCount,
      totalBuzzVotes: newBuzzVoteCount,
      averageBuzz: newAverageBuzz,
      averageRating: newAverageRating,
    );
  }
}

/// Aggregated crowd report data derived from a Firestore snapshot.
class _CrowdResult {
  final String? level;
  final int reportCount;
  final DateTime? lastReported;

  const _CrowdResult({this.level, this.reportCount = 0, this.lastReported});

  factory _CrowdResult.fromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (snapshot.docs.isEmpty) {
      return const _CrowdResult();
    }

    var totalWeight = 0;
    DateTime? lastReported;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalWeight += (data['weight'] as num?)?.toInt() ?? 2;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null &&
          (lastReported == null || timestamp.isAfter(lastReported))) {
        lastReported = timestamp;
      }
    }

    final avg = totalWeight / snapshot.docs.length;
    String label;
    if (avg < 1.67) {
      label = 'Low';
    } else if (avg < 2.34) {
      label = 'Moderate';
    } else {
      label = 'High';
    }

    return _CrowdResult(
      level: label,
      reportCount: snapshot.docs.length,
      lastReported: lastReported,
    );
  }

  _CrowdResult merge(_CrowdResult other) {
    if (reportCount == 0) return other;
    if (other.reportCount == 0) return this;

    final totalWeight = (_estimateWeight(this) * reportCount) +
        (_estimateWeight(other) * other.reportCount);
    final avg = totalWeight / (reportCount + other.reportCount);
    String label;
    if (avg < 1.67) {
      label = 'Low';
    } else if (avg < 2.34) {
      label = 'Moderate';
    } else {
      label = 'High';
    }

    return _CrowdResult(
      level: label,
      reportCount: reportCount + other.reportCount,
      lastReported: lastReported != null &&
              other.lastReported != null &&
              lastReported!.isAfter(other.lastReported!)
          ? lastReported
          : other.lastReported,
    );
  }

  static double _estimateWeight(_CrowdResult result) {
    return switch (result.level) {
      'Low' => 1.0,
      'High' => 3.0,
      _ => 2.0,
    };
  }
}
