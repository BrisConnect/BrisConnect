import 'package:cloud_firestore/cloud_firestore.dart';

/// Business profile model for local business owners
class Business {
  final String? id; // Firestore document ID
  final String ownerId; // UID of the business owner
  final String businessName;
  final String category; // Predefined: Restaurant, Retail, Service, Entertainment, etc.
  final String description;
  final String address;
  final double? lat; // Latitude for map display
  final double? lng; // Longitude for map display
  final String contactNumber;
  final String? website;
  final Map<String, String>? socialMedia; // {platform: url} e.g., {'facebook': 'url', 'instagram': 'url'}
  final String? logoUrl; // Firebase Storage URL
  final String? coverImageUrl; // Firebase Storage URL
  final BusinessHours? businessHours; // Opening hours
  final List<String>? menuItems; // Menu/services list
  final List<String>? photos; // Additional photo URLs
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isVerified; // Admin verification status
  final int? rating; // Average rating (optional, for future reviews)
  final double buzzScore; // Computed engagement score (0-100)
  final bool isTrending; // True when buzzScore meets threshold
  final int viewCount; // Total profile views
  final int reviewCount; // Total reviews

  Business({
    this.id,
    required this.ownerId,
    required this.businessName,
    required this.category,
    required this.description,
    required this.address,
    this.lat,
    this.lng,
    required this.contactNumber,
    this.website,
    this.socialMedia,
    this.logoUrl,
    this.coverImageUrl,
    this.businessHours,
    this.menuItems,
    this.photos,
    this.createdAt,
    this.updatedAt,
    this.isVerified = false,
    this.rating,
    this.buzzScore = 0.0,
    this.isTrending = false,
    this.viewCount = 0,
    this.reviewCount = 0,
  });

  /// Convert Business to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'businessName': businessName,
      'category': category,
      'description': description,
      'address': address,
      'lat': lat,
      'lng': lng,
      'contactNumber': contactNumber,
      'website': website,
      'socialMedia': socialMedia,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'businessHours': businessHours?.toFirestore(),
      'menuItems': menuItems,
      'photos': photos,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'rating': rating,
      'buzzScore': buzzScore,
      'isTrending': isTrending,
      'viewCount': viewCount,
      'reviewCount': reviewCount,
    };
  }

  /// Create Business from Firestore document
  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Business(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      businessName: data['businessName'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      contactNumber: data['contactNumber'] ?? '',
      website: data['website'],
      socialMedia: Map<String, String>.from(data['socialMedia'] ?? {}),
      logoUrl: data['logoUrl'],
      coverImageUrl: data['coverImageUrl'],
      businessHours: data['businessHours'] != null
          ? BusinessHours.fromFirestore(data['businessHours'] as Map<String, dynamic>)
          : null,
      menuItems: data['menuItems'] != null
          ? List<String>.from(data['menuItems'] as List)
          : null,
      photos: data['photos'] != null
          ? List<String>.from(data['photos'] as List)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isVerified: data['isVerified'] ?? false,
      rating: data['rating'],
      buzzScore: (data['buzzScore'] as num?)?.toDouble() ?? 0.0,
      isTrending: data['isTrending'] ?? false,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Create a copy with modifications
  Business copyWith({
    String? id,
    String? ownerId,
    String? businessName,
    String? category,
    String? description,
    String? address,
    double? lat,
    double? lng,
    String? contactNumber,
    String? website,
    Map<String, String>? socialMedia,
    String? logoUrl,
    String? coverImageUrl,
    BusinessHours? businessHours,
    List<String>? menuItems,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    int? rating,
    double? buzzScore,
    bool? isTrending,
    int? viewCount,
    int? reviewCount,
  }) {
    return Business(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      businessName: businessName ?? this.businessName,
      category: category ?? this.category,
      description: description ?? this.description,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      contactNumber: contactNumber ?? this.contactNumber,
      website: website ?? this.website,
      socialMedia: socialMedia ?? this.socialMedia,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      businessHours: businessHours ?? this.businessHours,
      menuItems: menuItems ?? this.menuItems,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      buzzScore: buzzScore ?? this.buzzScore,
      isTrending: isTrending ?? this.isTrending,
      viewCount: viewCount ?? this.viewCount,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}

/// Business operating hours model
class BusinessHours {
  final Map<String, DayHours> hours; // {day: hours} e.g., {'Monday': DayHours(...)}

  BusinessHours({required this.hours});

  Map<String, dynamic> toFirestore() {
    return {
      for (var entry in hours.entries) entry.key: entry.value.toFirestore(),
    };
  }

  factory BusinessHours.fromFirestore(Map<String, dynamic> data) {
    final Map<String, DayHours> hours = {};
    data.forEach((day, hourData) {
      if (hourData is Map<String, dynamic>) {
        hours[day] = DayHours.fromFirestore(hourData);
      }
    });
    return BusinessHours(hours: hours);
  }

  /// Get hours for a specific day
  DayHours? getHoursForDay(String day) => hours[day];
}

/// Operating hours for a single day
class DayHours {
  final bool isClosed;
  final String? openTime; // HH:mm format (24-hour)
  final String? closeTime; // HH:mm format (24-hour)

  DayHours({
    this.isClosed = false,
    this.openTime,
    this.closeTime,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'isClosed': isClosed,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }

  factory DayHours.fromFirestore(Map<String, dynamic> data) {
    return DayHours(
      isClosed: data['isClosed'] ?? false,
      openTime: data['openTime'],
      closeTime: data['closeTime'],
    );
  }

  /// Format hours as readable string
  String getDisplayText() {
    if (isClosed) return 'Closed';
    return '$openTime - $closeTime';
  }
}

/// List of predefined business categories
const List<String> businessCategories = [
  'Restaurant & Cafe',
  'Retail & Shopping',
  'Entertainment & Events',
  'Health & Wellness',
  'Professional Services',
  'Education',
  'Accommodation',
  'Transportation',
  'Arts & Culture',
  'Sports & Recreation',
  'Other',
];

/// Predefined social media platforms
const List<String> socialMediaPlatforms = [
  'Facebook',
  'Instagram',
  'Twitter',
  'LinkedIn',
  'TikTok',
  'YouTube',
];
