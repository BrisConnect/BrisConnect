import 'package:cloud_firestore/cloud_firestore.dart';

class FoodBusiness {
  final String id;
  final String name;
  final String description;
  final String address;
  final String? phone;
  final String? website;
  final List<String>? cuisineTypes;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final double? averageRating;
  final int? reviewCount;
  final String? operatingHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FoodBusiness({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    this.phone,
    this.website,
    this.cuisineTypes,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.averageRating,
    this.reviewCount,
    this.operatingHours,
    this.createdAt,
    this.updatedAt,
  });

  factory FoodBusiness.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Support both the legacy FoodBusiness schema and the owner-facing
    // Business schema (created via BusinessProfileSetupScreen / FormScreen).
    final name = data['name'] ?? data['businessName'] ?? '';
    final description = data['description'] ?? '';
    final address = data['address'] ?? '';
    final phone = data['phone'] ?? data['contactNumber'];
    final website = data['website'];
    final category = data['category'];
    final cuisineTypesRaw = data['cuisineTypes'];
    final cuisineTypes = cuisineTypesRaw != null && cuisineTypesRaw is List
        ? List<String>.from(cuisineTypesRaw)
        : category != null
            ? [category.toString()]
            : <String>[];
    final imageUrl = data['imageUrl'] ?? data['logoUrl'] ?? data['coverImageUrl'];
    final latitude = data['latitude'] ?? data['lat'];
    final longitude = data['longitude'] ?? data['lng'];
    final averageRating = data['averageRating'] ?? data['rating'];
    final reviewCount = data['reviewCount'];
    final operatingHours = data['operatingHours'] ?? data['businessHours'];

    return FoodBusiness(
      id: doc.id,
      name: name,
      description: description,
      address: address,
      phone: phone,
      website: website,
      cuisineTypes: cuisineTypes,
      imageUrl: imageUrl,
      latitude: (latitude as num?)?.toDouble(),
      longitude: (longitude as num?)?.toDouble(),
      averageRating: (averageRating as num?)?.toDouble(),
      reviewCount: reviewCount as int?,
      operatingHours: operatingHours is String ? operatingHours : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'website': website,
      'cuisineTypes': cuisineTypes,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'operatingHours': operatingHours,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
