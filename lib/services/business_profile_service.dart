import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:brisconnect/models/business.dart';

/// Service for managing business profiles in Firestore and Firebase Storage
class BusinessProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  BusinessProfileService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const String _collection = 'businesses';
  static const String _logoFolder = 'business_logos';
  static const String _coverFolder = 'business_covers';

  /// Create a new business profile
  Future<String> createBusinessProfile(Business business) async {
    try {
      final docRef = await _firestore.collection(_collection).add(
            business.toFirestore(),
          );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create business profile: $e');
    }
  }

  /// Update an existing business profile
  Future<void> updateBusinessProfile(Business business) async {
    if (business.id == null) {
      throw Exception('Business ID is required for update');
    }
    try {
      await _firestore.collection(_collection).doc(business.id).update(
            business.copyWith(updatedAt: DateTime.now()).toFirestore(),
          );
    } catch (e) {
      throw Exception('Failed to update business profile: $e');
    }
  }

  /// Get a business profile by ID
  Future<Business?> getBusinessProfile(String businessId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(businessId).get();
      if (doc.exists) {
        return Business.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch business profile: $e');
    }
  }

  /// Get business profile stream for real-time updates
  Stream<Business?> getBusinessProfileStream(String businessId) {
    return _firestore.collection(_collection).doc(businessId).snapshots().map((doc) {
      if (doc.exists) {
        return Business.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Get all business profiles owned by a user
  Future<List<Business>> getUserBusinessProfiles(String userId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('ownerId', isEqualTo: userId)
          .get();
      return query.docs.map((doc) => Business.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch user business profiles: $e');
    }
  }

  /// Stream of user's business profiles for real-time updates
  Stream<List<Business>> getUserBusinessProfilesStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Search businesses by name or category
  Future<List<Business>> searchBusinesses(String query) async {
    try {
      // Firestore doesn't support full-text search, so we do basic filtering
      final snapshot = await _firestore.collection(_collection).get();
      final results = snapshot.docs
          .map((doc) => Business.fromFirestore(doc))
          .where((business) {
        final queryLower = query.toLowerCase();
        return business.businessName.toLowerCase().contains(queryLower) ||
            business.category.toLowerCase().contains(queryLower) ||
            business.description.toLowerCase().contains(queryLower);
      }).toList();
      return results;
    } catch (e) {
      throw Exception('Failed to search businesses: $e');
    }
  }

  /// Get businesses by category
  Future<List<Business>> getBusinessesByCategory(String category) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .get();
      return query.docs.map((doc) => Business.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch businesses by category: $e');
    }
  }

  /// Upload business logo image
  Future<String> uploadLogoImage({
    required String businessId,
    required String filePath,
  }) async {
    try {
      final fileName = '${businessId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$_logoFolder/$fileName');

      // Upload file
      await ref.putFile(File(filePath));

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload logo: $e');
    }
  }

  /// Upload business cover image
  Future<String> uploadCoverImage({
    required String businessId,
    required String filePath,
  }) async {
    try {
      final fileName = '${businessId}_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$_coverFolder/$fileName');

      // Upload file
      await ref.putFile(File(filePath));

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload cover image: $e');
    }
  }

  /// Delete a business profile and its associated images
  Future<void> deleteBusinessProfile(String businessId) async {
    try {
      // Get business to find image URLs
      final business = await getBusinessProfile(businessId);

      if (business != null) {
        // Delete logo if exists
        if (business.logoUrl != null) {
          try {
            await _deleteImageFromUrl(business.logoUrl!);
          } catch (e) {
            // Continue even if logo deletion fails
          }
        }

        // Delete cover image if exists
        if (business.coverImageUrl != null) {
          try {
            await _deleteImageFromUrl(business.coverImageUrl!);
          } catch (e) {
            // Continue even if cover deletion fails
          }
        }
      }

      // Delete the business document
      await _firestore.collection(_collection).doc(businessId).delete();
    } catch (e) {
      throw Exception('Failed to delete business profile: $e');
    }
  }

  /// Helper method to delete image from Storage URL
  Future<void> _deleteImageFromUrl(String downloadUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail - URL might not exist
    }
  }

  /// Get all verified businesses (for public listing)
  Future<List<Business>> getVerifiedBusinesses() async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('isVerified', isEqualTo: true)
          .get();
      return query.docs.map((doc) => Business.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch verified businesses: $e');
    }
  }

  /// Stream of all verified businesses
  Stream<List<Business>> getVerifiedBusinessesStream() {
    return _firestore
        .collection(_collection)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Stream of trending businesses (isTrending == true)
  Stream<List<Business>> getTrendingBusinessesStream({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('isTrending', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .orderBy('buzzScore', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Increment view count for a business profile
  Future<void> incrementViewCount(String businessId) async {
    try {
      await _firestore.collection(_collection).doc(businessId).update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to increment view count: $e');
    }
  }

  /// Verify a business (admin only)
  Future<void> verifyBusiness(String businessId) async {
    try {
      await _firestore.collection(_collection).doc(businessId).update({
        'isVerified': true,
      });
    } catch (e) {
      throw Exception('Failed to verify business: $e');
    }
  }
}
