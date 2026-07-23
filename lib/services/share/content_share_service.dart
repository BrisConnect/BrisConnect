import 'dart:async';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of a share attempt.
enum ShareResult {
  shared,
  copied,
  timedOut,
  failed,
}

/// Function signature for clipboard writes.
typedef ClipboardWriter = Future<void> Function(String text);

/// Shareable content types.
enum ShareContentType { business, event, food, stadium }

/// Service for sharing businesses, events, food spots, and venues to social
/// platforms and other apps.
///
/// The service is intentionally pragmatic: Facebook has a public web sharer,
/// while Instagram and TikTok do not expose public share URLs from Flutter.
/// For Instagram/TikTok the link and formatted text are copied to the
/// clipboard so the user can paste them into the native app.
///
/// Rich previews on Facebook/Instagram/TikTok rely on Open Graph meta tags
/// served by the web landing page for the shared URL. This service builds
/// the same canonical URLs that those crawlers will fetch.
class ContentShareService {
  static const Duration shareTimeout = Duration(seconds: 5);
  static const String _baseUrl = 'https://brisconnect-68b78.web.app';

  final ClipboardWriter _clipboardWriter;

  ContentShareService({ClipboardWriter? clipboardWriter})
      : _clipboardWriter = clipboardWriter ?? _defaultClipboardWriter;

  static Future<void> _defaultClipboardWriter(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Builds a public, read-only deep link URL for the given content.
  String buildShareUrl({
    required ShareContentType type,
    required String id,
    String? slug,
  }) {
    final path = switch (type) {
      ShareContentType.business => 'business',
      ShareContentType.event => 'event',
      ShareContentType.food => 'food',
      ShareContentType.stadium => 'venue',
    };
    final encodedSlug = slug != null && slug.trim().isNotEmpty
        ? '?name=${Uri.encodeComponent(slug.trim())}'
        : '';
    return '$_baseUrl/$path/$id$encodedSlug';
  }

  /// Returns the human-readable platform label.
  String platformLabel(String platform) {
    switch (platform) {
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'native':
        return 'another app';
      case 'copy':
        return 'clipboard';
      default:
        return platform;
    }
  }

  /// Builds a plain-text share body with title, description, and URL.
  String buildShareText({
    required String title,
    required String url,
    String? description,
    String? location,
    String? dateTime,
  }) {
    final lines = <String>[
      title,
      if (dateTime != null && dateTime.trim().isNotEmpty) dateTime.trim(),
      if (location != null && location.trim().isNotEmpty) location.trim(),
      if (description != null && description.trim().isNotEmpty)
        description.trim(),
      url,
    ];
    return lines.join('\n\n');
  }

  /// Shares content to the selected platform with a 2-second timeout.
  ///
  /// [description], [location], and [dateTime] are included in the share text
  /// but are not required. The rich preview that Facebook/Instagram/TikTok
  /// show for the link is determined by Open Graph tags on the web landing
  /// page at the generated URL.
  Future<ShareResult> shareToPlatform({
    required String platform,
    required ShareContentType type,
    required String id,
    required String title,
    String? description,
    String? location,
    String? dateTime,
  }) async {
    final url = buildShareUrl(type: type, id: id, slug: title);
    final shareText = buildShareText(
      title: title,
      url: url,
      description: description,
      location: location,
      dateTime: dateTime,
    );

    Future<ShareResult> operation() async {
      // Always copy first so the user has a fallback even if the native
      // share sheet or launcher fails.
      await _clipboardWriter(shareText);

      switch (platform) {
        case 'facebook':
          final fbUrl =
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';
          try {
            if (await canLaunchUrl(Uri.parse(fbUrl))) {
              await launchUrl(
                Uri.parse(fbUrl),
                mode: LaunchMode.externalApplication,
              );
              return ShareResult.shared;
            }
          } catch (_) {
            // Fall through to native share if launcher fails.
          }
          try {
            await SharePlus.instance.share(ShareParams(text: shareText));
            return ShareResult.shared;
          } catch (_) {
            return ShareResult.copied;
          }
        case 'instagram':
          // Instagram does not expose a public share URL. On mobile the best
          // UX is to present the native share sheet so the user can pick the
          // Instagram app (Story/Post/DM) if it accepts the content, with the
          // link already copied to the clipboard as a reliable fallback.
          try {
            await SharePlus.instance.share(
              ShareParams(
                text: shareText,
                subject: 'Check out $title on BrisConnect+',
              ),
            );
            return ShareResult.shared;
          } catch (_) {
            // The native share sheet may fail when Instagram is selected or
            // when running under certain iOS conditions. The link is already
            // on the clipboard, so report success with the copy fallback.
            return ShareResult.copied;
          }
        case 'tiktok':
          return ShareResult.copied;
        case 'native':
          try {
            await SharePlus.instance.share(
              ShareParams(
                text: shareText,
                subject: 'Check out $title on BrisConnect+',
              ),
            );
            return ShareResult.shared;
          } catch (_) {
            return ShareResult.copied;
          }
        case 'copy':
          return ShareResult.copied;
        default:
          return ShareResult.copied;
      }
    }

    try {
      return await operation().timeout(shareTimeout, onTimeout: () async {
        // Fallback: copy link so the user can still share manually.
        await _clipboardWriter(shareText);
        return ShareResult.timedOut;
      });
    } catch (_) {
      // Last resort: try to copy the link even if everything else failed.
      try {
        await _clipboardWriter(shareText);
        return ShareResult.copied;
      } catch (_) {
        return ShareResult.failed;
      }
    }
  }
}
