import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;
import 'package:url_launcher/url_launcher.dart';

import 'content_share_service.dart';

/// Supported social story platforms.
enum StoryPlatform { instagram, facebook, tiktok }

/// Result of a social story share attempt.
enum StoryShareResult {
  shared,
  copied,
  cancelled,
  noMediaSelected,
  appNotInstalled,
  failed,
}

/// Service for sharing BrisConnect content directly to social media stories.
///
/// The service supports picking an image or video from the gallery and then
/// handing it off to the selected platform. On iOS it attempts to open the
/// native story composer (Instagram/Facebook) via URL schemes for the best
/// experience. On Android and as a fallback it uses the native share sheet so
/// the visitor can choose the app where they are already logged in.
///
/// Visitors must have the target social app installed and be logged into it
/// before they can post a picture or video to their story. The UI is expected
/// to explain this requirement before calling the service.
class SocialStoryService {
  final ImagePicker _imagePicker;
  final ContentShareService _contentShareService;

  SocialStoryService({
    ImagePicker? imagePicker,
    ContentShareService? contentShareService,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _contentShareService = contentShareService ?? ContentShareService();

  /// Shares the given [title]/[url] to the selected [platform]'s story flow.
  ///
  /// If [useMedia] is true, the user is prompted to pick an image or video.
  /// The media is then attached to the share so it can be posted as a story.
  /// When no media is selected the share falls back to copying the link/text
  /// to the clipboard and opening the platform (if a public flow exists).
  Future<StoryShareResult> shareToStory({
    required StoryPlatform platform,
    required ShareContentType contentType,
    required String id,
    required String title,
    String? description,
    String? location,
    String? dateTime,
    bool useMedia = true,
  }) async {
    if (kIsWeb) {
      // Web cannot access native story composers; fall back to link sharing.
      return _shareLinkOnly(
        platform: platform,
        contentType: contentType,
        id: id,
        title: title,
        description: description,
        location: location,
        dateTime: dateTime,
      );
    }

    if (useMedia) {
      final picked = await _pickMedia();
      if (picked == null) return StoryShareResult.noMediaSelected;

      final mediaFile = File(picked.path);
      if (!await mediaFile.exists()) return StoryShareResult.failed;

      final url = _contentShareService.buildShareUrl(
        type: contentType,
        id: id,
        slug: title,
      );
      final shareText = _contentShareService.buildShareText(
        title: title,
        url: url,
        description: description,
        location: location,
        dateTime: dateTime,
      );

      // Attempt platform-specific story composer first.
      final directResult = await _tryDirectStoryShare(
        platform: platform,
        mediaFile: mediaFile,
        shareText: shareText,
      );

      if (directResult != null) {
        // Copy the link as a fallback even if the direct share was attempted.
        await _copyToClipboard(shareText);
        return directResult;
      }

      // Fall back to the native share sheet with the media attached.
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(mediaFile.path)],
            text: shareText,
            subject: 'Check out $title on BrisConnect+',
          ),
        );
        return StoryShareResult.shared;
      } catch (_) {
        await _copyToClipboard(shareText);
        return StoryShareResult.copied;
      }
    }

    return _shareLinkOnly(
      platform: platform,
      contentType: contentType,
      id: id,
      title: title,
      description: description,
      location: location,
      dateTime: dateTime,
    );
  }

  /// Shares using only the link/text (no media picker).
  Future<StoryShareResult> _shareLinkOnly({
    required StoryPlatform platform,
    required ShareContentType contentType,
    required String id,
    required String title,
    String? description,
    String? location,
    String? dateTime,
  }) async {
    final result = await _contentShareService.shareToPlatform(
      platform: _platformName(platform),
      type: contentType,
      id: id,
      title: title,
      description: description,
      location: location,
      dateTime: dateTime,
    );
    return switch (result) {
      ShareResult.shared => StoryShareResult.shared,
      ShareResult.copied => StoryShareResult.copied,
      ShareResult.timedOut => StoryShareResult.failed,
      ShareResult.failed => StoryShareResult.failed,
    };
  }

  /// Picks an image or video from the device gallery.
  Future<XFile?> _pickMedia() async {
    try {
      return await _imagePicker.pickMedia(
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Attempts a platform-specific direct story share.
  ///
  /// Returns null when no direct flow is available and the caller should fall
  /// back to the native share sheet.
  Future<StoryShareResult?> _tryDirectStoryShare({
    required StoryPlatform platform,
    required File mediaFile,
    required String shareText,
  }) async {
    if (Platform.isIOS) {
      return await _shareToStoryIOS(
        platform: platform,
        mediaFile: mediaFile,
        shareText: shareText,
      );
    }
    // Android direct story composers require the platform SDKs. Use the
    // native share sheet fallback instead.
    return null;
  }

  /// iOS direct story share using documented URL schemes.
  Future<StoryShareResult?> _shareToStoryIOS({
    required StoryPlatform platform,
    required File mediaFile,
    required String shareText,
  }) async {
    final bytes = await mediaFile.readAsBytes();
    if (bytes.isEmpty) return StoryShareResult.failed;

    final ext = mediaFile.path.split('.').lastOrNull?.toLowerCase() ?? '';
    final isVideo = const {'mp4', 'mov', 'm4v'}.contains(ext);

    switch (platform) {
      case StoryPlatform.instagram:
        return await _shareToInstagramStoriesIOS(bytes: bytes, isVideo: isVideo);
      case StoryPlatform.facebook:
        return await _shareToFacebookStoriesIOS(
          bytes: bytes,
          isVideo: isVideo,
          shareText: shareText,
        );
      case StoryPlatform.tiktok:
        // TikTok does not expose a public iOS story URL scheme.
        return null;
    }
  }

  /// Opens Instagram Stories on iOS with the picked media.
  ///
  /// See https://developers.facebook.com/docs/instagram/sharing-to-stories/
  Future<StoryShareResult> _shareToInstagramStoriesIOS({
    required Uint8List bytes,
    required bool isVideo,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'brisconnect_ig_story_${DateTime.now().millisecondsSinceEpoch}.${isVideo ? 'mp4' : 'jpg'}';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final pasteboard = <String, dynamic>{
      'com.instagram.sharedSticker.stickerImage': isVideo ? null : file.path,
      if (isVideo) 'com.instagram.sharedSticker.backgroundVideo': file.path,
    };

    // Remove null entries so JSON encoding is clean.
    pasteboard.removeWhere((_, value) => value == null);

    final encoded = Uri.encodeComponent(jsonEncode(pasteboard));
    final scheme = 'instagram-stories://share?source_application=com.brisconnect&data=$encoded';

    try {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return StoryShareResult.shared;
      }
      return StoryShareResult.appNotInstalled;
    } catch (_) {
      return StoryShareResult.failed;
    }
  }

  /// Opens Facebook Stories on iOS with the picked media.
  ///
  /// Facebook stories URL scheme is undocumented but widely used. If it is
  /// unavailable we fall back to the native share sheet.
  Future<StoryShareResult> _shareToFacebookStoriesIOS({
    required Uint8List bytes,
    required bool isVideo,
    required String shareText,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'brisconnect_fb_story_${DateTime.now().millisecondsSinceEpoch}.${isVideo ? 'mp4' : 'jpg'}';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    // Facebook expects asset identifiers via the pasteboard. Build a JSON
    // payload similar to Instagram's documented format.
    final pasteboard = <String, dynamic>{
      'com.facebook.sharedSticker.backgroundImage': isVideo ? null : file.path,
      if (isVideo) 'com.facebook.sharedSticker.backgroundVideo': file.path,
      'com.facebook.sharedSticker.appID': 'brisconnect',
    };
    pasteboard.removeWhere((_, value) => value == null);

    final encoded = Uri.encodeComponent(jsonEncode(pasteboard));
    final scheme = 'facebook-stories://share?source_application=com.brisconnect&data=$encoded';

    try {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return StoryShareResult.shared;
      }
      return StoryShareResult.appNotInstalled;
    } catch (_) {
      return StoryShareResult.failed;
    }
  }

  /// Convenience helper to share a remote image URL as a story.
  ///
  /// Downloads the image at [imageUrl] to a temporary file, then shares it.
  /// If the download fails the link is still shared via the native sheet.
  Future<StoryShareResult> shareRemoteImage({
    required StoryPlatform platform,
    required ShareContentType contentType,
    required String id,
    required String title,
    required String imageUrl,
    String? description,
    String? location,
    String? dateTime,
  }) async {
    if (kIsWeb) {
      return _shareLinkOnly(
        platform: platform,
        contentType: contentType,
        id: id,
        title: title,
        description: description,
        location: location,
        dateTime: dateTime,
      );
    }

    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final ext = imageUrl.split('.').lastOrNull ?? 'jpg';
        final fileName =
            'brisconnect_remote_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes, flush: true);

        final url = _contentShareService.buildShareUrl(
          type: contentType,
          id: id,
          slug: title,
        );
        final shareText = _contentShareService.buildShareText(
          title: title,
          url: url,
          description: description,
          location: location,
          dateTime: dateTime,
        );

        final directResult = await _tryDirectStoryShare(
          platform: platform,
          mediaFile: file,
          shareText: shareText,
        );
        if (directResult != null) {
          await _copyToClipboard(shareText);
          return directResult;
        }

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: shareText,
            subject: 'Check out $title on BrisConnect+',
          ),
        );
        return StoryShareResult.shared;
      }
    } catch (_) {
      // Fall through to link-only share.
    }

    return _shareLinkOnly(
      platform: platform,
      contentType: contentType,
      id: id,
      title: title,
      description: description,
      location: location,
      dateTime: dateTime,
    );
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // Ignore clipboard errors.
    }
  }

  String _platformName(StoryPlatform platform) => switch (platform) {
        StoryPlatform.instagram => 'instagram',
        StoryPlatform.facebook => 'facebook',
        StoryPlatform.tiktok => 'tiktok',
      };

  /// Human-readable platform label.
  static String platformLabel(StoryPlatform platform) => switch (platform) {
        StoryPlatform.instagram => 'Instagram',
        StoryPlatform.facebook => 'Facebook',
        StoryPlatform.tiktok => 'TikTok',
      };
}
