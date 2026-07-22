import 'content_share_service.dart';

/// Re-export so existing imports continue to work.
export 'content_share_service.dart' show ShareResult, ClipboardWriter;

/// Service for sharing a business profile to social platforms.
///
/// This is a thin wrapper around [ContentShareService] that keeps the
/// original business-specific API intact while centralising platform logic.
class BusinessShareService {
  final ContentShareService _contentService;

  BusinessShareService({ClipboardWriter? clipboardWriter})
      : _contentService = ContentShareService(clipboardWriter: clipboardWriter);

  /// Builds the public, read-only deep link URL for a business profile.
  String buildBusinessUrl(String businessId, String businessName) {
    return _contentService.buildShareUrl(
      type: ShareContentType.business,
      id: businessId,
      slug: businessName,
    );
  }

  /// Returns the human-readable platform label.
  String platformLabel(String platform) => _contentService.platformLabel(platform);

  /// Shares the business to the selected platform with a 2-second timeout.
  ///
  /// For Instagram and TikTok (which do not expose public share URLs), the
  /// link is copied to the clipboard and [ShareResult.copied] is returned.
  /// For Facebook and native share, the platform sheet/URL is launched.
  /// If the operation exceeds the timeout, [ShareResult.timedOut] is
  /// returned and the link is copied to the clipboard as a fallback.
  Future<ShareResult> shareToPlatform({
    required String platform,
    required String businessId,
    required String businessName,
  }) async {
    return _contentService.shareToPlatform(
      platform: platform,
      type: ShareContentType.business,
      id: businessId,
      title: businessName,
      description: 'Check out $businessName on BrisConnect+!',
    );
  }
}
