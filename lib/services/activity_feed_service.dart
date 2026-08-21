import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:brisconnect/models/activity_feed_item.dart';

/// Service for the Visitor community activity feed.
///
/// Aggregates visible content from multiple sources:
/// - reviews (visitor recommendations)
/// - business_events (published events)
/// - businesses (newly listed food businesses)
/// - promotions (scheduled promotions and published AI-generated promotions)
/// - visitor_photos (visitor-contributed business/event photos)
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
  /// The stream reacts to changes in any source collection (reviews, events,
  /// businesses, promotions, AI posts, and visitor photos) so a newly uploaded
  /// photo appears in the "All" feed without waiting for a review to change.
  Stream<List<ActivityFeedItem>> activityFeedStream(
      {int limit = _defaultPageSize}) {
    final effectiveLimit = _clampLimit(limit);
    return _feedChangeTriggers(effectiveLimit).asyncMap((_) async {
      // Fetch all sources in parallel instead of sequentially awaiting each
      // one — this was the main cause of slow (2s+) community feed loads.
      final results = await Future.wait([
        _recentVisibleReviewsFuture(effectiveLimit),
        _recentPublishedEventsFuture(effectiveLimit),
        _recentBusinessesFuture(effectiveLimit),
        _recentPromotionsFuture(effectiveLimit),
        _recentVisitorPhotosFuture(effectiveLimit),
      ]);
      return _mergeAndDeduplicate(
        results.expand((list) => list).toList(),
        effectiveLimit,
      );
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
    final promotionsFuture = _recentPromotionsFuture(
      effectiveLimit,
      startAfter: startAfter,
    );
    final photosFuture = _recentVisitorPhotosFuture(
      effectiveLimit,
      startAfter: startAfter,
    );

    final results = await Future.wait([
      reviewsFuture,
      eventsFuture,
      businessesFuture,
      promotionsFuture,
      photosFuture,
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
            .map((items) => _sortByPriorityThenDate(items));
      case ActivityFeedType.event:
        return _firestore
            .collection('business_events')
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .limit(effectiveLimit)
            .snapshots()
            .map(
              (snapshot) => _sortByPriorityThenDate(
                snapshot.docs
                    .map(ActivityFeedItem.fromBusinessEventDoc)
                    .where((item) => item != null)
                    .cast<ActivityFeedItem>()
                    .toList(),
              ),
            );
      case ActivityFeedType.business:
        return _recentPromotionsStream(effectiveLimit);
      case ActivityFeedType.photo:
        return _recentVisitorPhotosStream(effectiveLimit)
            .map((items) => _sortByPriorityThenDate(items));
      case ActivityFeedType.trending:
        return activityFeedStream(limit: effectiveLimit * 2).map(
          (items) => _sortByTrending(
            _filterByPriorityAndDate(items, effectiveLimit),
          ),
        );
      case ActivityFeedType.nearby:
        return activityFeedStream(limit: effectiveLimit * 3);
      case ActivityFeedType.following:
        return activityFeedStream(limit: effectiveLimit * 3);
      case ActivityFeedType.newest:
        return activityFeedStream(limit: effectiveLimit).map(
          (items) =>
              _sortByPriorityThenDate(items.take(effectiveLimit).toList()),
        );
      case ActivityFeedType.popular:
        return activityFeedStream(limit: effectiveLimit * 2).map(
          (items) => _sortByTrending(
            _filterByPriorityAndDate(items, effectiveLimit),
          ),
        );
      case ActivityFeedType.all:
        return activityFeedStream(limit: effectiveLimit);
    }
  }

  /// Filters a merged list to the requested limit after applying priority sort.
  List<ActivityFeedItem> _filterByPriorityAndDate(
    List<ActivityFeedItem> items,
    int limit,
  ) {
    _sortByPriorityThenDate(items);
    return items.take(limit * 2).toList();
  }

  /// Sorts items by a simple trending score: highlighted/pinned first, then
  /// recency weighted by engagement signals when metadata is present.
  List<ActivityFeedItem> _sortByTrending(List<ActivityFeedItem> items) {
    final now = DateTime.now();
    final scored = items.map((item) {
      double score = 0;
      if (item.isPinned) score += 200;
      if (item.isHighlighted) score += 100;
      final ageHours = now.difference(item.createdAt).inHours.clamp(0, 168);
      score += (168 - ageHours) * 0.5;
      return (item, score);
    }).toList();
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  /// Pin an item so it appears at the top of the community feed.
  Future<void> pinItem(ActivityFeedItem item) async {
    final ref =
        _firestore.collection(_collectionForType(item.type)).doc(item.id);
    await ref.update({
      'isPinned': true,
      'pinnedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unpin an item.
  Future<void> unpinItem(ActivityFeedItem item) async {
    final ref =
        _firestore.collection(_collectionForType(item.type)).doc(item.id);
    await ref.update({
      'isPinned': false,
      'pinnedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Highlight an item so it is promoted in the community feed.
  Future<void> highlightItem(ActivityFeedItem item) async {
    final ref =
        _firestore.collection(_collectionForType(item.type)).doc(item.id);
    await ref.update({
      'isHighlighted': true,
      'highlightedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove the highlight from an item.
  Future<void> unhighlightItem(ActivityFeedItem item) async {
    final ref =
        _firestore.collection(_collectionForType(item.type)).doc(item.id);
    await ref.update({
      'isHighlighted': false,
      'highlightedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove an item from the community feed.
  ///
  /// Uses content-specific moderation flags so the item is excluded by the
  /// feed parsers and cannot reappear.
  ///
  /// [adminEmail] is recorded on photo removals so they go through the same
  /// soft-delete/recovery trail as photo-report moderation.
  Future<void> removeItem(ActivityFeedItem item, {String? adminEmail}) async {
    final ref =
        _firestore.collection(_collectionForType(item.type)).doc(item.id);
    switch (item.type) {
      case ActivityFeedType.review:
        await ref.update({
          'visible': false,
          'isFlagged': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case ActivityFeedType.photo:
        // 'status' is not consulted by the visitor-facing photo galleries
        // (getApprovedPhotosForBusiness/Event only check deletedAt) — use the
        // same soft-delete fields as photo-report moderation so the photo
        // actually disappears everywhere and stays 30-day recoverable.
        await ref.update({
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': adminEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case ActivityFeedType.event:
        await ref.update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case ActivityFeedType.business:
        await ref.update({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;
      case ActivityFeedType.all:
      case ActivityFeedType.trending:
      case ActivityFeedType.nearby:
      case ActivityFeedType.following:
      case ActivityFeedType.newest:
      case ActivityFeedType.popular:
        throw ArgumentError('Cannot remove an aggregated feed item');
    }
  }

  String _collectionForType(ActivityFeedType type) {
    switch (type) {
      case ActivityFeedType.review:
        return 'reviews';
      case ActivityFeedType.photo:
        return 'visitor_photos';
      case ActivityFeedType.event:
        return 'business_events';
      case ActivityFeedType.business:
        return 'businesses';
      case ActivityFeedType.all:
      case ActivityFeedType.trending:
      case ActivityFeedType.nearby:
      case ActivityFeedType.following:
      case ActivityFeedType.newest:
      case ActivityFeedType.popular:
        throw ArgumentError('No single collection for type $type');
    }
  }

  int _clampLimit(int limit) {
    if (limit <= 0) return _defaultPageSize;
    return limit > _maxPageSize ? _maxPageSize : limit;
  }

  /// Emits whenever any source collection used by the "All" feed changes.
  ///
  /// Errors from a single collection (e.g. a missing composite index) are
  /// swallowed so they do not break refreshes triggered by other collections.
  Stream<void> _feedChangeTriggers(int limit) {
    final controller = StreamController<void>.broadcast();
    final queries = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
      _recentVisibleReviewsQuery(limit).snapshots(),
      _firestore
          .collection('business_events')
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
      _businessFeedQuery(limit).snapshots(),
      _firestore
          .collection('food_businesses')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
      _firestore
          .collection('promotions')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
      _firestore
          .collection('ai_generated_posts')
          .where('status', isEqualTo: 'published')
          .where('postType', isEqualTo: 'promotion')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
      _firestore
          .collection('visitor_photos')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
    ];

    var activeSubscriptions = queries.length;
    Timer? debounce;

    void emit() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 200), () {
        if (!controller.isClosed) controller.add(null);
      });
    }

    for (final stream in queries) {
      stream.listen(
        (_) => emit(),
        onError: (_) {
          // A missing index or permission error on one collection should not
          // prevent the feed from refreshing when other collections change.
        },
        onDone: () {
          activeSubscriptions--;
          if (activeSubscriptions == 0 && !controller.isClosed) {
            controller.close();
          }
        },
      );
    }

    controller.onCancel = () {
      debounce?.cancel();
    };

    return controller.stream;
  }

  Stream<List<ActivityFeedItem>> _recentVisibleReviewsStream(int limit) {
    return _recentVisibleReviewsQuery(limit)
        .snapshots()
        .asyncMap(
          (snapshot) async {
            final items = snapshot.docs
                .map(ActivityFeedItem.fromReviewDoc)
                .where((item) => item != null)
                .cast<ActivityFeedItem>()
                .toList();
            return _enrichReviewsWithBusinessNames(items);
          },
        );
  }

  Future<List<ActivityFeedItem>> _recentVisibleReviewsFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _recentVisibleReviewsQuery(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snapshot = await query.get();
    final items = snapshot.docs
        .map(ActivityFeedItem.fromReviewDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
    return _enrichReviewsWithBusinessNames(items);
  }

  Future<List<ActivityFeedItem>> _enrichReviewsWithBusinessNames(
    List<ActivityFeedItem> items,
  ) async {
    final businessIds = items
        .map((i) => i.targetId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = <String, String?>{};
    for (final id in businessIds) {
      try {
        final doc = await _firestore.collection('businesses').doc(id).get();
        if (doc.exists) {
          names[id] = (doc.data()?['businessName'] ?? doc.data()?['name'])
              ?.toString()
              .trim();
        } else {
          final foodDoc =
              await _firestore.collection('food_businesses').doc(id).get();
          if (foodDoc.exists) {
            names[id] =
                (foodDoc.data()?['businessName'] ?? foodDoc.data()?['name'])
                    ?.toString()
                    .trim();
          }
        }
      } catch (_) {
        names[id] = null;
      }
    }
    return items
        .map(
          (item) => names[item.targetId]?.isNotEmpty == true
              ? ActivityFeedItem(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  subtitle: item.subtitle,
                  body: item.body,
                  imageUrl: item.imageUrl,
                  createdAt: item.createdAt,
                  isPinned: item.isPinned,
                  pinnedAt: item.pinnedAt,
                  isHighlighted: item.isHighlighted,
                  highlightedAt: item.highlightedAt,
                  targetId: item.targetId,
                  secondaryTargetId: item.secondaryTargetId,
                  promotionLabel: item.promotionLabel,
                  eventSuburb: item.eventSuburb,
                  isFreeEntry: item.isFreeEntry,
                  actorName: item.actorName,
                  actorPhotoUrl: item.actorPhotoUrl,
                  businessName: names[item.targetId],
                )
              : item,
        )
        .toList();
  }

  Stream<List<ActivityFeedItem>> _recentVisitorPhotosStream(int limit) {
    return _firestore
        .collection('visitor_photos')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap(
          (snapshot) async {
            final items = snapshot.docs
                .map(ActivityFeedItem.fromVisitorPhotoDoc)
                .where((item) => item != null)
                .cast<ActivityFeedItem>()
                .toList();
            return _enrichVisitorPhotosWithBusinessNames(items);
          },
        );
  }

  Future<List<ActivityFeedItem>> _recentVisitorPhotosFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _firestore
        .collection('visitor_photos')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final snapshot = await query.get();
    final items = snapshot.docs
        .map(ActivityFeedItem.fromVisitorPhotoDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
    return _enrichVisitorPhotosWithBusinessNames(items);
  }

  Future<List<ActivityFeedItem>> _enrichVisitorPhotosWithBusinessNames(
    List<ActivityFeedItem> items,
  ) async {
    final businessIds = items
        .map((i) => i.targetId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = <String, String?>{};
    for (final id in businessIds) {
      try {
        final doc = await _firestore.collection('businesses').doc(id).get();
        if (doc.exists) {
          names[id] = (doc.data()?['businessName'] ?? doc.data()?['name'])
              ?.toString()
              .trim();
        } else {
          final foodDoc =
              await _firestore.collection('food_businesses').doc(id).get();
          if (foodDoc.exists) {
            names[id] =
                (foodDoc.data()?['businessName'] ?? foodDoc.data()?['name'])
                    ?.toString()
                    .trim();
          }
        }
      } catch (_) {
        names[id] = null;
      }
    }
    return items
        .map(
          (item) => names[item.targetId]?.isNotEmpty == true
              ? ActivityFeedItem(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  subtitle: item.subtitle,
                  body: item.body,
                  imageUrl: item.imageUrl,
                  createdAt: item.createdAt,
                  isPinned: item.isPinned,
                  pinnedAt: item.pinnedAt,
                  isHighlighted: item.isHighlighted,
                  highlightedAt: item.highlightedAt,
                  targetId: item.targetId,
                  secondaryTargetId: item.secondaryTargetId,
                  promotionLabel: item.promotionLabel,
                  eventSuburb: item.eventSuburb,
                  isFreeEntry: item.isFreeEntry,
                  actorName: item.actorName,
                  actorPhotoUrl: item.actorPhotoUrl,
                  businessName: names[item.targetId],
                )
              : item,
        )
        .toList();
  }

  /// Base query for public reviews in the community feed.
  ///
  /// Only filters on `visible` at the server so older review documents that
  /// pre-date the `isFlagged` field are still returned. `fromReviewDoc`
  /// drops flagged reviews client-side.
  Query<Map<String, dynamic>> _recentVisibleReviewsQuery(int limit) {
    return _firestore
        .collection('reviews')
        .where('visible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);
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
    var query = _businessFeedQuery(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    final canonicalFuture = query.get();
    final legacyFuture = _legacyBusinessesQuery(limit, startAfter: startAfter);

    final results = await Future.wait([canonicalFuture, legacyFuture]);
    final canonicalItems = results[0].docs
        .map(ActivityFeedItem.fromBusinessDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>();
    final legacyItems = _filterAndSortLegacyBusinesses(results[1], limit);

    final merged = [...canonicalItems, ...legacyItems];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
  }

  /// Fetches the most recent legacy `food_businesses` documents.
  ///
  /// Falls back to an unordered query if the required `createdAt` index is
  /// missing, then sorts locally.
  Future<QuerySnapshot<Map<String, dynamic>>> _legacyBusinessesQuery(
    int limit, {
    DateTime? startAfter,
  }) async {
    var query = _firestore
        .collection('food_businesses')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter)]);
    }
    try {
      return await query.get();
    } catch (e) {
      // If ordering fails (missing index or mixed field types), fall back to
      // a simple query and filter/sort in memory.
      var fallback = _firestore.collection('food_businesses').limit(limit * 4);
      try {
        final snap = await fallback.get();
        return snap;
      } catch (_) {
        return _firestore.collection('food_businesses').limit(0).get();
      }
    }
  }

  /// Returns only legacy documents with a parseable `createdAt` timestamp,
  /// sorted newest first and capped to [limit].
  List<ActivityFeedItem> _filterAndSortLegacyBusinesses(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final items = snapshot.docs
        .map(ActivityFeedItem.fromFoodBusinessDoc)
        .where((item) => item != null)
        .cast<ActivityFeedItem>()
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(limit).toList();
  }

  /// Base query for businesses that are allowed in the public feed.
  ///
  /// This must mirror the Firestore security rule:
  /// `isActive == true && deletedAt == null`.
  /// A composite index is required for the two equality filters plus
  /// `createdAt` ordering.
  Query<Map<String, dynamic>> _businessFeedQuery(int limit) {
    return _firestore
        .collection('businesses')
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Stream<List<ActivityFeedItem>> _recentPromotionsStream(int limit) {
    final promotionsStream = _safeStream(
      () => _firestore
          .collection('promotions')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ActivityFeedItem.fromPromotionDoc)
                .where((item) => item != null)
                .cast<ActivityFeedItem>()
                .toList(),
          ),
      fallback: _simplePromotionsQuery(limit),
    );

    final aiPostsStream = _safeStream(
      () => _firestore
          .collection('ai_generated_posts')
          .where('status', isEqualTo: 'published')
          .where('postType', isEqualTo: 'promotion')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ActivityFeedItem.fromAiGeneratedPostDoc)
                .where((item) => item != null)
                .cast<ActivityFeedItem>()
                .toList(),
          ),
      fallback: _simpleAiPostsQuery(limit),
    );

    return _combineLatest2(
      promotionsStream,
      aiPostsStream,
      (promotions, aiPosts) => _sortByPriorityThenDate(
        [...promotions, ...aiPosts].take(limit).toList(),
      ),
    );
  }

  Stream<List<ActivityFeedItem>> _simplePromotionsQuery(int limit) {
    return _firestore
        .collection('promotions')
        .where('status', isEqualTo: 'active')
        .limit(limit * 2)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityFeedItem.fromPromotionDoc)
              .where((item) => item != null)
              .cast<ActivityFeedItem>()
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<ActivityFeedItem>> _simpleAiPostsQuery(int limit) {
    return _firestore
        .collection('ai_generated_posts')
        .where('status', isEqualTo: 'published')
        .limit(limit * 2)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityFeedItem.fromAiGeneratedPostDoc)
              .where((item) => item != null)
              .cast<ActivityFeedItem>()
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<T> _safeStream<T>(
    Stream<T> Function() builder, {
    required Stream<T> fallback,
  }) {
    StreamSubscription<T>? primarySub;
    StreamSubscription<T>? fallbackSub;
    final controller = StreamController<T>.broadcast();

    void emitFallback() {
      if (controller.isClosed) return;
      primarySub?.cancel();
      fallbackSub = fallback.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    }

    try {
      final primary = builder();
      var gotEvent = false;
      primarySub = primary.listen(
        (event) {
          gotEvent = true;
          controller.add(event);
        },
        onError: (_) => emitFallback(),
        onDone: () {
          if (!gotEvent) emitFallback();
        },
      );

      // If no event arrives within 8 seconds, switch to fallback.
      Future.delayed(const Duration(seconds: 8), () {
        if (!controller.hasListener || gotEvent || controller.isClosed) return;
        emitFallback();
      });
    } catch (_) {
      emitFallback();
    }

    controller.onCancel = () {
      primarySub?.cancel();
      fallbackSub?.cancel();
    };

    return controller.stream;
  }

  Stream<R> _combineLatest2<T1, T2, R>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    R Function(T1, T2) combiner,
  ) {
    T1? latest1;
    T2? latest2;
    var has1 = false;
    var has2 = false;

    final controller = StreamController<R>.broadcast();

    void emit() {
      if (has1 && has2 && !controller.isClosed) {
        controller.add(combiner(latest1 as T1, latest2 as T2));
      }
    }

    stream1.listen(
      (value) {
        latest1 = value;
        has1 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    stream2.listen(
      (value) {
        latest2 = value;
        has2 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }

  Future<List<ActivityFeedItem>> _recentPromotionsFuture(
    int limit, {
    DateTime? startAfter,
  }) async {
    Future<List<ActivityFeedItem>> fetchPromotions() async {
      try {
        var query = _firestore
            .collection('promotions')
            .where('status', isEqualTo: 'active')
            .orderBy('createdAt', descending: true)
            .limit(limit);
        if (startAfter != null) {
          query = query.startAfter([Timestamp.fromDate(startAfter)]);
        }
        final snapshot = await query.get();
        return snapshot.docs
            .map(ActivityFeedItem.fromPromotionDoc)
            .where((item) => item != null)
            .cast<ActivityFeedItem>()
            .toList();
      } catch (_) {
        var query = _firestore
            .collection('promotions')
            .where('status', isEqualTo: 'active')
            .limit(limit * 2);
        if (startAfter != null) {
          query = query.startAfter([Timestamp.fromDate(startAfter)]);
        }
        final snapshot = await query.get();
        final items = snapshot.docs
            .map(ActivityFeedItem.fromPromotionDoc)
            .where((item) => item != null)
            .cast<ActivityFeedItem>()
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items.take(limit).toList();
      }
    }

    Future<List<ActivityFeedItem>> fetchAiPosts() async {
      try {
        var query = _firestore
            .collection('ai_generated_posts')
            .where('status', isEqualTo: 'published')
            .where('postType', isEqualTo: 'promotion')
            .orderBy('createdAt', descending: true)
            .limit(limit);
        if (startAfter != null) {
          query = query.startAfter([Timestamp.fromDate(startAfter)]);
        }
        final snapshot = await query.get();
        return snapshot.docs
            .map(ActivityFeedItem.fromAiGeneratedPostDoc)
            .where((item) => item != null)
            .cast<ActivityFeedItem>()
            .toList();
      } catch (_) {
        var query = _firestore
            .collection('ai_generated_posts')
            .where('status', isEqualTo: 'published')
            .limit(limit * 2);
        if (startAfter != null) {
          query = query.startAfter([Timestamp.fromDate(startAfter)]);
        }
        final snapshot = await query.get();
        final items = snapshot.docs
            .map(ActivityFeedItem.fromAiGeneratedPostDoc)
            .where((item) => item != null)
            .cast<ActivityFeedItem>()
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items.take(limit).toList();
      }
    }

    final results = await Future.wait([
      fetchPromotions(),
      fetchAiPosts(),
    ]);

    return _sortByPriorityThenDate(
      [...results[0], ...results[1]].take(limit).toList(),
    );
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
    _sortByPriorityThenDate(merged);
    return merged.take(limit).toList();
  }

  /// Sort feed items so pinned items appear first, then highlighted items,
  /// then regular items. Within each tier the most recently pinned,
  /// highlighted, or created item is shown first.
  List<ActivityFeedItem> _sortByPriorityThenDate(List<ActivityFeedItem> items) {
    items.sort((a, b) {
      final scoreA = a.isPinned
          ? 2
          : a.isHighlighted
              ? 1
              : 0;
      final scoreB = b.isPinned
          ? 2
          : b.isHighlighted
              ? 1
              : 0;
      if (scoreA != scoreB) return scoreB - scoreA;

      final dateA = a.isPinned
          ? a.pinnedAt
          : a.isHighlighted
              ? a.highlightedAt
              : a.createdAt;
      final dateB = b.isPinned
          ? b.pinnedAt
          : b.isHighlighted
              ? b.highlightedAt
              : b.createdAt;
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });
    return items;
  }
}

/// Paginated result returned by [ActivityFeedService.activityFeedPage].
class ActivityFeedPage {
  final List<ActivityFeedItem> items;
  final DateTime? nextCursor;

  const ActivityFeedPage({required this.items, this.nextCursor});
}
