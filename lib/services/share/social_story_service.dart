import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;
import 'package:url_launcher/url_launcher.dart';

import 'content_share_service.dart';
import 'remote_media_helper.dart';
import '../../utils/image_download.dart';
import '../../utils/web_share_file.dart' as web_share;

const MethodChannel _socialStoryChannel =
    MethodChannel('com.brisconnect/social_story');

/// Supported social story platforms.
enum StoryPlatform { instagram, facebook, tiktok }

/// Result of a social story share attempt.
enum StoryShareResult {
  shared,
  copied,
  nativeShareFallback,
  cancelled,
  noMediaSelected,
  appNotInstalled,
  failed,
}

/// Service for sharing BrisConnect content to social media stories.
///
/// Cross-platform behaviour:
/// * Web: opens the best available web share target (Facebook Share Dialog,
///   generic platform site) and always copies the link so the visitor can
///   paste it as a story sticker.
/// * iOS: tries the native Instagram/Facebook story composer via the
///   `com.brisconnect/social_story` method channel, then falls back to the
///   native share sheet.
/// * Android: tries a direct `Intent` to the platform's story composer with
///   a `FileProvider` URI, then falls back to the native share sheet.
///
/// The link is always copied to the clipboard first, so even when the target
/// app does not open the user can still share manually.
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
  ///
  /// If [mediaFileParam] is provided, it is used directly on mobile (e.g. from
  /// the [StoryPreviewScreen]) and the picker/download steps are skipped. On
  /// web, pass the rendered image bytes via [mediaBytesParam] instead; mobile
  /// ignores [mediaBytesParam].
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
    File? mediaFileParam,
    Uint8List? mediaBytesParam,
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
      return _shareOnWeb(
        platform: platform,
        shareText: shareText,
        mediaBytes: mediaBytesParam,
      );
    }

    // Always copy the link first so the user can paste it even if the
    // platform composer fails to open.
    await _copyToClipboard(shareText);

    File? mediaFile = mediaFileParam;

    if (mediaFile == null || !await mediaFile.exists()) {
      // Prefer the provided remote image.
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        debugPrint('[SocialStoryService] downloading image: $imageUrl');
        mediaFile = await RemoteMediaHelper.downloadRemoteMedia(
          imageUrl,
          timeout: const Duration(seconds: 10),
        );
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
    }

    // No media: open the platform app/website with the copied link.
    if (mediaFile == null || !await mediaFile.exists()) {
      debugPrint('[SocialStoryService] no media, opening platform app');
      return _openPlatformApp(platform, fallback: shareText);
    }

    // Try the platform-specific direct story composer first.
    final directResult = await _shareImageToStory(
      platform: platform,
      mediaFile: mediaFile,
      link: url,
    );
    if (directResult == StoryShareResult.shared ||
        directResult == StoryShareResult.appNotInstalled) {
      return directResult;
    }

    // If direct Instagram/Facebook failed, or for TikTok which has no public
    // story composer, offer the native share sheet so the user can still post.
    debugPrint(
        '[SocialStoryService] direct composer unavailable, falling back to share sheet');
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(mediaFile.path)],
          text: shareText,
          subject: 'Check out $title on BrisConnect+',
        ),
      );
      debugPrint('[SocialStoryService] native share sheet completed');
      return StoryShareResult.nativeShareFallback;
    } catch (e, st) {
      debugPrint('[SocialStoryService] native share sheet error: $e\n$st');
      return StoryShareResult.copied;
    }
  }

  /// Opens the platform's story composer directly if a platform channel is
  /// available, otherwise falls back to the native share sheet.
  Future<StoryShareResult> _shareImageToStory({
    required StoryPlatform platform,
    required File mediaFile,
    required String link,
  }) async {
    // Instagram and Facebook have documented story composer APIs on mobile.
    if (platform == StoryPlatform.instagram ||
        platform == StoryPlatform.facebook) {
      if (!kIsWeb && Platform.isIOS) {
        final directResult = await _shareToMetaStoryDirect(
          platform: platform,
          mediaFile: mediaFile,
          link: link,
        );
        if (directResult == StoryShareResult.shared) {
          return StoryShareResult.shared;
        }
        if (directResult == StoryShareResult.appNotInstalled) {
          return StoryShareResult.appNotInstalled;
        }
        // Fall back to the native share sheet if the direct path fails.
      } else if (!kIsWeb && Platform.isAndroid) {
        final directResult = await _shareToMetaStoryDirectAndroid(
          platform: platform,
          mediaFile: mediaFile,
          link: link,
        );
        if (directResult == StoryShareResult.shared) {
          return StoryShareResult.shared;
        }
        if (directResult == StoryShareResult.appNotInstalled) {
          return StoryShareResult.appNotInstalled;
        }
        if (directResult == StoryShareResult.failed) {
          return StoryShareResult.nativeShareFallback;
        }
        // Fall back to the native share sheet if the direct path fails.
      }

      return StoryShareResult.nativeShareFallback;
    }

    // TikTok has no public third-party story composer. The best we can do is
    // offer the native share sheet so the user can choose TikTok (or any app),
    // while the link is already copied to the clipboard for pasting.
    if (platform == StoryPlatform.tiktok) {
      return StoryShareResult.failed;
    }

    return StoryShareResult.failed;
  }

  /// Directly opens the iOS Instagram or Facebook story composer with the
  /// provided image and optional link sticker URL via a platform channel.
  ///
  /// Requires the iOS `LSApplicationQueriesSchemes` entries for
  /// `instagram-stories` and `facebook-stories`, and a valid Facebook App ID.
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
      final ok = await _socialStoryChannel.invokeMethod<dynamic>(
        methodName,
        <String, dynamic>{
          'imageData': Uint8List.fromList(bytes),
          'link': link,
          'mimeType': _mimeTypeForFile(mediaFile.path),
        },
      );
      if (ok == true || ok == 'fallback') {
        debugPrint('[SocialStoryService] $platform direct share launched');
        return StoryShareResult.shared;
      }
    } on PlatformException catch (e) {
      debugPrint(
          '[SocialStoryService] $platform direct share error: ${e.code}: ${e.message}');
      if (e.code == 'APP_NOT_INSTALLED') {
        return StoryShareResult.appNotInstalled;
      }
    } catch (e, st) {
      debugPrint(
          '[SocialStoryService] $platform direct share unexpected error: $e\n$st');
    }
    return StoryShareResult.failed;
  }

  /// Web-specific story flow. On browsers that support the Web Share API
  /// with files (Chrome/Android, Safari/iOS, Edge), the generated image is
  /// shared directly so the user can pick Instagram/Facebook/TikTok. On
  /// unsupported browsers the image is downloaded and the platform site is
  /// opened so the user can upload/post it manually.
  Future<StoryShareResult> _shareOnWeb({
    required StoryPlatform platform,
    required String shareText,
    Uint8List? mediaBytes,
  }) async {
    await _copyToClipboard(shareText);

    final url = _extractUrl(shareText);
    final encodedUrl = Uri.encodeComponent(url);
    final encodedText =
        Uri.encodeComponent(shareText.split('\n\n').firstOrNull ?? shareText);

    // Prefer the browser's native file share when an image is available.
    final imageBytes = mediaBytes;
    if (imageBytes != null &&
        imageBytes.isNotEmpty &&
        web_share.webShareFilesSupported) {
      try {
        final shared = await web_share.shareFileOnWeb(
          bytes: imageBytes,
          filename: 'brisconnect_${platform.name.toLowerCase()}_story.png',
          title: 'Share to ${platformLabel(platform)}',
          text: shareText,
        );
        if (shared) return StoryShareResult.shared;
      } catch (e, st) {
        debugPrint('[SocialStoryService] Web Share API failed: $e\n$st');
      }
    }

    // Fallback: desktop and unsupported mobile browsers cannot share files
    // directly. Download the image and open the platform's web upload page so
    // the user can post it manually. Facebook additionally gets a Share Dialog
    // for the link, which at least gives a one-click feed post with a preview.
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final safeName = platform.name.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          );
      try {
        await downloadImage(
          imageBytes,
          'brisconnect_${safeName}_story.png',
        );
      } catch (e, st) {
        debugPrint('[SocialStoryService] Image download failed: $e\n$st');
      }
    }

    final webUrl = switch (platform) {
      StoryPlatform.instagram => 'https://www.instagram.com/',
      StoryPlatform.facebook =>
        'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedText',
      StoryPlatform.tiktok => 'https://www.tiktok.com/upload?lang=en',
    };

    try {
      await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
        webViewConfiguration:
            const WebViewConfiguration(enableJavaScript: true),
      );
    } catch (_) {
      // Ignore launcher errors; the link is already copied/downloaded.
    }

    return StoryShareResult.copied;
  }

  /// Returns true when the browser can share files directly (mobile browsers).
  bool get canShareFilesDirectly => kIsWeb && web_share.webShareFilesSupported;

  String _extractUrl(String shareText) {
    final lines = shareText.split('\n');
    for (final line in lines.reversed) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
    }
    return '';
  }

  /// Directly opens the Android Instagram or Facebook story composer via an
  /// `Intent` with a `FileProvider` content URI.
  ///
  /// Requires the `com.brisconnect.android` method channel to be implemented
  /// in `MainActivity` (or the platform channel can be added there).
  Future<StoryShareResult> _shareToMetaStoryDirectAndroid({
    required StoryPlatform platform,
    required File mediaFile,
    required String link,
  }) async {
    try {
      final bytes = await mediaFile.readAsBytes();
      final methodName = platform == StoryPlatform.instagram
          ? 'shareToInstagramStory'
          : 'shareToFacebookStory';
      final ok = await _socialStoryChannel.invokeMethod<dynamic>(
        methodName,
        <String, dynamic>{
          'imageData': Uint8List.fromList(bytes),
          'link': link,
          'mimeType': _mimeTypeForFile(mediaFile.path),
        },
      );
      if (ok == true || ok == 'fallback') {
        debugPrint(
            '[SocialStoryService] Android $platform direct share launched');
        return StoryShareResult.shared;
      }
    } on PlatformException catch (e) {
      debugPrint(
          '[SocialStoryService] Android $platform direct share error: ${e.code}: ${e.message}');
      if (e.code == 'APP_NOT_INSTALLED') {
        return StoryShareResult.appNotInstalled;
      }
    } catch (e, st) {
      debugPrint(
          '[SocialStoryService] Android $platform direct share unexpected error: $e\n$st');
    }
    return StoryShareResult.failed;
  }

  String _mimeTypeForFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return 'video/mp4';
    return 'image/jpeg';
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
