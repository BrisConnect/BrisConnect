import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminAttractionItem {
  const AdminAttractionItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.category,
    this.webLink,
    this.imageUrl,
    this.approvalStatus,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String? category;
  final String? webLink;
  final String? imageUrl;
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
        ((data['description'] as String?) ?? 'No description available.').trim();

    final String? category = _normalizeOptional(data['category'] as String?);
    final String? webLink = _normalizeOptional(data['webLink'] as String?);
    final String? imageUrl = _normalizeOptional(data['imageUrl'] as String?);

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
      webLink: webLink,
      imageUrl: imageUrl,
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
}

class AdminAttractionService {
  AdminAttractionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    String? webLink,
    String? imageUrl,
  }) async {
    final docRef = _firestore.collection('attractions').doc();
    final now = FieldValue.serverTimestamp();

    await docRef.set({
      'name': name.trim(),
      'title': name.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'category': category?.trim(),
      'webLink': webLink?.trim(),
      'imageUrl': imageUrl?.trim(),
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
    String? webLink,
    String? imageUrl,
  }) async {
    final docRef = _firestore.collection('attractions').doc(attractionId);

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
        'webLink': webLink?.trim(),
        'imageUrl': imageUrl?.trim(),
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Attraction no longer exists.');
      }
      transaction.delete(docRef);
    });
  }
}
