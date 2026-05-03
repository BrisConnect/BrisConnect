import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/utils/narration_builder.dart';

class AdminAttractionItem {
  const AdminAttractionItem({
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
    this.imageStoragePath,
    this.audioUrl,
    this.audioStoragePath,
    this.approvalStatus,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String? category;
  final List<String> accessibilityDetails;
  final String? webLink;
  final String? imageUrl;
  final String? imageStoragePath;
  final String? audioUrl;
  final String? audioStoragePath;
  final String? approvalStatus;

  bool get isApproved => (approvalStatus ?? '').toLowerCase() == 'approved';

  static AdminAttractionItem? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

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

    final String? category = _normalizeOptional(data['category'] as String?);
    final List<String> accessibilityDetails = _toStringList(
      data['accessibilityDetails'] ??
          data['accessibility'] ??
          data['accessibilityFeatures'],
    );
    final String? webLink = _normalizeOptional(data['webLink'] as String?);
    final String? imageUrl = _normalizeOptional(data['imageUrl'] as String?);
    final String? imageStoragePath =
        _normalizeOptional(data['imageStoragePath'] as String?);
    final String? audioUrl = _normalizeOptional(data['audioUrl'] as String?);
    final String? audioStoragePath =
        _normalizeOptional(data['audioStoragePath'] as String?);

    final String? approvalStatus = _normalizeOptional(
      (data['approvalStatus'] as String?) ??
          (data['status'] as String?) ??
          (data['reviewStatus'] as String?),
    );

    return AdminAttractionItem(
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
      imageStoragePath: imageStoragePath,
      audioUrl: audioUrl,
      audioStoragePath: audioStoragePath,
      approvalStatus: approvalStatus,
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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

class AdminAttractionService {
  AdminAttractionService(
      {FirebaseFirestore? firestore, FirebaseMediaService? mediaService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _mediaService = mediaService;

  final FirebaseFirestore _firestore;
  FirebaseMediaService? _mediaService;

  FirebaseMediaService get _effectiveMediaService =>
      _mediaService ??= FirebaseMediaService();

  Stream<List<AdminAttractionItem>> watchAllAttractions() {
    return _firestore.collection('attractions').snapshots().map((snapshot) {
      final List<AdminAttractionItem> items = <AdminAttractionItem>[];
      for (final doc in snapshot.docs) {
        try {
          final item = AdminAttractionItem.fromDoc(doc);
          if (item != null) {
            items.add(item);
          }
        } catch (error) {
          debugPrint(
            '[AdminAttractionService] Skipping invalid attraction ${doc.id}: $error',
          );
        }
      }

      items
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  Future<void> addAttraction({
    required String name,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
    String? category,
    List<String> accessibilityDetails = const <String>[],
    String? webLink,
    String? imageUrl,
    String? imageStoragePath,
    String? audioUrl,
    String? audioStoragePath,
  }) async {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"['']+"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final docRef = _firestore.collection('attractions').doc(slug);
    final now = FieldValue.serverTimestamp();

    final aiNarration = buildAttractionNarration(
      name: name.trim(),
      category: category?.trim() ?? '',
      description: description.trim(),
      location: location.trim(),
      webLink: webLink?.trim() ?? '',
    );

    await docRef.set({
      'name': name.trim(),
      'title': name.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'category': category?.trim(),
      'accessibilityDetails': accessibilityDetails
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      'webLink': webLink?.trim(),
      'imageUrl': imageUrl?.trim(),
      'imageStoragePath': imageStoragePath?.trim(),
      'audioUrl': audioUrl?.trim(),
      'audioStoragePath': audioStoragePath?.trim(),
      if (aiNarration.isNotEmpty) 'aiNarration': aiNarration,
      'approvalStatus': 'approved',
      'status': 'approved',
      'reviewStatus': 'approved',
      'isApproved': true,
      'updatedAt': now,
      'createdAt': now,
    });
  }

  Future<void> updateAttraction({
    required String attractionId,
    required String name,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
    String? category,
    List<String> accessibilityDetails = const <String>[],
    String? webLink,
    String? imageUrl,
    String? imageStoragePath,
    String? audioUrl,
    String? audioStoragePath,
  }) async {
    final docRef = _firestore.collection('attractions').doc(attractionId);

    final aiNarration = buildAttractionNarration(
      name: name.trim(),
      category: category?.trim() ?? '',
      description: description.trim(),
      location: location.trim(),
      webLink: webLink?.trim() ?? '',
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Attraction no longer exists.');
      }

      transaction.update(docRef, {
        'name': name.trim(),
        'title': name.trim(),
        'description': description.trim(),
        'location': location.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'category': category?.trim(),
        'accessibilityDetails': accessibilityDetails
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        'webLink': webLink?.trim(),
        'imageUrl': imageUrl?.trim(),
        'imageStoragePath': imageStoragePath?.trim(),
        'audioUrl': audioUrl?.trim(),
        'audioStoragePath': audioStoragePath?.trim(),
        if (aiNarration.isNotEmpty) 'aiNarration': aiNarration,
        'approvalStatus': 'approved',
        'status': 'approved',
        'reviewStatus': 'approved',
        'isApproved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteAttraction(String attractionId) async {
    final docRef = _firestore.collection('attractions').doc(attractionId);
    String? imageStoragePath;
    String? audioStoragePath;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Attraction no longer exists.');
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      imageStoragePath = (data['imageStoragePath'] as String?)?.trim();
      audioStoragePath = (data['audioStoragePath'] as String?)?.trim();
      transaction.delete(docRef);
    });

    if (imageStoragePath != null && imageStoragePath!.isNotEmpty) {
      await _effectiveMediaService.deleteMedia(imageStoragePath);
    }
    if (audioStoragePath != null && audioStoragePath!.isNotEmpty) {
      await _effectiveMediaService.deleteMedia(audioStoragePath);
    }
  }
}
