import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  ReviewService({
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivity = connectivity ?? Connectivity();

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('reviews');

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
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      throw Exception(
        'No internet connection. Please check your connection and try again.',
      );
    }
  }

  /// Create a new review
  Future<String> createReview({
    required String businessId,
    required String visitorId,
    required String visitorName,
    required int rating,
    required String comment,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }
      if (comment.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      await _assertOnline();
      final docRef = await _withRetry(
        () => _reviewsCollection.add({
          'businessId': businessId,
          'visitorId': visitorId,
          'visitorName': visitorName,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': null,
          'isReported': false,
          'reportReason': null,
        }),
        operationName: 'createReview',
      );

      // Update business review count and trigger buzz score recalculation
      await _updateBusinessReviewMetrics(businessId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Get all reviews for a business (excluding reported ones)
  Future<List<Review>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('isReported', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get(),
        operationName: 'getBusinessReviews',
      );

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Stream reviews for real-time updates
  Stream<List<Review>> getBusinessReviewsStream(String businessId) {
    return _reviewsCollection
        .where('businessId', isEqualTo: businessId)
        .where('isReported', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList());
  }

  /// Calculate average rating for a business
  Future<double> getAverageRating(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('isReported', isEqualTo: false)
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

  /// Stream average rating for real-time updates
  Stream<double> getAverageRatingStream(String businessId) {
    return _reviewsCollection
        .where('businessId', isEqualTo: businessId)
        .where('isReported', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0.0;
      final totalRating = snapshot.docs
          .fold<int>(0, (sum, doc) => sum + (doc['rating'] as int? ?? 0));
      return totalRating / snapshot.docs.length;
    });
  }

  /// Get review count for a business
  Future<int> getReviewCount(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('isReported', isEqualTo: false)
            .count()
            .get(),
        operationName: 'getReviewCount',
      );

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get review count: $e');
    }
  }

  /// Stream review count for real-time updates
  Stream<int> getReviewCountStream(String businessId) {
    return _reviewsCollection
        .where('businessId', isEqualTo: businessId)
        .where('isReported', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Report a review as inappropriate
  Future<void> reportReview(String reviewId, String reportReason) async {
    try {
      if (reportReason.trim().isEmpty) {
        throw Exception('Report reason cannot be empty');
      }

      await _assertOnline();
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).update({
          'isReported': true,
          'reportReason': reportReason,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        operationName: 'reportReview',
      );
    } catch (e) {
      throw Exception('Failed to report review: $e');
    }
  }

  /// Delete a review (review owner, business owner, or admin)
  Future<void> deleteReview(String reviewId) async {
    try {
      await _assertOnline();
      final review = await _withRetry(
        () => getReview(reviewId),
        operationName: 'getReview',
      );
      await _withRetry(
        () => _reviewsCollection.doc(reviewId).delete(),
        operationName: 'deleteReview',
      );
      if (review != null) {
        await _updateBusinessReviewMetrics(review.businessId);
      }
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  /// Update business review count and average rating after review changes.
  /// Buzz score is recalculated by the backend Cloud Function; this just
  /// ensures the denormalized counts are kept in sync.
  Future<void> _updateBusinessReviewMetrics(String businessId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('isReported', isEqualTo: false)
            .get(),
        operationName: '_updateBusinessReviewMetrics',
      );

      final totalRating = snapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc['rating'] as int? ?? 0),
      );
      final count = snapshot.docs.length;
      final averageRating = count > 0 ? totalRating / count : 0.0;

      await _firestore.collection('businesses').doc(businessId).update({
        'reviewCount': count,
        'rating': averageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't fail the review operation if denormalization fails.
      debugPrint('Failed to update business review metrics: $e');
    }
  }

  /// Get a single review
  Future<Review?> getReview(String reviewId) async {
    try {
      final doc = await _withRetry(
        () => _reviewsCollection.doc(reviewId).get(),
        operationName: 'getReview',
      );
      if (!doc.exists) return null;
      return Review.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch review: $e');
    }
  }

  /// Check if visitor already reviewed this business
  Future<bool> hasVisitorReviewedBusiness(
      String businessId, String visitorId) async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('businessId', isEqualTo: businessId)
            .where('visitorId', isEqualTo: visitorId)
            .limit(1)
            .get(),
        operationName: 'hasVisitorReviewedBusiness',
      );

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check review status: $e');
    }
  }

  /// Get all reported reviews (admin only)
  Future<List<Review>> getReportedReviews() async {
    try {
      final snapshot = await _withRetry(
        () => _reviewsCollection
            .where('isReported', isEqualTo: true)
            .orderBy('updatedAt', descending: true)
            .get(),
        operationName: 'getReportedReviews',
      );

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reported reviews: $e');
    }
  }
}
