import 'package:flutter/material.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/services/owner_notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Notification bell for the business-owner portal with a live unread badge.
class OwnerNotificationBell extends StatelessWidget {
  const OwnerNotificationBell({
    super.key,
    this.onTap,
    this.iconColor,
    this.badgeColor,
  });

  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final owner = LocalAuth.currentLocal;
    if (owner == null) {
      return IconButton(
        icon: Icon(Icons.notifications_outlined, color: iconColor),
        onPressed: onTap,
      );
    }

    return StreamBuilder<int>(
      stream: OwnerNotificationRepository(userEmail: owner.email)
          .watchUnreadCount(),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                color: iconColor,
              ),
              tooltip: 'Notifications',
              onPressed: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppPalette.ochre,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.background,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
