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
  final String? email;
  final String? ownerId;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? onlineOrderUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isGoogleListing; // True for Google Places imports; reviews and crowdsourcing disabled
  final String? sourceProvider; // 'google_places' for Google-seeded listings

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
    this.email,
    this.ownerId,
    this.facebookUrl,
    this.instagramUrl,
    this.onlineOrderUrl,
    this.createdAt,
    this.updatedAt,
    this.isGoogleListing = false,
    this.sourceProvider,
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
    final email = data['email'] ?? data['businessEmail'];
    final ownerId = data['ownerId'] ?? data['ownerEmail'] ?? email;
    final facebookUrl = data['facebookUrl'] ?? data['facebook'];
    final instagramUrl = data['instagramUrl'] ?? data['instagram'];
    final onlineOrderUrl = data['onlineOrderUrl'] ?? data['onlineOrderLink'];

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
      email: email is String ? email : null,
      ownerId: ownerId is String ? ownerId : null,
      facebookUrl: facebookUrl is String ? facebookUrl : null,
      instagramUrl: instagramUrl is String ? instagramUrl : null,
      onlineOrderUrl: onlineOrderUrl is String ? onlineOrderUrl : null,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isGoogleListing: data['isGoogleListing'] ?? false,
      sourceProvider: data['sourceProvider']?.toString(),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
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
      'email': email,
      'ownerId': ownerId,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'onlineOrderUrl': onlineOrderUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isGoogleListing': isGoogleListing,
      'sourceProvider': sourceProvider,
    };
  }
}
