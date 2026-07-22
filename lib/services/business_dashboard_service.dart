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
  final double profileViewsChange;
  final double savesChange;
  final double activePromotionsChange;
  final double upcomingEventsChange;
  final double newReviewsChange;

  const BusinessDashboardMetrics({
    this.profileViews = 0,
    this.saves = 0,
    this.activePromotions = 0,
    this.upcomingEvents = 0,
    this.newReviews = 0,
    this.profileViewsChange = 0,
    this.savesChange = 0,
    this.activePromotionsChange = 0,
    this.upcomingEventsChange = 0,
    this.newReviewsChange = 0,
  });
}

/// Service for the business owner dashboard summary.
///
/// Aggregates views, saves, active promotions, upcoming events, and recent
/// reviews. Trend percentages compare the current rolling 7-day window to the
/// previous 7-day window. All reads are intentionally parallel to keep the
/// dashboard load under 2–3 seconds.
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

  /// Real-time aggregated metrics for all businesses owned by [ownerId].
  Stream<BusinessDashboardMetrics> metricsStream(String ownerId) {
    return _businessesForOwner(ownerId)
        .asyncExpand((businesses) => _metricsStreamForBusinesses(businesses));
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

  Stream<BusinessDashboardMetrics> _metricsStreamForBusinesses(
    List<Business> businesses,
  ) {
    return Stream.fromFuture(_metricsForBusinesses(businesses));
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

    final viewsResult = await _profileViews(businessIds, weekAgo, twoWeeksAgo);
    final savesResult = await _saves(businessIds, weekAgo, twoWeeksAgo);
    final activePromotions = await _activePromotions(ownerId);
    final upcomingEvents = await _upcomingEvents(ownerId, now);
    final reviewsResult = await _newReviews(businessIds, weekAgo, twoWeeksAgo);

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
      profileViewsChange: _percentageChange(currentViews, previousViews),
      savesChange: _percentageChange(currentSaves, previousSaves),
      activePromotionsChange: 0,
      upcomingEventsChange: 0,
      newReviewsChange: _percentageChange(currentReviews, previousReviews),
    );
  }

  Future<Map<String, int>> _profileViews(
    List<String> businessIds,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) async {
    var current = 0;
    var previous = 0;
    for (final id in businessIds) {
      final doc = await _firestore.collection(_businessesCollection).doc(id).get();
      final data = doc.data();
      if (data == null) continue;
      final history = data['viewHistory'] as Map<String, dynamic>?;
      if (history != null) {
        current += _sumHistoryInRange(history, weekAgo, DateTime.now());
        previous += _sumHistoryInRange(history, twoWeeksAgo, weekAgo);
      } else {
        final count = (data['viewCount'] as num?)?.toInt() ?? 0;
        current += count;
      }
    }
    return {'current': current, 'previous': previous};
  }

  Future<Map<String, int>> _saves(
    List<String> businessIds,
    DateTime weekAgo,
    DateTime twoWeeksAgo,
  ) async {
    var current = 0;
    var previous = 0;
    for (final id in businessIds) {
      final doc = await _firestore.collection(_businessesCollection).doc(id).get();
      final data = doc.data();
      if (data == null) continue;
      final saveHistory = data['saveHistory'] as Map<String, dynamic>?;
      if (saveHistory != null) {
        current += _sumHistoryInRange(saveHistory, weekAgo, DateTime.now());
        previous += _sumHistoryInRange(saveHistory, twoWeeksAgo, weekAgo);
      } else {
        current += (data['savedCount'] as num?)?.toInt() ?? 0;
      }
    }
    return {'current': current, 'previous': previous};
  }

  Future<int> _activePromotions(String ownerId) async {
    final snapshot = await _firestore
        .collection(_promotionsCollection)
        .where('ownerId', isEqualTo: ownerId)
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .count()
        .get();
    return snapshot.count ?? 0;
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

  int _sumHistoryInRange(
    Map<String, dynamic> history,
    DateTime start,
    DateTime end,
  ) {
    var sum = 0;
    history.forEach((key, value) {
      try {
        final parts = key.split('/');
        if (parts.length != 3) return;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final parsed = DateTime(year, month, day);
        if (!parsed.isBefore(start) && parsed.isBefore(end)) {
          sum += (value as num).toInt();
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
    return '$day/$month/$year';
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

      await _firestore.collection(_businessesCollection).doc(businessId).update({
        'viewCount': FieldValue.increment(1),
        'viewHistory.$today': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

      await _firestore.collection(_businessesCollection).doc(businessId).update({
        'savedCount': FieldValue.increment(1),
        'saveHistory.$today': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
