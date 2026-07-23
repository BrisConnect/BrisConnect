import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brisconnect/models/business_review.dart';

class BusinessRatingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a rating and review for a food business
  Future<void> submitReview({
    required String businessId,
    required double rating,
    double buzzRating = 0,
    required String comment,
  }) async {
    try {
      final user = _auth.currentUser;
      // Dev fallback for unsigned macOS builds where Firebase Auth keychain
      // access fails and currentUser is null.
      final userId = user?.uid ?? 'dev-anonymous-user';
      final userName = user?.displayName ?? 'Anonymous';
      final now = FieldValue.serverTimestamp();

      final reviewData = {
        'businessId': businessId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'buzzRating': buzzRating,
        'comment': comment,
        'createdAt': now,
        'helpfulCount': 0,
      };

      // Add the review to the business-specific subcollection for the
      // public business profile.
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reviews')
          .add(reviewData);

      // Also mirror the review to the top-level reviews collection so it
      // appears on the local Vendor Reviews screen and business dashboard.
      await _firestore.collection('reviews').add({
        'businessId': businessId,
        'visitorId': userId,
        'visitorName': userName,
        'rating': rating.round(),
        'buzzRating': buzzRating.round(),
        'comment': comment,
        'createdAt': now,
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'reportedBy': null,
        'deletedBy': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
      });

      // Update business average rating and review count
      await _updateBusinessRating(businessId);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Get all reviews for a business
  Stream<List<BusinessReview>> getBusinessReviews(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BusinessReview.fromFirestore(doc))
          .toList();
    });
  }

  /// Get average rating for a business
  Future<double> getAverageRating(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reviews')
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double totalRating = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as num).toDouble();
      }

      return totalRating / snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get average rating: $e');
    }
  }

  /// Update business average rating in the main document
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reviews')
          .get();

      if (snapshot.docs.isEmpty) {
        await _firestore.collection('businesses').doc(businessId).update({
          'averageRating': 0,
          'reviewCount': 0,
        });
        return;
      }

      double totalRating = 0;
      double totalBuzz = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as num).toDouble();
        totalBuzz += (data['buzzRating'] as num?)?.toDouble() ?? 0.0;
      }

      final averageRating = totalRating / snapshot.docs.length;
      final averageBuzz = totalBuzz / snapshot.docs.length;

      await _firestore.collection('businesses').doc(businessId).update({
        'averageRating': averageRating,
        'buzzRating': averageBuzz,
        'reviewCount': snapshot.docs.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update business rating: $e');
    }
  }

  /// Check if user has already reviewed this business
  Future<bool> hasUserReviewed(String businessId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check review status: $e');
    }
  }

  /// Delete a review (only owner can delete)
  Future<void> deleteReview(String businessId, String reviewId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Verify ownership
      final reviewDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('reviews')
          .doc(reviewId)
          .get();

      final reviewData = reviewDoc.data();
      if (reviewData?['userId'] != user.uid) {
        throw Exception('Unauthorized');
      }

      // Delete the review
      await reviewDoc.reference.delete();

      // Update business rating
      await _updateBusinessRating(businessId);
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }
}
