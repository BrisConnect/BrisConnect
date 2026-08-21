import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/visitor_notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Notification bell for the visitor portal with a live unread badge.
class VisitorNotificationBell extends StatelessWidget {
  const VisitorNotificationBell({
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
    final visitor = VisitorAuth.currentVisitor;
    if (visitor == null) {
      return IconButton(
        icon: Icon(Icons.notifications_outlined, color: iconColor, size: 36),
        iconSize: 36,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onTap,
      );
    }

    return StreamBuilder<int>(
      stream: VisitorNotificationRepository(userEmail: visitor.email)
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
                size: 36,
              ),
              iconSize: 36,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Notifications',
              onPressed: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppPalette.ochre,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.background,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
