import 'package:flutter/material.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/screens/admin_notifications_screen.dart';
import 'package:brisconnect/services/admin_notification_service.dart';

/// Notification bell for the admin dashboard header.
///
/// Shows a real-time unread badge and opens the admin notifications screen
/// when tapped.
class AdminNotificationBell extends StatelessWidget {
  const AdminNotificationBell({super.key, this.adminEmail});

  final String? adminEmail;

  @override
  Widget build(BuildContext context) {
    final service = AdminNotificationService(adminEmail: adminEmail);

    return StreamBuilder<int>(
      stream: service.watchUnreadCount(),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AdminNeonTheme.textSecondary,
              ),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    height: 16,
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AdminNeonTheme.neonOrange,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminNeonTheme.headerBg, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminNotificationsScreen(adminEmail: adminEmail),
              ),
            );
          },
        );
      },
    );
  }
}
