import 'package:flutter/material.dart';
import 'package:brisconnect/services/share/content_share_service.dart';

/// Shows a platform-specific share bottom sheet for any shareable content.
///
/// [type] determines the deep-link path. [id] is the Firestore document id.
/// [title], [description], [location] and [dateTime] are used to build the
/// share text. The rich preview shown by Facebook/Instagram/TikTok is
/// controlled by Open Graph meta tags on the generated web URL.
Future<void> showShareBottomSheet({
  required BuildContext context,
  required ShareContentType type,
  required String id,
  required String title,
  String? description,
  String? location,
  String? dateTime,
  ContentShareService? shareService,
}) async {
  final service = shareService ?? ContentShareService();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1F2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share $title',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _subtitleForType(type),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
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
                      platform: 'facebook',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  color: const Color(0xFFE1306C),
                  badge: 'Copy link',
                  onTap: () {
                    Navigator.pop(ctx);
                    _share(
                      context: context,
                      service: service,
                      platform: 'instagram',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
                    );
                  },
                ),
                _ShareButton(
                  icon: Icons.music_note,
                  label: 'TikTok',
                  color: const Color(0xFF010101),
                  badge: 'Copy link',
                  onTap: () {
                    Navigator.pop(ctx);
                    _share(
                      context: context,
                      service: service,
                      platform: 'tiktok',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
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
                      platform: 'native',
                      type: type,
                      id: id,
                      title: title,
                      description: description,
                      location: location,
                      dateTime: dateTime,
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
                  platform: 'copy',
                  type: type,
                  id: id,
                  title: title,
                  description: description,
                  location: location,
                  dateTime: dateTime,
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
  }
}

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

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case ShareResult.copied:
      if (platform == 'instagram') {
        messenger.showSnackBar(
          _buildSnackBar(
            'Link copied! Open Instagram and paste it in your Story, Post caption, or DM.',
            backgroundColor: const Color(0xFFE1306C),
            durationSeconds: 4,
          ),
        );
      } else if (platform == 'tiktok') {
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
