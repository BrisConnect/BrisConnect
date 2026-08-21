import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/models/food_business.dart';

/// Service that exposes food/drink businesses to visitors.
///
/// The canonical collection for owner-created business profiles is
/// [businesses]. The legacy [food_businesses] collection (imported/demo data)
/// is merged in so existing listings remain visible while new owner profiles
/// take precedence on duplicate IDs.
class FoodBusinessService {
  final FirebaseFirestore _firestore;

  FoodBusinessService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _canonicalCollection = 'businesses';
  static const String _legacyCollection = 'food_businesses';

  /// Returns true for active, non-deleted canonical business documents.
  bool _isActiveCanonicalDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    if (data['deletedAt'] != null) return false;
    final isActive = data['isActive'];
    if (isActive is bool && !isActive) return false;
    return true;
  }

  /// Streams merged, de-duplicated documents from both collections.
  Stream<List<DocumentSnapshot>> _mergedDocsStream() {
    final controller = StreamController<List<DocumentSnapshot>>.broadcast();
    List<DocumentSnapshot>? canonicalDocs;
    List<DocumentSnapshot>? legacyDocs;
    var canonicalEmitted = false;
    var legacyEmitted = false;

    void emit() {
      if (!canonicalEmitted || !legacyEmitted) return;
      controller.add([
        ...?canonicalDocs,
        ...?legacyDocs,
      ]);
    }

    final sub1 = _firestore
        .collection(_canonicalCollection)
        .snapshots()
        .listen(
          (snap) {
            canonicalDocs = snap.docs.where(_isActiveCanonicalDoc).toList();
            canonicalEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] $_canonicalCollection error: $e');
            canonicalDocs ??= [];
            canonicalEmitted = true;
            emit();
          },
        );

    final sub2 = _firestore
        .collection(_legacyCollection)
        .snapshots()
        .listen(
          (snap) {
            legacyDocs = snap.docs;
            legacyEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] $_legacyCollection error: $e');
            legacyDocs ??= [];
            legacyEmitted = true;
            emit();
          },
        );

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };

    return controller.stream;
  }

  /// De-duplicates by ID and sorts by average rating (highest first).
  List<FoodBusiness> _dedupeAndSortByRating(List<FoodBusiness> list) {
    final map = <String, FoodBusiness>{};
    for (final business in list) {
      map[business.id] = business;
    }
    final result = map.values.toList();
    result.sort((a, b) {
      final ratingA = a.averageRating ?? 0;
      final ratingB = b.averageRating ?? 0;
      return ratingB.compareTo(ratingA);
    });
    return result;
  }

  /// Get all food businesses
  Stream<List<FoodBusiness>> getAllBusinesses() {
    return _mergedDocsStream().map((docs) {
      final businesses = docs.map(FoodBusiness.fromFirestore).toList();
      return _dedupeAndSortByRating(businesses);
    });
  }

  /// Search businesses by name or cuisine type
  Stream<List<FoodBusiness>> searchBusinesses(String query) {
    final lowerQuery = query.toLowerCase();
    return _mergedDocsStream().map((docs) {
      final businesses = docs
          .map(FoodBusiness.fromFirestore)
          .where((business) {
            return business.name.toLowerCase().contains(lowerQuery) ||
                (business.cuisineTypes
                        ?.any((c) => c.toLowerCase().contains(lowerQuery)) ??
                    false) ||
                business.description.toLowerCase().contains(lowerQuery);
          })
          .toList();
      return _dedupeAndSortByRating(businesses);
    });
  }

  /// Get a single business by ID. Canonical collection is checked first.
  Future<FoodBusiness?> getBusinessById(String businessId) async {
    try {
      final canonicalDoc =
          await _firestore.collection(_canonicalCollection).doc(businessId).get();
      if (canonicalDoc.exists && _isActiveCanonicalDoc(canonicalDoc)) {
        return FoodBusiness.fromFirestore(canonicalDoc);
      }

      final legacyDoc =
          await _firestore.collection(_legacyCollection).doc(businessId).get();
      if (legacyDoc.exists) {
        return FoodBusiness.fromFirestore(legacyDoc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get business: $e');
    }
  }

  /// Get businesses by cuisine/category type
  Stream<List<FoodBusiness>> getBusinessesByCuisine(String cuisineType) {
    final controller = StreamController<List<FoodBusiness>>.broadcast();
    List<FoodBusiness>? canonicalList;
    List<FoodBusiness>? legacyList;
    var canonicalEmitted = false;
    var legacyEmitted = false;

    void emit() {
      if (!canonicalEmitted || !legacyEmitted) return;
      final all = [...?canonicalList, ...?legacyList];
      controller.add(_dedupeAndSortByRating(all));
    }

    final sub1 = _firestore
        .collection(_canonicalCollection)
        .where('category', isEqualTo: cuisineType)
        .snapshots()
        .listen(
          (snap) {
            canonicalList = snap.docs
                .where(_isActiveCanonicalDoc)
                .map(FoodBusiness.fromFirestore)
                .toList();
            canonicalEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] cuisine canonical error: $e');
            canonicalList ??= [];
            canonicalEmitted = true;
            emit();
          },
        );

    final sub2 = _firestore
        .collection(_legacyCollection)
        .where('cuisineTypes', arrayContains: cuisineType)
        .snapshots()
        .listen(
          (snap) {
            legacyList = snap.docs.map(FoodBusiness.fromFirestore).toList();
            legacyEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] cuisine legacy error: $e');
            legacyList ??= [];
            legacyEmitted = true;
            emit();
          },
        );

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };

    return controller.stream;
  }

  /// Get top rated businesses
  Stream<List<FoodBusiness>> getTopRatedBusinesses({int limit = 10}) {
    return _mergedDocsStream().map((docs) {
      final businesses = docs
          .map(FoodBusiness.fromFirestore)
          .where((b) => (b.averageRating ?? 0) > 0)
          .toList();
      return _dedupeAndSortByRating(businesses).take(limit).toList();
    });
  }

  /// Get newly added businesses
  Stream<List<FoodBusiness>> getNewBusinesses({int limit = 10}) {
    final controller = StreamController<List<FoodBusiness>>.broadcast();
    List<FoodBusiness>? canonicalList;
    List<FoodBusiness>? legacyList;
    var canonicalEmitted = false;
    var legacyEmitted = false;

    void emit() {
      if (!canonicalEmitted || !legacyEmitted) return;
      final all = [...?canonicalList, ...?legacyList];
      all.sort((a, b) {
        final timeA = a.createdAt ?? DateTime(2000);
        final timeB = b.createdAt ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });
      controller.add(all.take(limit).toList());
    }

    final sub1 = _firestore
        .collection(_canonicalCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
          (snap) {
            canonicalList = snap.docs
                .where(_isActiveCanonicalDoc)
                .map(FoodBusiness.fromFirestore)
                .toList();
            canonicalEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] new canonical error: $e');
            canonicalList ??= [];
            canonicalEmitted = true;
            emit();
          },
        );

    final sub2 = _firestore
        .collection(_legacyCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
          (snap) {
            legacyList = snap.docs.map(FoodBusiness.fromFirestore).toList();
            legacyEmitted = true;
            emit();
          },
          onError: (Object e) {
            debugPrint('[FoodBusinessService] new legacy error: $e');
            legacyList ??= [];
            legacyEmitted = true;
            emit();
          },
        );

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };

    return controller.stream;
  }
}
