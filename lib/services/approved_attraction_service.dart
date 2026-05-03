import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/services/location_utilities.dart';

class ApprovedAttraction {
  const ApprovedAttraction({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.category,
    this.accessibilityDetails = const <String>[],
    this.webLink,
    this.imageUrl,
    this.audioUrl,
    this.aiNarration,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final double latitude;
  final double longitude;

  /// Raw category string from Firestore (e.g. "Cultural", "Historical", "Nature").
  /// Null when the document has no category field.
  final String? category;
  final List<String> accessibilityDetails;
  final String? webLink;
  final String? imageUrl;
  final String? audioUrl;
  final String? aiNarration;

  static ApprovedAttraction? fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    if (!_isApproved(data)) {
      return null;
    }

    final String name =
        ((data['name'] as String?) ?? (data['title'] as String?) ?? '').trim();
    if (name.isEmpty) {
      return null;
    }

    final double? latitude = _toDouble(
      data['latitude'] ?? data['lat'] ?? data['locationLat'],
    );
    final double? longitude = _toDouble(
      data['longitude'] ?? data['lng'] ?? data['locationLng'],
    );

    if (latitude == null || longitude == null) {
      return null;
    }

    final String location = ((data['location'] as String?) ??
            (data['address'] as String?) ??
            (data['suburb'] as String?) ??
            'Location not provided')
        .trim();

    final String description =
        ((data['description'] as String?) ?? 'No description available.')
            .trim();

    final String? rawCategory = (data['category'] as String?)?.trim();
    final String? category =
        (rawCategory != null && rawCategory.isNotEmpty) ? rawCategory : null;
    final String? rawWebLink = (data['webLink'] as String?)?.trim();
    final String? webLink =
        (rawWebLink != null && rawWebLink.isNotEmpty) ? rawWebLink : null;
    final String? rawImageUrl = (data['imageUrl'] as String?)?.trim();
    final String? imageUrl =
        (rawImageUrl != null && rawImageUrl.isNotEmpty) ? rawImageUrl : null;
    final String? rawAudioUrl = (data['audioUrl'] as String?)?.trim();
    final String? audioUrl =
        (rawAudioUrl != null && rawAudioUrl.isNotEmpty) ? rawAudioUrl : null;
    final String? rawAiNarration = (data['aiNarration'] as String?)?.trim();
    final String? aiNarration =
        (rawAiNarration != null && rawAiNarration.isNotEmpty) ? rawAiNarration : null;
    final List<String> accessibilityDetails = _toStringList(
      data['accessibilityDetails'] ??
          data['accessibility'] ??
          data['accessibilityFeatures'],
    );

    return ApprovedAttraction(
      id: doc.id,
      name: name,
      description: description,
      location: location,
      latitude: latitude,
      longitude: longitude,
      category: category,
      accessibilityDetails: accessibilityDetails,
      webLink: webLink,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      aiNarration: aiNarration,
    );
  }

  static bool _isApproved(Map<String, dynamic> data) {
    final approvalStatus = (data['approvalStatus'] as String?)?.toLowerCase();
    final status = (data['status'] as String?)?.toLowerCase();
    final reviewStatus = (data['reviewStatus'] as String?)?.toLowerCase();
    final bool isApprovedFlag = (data['isApproved'] as bool?) ?? false;

    return isApprovedFlag ||
        approvalStatus == 'approved' ||
        status == 'approved' ||
        reviewStatus == 'approved';
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static List<String> _toStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String>[value.trim()];
    }
    return const <String>[];
  }
}

class ApprovedAttractionService {
  ApprovedAttractionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<ApprovedAttraction>> watchApprovedAttractions() {
    return _firestore.collection('attractions').snapshots().map((snapshot) {
      final List<ApprovedAttraction> items = <ApprovedAttraction>[];

      for (final doc in snapshot.docs) {
        try {
          final item = ApprovedAttraction.fromDoc(doc);
          if (item != null) {
            items.add(item);
          }
        } catch (error) {
          debugPrint(
            '[ApprovedAttractionService] Skipping invalid attraction ${doc.id}: $error',
          );
        }
      }

      items
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  Future<List<ApprovedAttraction>> fetchApprovedAttractions() async {
    final snapshot = await _firestore.collection('attractions').get();
    final List<ApprovedAttraction> items = <ApprovedAttraction>[];

    for (final doc in snapshot.docs) {
      try {
        final item = ApprovedAttraction.fromDoc(doc);
        if (item != null) {
          items.add(item);
        }
      } catch (error) {
        debugPrint(
          '[ApprovedAttractionService] Skipping invalid attraction ${doc.id}: $error',
        );
      }
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  /// Filters attractions by radius from the specified location.
  ///
  /// Returns all attractions within [radiusKm] of the given [userLatitude]
  /// and [userLongitude].
  List<ApprovedAttraction> filterByRadius({
    required List<ApprovedAttraction> attractions,
    required double userLatitude,
    required double userLongitude,
    required int radiusKm,
  }) {
    return LocationUtilities.filterByRadius<ApprovedAttraction>(
      items: attractions,
      userLat: userLatitude,
      userLon: userLongitude,
      radiusKm: radiusKm,
      getLatitude: (attraction) => attraction.latitude,
      getLongitude: (attraction) => attraction.longitude,
    );
  }

  /// Watches approved attractions and filters by radius from the specified location.
  ///
  /// Combines watchApprovedAttractions with radius filtering for real-time
  /// updates of attractions within the specified radius.
  Stream<List<ApprovedAttraction>> watchApprovedAttractionsWithinRadius({
    required double userLatitude,
    required double userLongitude,
    required int radiusKm,
  }) {
    return watchApprovedAttractions().map((attractions) {
      return filterByRadius(
        attractions: attractions,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radiusKm: radiusKm,
      );
    });
  }
}
