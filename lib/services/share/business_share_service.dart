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

/// Service for sharing a business profile to social platforms.
class BusinessShareService {
  static const Duration shareTimeout = Duration(seconds: 2);

  final ClipboardWriter _clipboardWriter;

  BusinessShareService({ClipboardWriter? clipboardWriter})
      : _clipboardWriter = clipboardWriter ?? _defaultClipboardWriter;

  static Future<void> _defaultClipboardWriter(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Builds the public, read-only deep link URL for a business profile.
  String buildBusinessUrl(String businessId, String businessName) {
    final encoded = Uri.encodeComponent(businessName);
    return 'https://www.brisconnect.com.au/business/$businessId?name=$encoded';
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
      default:
        return platform;
    }
  }

  /// Shares the business to the selected platform with a 2-second timeout.
  ///
  /// For Instagram and TikTok (which do not expose public share URLs), the
  /// link is copied to the clipboard and [ShareResult.copied] is returned.
  /// For Facebook and native share, the platform sheet/URL is launched.
  /// If the operation exceeds [shareTimeout], [ShareResult.timedOut] is
  /// returned and the link is copied to the clipboard as a fallback.
  Future<ShareResult> shareToPlatform({
    required String platform,
    required String businessId,
    required String businessName,
  }) async {
    final url = buildBusinessUrl(businessId, businessName);

    Future<ShareResult> operation() async {
      switch (platform) {
        case 'facebook':
          final fbUrl =
              'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';
          if (await canLaunchUrl(Uri.parse(fbUrl))) {
            await launchUrl(
              Uri.parse(fbUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            await SharePlus.instance.share(ShareParams(text: _shareText(businessName, url)));
          }
          return ShareResult.shared;
        case 'instagram':
        case 'tiktok':
          await _clipboardWriter(url);
          return ShareResult.copied;
        case 'native':
          await SharePlus.instance.share(
            ShareParams(
              text: _shareText(businessName, url),
              subject: 'Check out $businessName on BrisConnect+',
            ),
          );
          return ShareResult.shared;
        case 'copy':
          await _clipboardWriter(url);
          return ShareResult.copied;
        default:
          await _clipboardWriter(url);
          return ShareResult.copied;
      }
    }

    try {
      return await operation().timeout(shareTimeout, onTimeout: () async {
        // Fallback: copy link so the user can still share manually.
        await _clipboardWriter(url);
        return ShareResult.timedOut;
      });
    } catch (_) {
      return ShareResult.failed;
    }
  }

  String _shareText(String businessName, String url) {
    return 'Check out $businessName on BrisConnect+! $url';
  }
}
