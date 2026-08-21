import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Categories of map pins. Matches the original internal enum so the rest of
/// the app can keep filtering by the same semantic groups.
enum MapPinType {
  event,
  attraction,
  stadium,
  olympicVenue,
  culturalVenue,
  food,
}

/// Status that drives the colour of a business / food pin on the map.
enum MapPinStatus {
  closed,
  open,
  verified,
  popular,
  premium,
}

/// A single item rendered on the BrisConnect+ discovery map.
///
/// Implements [ClusterItem] so it can be fed directly to
/// [google_maps_cluster_manager_2] for clustering.
class MapPin with ClusterItem {
  MapPin({
    required this.id,
    required this.title,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.source,
    this.imageUrl,
    this.badge,
    this.description,
    this.price,
    this.rating,
    this.categories,
    this.phone,
    this.website,
    this.rawItem,
    this.isOpenNow,
    this.isClosingSoon,
    this.isVerified = false,
    this.isPopular = false,
    this.isPremium = false,
    this.crowdLevel,
    this.waitTime,
  });

  final String id;
  final String title;
  final String locationName;
  final double latitude;
  final double longitude;
  final MapPinType type;
  final String source;
  final String? imageUrl;
  final String? badge;
  final String? description;
  final String? price;
  final double? rating;
  final List<String>? categories;
  final String? phone;
  final String? website;
  final Map<String, dynamic>? rawItem;
  final bool? isOpenNow;
  final bool? isClosingSoon;
  final bool isVerified;
  final bool isPopular;
  final bool isPremium;
  final String? crowdLevel;
  final String? waitTime;

  /// [ClusterItem] expects a getter called [location].
  @override
  LatLng get location => LatLng(latitude, longitude);

  /// Unique key used for selection and deduplication.
  String get key => '$source:$id:${type.name}';

  MapPin copyWith({
    bool? isOpenNow,
    bool? isClosingSoon,
    bool? isVerified,
    bool? isPopular,
    bool? isPremium,
    String? crowdLevel,
    String? waitTime,
  }) {
    return MapPin(
      id: id,
      title: title,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      type: type,
      source: source,
      imageUrl: imageUrl,
      badge: badge,
      description: description,
      price: price,
      rating: rating,
      categories: categories,
      phone: phone,
      website: website,
      rawItem: rawItem,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      isClosingSoon: isClosingSoon ?? this.isClosingSoon,
      isVerified: isVerified ?? this.isVerified,
      isPopular: isPopular ?? this.isPopular,
      isPremium: isPremium ?? this.isPremium,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      waitTime: waitTime ?? this.waitTime,
    );
  }
}
