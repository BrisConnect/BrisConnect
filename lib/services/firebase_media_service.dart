
import 'package:flutter/foundation.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoredMediaFile {
  const StoredMediaFile({
    required this.downloadUrl,
    required this.storagePath,
    required this.contentType,
  });

  final String downloadUrl;
  final String storagePath;
  final String contentType;
}

abstract class MediaStorageDriver {
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> delete(String path);
}

class FirebaseStorageDriver implements MediaStorageDriver {
  FirebaseStorageDriver({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    debugPrint('[StorageUpload] bucket=${_storage.bucket} path=$path size=${bytes.length}');
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    final url = await task.ref.getDownloadURL();
    debugPrint('[StorageUpload] success url=$url');
    return url;
  }

  @override
  Future<void> delete(String path) async {
    if (path.trim().isEmpty) {
      return;
    }
    await _storage.ref(path.trim()).delete();
  }
}

class FirebaseMediaService {
  FirebaseMediaService({MediaStorageDriver? driver})
      : _driver = driver ?? FirebaseStorageDriver();

  static const Duration operationTimeout = Duration(seconds: 30);
  static const int maxEventImageBytes = 2 * 1024 * 1024;
  static const int maxAudioBytes = 8 * 1024 * 1024;
  static const int maxEventVideoBytes = 50 * 1024 * 1024;
  static const Set<String> _supportedVideoExtensions = <String>{
    'mp4',
    'mov',
    'avi',
  };
  static const Set<String> _supportedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
  };
  static const Set<String> _supportedAudioExtensions = <String>{
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
  };

  final MediaStorageDriver _driver;

  static bool isSupportedVideoFileName(String fileName) {
    final extension = _extensionOf(fileName);
    return _supportedVideoExtensions.contains(extension);
  }

  static bool isSupportedAudioFileName(String fileName) {
    final extension = _extensionOf(fileName);
    return _supportedAudioExtensions.contains(extension);
  }

  static bool isSupportedImageFileName(String fileName) {
    final extension = _extensionOf(fileName);
    return _supportedImageExtensions.contains(extension);
  }

  static String inferImageExtension(Uint8List bytes, {String? fileName}) {
    final namedExtension = _extensionOf(fileName ?? '');
    if (_supportedImageExtensions.contains(namedExtension)) {
      return namedExtension == 'jpeg' ? 'jpg' : namedExtension;
    }
    if (ProfileImageUtils.isLikelyPng(bytes)) {
      return 'png';
    }
    return 'jpg';
  }

  Future<StoredMediaFile> uploadProfileImage({
    required String role,
    required String email,
    required Uint8List bytes,
    required String fileName,
    String? previousStoragePath,
  }) async {
    if (!ProfileImageUtils.isSupportedImage(bytes)) {
      throw const FormatException('Only JPG and PNG images are supported.');
    }
    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      throw const FormatException('Profile image is too large.');
    }

    final ext = inferImageExtension(bytes, fileName: fileName);
    final path =
        'profile-images/${_slugify(role)}/${_slugify(email)}/avatar.$ext';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    return _uploadAndReplace(
      path: path,
      bytes: bytes,
      contentType: contentType,
      previousStoragePath: previousStoragePath,
    );
  }

  Future<StoredMediaFile> uploadEventImage({
    required String eventId,
    required String ownerEmail,
    required Uint8List bytes,
    required String fileName,
    String? previousStoragePath,
  }) async {
    if (!ProfileImageUtils.isSupportedImage(bytes) ||
        !isSupportedImageFileName(fileName)) {
      throw const FormatException(
          'Only JPG and PNG event images are supported.');
    }
    if (bytes.length > maxEventImageBytes) {
      throw const FormatException('Event image is too large.');
    }

    final ext = inferImageExtension(bytes, fileName: fileName);
    final path =
        'event-images/${_slugify(ownerEmail)}/${_slugify(eventId)}/hero.$ext';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    return _uploadAndReplace(
      path: path,
      bytes: bytes,
      contentType: contentType,
      previousStoragePath: previousStoragePath,
    );
  }

  Future<StoredMediaFile> uploadAttractionAudio({
    required String attractionId,
    required Uint8List bytes,
    required String fileName,
    String? previousStoragePath,
  }) async {
    if (!isSupportedAudioFileName(fileName)) {
      throw const FormatException(
          'Only MP3, WAV, M4A, AAC, and OGG audio files are supported.');
    }
    if (bytes.length > maxAudioBytes) {
      throw const FormatException('Audio file is too large.');
    }

    final ext = _extensionOf(fileName);
    final path = 'attraction-media/${_slugify(attractionId)}/audio-guide.$ext';
    final contentType = _audioContentType(ext);
    return _uploadAndReplace(
      path: path,
      bytes: bytes,
      contentType: contentType,
      previousStoragePath: previousStoragePath,
    );
  }

  Future<StoredMediaFile> uploadEventAudio({
    required String eventId,
    required String ownerEmail,
    required Uint8List bytes,
    required String fileName,
    String? previousStoragePath,
  }) async {
    if (!isSupportedAudioFileName(fileName)) {
      throw const FormatException(
          'Only MP3, WAV, M4A, AAC, and OGG audio files are supported.');
    }
    if (bytes.length > maxAudioBytes) {
      throw const FormatException('Audio file is too large (max 8 MB).');
    }

    final ext = _extensionOf(fileName);
    final path =
        'event-audio/${_slugify(ownerEmail)}/${_slugify(eventId)}/audio.$ext';
    final contentType = _audioContentType(ext);
    return _uploadAndReplace(
      path: path,
      bytes: bytes,
      contentType: contentType,
      previousStoragePath: previousStoragePath,
    );
  }

  Future<StoredMediaFile> uploadEventVideo({
    required String eventId,
    required String ownerEmail,
    required Uint8List bytes,
    required String fileName,
    String? previousStoragePath,
  }) async {
    if (!isSupportedVideoFileName(fileName)) {
      throw const FormatException(
          'Only MP4, MOV, and AVI video files are supported.');
    }
    if (bytes.length > maxEventVideoBytes) {
      throw const FormatException('Video file is too large (max 50 MB).');
    }

    final ext = _extensionOf(fileName);
    final path =
        'event-videos/${_slugify(ownerEmail)}/${_slugify(eventId)}/video.$ext';
    final contentType = switch (ext) {
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      _ => 'video/mp4',
    };
    return _uploadAndReplace(
      path: path,
      bytes: bytes,
      contentType: contentType,
      previousStoragePath: previousStoragePath,
    );
  }

  Future<void> deleteMedia(String? storagePath) async {
    final normalized = storagePath?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    await _driver.delete(normalized).timeout(operationTimeout);
  }

  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    return _driver
        .uploadBytes(path: path, bytes: bytes, contentType: contentType)
        .timeout(operationTimeout);
  }

  Future<StoredMediaFile> _uploadAndReplace({
    required String path,
    required Uint8List bytes,
    required String contentType,
    String? previousStoragePath,
  }) async {
    final url = await _driver
        .uploadBytes(path: path, bytes: bytes, contentType: contentType)
        .timeout(operationTimeout);

    final previous = previousStoragePath?.trim() ?? '';
    if (previous.isNotEmpty && previous != path) {
      try {
        await _driver.delete(previous).timeout(operationTimeout);
      } catch (_) {
        // Storage cleanup failure should not block the new media link.
      }
    }

    return StoredMediaFile(
      downloadUrl: url,
      storagePath: path,
      contentType: contentType,
    );
  }

  static String _slugify(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9.@_-]+'), '-');
  }

  static String _extensionOf(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    if (dot == -1 || dot == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dot + 1);
  }

  static String _audioContentType(String ext) {
    switch (ext) {
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'mp3':
      default:
        return 'audio/mpeg';
    }
  }
}
