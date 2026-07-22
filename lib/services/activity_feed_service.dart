import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:brisconnect/models/activity_feed_item.dart';

/// Service for the Visitor community activity feed.
///
/// Aggregates visible, moderated content from multiple sources:
/// - reviews (visitor recommendations)
/// - business_events (published events)
/// - businesses (newly listed food businesses)
///
/// Photos are represented by review and event images today. A dedicated
/// `photos` collection can be added later without changing the public API.
class ActivityFeedService {
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;

  final FirebaseFirestore _firestore;

  ActivityFeedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  /// Returns a real-time stream of the latest [limit] activity items across
  /// all supported content types.
  ///
  /// The stream is appropriate for the initial feed load and automatically
  /// reflects new posts within Firestore's snapshot latency (typically < 1s).
  Stream<List<ActivityFeedItem>> activityFeedStream({int limit = _defaultPageSize}) {
    final effectiveLimit = _clampLimit(limit);
    return _recentVisibleReviewsStream(effectiveLimit)
        .asyncMap((reviews) async {
      final events = await _recentPublishedEventsFuture(effectiveLimit);
      final businesses = await _recentBusinessesFuture(effectiveLimit);
      return _mergeAndDeduplicate([
        ...reviews,
        ...events,
        ...businesses,
      ], effectiveLimit);
    });
  }

  /// Fetches a single page of activity items.
  ///
  /// [startAfter] is the timestamp of the last item shown. Pass it back to
  /// fetch the next page. Returns a cursor object that contains the items and
  /// the next timestamp cursor (null when no more pages).
  Future<ActivityFeedPage> activityFeedPage({
    int limit = _defaultPageSize,
    DateTime? startAfter,
  }) async {
    final effectiveLimit = _clampLimit(limit);

    final reviewsFuture = _recentVisibleReviewsFuture(
      effectiveLimit,
      startAfter: startAfter,
    );
    final eventsFuture = _recentPublishedEventsFuture(
      effectiveLimit,
      startAfter: startAfter,
    );
    final businessesFuture = _recentBusinessesFuture(
      effectiveLimit,
      startAfter: startAfter,
    );

    final results = await Future.wait([
      reviewsFuture,
      eventsFuture,
      businessesFuture,
    ]);

    final merged = _mergeAndDeduplicate(
      results.expand((list) => list).toList(),
      effectiveLimit,
    );

    final nextCursor = merged.isEmpty ? null : merged.last.createdAt;
    return ActivityFeedPage(items: merged, nextCursor: nextCursor);
  }

  /// Stream filtered to a single content type.
  Stream<List<ActivityFeedItem>> activityFeedStreamByType(
    ActivityFeedType type, {
    int limit = _defaultPageSize,
  }) {
    final effectiveLimit = _clampLimit(limit);
    switch (type) {
      case ActivityFeedType.review:
        return _recentVisibleReviewsStream(effectiveLimit)
            .map((items) => _sortByCreatedAtDesc(items));
      case ActivityFeedType.event:
        return _firestore
            .collection('business_events')
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .limit(effectiveLimit)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(ActivityFeedItem.fromBusinessEventDoc)
                  .where((item) => item != null)
                  .cast<ActivityFeedItem>()
                  .toList(),
            );
      case ActivityFeedType.business:
        return _firestore
            .collection('businesses')
            .orderBy('createdAt', descending: true)
            .limit(effectiveLimit)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map(ActivityFeedItem.fromBusinessDoc)
                  .where((item) => item != null)
                  .cast<ActivityFeedItem>()
                  .toList(),
            );
      case ActivityFeedType.photo:
        // Photos are not yet stored as a separate collection. Surface review
        // and event images as photo activity until a dedicated collection is
        // introduced.
        return activityFeedStream(limit: effectiveLimit)
            .map((items) => items.where((i) => i.imageUrl.isNotEmpty).toList());
      case ActivityFeedType.all:
        return activityFeedStream(limit: effectiveLimit);
    }
  }

  int _clampLimit(int limit) {
    if (limit <= 0) return _defaultPageSize;
    return limit > _maxPageSize ? _maxPageSize : limit;
  }

  Stream<List<ActivityFeedItem>> _recentVisibleReviewsStream(int limit) {
    return _firestore
        .collection('reviews')
        .where('visible', isEqualTo: true)
        .where('isFlagged', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityFeedItem.fromReviewDoc)
              .where((item) => item != null)
              .cast<ActivityFeedItem>()
              .toList(),
        );
  }

  Future<List<ActivityFeedItem>> _recentVisibleReviewsFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _firestore
        .collection('reviews')
        .where('visible', isEqualTo: true)
        .where('isFlagged', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map(ActivityFeedItem.fromReviewDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
  }

  Future<List<ActivityFeedItem>> _recentPublishedEventsFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _firestore
        .collection('business_events')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map(ActivityFeedItem.fromBusinessEventDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
  }

  Future<List<ActivityFeedItem>> _recentBusinessesFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _firestore
        .collection('businesses')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map(ActivityFeedItem.fromBusinessDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
  }

  List<ActivityFeedItem> _mergeAndDeduplicate(
    List<ActivityFeedItem> items,
    int limit,
  ) {
    final seen = <String>{};
    final merged = <ActivityFeedItem>[];
    for (final item in items) {
      final key = '${item.type.name}_${item.id}';
      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(item);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
  }

  List<ActivityFeedItem> _sortByCreatedAtDesc(List<ActivityFeedItem> items) {
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

/// Paginated result returned by [ActivityFeedService.activityFeedPage].
class ActivityFeedPage {
  final List<ActivityFeedItem> items;
  final DateTime? nextCursor;

  const ActivityFeedPage({required this.items, this.nextCursor});
}
