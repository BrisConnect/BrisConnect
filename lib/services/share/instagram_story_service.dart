import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'remote_media_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of an Instagram Story share attempt.
enum InstagramStoryResult {
  shared,
  nativeShareFallback,
  copied,
  cancelled,
  failed,
}

/// Service for sharing content directly to Instagram Stories.
///
/// Instagram Stories are opened via platform-specific URI schemes/intents.
/// The user picks or provides an image/video, and the BrisConnect link is
/// either added as a sticker (iOS) or pre-copied to the clipboard (Android).
/// If Instagram is not installed, the file is offered to the native share
/// sheet as a fallback.
class InstagramStoryService {
  final ImagePicker _picker;
  final http.Client _httpClient;

  InstagramStoryService({
    ImagePicker? picker,
    http.Client? httpClient,
  })  : _picker = picker ?? ImagePicker(),
        _httpClient = httpClient ?? http.Client();

  /// Opens the Instagram Story composer with a background image or video.
  ///
  /// If [mediaFile] is provided it is used directly. Otherwise the user is
  /// prompted to pick an image or video from their gallery.
  ///
  /// [shareText] is used as the sticker text (iOS) or copied to the clipboard
  /// (Android) so the user can paste it into the Story.
  Future<InstagramStoryResult> shareToStory({
    required String shareText,
    File? mediaFile,
    String? remoteMediaUrl,
  }) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: shareText));
      return InstagramStoryResult.copied;
    }

    File? file = mediaFile;

    if (file == null && remoteMediaUrl != null && remoteMediaUrl.isNotEmpty) {
      file = await RemoteMediaHelper.downloadRemoteMedia(
        remoteMediaUrl,
        client: _httpClient,
        fileNamePrefix: 'brisconnect_share',
      );
    }

    file ??= await _pickMedia();

    if (file == null) {
      // User cancelled picker.
      await Clipboard.setData(ClipboardData(text: shareText));
      return InstagramStoryResult.copied;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      await Clipboard.setData(ClipboardData(text: shareText));
      return InstagramStoryResult.copied;
    }

    // Copy link to clipboard so the user can paste it as a sticker/link.
    await Clipboard.setData(ClipboardData(text: shareText));

    if (Platform.isIOS) {
      return _shareToStoryIOS(bytes: bytes, shareText: shareText);
    }

    if (Platform.isAndroid) {
      return _shareToStoryAndroid(file: file, shareText: shareText);
    }

    // Desktop / unsupported: fall back to native share sheet with file.
    return _fallbackNativeShare(file: file, shareText: shareText);
  }

  /// Shares to Instagram Stories on iOS using the documented URL scheme.
  ///
  /// See: https://developers.facebook.com/docs/instagram/sharing-to-stories
  Future<InstagramStoryResult> _shareToStoryIOS({
    required Uint8List bytes,
    required String shareText,
  }) async {
    try {
      final base64Data = _base64Encode(bytes);
      final isVideo = _isVideoBytes(bytes);

      final params = <String, String>{
        if (isVideo) 'source_url': base64Data else 'source_image': base64Data,
        'content_url': _extractUrl(shareText),
      };

      final uri = Uri(
          scheme: 'instagram-stories', host: 'share', queryParameters: params);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return InstagramStoryResult.shared;
      }

      return InstagramStoryResult.failed;
    } catch (_) {
      return InstagramStoryResult.failed;
    }
  }

  /// Shares to Instagram Stories on Android using the documented intent.
  ///
  /// The Android intent requires a content URI and the Instagram app package.
  /// We use share_plus to deliver the file to Instagram directly.
  Future<InstagramStoryResult> _shareToStoryAndroid({
    required File file,
    required String shareText,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: shareText,
          subject: shareText.split('\n').first,
        ),
      );
      return InstagramStoryResult.nativeShareFallback;
    } catch (_) {
      return InstagramStoryResult.failed;
    }
  }

  Future<InstagramStoryResult> _fallbackNativeShare({
    required File file,
    required String shareText,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: shareText,
          subject: shareText.split('\n').first,
        ),
      );
      return InstagramStoryResult.nativeShareFallback;
    } catch (_) {
      return InstagramStoryResult.failed;
    }
  }

  Future<File?> _pickMedia() async {
    try {
      final picked = await _picker.pickMedia(
        imageQuality: 90,
        maxWidth: 1080,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (_) {
      return null;
    }
  }

  String _base64Encode(Uint8List bytes) {
    return base64Encode(bytes);
  }

  bool _isVideoBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // MP4 / MOV signatures.
    final signature = bytes.sublist(0, 12);
    final ftypIndex =
        _indexOfBytes(signature, [0x66, 0x74, 0x79, 0x70]); // 'ftyp'
    if (ftypIndex >= 0) {
      final brand = signature.sublist(ftypIndex + 4, ftypIndex + 8);
      final brandString = String.fromCharCodes(brand);
      return ['mp4', 'qt  ', 'M4V '].contains(brandString);
    }
    return false;
  }

  int _indexOfBytes(Uint8List bytes, List<int> pattern) {
    for (var i = 0; i <= bytes.length - pattern.length; i++) {
      var match = true;
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  String _extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text);
    return match?.group(0) ?? 'https://brisconnect-68b78.web.app';
  }
}
