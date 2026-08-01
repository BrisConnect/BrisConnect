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
  final int savedCount; // Total saves/favourites
  final int reviewCount; // Total reviews
  final Map<String, int> viewHistory; // Daily view counts keyed dd-mm-yyyy
  final Map<String, int> saveHistory; // Daily save counts keyed dd-mm-yyyy
  final bool isActive; // Admin can deactivate without deleting
  final DateTime? deletedAt; // Soft-delete timestamp
  final String? deletedBy; // Admin email that performed soft delete
  final String? duplicateOf; // Document ID of canonical business if flagged duplicate

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
    this.savedCount = 0,
    this.reviewCount = 0,
    this.viewHistory = const {},
    this.saveHistory = const {},
    this.isActive = true,
    this.deletedAt,
    this.deletedBy,
    this.duplicateOf,
  });

  /// Whether the listing has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Display status label for admin dashboards.
  String get statusLabel {
    if (isDeleted) return 'Archived';
    if (!isActive) return 'Inactive';
    if (isVerified) return 'Verified';
    return 'Pending';
  }

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
      'savedCount': savedCount,
      'reviewCount': reviewCount,
      'viewHistory': viewHistory,
      'saveHistory': saveHistory,
      'isActive': isActive,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'duplicateOf': duplicateOf,
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
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isVerified: data['isVerified'] ?? false,
      rating: (data['rating'] as num?)?.toInt(),
      buzzScore: (data['buzzScore'] as num?)?.toDouble() ?? 0.0,
      isTrending: data['isTrending'] ?? false,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      viewHistory: _parseHistory(data['viewHistory']),
      saveHistory: _parseHistory(data['saveHistory']),
      isActive: data['isActive'] ?? !(data['deletedAt'] != null),
      deletedAt: _parseTimestamp(data['deletedAt']),
      deletedBy: data['deletedBy'],
      duplicateOf: data['duplicateOf'],
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

  static Map<String, int> _parseHistory(dynamic value) {
    if (value is! Map) return const {};
    return value.map<String, int>(
      (key, val) => MapEntry(key.toString(), (val as num?)?.toInt() ?? 0),
    );
  }

  /// Create a [Business] from a [food_businesses] document.
  ///
  /// This is a compatibility shim: the visitor portal's discover feed and
  /// detail screens use the [food_businesses] collection, while the business
  /// owner portal and public share links use the canonical [businesses]
  /// collection. Tapping a promotion or activity feed card that points at a
  /// food business should still render a profile.
  factory Business.fromFoodBusinessDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return Business(id: doc.id, ownerId: '', businessName: '', category: '', description: '', address: '', contactNumber: '');
    }
    final name = (data['name'] ?? data['businessName'] ?? '').toString();
    final category = (data['category'] ?? 'Food').toString();
    final logoUrl = data['logoUrl'] ?? data['imageUrl'];
    final coverImageUrl = data['coverImageUrl'] ?? data['imageUrl'];
    final lat = (data['lat'] ?? data['latitude']) as num?;
    final lng = (data['lng'] ?? data['longitude']) as num?;
    final phone = data['phone'] ?? data['contactNumber'];
    final website = data['website'];
    final facebook = data['facebookUrl'] ?? data['facebook'];
    final instagram = data['instagramUrl'] ?? data['instagram'];
    final socialMedia = <String, String>{};
    if (facebook is String && facebook.isNotEmpty) socialMedia['facebook'] = facebook;
    if (instagram is String && instagram.isNotEmpty) socialMedia['instagram'] = instagram;
    final operatingHours = data['operatingHours'] ?? data['businessHours'];
    BusinessHours? businessHours;
    if (operatingHours is Map<String, dynamic>) {
      businessHours = BusinessHours.fromFirestore(operatingHours);
    } else if (operatingHours is String && operatingHours.isNotEmpty) {
      // Treat free-text hours as a single "Hours" entry.
      businessHours = BusinessHours(hours: {
        'Hours': DayHours(openTime: '', closeTime: operatingHours),
      });
    }
    final menuRaw = data['menu'];
    final menuItems = menuRaw is List
        ? menuRaw.whereType<String>().toList()
        : <String>[];
    final photoGalleryRaw = data['photoGallery'];
    final photos = photoGalleryRaw is List
        ? photoGalleryRaw.whereType<String>().toList()
        : <String>[];
    final createdAt = _parseTimestamp(data['createdAt']);
    final updatedAt = _parseTimestamp(data['updatedAt']);

    return Business(
      id: doc.id,
      ownerId: (data['ownerId'] ?? '').toString(),
      businessName: name,
      category: category,
      description: (data['description'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      lat: lat?.toDouble(),
      lng: lng?.toDouble(),
      contactNumber: (phone ?? '').toString(),
      website: website is String ? website : null,
      socialMedia: socialMedia.isEmpty ? null : socialMedia,
      logoUrl: logoUrl is String ? logoUrl : null,
      coverImageUrl: coverImageUrl is String ? coverImageUrl : null,
      businessHours: businessHours,
      menuItems: menuItems.isEmpty ? null : menuItems,
      photos: photos.isEmpty ? null : photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isVerified: data['isVerified'] ?? false,
      rating: (data['rating'] as num?)?.toInt(),
      buzzScore: (data['buzzScore'] as num?)?.toDouble() ?? 0.0,
      isTrending: data['isTrending'] ?? false,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      viewHistory: _parseHistory(data['viewHistory']),
      saveHistory: _parseHistory(data['saveHistory']),
      isActive: data['isActive'] ?? !(data['deletedAt'] != null),
      deletedAt: _parseTimestamp(data['deletedAt']),
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
    int? savedCount,
    int? reviewCount,
    Map<String, int>? viewHistory,
    Map<String, int>? saveHistory,
    bool? isActive,
    DateTime? deletedAt,
    String? deletedBy,
    String? duplicateOf,
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
      savedCount: savedCount ?? this.savedCount,
      reviewCount: reviewCount ?? this.reviewCount,
      viewHistory: viewHistory ?? this.viewHistory,
      saveHistory: saveHistory ?? this.saveHistory,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
      duplicateOf: duplicateOf,
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

/// List of predefined business categories (food / cuisine only).
const List<String> businessCategories = [
  'Italian',
  'Caribbean',
  'Mexican',
  'Chinese',
  'Indian',
  'Japanese',
  'Thai',
  'Mediterranean',
  'French',
  'American',
  'BBQ',
  'Seafood',
  'Vegan / Plant-Based',
  'Bakery & Cafe',
  'Desserts',
  'Coffee & Tea',
  'Fast Food',
  'Fine Dining',
  'Food Truck',
  'Other Food',
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
