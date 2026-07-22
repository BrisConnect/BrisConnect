import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/models/food_business.dart';

class FoodBusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all food businesses
  Stream<List<FoodBusiness>> getAllBusinesses() {
    return _firestore
        .collection('businesses')
        .snapshots()
        .map((snapshot) {
      List<FoodBusiness> businesses = snapshot.docs
          .map((doc) => FoodBusiness.fromFirestore(doc))
          .toList();
      // Sort by average rating in Dart instead of Firestore to handle missing fields
      businesses.sort((a, b) {
        final ratingA = a.averageRating ?? 0;
        final ratingB = b.averageRating ?? 0;
        return ratingB.compareTo(ratingA); // descending order
      });
      return businesses;
    });
  }

  /// Search businesses by name or cuisine type
  Stream<List<FoodBusiness>> searchBusinesses(String query) {
    final lowerQuery = query.toLowerCase();
    return _firestore
        .collection('businesses')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodBusiness.fromFirestore(doc))
          .where((business) {
        return business.name.toLowerCase().contains(lowerQuery) ||
            (business.cuisineTypes
                    ?.any((c) => c.toLowerCase().contains(lowerQuery)) ??
                false) ||
            business.description.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  /// Get a single business by ID
  Future<FoodBusiness?> getBusinessById(String businessId) async {
    try {
      final doc =
          await _firestore.collection('businesses').doc(businessId).get();
      if (doc.exists) {
        return FoodBusiness.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get business: $e');
    }
  }

  /// Get businesses by cuisine type
  Stream<List<FoodBusiness>> getBusinessesByCuisine(String cuisineType) {
    return _firestore
        .collection('businesses')
        .where('cuisineTypes', arrayContains: cuisineType)
        .snapshots()
        .map((snapshot) {
      List<FoodBusiness> businesses = snapshot.docs
          .map((doc) => FoodBusiness.fromFirestore(doc))
          .toList();
      // Sort by rating in Dart
      businesses.sort((a, b) {
        final ratingA = a.averageRating ?? 0;
        final ratingB = b.averageRating ?? 0;
        return ratingB.compareTo(ratingA); // descending order
      });
      return businesses;
    });
  }

  /// Get top rated businesses
  Stream<List<FoodBusiness>> getTopRatedBusinesses({int limit = 10}) {
    return _firestore
        .collection('businesses')
        .snapshots()
        .map((snapshot) {
      List<FoodBusiness> businesses = snapshot.docs
          .map((doc) => FoodBusiness.fromFirestore(doc))
          .where((b) => (b.averageRating ?? 0) > 0)
          .toList();
      businesses.sort((a, b) {
        final ratingA = a.averageRating ?? 0;
        final ratingB = b.averageRating ?? 0;
        return ratingB.compareTo(ratingA); // descending order
      });
      return businesses.take(limit).toList();
    });
  }

  /// Get newly added businesses
  Stream<List<FoodBusiness>> getNewBusinesses({int limit = 10}) {
    return _firestore
        .collection('businesses')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodBusiness.fromFirestore(doc))
          .toList();
    });
  }
}
