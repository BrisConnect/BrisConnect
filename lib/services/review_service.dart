import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/review.dart';

/// Service for visitor recommendations (reusing the reviews collection).
///
/// A recommendation is a public rating + comment left by an authenticated
/// visitor for a food business. The service enforces rate limits to reduce
/// spam, supports paginated reads for fast business-profile loading, and uses
/// soft deletes so recommendation history is preserved.
class ReviewService {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final Connectivity? _connectivity;
  final String? _currentUserId;
  final bool _useFirebaseAuth;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  // Spam / rate-limiting constants.
  static const Duration _globalCooldown = Duration(minutes: 1);
  static const int _defaultPageSize = 10;
  static const int _maxCommentLength = 500;

  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Connectivity? connectivity,
    String? currentUserId,
    bool useFirebaseAuth = true,
  })  : _firestore = firestore,
        _auth = auth,
        _connectivity = connectivity,
        _currentUserId = currentUserId,
        _useFirebaseAuth = useFirebaseAuth;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Connectivity get connectivity => _connectivity ?? Connectivity();

  String? get _currentUserIdOrAuth {
    if (_currentUserId != null) return _currentUserId;
    final auth = _auth;
    if (auth != null) return auth.currentUser?.uid;
    if (_useFirebaseAuth) return FirebaseAuth.instance.currentUser?.uid;
    return null;
  }

  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      firestore.collection('reviews');

  Query<Map<String, dynamic>> _visibleReviewsForBusiness(String businessId) =>
      _reviewsCollection
          .where('visible', isEqualTo: true)
          .where('businessId', isEqualTo: businessId);

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    var attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        final isRetryable = _isRetryableError(e);
        if (isRetryable && attempts < _maxRetries) {
          debugPrint(
            '[$operationName] attempt $attempts failed, retrying: $e',
          );
          await Future.delayed(_retryDelay * attempts);
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'network-request-failed' ||
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded';
    }
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('timeout') ||
        message.contains('connection') ||
        message.contains('unavailable');
  }

  Future<void> _assertOnline() async {
    final results = await connectivity.checkConnectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      throw Exception(
        'No internet connection. Please check your connection and try again.',
      );
    }
  }

  void _validateInputs({
    required int rating,
    required int buzzRating,
    required String comment,
  }) {
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }
    if (buzzRating < 0 || buzzRating > 5) {
      throw Exception('Buzz rating must be between 0 and 5');
    }
    final trimmed = comment.trim();
    if (trimmed.isEmpty) {
      throw Exception('Comment cannot be empty');
    }
    if (trimmed.length > _maxCommentLength) {
      throw Exception('Comment must be $_maxCommentLength characters or less');
    }
  }

  /// Returns the effective visitor ID or throws if unauthenticated.
  String _requireVisitorId(String? provided) {
    final visitorId = provided ?? _currentUserIdOrAuth;
    if (visitorId == null || visitorId.isEmpty) {
      throw Exception('You must be signed in to submit a recommendation.');
    }
    return visitorId;
  }

  /// Returns true if the visitor is currently allowed to create a
  /// recommendation for [businessId].
  ///
  /// Reasons for denial include: missing authentication, an existing
  /// non-deleted recommendation for the business, or a recent global cooldown.
  Future<bool> canCreateReview({
    required String businessId,
    String? visitorId,
  }) async {
    try {
      final effectiveVisitorId = visitorId ?? _currentUserIdOrAuth;
      if (effectiveVisitorId == null || effectiveVisitorId.isEmpty) {
        return false;
      }

      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visitorId', isEqualTo: effectiveVisitorId)
            .where('deletedAt', isNull: true)
            .limit(1)
            .get(),
        operationName: 'canCreateReview_existing',
      );

      if (snapshot.docs.isNotEmpty) return false;

      final latestSnapshot = await _withRetry(
        () => _reviewsCollection
            .where('visitorId', isEqualTo: effectiveVisitorId)
            .where('deletedAt', isNull: true)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(),
        operationName: 'canCreateReview_cooldown',
      );

      if (latestSnapshot.docs.isEmpty) return true;

      final data = latestSnapshot.docs.first.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) return true;

      return DateTime.now().difference(createdAt) >= _globalCooldown;
    } catch (e) {
      debugPrint('canCreateReview failed: $e');
      return false;
    }
  }

  /// Create a new recommendation (review) for a business.
  Future<String> createReview({
    required String businessId,
    String? visitorId,
    required String visitorName,
    required int rating,
    int buzzRating = 0,
    required String comment,
  }) async {
    try {
      final effectiveVisitorId = _requireVisitorId(visitorId);
      _validateInputs(rating: rating, buzzRating: buzzRating, comment: comment);

      await _assertOnline();

      final canSubmit = await canCreateReview(
        businessId: businessId,
        visitorId: effectiveVisitorId,
      );
      if (!canSubmit) {
        throw Exception(
          'You can only recommend a business once, and must wait '
          '${_globalCooldown.inMinutes} minute(s) between recommendations.',
        );
      }

      final docRef = await _withRetry(
        () => _reviewsCollection.add({
          'businessId': businessId,
          'visitorId': effectiveVisitorId,
          'visitorName': visitorName.trim().isEmpty ? 'Anonymous' : visitorName,
          'rating': rating,
          'buzzRating': buzzRating,
          'comment': comment.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': null,
          'deletedAt': null,
          'isReported': false,
          'reportReason': null,
          'reportedBy': null,
          'deletedBy': null,
          'helpfulCount': 0,
          'isFlagged': false,
          'visible': true,
        }),
        operationName: 'createReview',
      );

      // Update denormalized business metrics in the background.
      await _updateBusinessReviewMetrics(businessId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create recommendation: $e');
    }
  }

  /// Get a paginated list of visible recommendations for a business.
  ///
  /// Use [startAfterDocument] to fetch the next page. [limit] defaults to
  /// [_defaultPageSize] to keep business-profile loads under ~2 seconds.
  Future<List<Review>> getBusinessReviews(
    String businessId, {
    int limit = _defaultPageSize,
    DocumentSnapshot? startAfterDocument,
  }) async {
    final page = await getBusinessReviewsPage(
      businessId,
      limit: limit,
      startAfterDocument: startAfterDocument,
    );
    return page.items;
  }

  /// Get a paginated page of visible recommendations, including the cursor
  /// needed to fetch the next page.
  Future<ReviewsPage> getBusinessReviewsPage(
    String businessId, {
    int limit = _defaultPageSize,
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      if (limit <= 0) limit = _defaultPageSize;

      var query = _visibleReviewsForBusiness(businessId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await _withRetry(
        () => query.get(),
        operationName: 'getBusinessReviewsPage',
      );

      final items = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
      final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return ReviewsPage(items: items, lastDocument: lastDocument);
    } catch (e) {
      throw Exception('Failed to fetch recommendations: $e');
    }
  }

  /// Stream of visible recommendations for a business, limited to the first
  /// page for real-time UI updates.
  Stream<List<Review>> getBusinessReviewsStream(
    String businessId, {
    int limit = _defaultPageSize,
  }) {
    return _visibleReviewsForBusiness(businessId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Review.fromFirestore(doc))
              .toList(),
        );
  }

  /// Calculate average rating for a business using only visible recommendations.
  Future<double> getAverageRating(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visible', isEqualTo: true)
            .get(),
        operationName: 'getAverageRating',
      );

      if (snapshot.docs.isEmpty) return 0.0;

      final totalRating = snapshot.docs
          .fold<int>(0, (sum, doc) => sum + (doc['rating'] as int? ?? 0));
      return totalRating / snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to calculate average rating: $e');
    }
  }

  /// Stream average rating for real-time updates.
  Stream<double> getAverageRatingStream(String businessId) {
    return _reviewsCollection
        .where('businessId', isEqualTo: businessId)
        .where('visible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0.0;
      final totalRating = snapshot.docs
          .fold<int>(0, (sum, doc) => sum + (doc['rating'] as int? ?? 0));
      return totalRating / snapshot.docs.length;
    });
  }

  /// Get visible recommendation count for a business.
  Future<int> getReviewCount(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visible', isEqualTo: true)
            .count()
            .get(),
        operationName: 'getReviewCount',
      );

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get recommendation count: $e');
    }
  }

  /// Stream visible recommendation count for real-time updates.
  Stream<int> getReviewCountStream(String businessId) {
    return _reviewsCollection
        .where('businessId', isEqualTo: businessId)
        .where('visible', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Report a recommendation as inappropriate / spam.
  Future<void> reportReview(
    String reviewId,
    String reportReason, {
    String? reporterId,
  }) async {
    try {
      if (reportReason.trim().isEmpty) {
        throw Exception('Report reason cannot be empty');
      }

      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'isReported': true,
          'reportReason': reportReason.trim(),
          'reportedBy': reporterId ?? _currentUserIdOrAuth ?? '',
          'visible': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'reportReview',
      );
    } catch (e) {
      throw Exception('Failed to report recommendation: $e');
    }
  }

  /// Soft-delete a recommendation so history is preserved.
  ///
  /// Only the original author or an admin can delete (enforced by Firestore
  /// rules); the service itself performs the soft delete.
  Future<void> deleteReview(
    String reviewId, {
    String? visitorId,
  }) async {
    try {
      await _assertOnline();
      final review = await _withRetry(
        () => getReview(reviewId),
        operationName: 'getReview',
      );

      if (review == null) {
        throw Exception('Recommendation not found');
      }

      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': visitorId ?? _currentUserIdOrAuth ?? '',
          'visible': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'deleteReview',
      );

      await _updateBusinessReviewMetrics(review.businessId);
    } catch (e) {
      throw Exception('Failed to delete recommendation: $e');
    }
  }

  /// Restore a soft-deleted recommendation (admin only).
  Future<void> restoreReview(String reviewId) async {
    try {
      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'deletedAt': null,
          'deletedBy': null,
          'visible': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'restoreReview',
      );

      final review = await getReview(reviewId);
      if (review != null) {
        await _updateBusinessReviewMetrics(review.businessId);
      }
    } catch (e) {
      throw Exception('Failed to restore recommendation: $e');
    }
  }

  /// Flag a recommendation for admin moderation.
  Future<void> flagReview(String reviewId) async {
    try {
      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'isFlagged': true,
          'visible': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'flagReview',
      );
    } catch (e) {
      throw Exception('Failed to flag recommendation: $e');
    }
  }

  /// Remove the moderation flag from a recommendation.
  Future<void> unflagReview(String reviewId) async {
    try {
      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'isFlagged': false,
          'visible': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'unflagReview',
      );
    } catch (e) {
      throw Exception('Failed to unflag recommendation: $e');
    }
  }

  /// Increment the helpful count for a recommendation.
  Future<void> markHelpful(String reviewId) async {
    try {
      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'helpfulCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'markHelpful',
      );
    } catch (e) {
      throw Exception('Failed to mark recommendation as helpful: $e');
    }
  }

  /// Update business review count and average rating after recommendation
  /// changes. The backend Cloud Function recalculates the buzz score; this
  /// keeps the denormalized counts in sync for fast profile loads.
  Future<void> _updateBusinessReviewMetrics(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visible', isEqualTo: true)
            .get(),
        operationName: '_updateBusinessReviewMetrics',
      );

      final totalRating = snapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc['rating'] as int? ?? 0),
      );
      final totalBuzz = snapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc['buzzRating'] as int? ?? 0),
      );
      final count = snapshot.docs.length;
      final averageRating = count > 0 ? totalRating / count : 0.0;
      final averageBuzz = count > 0 ? totalBuzz / count : 0.0;

      await firestore.collection('businesses').doc(businessId).update({
        'reviewCount': count,
        'rating': averageRating,
        'buzzRating': averageBuzz,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't fail the review operation if denormalization fails.
      debugPrint('Failed to update business review metrics: $e');
    }
  }

  /// Get a single recommendation.
  Future<Review?> getReview(String reviewId) async {
    try {
      final doc = await _withRetry(
        () => _reviewsCollection.doc(reviewId).get(),
        operationName: 'getReview',
      );
      if (!doc.exists) return null;
      return Review.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch recommendation: $e');
    }
  }

  /// Check if visitor already has a visible recommendation for this business.
  Future<bool> hasVisitorReviewedBusiness(
    String businessId,
    String visitorId,
  ) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visitorId', isEqualTo: visitorId)
            .where('deletedAt', isNull: true)
            .limit(1)
            .get(),
        operationName: 'hasVisitorReviewedBusiness',
      );

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check recommendation status: $e');
    }
  }

  /// Get all reported recommendations (admin only).
  Future<List<Review>> getReportedReviews() async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('isReported', isEqualTo: true)
            .where('deletedAt', isNull: true)
            .orderBy('updatedAt', descending: true)
            .get(),
        operationName: 'getReportedReviews',
      );

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reported recommendations: $e');
    }
  }

  /// Get recommendation history for a visitor (including soft-deleted).
  Future<List<Review>> getVisitorRecommendationHistory(
    String visitorId, {
    int limit = _defaultPageSize,
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      var query = _reviewsCollection
          .where('visitorId', isEqualTo: visitorId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final snapshot = await _withRetry(
        () => query.get(),
        operationName: 'getVisitorRecommendationHistory',
      );

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch recommendation history: $e');
    }
  }
}

/// A paginated result returned by [ReviewService.getBusinessReviewsPage].
class ReviewsPage {
  final List<Review> items;
  final DocumentSnapshot? lastDocument;

  const ReviewsPage({required this.items, this.lastDocument});
}
