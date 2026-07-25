import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/models/visitor_photo.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';

/// Service for visitor-contributed photos of food businesses and events.
///
/// The service enforces:
///   - Authentication (a signed-in visitor is required).
///   - Supported image formats: JPG, PNG, WebP.
///   - Maximum file size: 5 MB.
///   - One target per photo (business OR event).
///   - Captions limited to 200 characters.
class VisitorPhotoService {
  VisitorPhotoService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMediaService? mediaService,
    ImagePicker? imagePicker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _mediaService = mediaService ?? FirebaseMediaService(),
        _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMediaService _mediaService;
  final ImagePicker _imagePicker;

  static const int maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxCaptionLength = 200;
  static const Set<String> _supportedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  CollectionReference<Map<String, dynamic>> get _photosCollection =>
      _firestore.collection('visitor_photos');

  String? get _currentVisitorId => _auth.currentUser?.uid;

  String get _currentVisitorEmail =>
      (_auth.currentUser?.email ?? 'unknown').toLowerCase();

  /// Pick an image from the gallery and return its bytes and name.
  ///
  /// Returns `null` if the user cancels. Throws [FormatException] for
  /// unsupported formats or oversized files.
  Future<PickedImage?> pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final mimeType = _inferMimeType(bytes, fileName: picked.name);

    _validateImage(bytes, mimeType: mimeType, fileName: picked.name);

    return PickedImage(
      bytes: bytes,
      fileName: picked.name,
      mimeType: mimeType,
    );
  }

  /// Upload a visitor photo for either a business or an event.
  ///
  /// Exactly one of [businessId] or [eventId] must be provided.
  Future<VisitorPhoto> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? businessId,
    String? eventId,
    String? caption,
    String visitorName = 'Anonymous',
  }) async {
    _validateTarget(businessId: businessId, eventId: eventId);
    _validateImage(bytes, mimeType: mimeType, fileName: fileName);
    _validateCaption(caption);

    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) {
      throw Exception('You must be signed in as a Visitor to upload photos.');
    }

    final ext = _extensionFor(mimeType);
    final targetId = (businessId ?? eventId)!;
    final targetType = businessId != null ? 'business' : 'event';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'visitor_photos/$_currentVisitorEmail/$targetType/$targetId/$timestamp.$ext';

    final imageUrl = await _mediaService.uploadBytes(
      path: path,
      bytes: bytes,
      contentType: mimeType,
    );

    final createdAt = DateTime.now();
    final docRef = await _photosCollection.add({
      if (businessId != null) 'businessId': businessId,
      if (eventId != null) 'eventId': eventId,
      'visitorId': visitorId,
      'visitorName':
          visitorName.trim().isEmpty ? 'Anonymous' : visitorName.trim(),
      'imageUrl': imageUrl,
      'storagePath': path,
      'mimeType': mimeType,
      'fileSize': bytes.length,
      'caption': caption?.trim(),
      'status': 'pending',
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': null,
    });

    final doc = await docRef.get();
    return VisitorPhoto.fromFirestore(doc);
  }

  /// Stream approved photos for a business.
  Stream<List<VisitorPhoto>> getApprovedPhotosForBusiness(String businessId) {
    return _photosCollection
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VisitorPhoto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream approved photos for an event.
  Stream<List<VisitorPhoto>> getApprovedPhotosForEvent(String eventId) {
    return _photosCollection
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VisitorPhoto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream photos uploaded by the current visitor (any status).
  Stream<List<VisitorPhoto>> getMyPhotos({String? visitorId}) {
    final effectiveVisitorId = visitorId ?? _currentVisitorId;
    if (effectiveVisitorId == null || effectiveVisitorId.isEmpty) {
      return Stream.value(<VisitorPhoto>[]);
    }
    return _photosCollection
        .where('visitorId', isEqualTo: effectiveVisitorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VisitorPhoto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Approve a visitor photo. Intended for admin moderation.
  Future<void> approvePhoto(String photoId) async {
    await _photosCollection.doc(photoId).update({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a visitor photo. Intended for admin moderation.
  Future<void> rejectPhoto(String photoId) async {
    await _photosCollection.doc(photoId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a photo. Only the original author or an admin may delete.
  Future<void> deletePhoto(String photoId, {String? visitorId}) async {
    final doc = await _photosCollection.doc(photoId).get();
    if (!doc.exists) {
      throw Exception('Photo not found');
    }
    final photo = VisitorPhoto.fromFirestore(doc);

    final effectiveVisitorId = visitorId ?? _currentVisitorId;
    final isAuthor = photo.visitorId == effectiveVisitorId;
    final isAdmin = await _isCurrentUserAdmin();

    if (!isAuthor && !isAdmin) {
      throw Exception('You can only delete your own photos.');
    }

    await _mediaService.deleteMedia(photo.storagePath);
    await _photosCollection.doc(photoId).delete();
  }

  void _validateTarget({String? businessId, String? eventId}) {
    final hasBusiness = businessId != null && businessId.isNotEmpty;
    final hasEvent = eventId != null && eventId.isNotEmpty;
    if (hasBusiness == hasEvent) {
      throw Exception('Provide either a businessId or an eventId, not both.');
    }
  }

  void _validateImage(Uint8List bytes,
      {required String mimeType, String? fileName}) {
    if (bytes.isEmpty) {
      throw const FormatException('Image is empty.');
    }
    if (bytes.length > maxPhotoBytes) {
      throw const FormatException('Photo must be 5 MB or smaller.');
    }
    if (!_supportedMimeTypes.contains(mimeType)) {
      throw FormatException(
          'Unsupported image format: $mimeType. Use JPG, PNG or WebP.');
    }
    if (!ProfileImageUtils.isSupportedImage(bytes) && !_isWebP(bytes)) {
      throw const FormatException('File does not look like a supported image.');
    }
  }

  void _validateCaption(String? caption) {
    if (caption != null && caption.trim().length > maxCaptionLength) {
      throw Exception('Caption must be $maxCaptionLength characters or less.');
    }
  }

  String _inferMimeType(Uint8List bytes, {String? fileName}) {
    if (ProfileImageUtils.isLikelyPng(bytes)) return 'image/png';
    if (_isWebP(bytes)) return 'image/webp';
    if (ProfileImageUtils.isLikelyJpeg(bytes)) return 'image/jpeg';

    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  bool _isWebP(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  String _extensionFor(String mimeType) {
    return switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  Future<bool> _isCurrentUserAdmin() async {
    try {
      final email = _auth.currentUser?.email;
      if (email == null || email.isEmpty) return false;
      final doc =
          await _firestore.collection('admins').doc(email.toLowerCase()).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[VisitorPhotoService] admin check failed: $e');
      return false;
    }
  }
}

/// Simple wrapper for a picked image and its metadata.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}
