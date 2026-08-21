import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Prompt card shown at the top of the community feed that encourages
/// visitors to create content.
///
/// Provides taps for Write Review and Add Photo.
class ActivityFeedCreatePostCard extends StatelessWidget {
  final VoidCallback onWriteReview;
  final VoidCallback onAddPhoto;

  const ActivityFeedCreatePostCard({
    super.key,
    required this.onWriteReview,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final visitor = VisitorAuth.currentVisitor;
    final avatarUrl = visitor?.profileImageUrl;
    final firstName = visitor?.name.split(' ').first ?? 'Guest';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), AppPalette.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppPalette.ochre.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildAvatar(imageUrl: avatarUrl, fallback: firstName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onWriteReview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppPalette.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'Share a recommendation, $firstName...',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _CreatePostAction(
                icon: Icons.rate_review_rounded,
                label: 'Write Review',
                color: AppPalette.deepBlue,
                onTap: onWriteReview,
              ),
              _CreatePostAction(
                icon: Icons.add_photo_alternate_rounded,
                label: 'Add Photo',
                color: const Color(0xFF10B981),
                onTap: onAddPhoto,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String? imageUrl,
    required String fallback,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surfaceAlt,
        border: Border.all(color: AppPalette.border, width: 1),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackAvatar(fallback, size),
              )
            : _fallbackAvatar(fallback, size),
      ),
    );
  }

  Widget _fallbackAvatar(String fallback, double size) {
    return Center(
      child: Text(
        fallback.isNotEmpty ? fallback[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppPalette.ochre,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

class _CreatePostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CreatePostAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
