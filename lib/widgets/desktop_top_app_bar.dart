import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/responsive_utils.dart';

/// A desktop-friendly top app bar that combines branding, a global search
/// field, and a profile chip.
///
/// On mobile-sized screens this widget renders an empty [SizedBox] so it does
/// not collide with the mobile app bars / hero sections. It is intended to be
/// placed at the top of a desktop layout, above the main content area.
class DesktopTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopTopAppBar({
    super.key,
    this.title = 'BrisConnect+',
    this.subtitle,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Search...',
    this.onFilterTap,
    this.onProfileTap,
    this.profileImage,
    this.userName,
    this.userEmail,
    this.profileBadge,
    this.backgroundColor = AppPalette.surface,
  });

  final String title;
  final String? subtitle;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? searchHint;
  final VoidCallback? onFilterTap;
  final VoidCallback? onProfileTap;
  final ImageProvider? profileImage;
  final String? userName;
  final String? userEmail;
  final Widget? profileBadge;
  final Color backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    // Only render on desktop layouts.
    if (ResponsiveUtils.isMobile(context)) return const SizedBox.shrink();

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: AppPalette.border.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand
          ClipOval(
            child: Container(
              width: 44,
              height: 44,
              color: Colors.white.withValues(alpha: 0.1),
              child: Image.asset(
                'assets/Brisconnect New.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoal,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 32),

          // Global search
          Expanded(
            child: _buildSearchField(context),
          ),

          const SizedBox(width: 24),

          // Profile chip
          _buildProfileChip(context),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppPalette.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppPalette.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: AppPalette.mutedText),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: AppPalette.charcoal),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: searchHint,
                hintStyle: TextStyle(
                  color: AppPalette.mutedText,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onFilterTap != null)
            GestureDetector(
              onTap: onFilterTap,
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppPalette.border.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppPalette.mutedText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileChip(BuildContext context) {
    final initials = (userName ?? userEmail ?? 'U')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join('')
        .toUpperCase();

    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppPalette.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppPalette.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppPalette.ochre,
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Text(
                      initials.isEmpty ? 'U' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName ?? 'User',
                  style: const TextStyle(
                    color: AppPalette.charcoal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (userEmail != null && userEmail!.isNotEmpty)
                  Text(
                    userEmail!,
                    style: const TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            if (profileBadge != null) ...[
              const SizedBox(width: 8),
              profileBadge!,
            ],
          ],
        ),
      ),
    );
  }
}
