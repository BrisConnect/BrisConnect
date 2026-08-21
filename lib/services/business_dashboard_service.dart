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
  final int socialShares;
  final int totalSocialShares;
  final int activePromotions;
  final int newReviews;
  final int totalReviews;
  final double averageRating;
  final double averageBuzzRating;
  final int totalBuzzVotes;
  final double profileViewsChange;
  final double savesChange;
  final double socialSharesChange;
  final double activePromotionsChange;
  final double newReviewsChange;
  final double buzzScore;
  final String? crowdLevel;
  final int crowdReportCount;

  const BusinessDashboardMetrics({
    this.profileViews = 0,
    this.saves = 0,
    this.socialShares = 0,
    this.totalSocialShares = 0,
    this.activePromotions = 0,
    this.newReviews = 0,
    this.totalReviews = 0,
    this.averageRating = 0.0,
    this.averageBuzzRating = 0.0,
    this.totalBuzzVotes = 0,
    this.profileViewsChange = 0,
    this.savesChange = 0,
    this.socialSharesChange = 0,
    this.activePromotionsChange = 0,
    this.newReviewsChange = 0,
    this.buzzScore = 0.0,
    this.crowdLevel,
    this.crowdReportCount = 0,
  });
}

/// Daily metric history for a business owner's listings.
class BusinessDailyHistory {
  /// Short day labels (e.g. Mon, Tue) ordered oldest → newest.
  final List<String> labels;

  /// Daily profile view counts aligned with [labels].
  final List<int> views;

  /// Daily save/favourite counts aligned with [labels].
  final List<int> saves;

  /// Daily new review counts aligned with [labels].
  final List<int> reviews;

  /// Cumulative total review counts aligned with [labels].
  final List<int> totalReviews;

  /// Daily average star rating (1-5) aligned with [labels].
  final List<double> averageRatings;

  /// Daily average buzz rating (1-5) aligned with [labels].
  final List<double> averageBuzzRatings;

  /// Cumulative average buzz rating (1-5) aligned with [labels].
  final List<double> cumulativeAverageBuzzRatings;

  /// Daily social share counts aligned with [labels].
  final List<int> shares;

  /// Daily active promotion counts aligned with [labels].
  final List<int> promotions;

  /// Daily buzz vote counts aligned with [labels].
  final List<int> buzzVotes;

  /// Daily crowd report counts aligned with [labels].
  final List<int> crowdReports;

  const BusinessDailyHistory({
    this.labels = const [],
    this.views = const [],
    this.saves = const [],
    this.reviews = const [],
    this.totalReviews = const [],
    this.averageRatings = const [],
    this.averageBuzzRatings = const [],
    this.cumulativeAverageBuzzRatings = const [],
    this.shares = const [],
    this.promotions = const [],
    this.buzzVotes = const [],
    this.crowdReports = const [],
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
  static const String _reviewsCollection = 'reviews';
  static const String _promotionsCollection = 'promotions';
  static const String _crowdReportsCollection = 'crowd_reports';
  static const String _socialSharesCollection = 'social_shares';

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

  /// Stream of social share counts for [businessIds] in the current and
  /// previous 7-day windows.
  Stream<_SharesResult> _socialSharesStream(
    List<String> businessIds,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) {
    if (businessIds.isEmpty) {
      return Stream.value(const _SharesResult());
    }

    final chunks = _chunk(businessIds, 10);
    final chunkStreams = chunks.map((chunk) {
      return _firestore
          .collection(_socialSharesCollection)
          .where('businessId', whereIn: chunk)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twoWeeksAgo))
          .snapshots()
          .map(_SharesResult.fromSnapshot);
    }).toList();

    if (chunkStreams.length == 1) return chunkStreams.first;

    late StreamController<_SharesResult> controller;
    final subscriptions = <StreamSubscription<_SharesResult>>[];
    final latest = List<_SharesResult?>.filled(chunkStreams.length, null);

    void emitIfReady() {
      if (latest.every((r) => r != null)) {
        controller.add(
          latest.whereType<_SharesResult>().reduce((a, b) => a.merge(b)),
        );
      }
    }

    controller = StreamController<_SharesResult>(
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

  /// Real-time daily metric history for the last [days] days across all
  /// businesses owned by [ownerId].
  Stream<BusinessDailyHistory> dailyHistoryStream(
    String ownerId, {
    int days = 7,
  }) {
    return _businessesForOwner(ownerId).asyncExpand((businesses) {
      return _dailyHistoryStreamForBusinesses(businesses, days: days);
    });
  }

  Stream<BusinessDailyHistory> _dailyHistoryStreamForBusinesses(
    List<Business> businesses, {
    int days = 7,
  }) {
    if (businesses.isEmpty) {
      return Stream.value(const BusinessDailyHistory());
    }

    final businessIds = businesses.map((b) => b.id!).toList();
    final ownerId = businesses.first.ownerId;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));

    final reviewAggregatesStream = _dailyReviewAggregatesStream(
      businessIds: businessIds,
      start: start,
      days: days,
    );
    final sharesStream = _dailyCountsStream(
      collection: _socialSharesCollection,
      businessIds: businessIds,
      field: 'createdAt',
      start: start,
      days: days,
    );
    final crowdStream = _dailyCountsStream(
      collection: _crowdReportsCollection,
      businessIds: businessIds,
      field: 'timestamp',
      start: start,
      days: days,
    );

    final intFallback = List<int>.filled(days, 0);
    final aggregateFallback = List<_DailyReviewAggregate>.filled(
      days,
      const _DailyReviewAggregate(),
      growable: false,
    );

    return _combineLatest4<
        List<_DailyReviewAggregate>,
        List<int>,
        List<int>,
        List<int>,
        BusinessDailyHistory>(
      _streamWithFallback(reviewAggregatesStream, aggregateFallback),
      _streamWithFallback(sharesStream, intFallback),
      _streamWithFallback(crowdStream, intFallback),
      Stream.value(_activePromotionHistory(ownerId, days: days)),
      (aggregates, shares, crowd, promotions) {
        final labels = <String>[];
        final views = List<int>.filled(days, 0);
        final saves = List<int>.filled(days, 0);
        final reviews = List<int>.filled(days, 0);
        final totalReviews = List<int>.filled(days, 0);
        final averageRatings = List<double>.filled(days, 0);
        final averageBuzzRatings = List<double>.filled(days, 0);
        final cumulativeAverageBuzzRatings = List<double>.filled(days, 0);
        final buzzVotes = List<int>.filled(days, 0);
        final dayNames = <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        var cumulativeReviews = 0;
        var cumulativeBuzzTotal = 0;
        var cumulativeBuzzCount = 0;
        for (var i = 0; i < days; i++) {
          final date = start.add(Duration(days: i));
          labels.add(dayNames[date.weekday % 7]);
          final key = _formatDate(date);

          for (final business in businesses) {
            views[i] += business.viewHistory[key] ?? 0;
            saves[i] += business.saveHistory[key] ?? 0;
          }

          reviews[i] = aggregates[i].count;
          buzzVotes[i] = aggregates[i].buzzVoteCount;
          averageRatings[i] = aggregates[i].averageRating;
          averageBuzzRatings[i] = aggregates[i].averageBuzz;
          cumulativeReviews += aggregates[i].count;
          totalReviews[i] = cumulativeReviews;
          cumulativeBuzzTotal += aggregates[i].totalBuzz;
          cumulativeBuzzCount += aggregates[i].buzzVoteCount;
          cumulativeAverageBuzzRatings[i] = cumulativeBuzzCount > 0
              ? cumulativeBuzzTotal / cumulativeBuzzCount
              : 0.0;
        }

        return BusinessDailyHistory(
          labels: labels,
          views: views,
          saves: saves,
          reviews: reviews,
          totalReviews: totalReviews,
          averageRatings: averageRatings,
          averageBuzzRatings: averageBuzzRatings,
          cumulativeAverageBuzzRatings: cumulativeAverageBuzzRatings,
          buzzVotes: buzzVotes,
          shares: shares,
          crowdReports: crowd,
          promotions: promotions,
        );
      },
    );
  }

  List<int> _activePromotionHistory(String ownerId, {int days = 7}) {
    // Active promotions is a point-in-time metric; no daily history is stored.
    // Return a flat line equal to today's count so the card still renders a graph.
    return List<int>.filled(days, 0);
  }

  /// Per-day review aggregates (count, average rating, average buzz).
  Stream<List<_DailyReviewAggregate>> _dailyReviewAggregatesStream({
    required List<String> businessIds,
    required DateTime start,
    required int days,
  }) {
    if (businessIds.isEmpty) {
      return Stream.value(
        List<_DailyReviewAggregate>.filled(days, const _DailyReviewAggregate(), growable: false),
      );
    }

    final chunks = _chunk(businessIds, 10);
    final chunkStreams = chunks.map((chunk) {
      return _firestore
          .collection(_reviewsCollection)
          .where('businessId', whereIn: chunk)
          .where('visible', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .snapshots()
          .map((snap) => _groupReviewsByDay(snap.docs, start, days));
    }).toList();

    if (chunkStreams.length == 1) return chunkStreams.first;

    late StreamController<List<_DailyReviewAggregate>> controller;
    final subscriptions = <StreamSubscription<List<_DailyReviewAggregate>>>[];
    final latest = List<List<_DailyReviewAggregate>?>.filled(chunkStreams.length, null);

    void emitIfReady() {
      if (latest.every((r) => r != null)) {
        final combined = List<_DailyReviewAggregate>.generate(days, (i) {
          var count = 0;
          var totalRating = 0;
          var totalBuzz = 0;
          var buzzVoteCount = 0;
          for (final list in latest.whereType<List<_DailyReviewAggregate>>()) {
            final agg = list[i];
            count += agg.count;
            totalRating += agg.totalRating;
            totalBuzz += agg.totalBuzz;
            buzzVoteCount += agg.buzzVoteCount;
          }
          return _DailyReviewAggregate(
            count: count,
            totalRating: totalRating,
            totalBuzz: totalBuzz,
            buzzVoteCount: buzzVoteCount,
          );
        }, growable: false);
        controller.add(combined);
      }
    }

    controller = StreamController<List<_DailyReviewAggregate>>(
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

  List<_DailyReviewAggregate> _groupReviewsByDay(
    List<QueryDocumentSnapshot> docs,
    DateTime start,
    int days,
  ) {
    final aggregates = List<_DailyReviewAggregate>.filled(
      days,
      const _DailyReviewAggregate(),
      growable: false,
    );
    // Fill with mutable instances so we can accumulate values.
    for (var i = 0; i < days; i++) {
      aggregates[i] = const _DailyReviewAggregate();
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null || createdAt.isBefore(start)) continue;

      final dayIndex = createdAt.difference(start).inDays;
      if (dayIndex < 0 || dayIndex >= days) continue;

      final rating = (data['rating'] as num?)?.toInt() ?? 0;
      final buzz = (data['buzzRating'] as num?)?.toInt() ?? 0;
      final current = aggregates[dayIndex];
      aggregates[dayIndex] = _DailyReviewAggregate(
        count: current.count + 1,
        totalRating: current.totalRating + rating,
        totalBuzz: current.totalBuzz + (buzz > 0 ? buzz : 0),
        buzzVoteCount: current.buzzVoteCount + (buzz > 0 ? 1 : 0),
      );
    }

    return aggregates;
  }

  Stream<List<int>> _dailyCountsStream({
    required String collection,
    required List<String> businessIds,
    required String field,
    required DateTime start,
    required int days,
    bool stringField = false,
    bool Function(Map<String, dynamic> data)? countIf,
  }) {
    if (businessIds.isEmpty) {
      return Stream.value(List<int>.filled(days, 0));
    }

    final chunks = _chunk(businessIds, 10);
    final chunkStreams = chunks.map((chunk) {
      final query = _firestore
          .collection(collection)
          .where('businessId', whereIn: chunk);

      final boundedQuery = stringField
          ? query.where(field, isGreaterThanOrEqualTo: _formatDate(start))
          : query.where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start));

      return boundedQuery
          .snapshots()
          .map((snap) => _groupByDay(snap.docs, field, stringField, start, days, countIf: countIf));
    }).toList();

    if (chunkStreams.length == 1) return chunkStreams.first;

    late StreamController<List<int>> controller;
    final subscriptions = <StreamSubscription<List<int>>>[];
    final latest = List<List<int>?>.filled(chunkStreams.length, null);

    void emitIfReady() {
      if (latest.every((r) => r != null)) {
        final combined = List<int>.filled(days, 0);
        for (var i = 0; i < days; i++) {
          for (final list in latest.whereType<List<int>>()) {
            combined[i] += list[i];
          }
        }
        controller.add(combined);
      }
    }

    controller = StreamController<List<int>>(
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

  List<int> _groupByDay(
    List<QueryDocumentSnapshot> docs,
    String field,
    bool stringField,
    DateTime start,
    int days, {
    bool Function(Map<String, dynamic> data)? countIf,
  }) {
    final counts = List<int>.filled(days, 0);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (countIf != null && !countIf(data)) continue;

      final raw = data[field];
      DateTime? date;

      if (raw is Timestamp) {
        date = raw.toDate();
      } else if (raw is String) {
        try {
          final parts = raw.split('-');
          if (parts.length == 3) {
            date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }

      if (date == null || date.isBefore(start)) continue;

      final dayIndex = date.difference(start).inDays;
      if (dayIndex >= 0 && dayIndex < days) {
        counts[dayIndex] += 1;
      }
    }

    return counts;
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
    StreamSubscription<_ReviewsResult>? reviewsSub;
    StreamSubscription<_CrowdResult>? crowdSub;
    StreamSubscription<_SharesResult>? sharesSub;

    List<Business>? latestBusinesses;
    int? latestPromotions;
    _ReviewsResult? latestReviews;
    _CrowdResult? latestCrowd;
    _SharesResult? latestShares;

    void emitIfReady() {
      if (latestBusinesses == null ||
          latestPromotions == null ||
          latestReviews == null ||
          latestCrowd == null ||
          latestShares == null) {
        return;
      }
      controller.add(
        _computeMetrics(
          latestBusinesses!,
          latestPromotions!,
          latestReviews!,
          latestCrowd!,
          latestShares!,
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
        sharesSub = _socialSharesStream(businessIds, weekAgo, twoWeeksAgo).listen(
          (result) {
            latestShares = result;
            emitIfReady();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await businessesSub?.cancel();
        await promotionsSub?.cancel();
        await reviewsSub?.cancel();
        await crowdSub?.cancel();
        await sharesSub?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  /// Computes metrics from the latest snapshot of each data source.
  BusinessDashboardMetrics _computeMetrics(
    List<Business> businesses,
    int activePromotions,
    _ReviewsResult reviews,
    _CrowdResult crowd,
    _SharesResult shares,
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
      socialShares: shares.currentWeekCount,
      totalSocialShares: shares.totalCount,
      activePromotions: activePromotions,
      newReviews: reviews.currentWeekCount,
      totalReviews: reviews.totalCount,
      averageRating: reviews.averageRating,
      averageBuzzRating: reviews.averageBuzz,
      totalBuzzVotes: reviews.totalBuzzVotes,
      profileViewsChange: _percentageChange(currentViews, previousViews),
      savesChange: _percentageChange(currentSaves, previousSaves),
      socialSharesChange: _percentageChange(
        shares.currentWeekCount,
        shares.previousWeekCount,
      ),
      activePromotionsChange: 0,
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
    final reviewsResult = await _newReviews(businessIds, weekAgo, twoWeeksAgo);
    final allReviewsResult = await _allReviews(businessIds);
    final sharesResult = await _newSocialShares(_firestore, businessIds, weekAgo, twoWeeksAgo);
    final allSharesCount = await _allSocialShares(businessIds);
    final buzzScore = _averageBuzzScore(businesses);
    final crowdStatus = await _latestCrowdStatus(businessIds);

    final currentViews = viewsResult['current'] ?? 0;
    final previousViews = viewsResult['previous'] ?? 0;
    final currentSaves = savesResult['current'] ?? 0;
    final previousSaves = savesResult['previous'] ?? 0;
    final currentReviews = reviewsResult['current'] ?? 0;
    final previousReviews = reviewsResult['previous'] ?? 0;
    final currentShares = sharesResult['current'] ?? 0;
    final previousShares = sharesResult['previous'] ?? 0;

    return BusinessDashboardMetrics(
      profileViews: currentViews,
      saves: currentSaves,
      socialShares: currentShares,
      totalSocialShares: allSharesCount,
      activePromotions: activePromotions,
      newReviews: currentReviews,
      totalReviews: allReviewsResult.totalCount,
      averageRating: allReviewsResult.averageRating,
      averageBuzzRating: allReviewsResult.averageBuzz,
      totalBuzzVotes: allReviewsResult.totalBuzzVotes,
      profileViewsChange: _percentageChange(currentViews, previousViews),
      savesChange: _percentageChange(currentSaves, previousSaves),
      socialSharesChange: _percentageChange(currentShares, previousShares),
      activePromotionsChange: 0,
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
      } else if (business.createdAt != null &&
          business.createdAt!.isAfter(weekAgo)) {
        // No daily history yet, but the listing is brand new, so every
        // lifetime view genuinely happened within the current week.
        current += business.viewCount;
      }
      // Otherwise there is no way to know which week legacy views happened
      // in, so they are left out rather than misreported as "this week".
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
      } else if (business.createdAt != null &&
          business.createdAt!.isAfter(weekAgo)) {
        // No daily history yet, but the listing is brand new, so every
        // lifetime save genuinely happened within the current week.
        current += business.savedCount;
      }
      // Otherwise there is no way to know which week legacy saves happened
      // in, so they are left out rather than misreported as "this week".
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

  /// Total social shares across [businessIds] (all-time).
  Future<int> _allSocialShares(List<String> businessIds) async {
    if (businessIds.isEmpty) return 0;

    const collection = 'social_shares';
    var total = 0;
    for (final businessId in businessIds) {
      final snapshot = await _firestore
          .collection(collection)
          .where('businessId', isEqualTo: businessId)
          .count()
          .get();
      total += snapshot.count ?? 0;
    }
    return total;
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

  /// Returns a stream that emits [fallback] whenever the source stream errors.
  /// This keeps dashboards rendering even if a single Firestore query fails
  /// (for example because a composite index is missing).
  Stream<T> _streamWithFallback<T>(Stream<T> source, T fallback) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: (_) => controller.add(fallback),
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  /// Combines the latest values from 4 streams into a single stream.
  Stream<R> _combineLatest4<T1, T2, T3, T4, R>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    Stream<T3> stream3,
    Stream<T4> stream4,
    R Function(T1, T2, T3, T4) combiner,
  ) {
    late StreamController<R> controller;
    StreamSubscription<T1>? sub1;
    StreamSubscription<T2>? sub2;
    StreamSubscription<T3>? sub3;
    StreamSubscription<T4>? sub4;

    T1? latest1;
    T2? latest2;
    T3? latest3;
    T4? latest4;

    bool allReady() =>
        latest1 != null &&
        latest2 != null &&
        latest3 != null &&
        latest4 != null;

    void emit() {
      if (allReady()) {
        controller.add(combiner(latest1 as T1, latest2 as T2, latest3 as T3, latest4 as T4));
      }
    }

    controller = StreamController<R>(
      onListen: () {
        sub1 = stream1.listen((v) { latest1 = v; emit(); }, onError: controller.addError);
        sub2 = stream2.listen((v) { latest2 = v; emit(); }, onError: controller.addError);
        sub3 = stream3.listen((v) { latest3 = v; emit(); }, onError: controller.addError);
        sub4 = stream4.listen((v) { latest4 = v; emit(); }, onError: controller.addError);
      },
      onCancel: () async {
        await sub1?.cancel();
        await sub2?.cancel();
        await sub3?.cancel();
        await sub4?.cancel();
      },
    );

    return controller.stream.distinct();
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
    String? ownerId,
  }) async {
    final today = _formatDate(DateTime.now());
    try {
      String effectiveOwnerId = (ownerId ?? '').trim();
      if (effectiveOwnerId.isEmpty) {
        final businessDoc = await _firestore
            .collection(_businessesCollection)
            .doc(businessId)
            .get();
        effectiveOwnerId =
            businessDoc.data()?['ownerId'] as String? ?? '';
      }

      final updatePayload = <String, dynamic>{
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (effectiveOwnerId.isNotEmpty) {
        updatePayload['ownerId'] = effectiveOwnerId;
      }

      final docRef =
          _firestore.collection(_businessesCollection).doc(businessId);
      await docRef.set(updatePayload, SetOptions(merge: true));
      // Dotted-path nested field increments must go through update(), not
      // set(merge:true) — on some platforms the latter stores the dotted
      // string as a literal top-level field instead of nesting it.
      await docRef.update({'viewHistory.$today': FieldValue.increment(1)});

      if (visitorId != null &&
          visitorId.trim().isNotEmpty &&
          effectiveOwnerId.isNotEmpty) {
        await _audienceAnalyticsService?.recordInteraction(
          businessId: businessId,
          ownerId: effectiveOwnerId,
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

      final docRef =
          _firestore.collection(_businessesCollection).doc(businessId);
      await docRef.set({
        'savedCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Dotted-path nested field increments must go through update(), not
      // set(merge:true) — on some platforms the latter stores the dotted
      // string as a literal top-level field instead of nesting it.
      await docRef.update({'saveHistory.$today': FieldValue.increment(1)});

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

/// One-time fetch of social share counts for [businessIds] in the current
/// and previous 7-day windows.
Future<Map<String, int>> _newSocialShares(
  FirebaseFirestore firestore,
  List<String> businessIds,
  DateTime weekAgo,
  DateTime twoWeeksAgo,
) async {
  if (businessIds.isEmpty) {
    return {'current': 0, 'previous': 0};
  }

  const collection = 'social_shares';
  var current = 0;
  var previous = 0;
  for (final businessId in businessIds) {
    final currentSnap = await firestore
        .collection(collection)
        .where('businessId', isEqualTo: businessId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .count()
        .get();
    final previousSnap = await firestore
        .collection(collection)
        .where('businessId', isEqualTo: businessId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(twoWeeksAgo))
        .where('createdAt', isLessThan: Timestamp.fromDate(weekAgo))
        .count()
        .get();
    current += currentSnap.count ?? 0;
    previous += previousSnap.count ?? 0;
  }
  return {'current': current, 'previous': previous};
}

/// Mutable accumulator for daily review aggregates.
class _DailyReviewAggregate {
  final int count;
  final int totalRating;
  final int totalBuzz;
  final int buzzVoteCount;

  const _DailyReviewAggregate({
    this.count = 0,
    this.totalRating = 0,
    this.totalBuzz = 0,
    this.buzzVoteCount = 0,
  });

  double get averageRating => count > 0 ? totalRating / count : 0.0;
  double get averageBuzz => buzzVoteCount > 0 ? totalBuzz / buzzVoteCount : 0.0;
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

/// Aggregated social share data for the current and previous 7-day windows.
class _SharesResult {
  final int currentWeekCount;
  final int previousWeekCount;
  final int totalCount;

  const _SharesResult({
    this.currentWeekCount = 0,
    this.previousWeekCount = 0,
    this.totalCount = 0,
  });

  factory _SharesResult.fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    var currentWeekCount = 0;
    var previousWeekCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) continue;
      if (!createdAt.isBefore(weekAgo)) {
        currentWeekCount++;
      } else if (!createdAt.isBefore(twoWeeksAgo) && createdAt.isBefore(weekAgo)) {
        previousWeekCount++;
      }
    }

    return _SharesResult(
      currentWeekCount: currentWeekCount,
      previousWeekCount: previousWeekCount,
      totalCount: snapshot.docs.length,
    );
  }

  _SharesResult merge(_SharesResult other) {
    return _SharesResult(
      currentWeekCount: currentWeekCount + other.currentWeekCount,
      previousWeekCount: previousWeekCount + other.previousWeekCount,
      totalCount: totalCount + other.totalCount,
    );
  }
}
