import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/admin_notification_record.dart';
import 'package:brisconnect/services/admin_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/role_guard.dart';

/// Admin notifications panel.
///
/// Lists platform notifications newest first, distinguishes unread items, and
/// supports marking individual or all notifications as read. Tapping a
/// notification with an action route navigates to the relevant admin screen.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key, this.adminEmail});

  final String? adminEmail;

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  late final AdminNotificationService _service;

  @override
  void initState() {
    super.initState();
    _service = AdminNotificationService(adminEmail: widget.adminEmail);
  }

  Future<void> _markAllAsRead() async {
    final count = await _service.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No unread notifications'
              : 'Marked $count notification${count == 1 ? '' : 's'} as read',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openRoute(AdminNotificationRecord notification) {
    final route = notification.actionRoute;
    if (route == null || route.isEmpty) return;

    if (!mounted) return;

    // Map old routes to correct admin routes
    final finalRoute = _normalizeRoute(route);
    if (finalRoute.isEmpty) return;

    // Build arguments based on route type
    final arguments = _buildArguments(finalRoute, notification);

    Navigator.of(context)
        .pushNamed(finalRoute, arguments: arguments)
        .catchError((error) {
      debugPrint('[AdminNotifications] Navigation error for route $finalRoute: $error');
      return null;
    });
  }

  /// Normalize and validate admin routes to match defined navigation
  String _normalizeRoute(String route) {
    // Already a valid registered admin route - keep as-is (checked first so
    // e.g. '/admin/reported-events' isn't clobbered by the 'report' keyword
    // fallback below, since it contains that substring too).
    const validRoutes = {
      '/admin/dashboard',
      '/admin/google-listings',
      '/admin/businesses',
      '/admin/notifications',
      '/admin/reports',
      '/admin/reported-events',
      '/admin/reported-reviews',
      '/admin/subscriptions',
      '/admin/promotions',
      '/admin/users',
      '/admin/community',
    };
    if (validRoutes.contains(route)) return route;

    // Map legacy/non-existent routes to the closest matching admin screen.
    if (route.contains('crowd')) {
      return '/admin/reports';
    }
    if (route.contains('event')) {
      return '/admin/reported-events';
    }
    if (route.contains('review')) {
      return '/admin/reported-reviews';
    }
    if (route.contains('report')) {
      return '/admin/reports';
    }
    if (route.contains('verification') || route.contains('business')) {
      return '/admin/businesses';
    }
    if (route.startsWith('/admin/')) {
      return route;
    }
    return '';
  }

  /// Build arguments based on route destination
  Object? _buildArguments(String route, AdminNotificationRecord notification) {
    switch (route) {
      case '/admin/notifications':
        return null;
      case '/admin/reports':
        return <String, dynamic>{
          'relatedItemId': notification.relatedItemId,
          'relatedItemType': notification.relatedItemType,
          'notificationType': notification.type.name,
        };
      case '/admin/businesses':
        return <String, dynamic>{
          'businessId': notification.relatedItemId,
        };
      case '/admin/subscriptions':
      case '/admin/users':
      case '/admin/promotions':
      case '/admin/reported-events':
      case '/admin/reported-reviews':
        return <String, dynamic>{
          'notificationId': notification.id,
          'relatedItemId': notification.relatedItemId,
          'relatedItemType': notification.relatedItemType,
        };
      default:
        return null;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFEBF4FF),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppPalette.ochre,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<AdminNotificationRecord>>(
        stream: _service.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre),
            );
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: AppPalette.mutedText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                formattedTime: _formatTime(notification.createdAt),
                onTap: () {
                  _openRoute(notification);
                  // Clear it from the list once acted on, instead of leaving
                  // it sitting there marked read.
                  _service.deleteNotification(notification.id);
                },
              );
            },
          );
        },
      ),
    );

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      child: screen,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.formattedTime,
    required this.onTap,
  });

  final AdminNotificationRecord notification;
  final String formattedTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: notification.read ? Colors.white : AppPalette.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: notification.read
              ? AppPalette.border.withValues(alpha: 0.5)
              : AppPalette.ochre.withValues(alpha: 0.35),
          width: notification.read ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.type.icon,
                  color: AppPalette.ochre,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppPalette.charcoal,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppPalette.ochre,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppPalette.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          notification.type.displayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ochre,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppPalette.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
