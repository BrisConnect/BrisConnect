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
  static const String _archiveCollection = 'business_archive';
  static const String _verificationLogCollection = 'business_verification_log';
  static const String _logoFolder = 'business_logos';
  static const String _coverFolder = 'business_covers';

  /// Archive retention period in days.
  static const int archiveRetentionDays = 30;

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

  /// Dev fallback: returns the first business document found. Used on
  /// unsigned macOS builds where Firebase Auth keychain access fails and the
  /// current user's email may not be available.
  Future<Business?> getFirstBusiness() async {
    try {
      final query = await _firestore
          .collection(_collection)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return Business.fromFirestore(query.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch first business: $e');
    }
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

  /// Stream of all verified, active, non-deleted businesses (public listing).
  Stream<List<Business>> getVerifiedBusinessesStream() {
    return _firestore
        .collection(_collection)
        .where('isVerified', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Stream of all active, non-deleted businesses regardless of verification status.
  /// Useful for development/testing when no profiles have been verified yet.
  Stream<List<Business>> getAllBusinessesStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Stream of trending businesses (isTrending == true)
  Stream<List<Business>> getTrendingBusinessesStream({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('isTrending', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('deletedAt', isNull: true)
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

  /// Verify a business (admin only). Records an audit log entry so the
  /// verification can be reviewed later.
  Future<void> verifyBusiness({
    required String businessId,
    required String adminEmail,
    String? notes,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc(businessId);
      final now = FieldValue.serverTimestamp();

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Business not found');
        }
        transaction.update(docRef, {
          'isVerified': true,
          'verifiedAt': now,
          'verifiedBy': adminEmail,
          'updatedAt': now,
        });
        transaction.set(
          _firestore.collection(_verificationLogCollection).doc(),
          {
            'businessId': businessId,
            'adminEmail': adminEmail,
            'action': 'verify',
            'verifiedAt': now,
            'notes': notes,
          },
        );
      });
    } catch (e) {
      throw Exception('Failed to verify business: $e');
    }
  }

  /// Revoke verification (admin only).
  Future<void> unverifyBusiness({
    required String businessId,
    required String adminEmail,
    String? notes,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc(businessId);
      final now = FieldValue.serverTimestamp();

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Business not found');
        }
        transaction.update(docRef, {
          'isVerified': false,
          'verifiedAt': FieldValue.delete(),
          'verifiedBy': FieldValue.delete(),
          'updatedAt': now,
        });
        transaction.set(
          _firestore.collection(_verificationLogCollection).doc(),
          {
            'businessId': businessId,
            'adminEmail': adminEmail,
            'action': 'unverify',
            'verifiedAt': now,
            'notes': notes,
          },
        );
      });
    } catch (e) {
      throw Exception('Failed to unverify business: $e');
    }
  }

  /// Stream verification audit records for a business.
  Stream<List<Map<String, dynamic>>> getVerificationLog(String businessId) {
    return _firestore
        .collection(_verificationLogCollection)
        .where('businessId', isEqualTo: businessId)
        .orderBy('verifiedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Deactivate a business listing (admin only).
  Future<void> deactivateBusiness({
    required String businessId,
    required String adminEmail,
    String? reason,
  }) async {
    try {
      await _firestore.collection(_collection).doc(businessId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedBy': adminEmail,
        'deactivationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate business: $e');
    }
  }

  /// Reactivate a previously deactivated business listing (admin only).
  Future<void> reactivateBusiness({
    required String businessId,
    required String adminEmail,
  }) async {
    try {
      await _firestore.collection(_collection).doc(businessId).update({
        'isActive': true,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': adminEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reactivate business: $e');
    }
  }

  /// Soft-delete a business and archive it for 30-day recovery.
  Future<void> archiveBusiness({
    required String businessId,
    required String adminEmail,
    String? reason,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc(businessId);
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: archiveRetentionDays)),
      );

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Business not found');
        }
        final data = snapshot.data()!;
        data['originalId'] = businessId;
        data['deletedAt'] = now;
        data['deletedBy'] = adminEmail;
        data['deleteReason'] = reason;
        data['archiveExpiresAt'] = expiresAt;

        transaction.set(
          _firestore.collection(_archiveCollection).doc(businessId),
          data,
        );
        transaction.update(docRef, {
          'deletedAt': now,
          'deletedBy': adminEmail,
          'deleteReason': reason,
          'isActive': false,
          'updatedAt': now,
        });
      });
    } catch (e) {
      throw Exception('Failed to archive business: $e');
    }
  }

  /// Restore a soft-deleted business from the archive.
  Future<void> restoreBusiness({
    required String businessId,
    required String adminEmail,
  }) async {
    try {
      final liveRef = _firestore.collection(_collection).doc(businessId);
      final archiveRef = _firestore.collection(_archiveCollection).doc(businessId);

      await _firestore.runTransaction((transaction) async {
        final archiveSnap = await transaction.get(archiveRef);
        if (!archiveSnap.exists) {
          throw Exception('Archived business not found');
        }
        final data = archiveSnap.data()!;
        data.remove('archiveExpiresAt');
        data['restoredAt'] = FieldValue.serverTimestamp();
        data['restoredBy'] = adminEmail;
        data['deletedAt'] = FieldValue.delete();
        data['deletedBy'] = FieldValue.delete();
        data['deleteReason'] = FieldValue.delete();
        data['isActive'] = true;
        data['updatedAt'] = FieldValue.serverTimestamp();

        transaction.set(liveRef, data);
        transaction.delete(archiveRef);
      });
    } catch (e) {
      throw Exception('Failed to restore business: $e');
    }
  }

  /// Permanently delete an archived business after the retention window.
  Future<void> permanentlyDeleteArchivedBusiness(String businessId) async {
    try {
      final archiveRef = _firestore.collection(_archiveCollection).doc(businessId);
      final archiveSnap = await archiveRef.get();
      if (!archiveSnap.exists) return;

      final business = Business.fromFirestore(archiveSnap);
      if (business.logoUrl != null) {
        try {
          await _deleteImageFromUrl(business.logoUrl!);
        } catch (_) {}
      }
      if (business.coverImageUrl != null) {
        try {
          await _deleteImageFromUrl(business.coverImageUrl!);
        } catch (_) {}
      }

      await archiveRef.delete();
    } catch (e) {
      throw Exception('Failed to permanently delete archived business: $e');
    }
  }

  /// Stream of all businesses including inactive and archived, for admin use.
  Stream<List<Business>> getAllBusinessesAdminStream() {
    return _firestore
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Stream of archived businesses pending permanent deletion.
  Stream<List<Business>> getArchivedBusinessesStream() {
    return _firestore
        .collection(_archiveCollection)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }

  /// Stream of businesses flagged as potential duplicates.
  Stream<List<Business>> getFlaggedDuplicatesStream() {
    return _firestore
        .collection(_collection)
        .where('duplicateOf', isNull: false)
        .orderBy('duplicateOf')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList());
  }
}
