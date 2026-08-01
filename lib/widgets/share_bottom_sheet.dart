import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/services/share/content_share_service.dart';
import 'package:brisconnect/services/share/social_story_service.dart';
import 'package:brisconnect/services/social_share_tracking_service.dart';

/// Shows a platform-specific share bottom sheet for any shareable content.
///
/// [type] determines the deep-link path. [id] is the Firestore document id.
/// [title], [description], [location] and [dateTime] are used to build the
/// share text. The rich preview shown by Facebook/Instagram/TikTok is
/// controlled by Open Graph meta tags on the generated web URL.
///
/// The bottom sheet offers two sections:
/// 1. Share to Story (Instagram / Facebook / TikTok) with optional media
///    picker so visitors can post pictures or videos to their stories.
/// 2. Share Link (Facebook feed, native share, copy link).
///
/// Visitors must have the target social app installed and be logged into it
/// to post to stories. The UI explains this requirement.
Future<void> showShareBottomSheet({
  required BuildContext context,
  required ShareContentType type,
  required String id,
  required String title,
  String? description,
  String? location,
  String? dateTime,
  String? businessId,
  String? businessName,
  String? imageUrl,
  ContentShareService? shareService,
  SocialStoryService? storyService,
  SocialShareTrackingService? trackingService,
}) async {
  final service = shareService ?? ContentShareService();
  final storySvc = storyService ?? SocialStoryService();
  final tracker = trackingService ?? SocialShareTrackingService();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1F2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          top: 12,
          right: 20,
          bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Share $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _subtitleForType(type),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share to Story',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareButton(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  color: const Color(0xFFE1306C),
                  badge: 'Story',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareToStory(
                      context: context,
                      storyService: storySvc,
                      platform: StoryPlatform.instagram,
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                      trackingService: tracker,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  badge: 'Story',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareToStory(
                      context: context,
                      storyService: storySvc,
                      platform: StoryPlatform.facebook,
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                      trackingService: tracker,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.music_note,
                  label: 'TikTok',
                  color: const Color(0xFF010101),
                  badge: 'Story',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareToStory(
                      context: context,
                      storyService: storySvc,
                      platform: StoryPlatform.tiktok,
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                      trackingService: tracker,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                kIsWeb
                    ? 'On the web, story sharing opens the platform site so you can log in and paste the copied link as a sticker.'
                    : 'Instagram and Facebook open directly with the image. TikTok uses your phone\'s share sheet — choose TikTok and paste the copied link.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Share Link',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareButton(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () {
                    Navigator.pop(ctx);
                    _share(
                      context: context,
                      service: service,
                      trackingService: tracker,
                      platform: 'facebook',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.share_rounded,
                  label: 'More',
                  color: const Color(0xFF7A8FA6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _share(
                      context: context,
                      service: service,
                      trackingService: tracker,
                      platform: 'native',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.copy,
                  label: 'Copy link',
                  color: const Color(0xFFFF7A1A),
                  onTap: () {
                    Navigator.pop(ctx);
                    _share(
                      context: context,
                      service: service,
                      trackingService: tracker,
                      platform: 'copy',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                      businessId: businessId,
                      businessName: businessName,
                      imageUrl: imageUrl,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _share(
                  context: context,
                  service: service,
                  trackingService: tracker,
                  platform: 'copy',
                  type: type,
                  id: id,
                  title: title,
                  description: description,
                  location: location,
                  dateTime: dateTime,
                  businessId: businessId,
                  businessName: businessName,
                  imageUrl: imageUrl,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2F3F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: Color(0xFFFF7A1A),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        service.buildShareUrl(type: type, id: id, slug: title),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Copy',
                      style: TextStyle(
                        color: Color(0xFFFF7A1A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _subtitleForType(ShareContentType type) {
  switch (type) {
    case ShareContentType.business:
      return 'Let your friends discover this business';
    case ShareContentType.event:
      return 'Spread the word about this event';
    case ShareContentType.food:
      return 'Recommend this food spot';
    case ShareContentType.stadium:
      return 'Share this venue';
    case ShareContentType.promotion:
      return 'Share this promotion with your friends';
  }
}

Future<void> _shareToStory({
  required BuildContext context,
  required SocialStoryService storyService,
  required StoryPlatform platform,
  required ShareContentType type,
  required String id,
  required String title,
  String? description,
  String? location,
  String? dateTime,
  String? businessId,
  String? businessName,
  String? imageUrl,
  SocialShareTrackingService? trackingService,
}) async {
  final result = await storyService.shareToStory(
    platform: platform,
    contentType: type,
    id: id,
    title: title,
    description: description,
    location: location,
    dateTime: dateTime,
    imageUrl: imageUrl,
    useMedia: true,
  );

  _recordShare(
    trackingService: trackingService,
    platform: SocialStoryService.platformLabel(platform).toLowerCase(),
    shareKind: 'story',
    type: type,
    id: id,
    title: title,
    description: description,
    businessId: businessId,
    businessName: businessName,
    imageUrl: imageUrl,
    shareUrl: ContentShareService().buildShareUrl(type: type, id: id, slug: title),
  );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final platformName = SocialStoryService.platformLabel(platform);

  switch (result) {
    case StoryShareResult.shared:
      messenger.showSnackBar(
        _buildSnackBar(
          'Opening $platformName… paste the copied link as a sticker if needed.',
          backgroundColor: _colorForPlatform(platform),
          durationSeconds: 4,
        ),
      );
    case StoryShareResult.copied:
      messenger.showSnackBar(
        _buildSnackBar(
          kIsWeb
              ? '$platformName web opened in a new tab. Link copied — log in and paste it as a story sticker.'
              : 'Link copied! Open $platformName and paste it into your story.',
          durationSeconds: 5,
        ),
      );
    case StoryShareResult.noMediaSelected:
      messenger.showSnackBar(
        _buildSnackBar(
          'No photo or video selected. Pick one to share to your $platformName story.',
          durationSeconds: 3,
        ),
      );
    case StoryShareResult.appNotInstalled:
      messenger.showSnackBar(
        _buildSnackBar(
          '$platformName is not installed. Please install it and log in to share to stories.',
          durationSeconds: 4,
        ),
      );
    case StoryShareResult.cancelled:
      messenger.showSnackBar(
        _buildSnackBar('$platformName share cancelled.'),
      );
    case StoryShareResult.failed:
      messenger.showSnackBar(
        _buildSnackBar(
          'Could not open $platformName. Link copied to clipboard so you can paste it manually.',
          durationSeconds: 4,
        ),
      );
  }
}

Color? _colorForPlatform(StoryPlatform platform) => switch (platform) {
      StoryPlatform.instagram => const Color(0xFFE1306C),
      StoryPlatform.facebook => const Color(0xFF1877F2),
      StoryPlatform.tiktok => const Color(0xFF010101),
    };

Future<void> _share({
  required BuildContext context,
  required ContentShareService service,
  required String platform,
  required ShareContentType type,
  required String id,
  required String title,
  String? description,
  String? location,
  String? dateTime,
  String? businessId,
  String? businessName,
  String? imageUrl,
  SocialShareTrackingService? trackingService,
}) async {
  final result = await service.shareToPlatform(
    platform: platform,
    type: type,
    id: id,
    title: title,
    description: description,
    location: location,
    dateTime: dateTime,
  );

  _recordShare(
    trackingService: trackingService,
    platform: platform,
    shareKind: platform == 'copy' ? 'copy_link' : 'link',
    type: type,
    id: id,
    title: title,
    description: description,
    businessId: businessId,
    businessName: businessName,
    imageUrl: imageUrl,
    shareUrl: service.buildShareUrl(type: type, id: id, slug: title),
  );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case ShareResult.copied:
      if (platform == 'tiktok') {
        messenger.showSnackBar(
          _buildSnackBar(
            'Link copied! Open TikTok and paste it in your bio or video description.',
            backgroundColor: const Color(0xFF010101),
            durationSeconds: 4,
          ),
        );
      } else {
        messenger.showSnackBar(
          _buildSnackBar('Link copied to clipboard!'),
        );
      }
    case ShareResult.shared:
      messenger.showSnackBar(
        _buildSnackBar('Shared to ${service.platformLabel(platform)}!'),
      );
    case ShareResult.timedOut:
      messenger.showSnackBar(
        _buildSnackBar(
          'Share took too long. Link copied to clipboard so you can paste it manually.',
          durationSeconds: 4,
        ),
      );
    case ShareResult.failed:
      messenger.showSnackBar(
        _buildSnackBar('Could not complete share. Try again.'),
      );
  }
}

void _recordShare({
  required SocialShareTrackingService? trackingService,
  required String platform,
  required String shareKind,
  required ShareContentType type,
  required String id,
  required String title,
  String? description,
  String? businessId,
  String? businessName,
  String? imageUrl,
  String? shareUrl,
}) {
  final effectiveBusinessId = businessId ?? id;
  trackingService?.recordShare(
    businessId: effectiveBusinessId,
    businessName: businessName,
    contentId: id,
    contentType: type,
    platform: platform,
    shareKind: shareKind,
    title: title,
    description: description,
    imageUrl: imageUrl,
    shareUrl: shareUrl,
  );
}

SnackBar _buildSnackBar(
  String message, {
  Color? backgroundColor,
  int durationSeconds = 2,
}) {
  return SnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: backgroundColor ?? Colors.green[700],
    duration: Duration(seconds: durationSeconds),
    behavior: SnackBarBehavior.floating,
  );
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
