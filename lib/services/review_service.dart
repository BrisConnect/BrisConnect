import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('reviews');

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

      final docRef = await _reviewsCollection.add({
        'businessId': businessId,
        'visitorId': visitorId,
        'visitorName': visitorName,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
        'isReported': false,
        'reportReason': null,
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Get all reviews for a business (excluding reported ones)
  Future<List<Review>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _reviewsCollection
          .where('businessId', isEqualTo: businessId)
          .where('isReported', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

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
      final snapshot = await _reviewsCollection
          .where('businessId', isEqualTo: businessId)
          .where('isReported', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final totalRating =
          snapshot.docs.fold<int>(0, (sum, doc) => sum + (doc['rating'] as int? ?? 0));
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
      final snapshot = await _reviewsCollection
          .where('businessId', isEqualTo: businessId)
          .where('isReported', isEqualTo: false)
          .count()
          .get();

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

      await _reviewsCollection.doc(reviewId).update({
        'isReported': true,
        'reportReason': reportReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to report review: $e');
    }
  }

  /// Delete a review (admin/business owner only)
  Future<void> deleteReview(String reviewId) async {
    try {
      await _reviewsCollection.doc(reviewId).delete();
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  /// Get a single review
  Future<Review?> getReview(String reviewId) async {
    try {
      final doc = await _reviewsCollection.doc(reviewId).get();
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
      final snapshot = await _reviewsCollection
          .where('businessId', isEqualTo: businessId)
          .where('visitorId', isEqualTo: visitorId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check review status: $e');
    }
  }

  /// Get all reported reviews (admin only)
  Future<List<Review>> getReportedReviews() async {
    try {
      final snapshot = await _reviewsCollection
          .where('isReported', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reported reviews: $e');
    }
  }
}
