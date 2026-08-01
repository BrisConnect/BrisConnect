import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;
import 'package:url_launcher/url_launcher.dart';

import 'content_share_service.dart';

const MethodChannel _socialStoryChannel = MethodChannel('com.brisconnect/social_story');

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

/// Service for sharing BrisConnect content to social media stories.
///
/// Instagram, Facebook and TikTok do not expose reliable public APIs for
/// posting directly to stories from Flutter without a Facebook App ID and
/// native SDK integrations. This service uses the dependable cross-platform
/// path: open the device's native share sheet with the content image attached,
/// copy the BrisConnect link to the clipboard, and let the user pick
/// Instagram/Facebook/TikTok and paste the link as a story sticker.
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
  /// If [imageUrl] is provided, that image is downloaded and used as the story
  /// background. On mobile the user can also pick their own media when
  /// [useMedia] is true and no [imageUrl] is supplied. The link and text are
  /// always copied to the clipboard as a fallback.
  Future<StoryShareResult> shareToStory({
    required StoryPlatform platform,
    required ShareContentType contentType,
    required String id,
    required String title,
    String? description,
    String? location,
    String? dateTime,
    String? imageUrl,
    bool useMedia = true,
  }) async {
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

    if (kIsWeb) {
      return _shareOnWeb(platform: platform, shareText: shareText);
    }

    // Always copy the link first so the user can paste it even if the
    // platform composer fails to open.
    await _copyToClipboard(shareText);

    File? mediaFile;

    // Prefer the provided remote image.
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      debugPrint('[SocialStoryService] downloading image: $imageUrl');
      mediaFile = await _downloadRemoteMedia(imageUrl);
      debugPrint('[SocialStoryService] downloaded file: ${mediaFile?.path}');
    }

    // Otherwise let the user pick media if requested.
    if (mediaFile == null && useMedia) {
      debugPrint('[SocialStoryService] showing media picker');
      final picked = await _pickMedia();
      if (picked != null) {
        mediaFile = File(picked.path);
        debugPrint('[SocialStoryService] picked file: ${mediaFile.path}');
      }
    }

    // No media: open the platform app/website with the copied link.
    if (mediaFile == null || !await mediaFile.exists()) {
      debugPrint('[SocialStoryService] no media, opening platform app');
      return _openPlatformApp(platform, fallback: shareText);
    }

    // On iOS, try to open Instagram's or Facebook's story composer directly
    // with the image pre-populated using the Facebook App ID.
    if (Platform.isIOS &&
        (platform == StoryPlatform.instagram || platform == StoryPlatform.facebook)) {
      final directResult = await _shareToMetaStoryDirect(
        platform: platform,
        mediaFile: mediaFile,
        link: url,
      );
      if (directResult == StoryShareResult.shared) {
        return StoryShareResult.shared;
      }
      // Fall back to the native share sheet if the direct path fails.
    }

    // Primary fallback: native share sheet with the image attached.
    // The user picks Instagram/Facebook/TikTok from the sheet. The link is
    // already copied for sticker pasting. This is the most reliable approach
    // for Facebook/TikTok because direct story composer APIs require platform
    // SDKs and a Facebook App ID that BrisConnect does not currently have.
    debugPrint('[SocialStoryService] opening native share sheet');
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(mediaFile.path)],
          text: shareText,
          subject: 'Check out $title on BrisConnect+',
        ),
      );
      debugPrint('[SocialStoryService] native share sheet completed');
      return StoryShareResult.shared;
    } catch (e, st) {
      debugPrint('[SocialStoryService] native share sheet error: $e\n$st');
      return StoryShareResult.copied;
    }
  }

  /// Directly opens the iOS Instagram or Facebook story composer with the
  /// provided image and optional link sticker URL via a platform channel.
  Future<StoryShareResult> _shareToMetaStoryDirect({
    required StoryPlatform platform,
    required File mediaFile,
    required String link,
  }) async {
    try {
      final bytes = await mediaFile.readAsBytes();
      final methodName = platform == StoryPlatform.instagram
          ? 'shareToInstagramStory'
          : 'shareToFacebookStory';
      final ok = await _socialStoryChannel.invokeMethod<bool>(
        methodName,
        <String, dynamic>{
          'imageData': Uint8List.fromList(bytes),
          'link': link,
        },
      );
      if (ok == true) {
        debugPrint('[SocialStoryService] $platform direct share launched');
        return StoryShareResult.shared;
      }
    } on PlatformException catch (e) {
      debugPrint('[SocialStoryService] $platform direct share error: ${e.code}: ${e.message}');
      if (e.code == 'APP_NOT_INSTALLED') {
        return StoryShareResult.appNotInstalled;
      }
    } catch (e, st) {
      debugPrint('[SocialStoryService] $platform direct share unexpected error: $e\n$st');
    }
    return StoryShareResult.failed;
  }

  /// Web-specific story flow. Copies the link and opens the platform's web
  /// app so the visitor can log in and paste the link as a sticker.
  Future<StoryShareResult> _shareOnWeb({
    required StoryPlatform platform,
    required String shareText,
  }) async {
    await _copyToClipboard(shareText);

    final webUrl = switch (platform) {
      StoryPlatform.instagram => 'https://www.instagram.com/',
      StoryPlatform.facebook => 'https://www.facebook.com/',
      StoryPlatform.tiktok => 'https://www.tiktok.com/',
    };

    try {
      await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );
    } catch (_) {
      // Ignore launcher errors; the link is already copied.
    }

    return StoryShareResult.copied;
  }

  /// Tries to open the target platform app directly. If that fails, the link
  /// is already on the clipboard.
  Future<StoryShareResult> _openPlatformApp(
    StoryPlatform platform, {
    required String fallback,
  }) async {
    final scheme = switch (platform) {
      StoryPlatform.instagram => 'instagram://',
      StoryPlatform.facebook => 'fb://',
      StoryPlatform.tiktok => 'tiktok://',
    };

    try {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return StoryShareResult.shared;
      }
    } catch (_) {
      // Ignore and fall back to copied link.
    }

    return StoryShareResult.copied;
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

  /// Downloads remote media to a temporary file.
  Future<File?> _downloadRemoteMedia(String imageUrl) async {
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
        return file;
      }
    } catch (_) {
      // Fall through to picker/fallback.
    }
    return null;
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      // Ignore clipboard errors.
    }
  }

  /// Human-readable platform label.
  static String platformLabel(StoryPlatform platform) => switch (platform) {
        StoryPlatform.instagram => 'Instagram',
        StoryPlatform.facebook => 'Facebook',
        StoryPlatform.tiktok => 'TikTok',
      };
}
