import 'package:flutter/material.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/visitor_notification_record.dart';
import 'package:brisconnect/services/visitor_notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

/// Visitor notification centre for business and promotion push alerts.
///
/// Lists notifications newest first, supports mark read / mark all read /
/// delete, and navigates to the relevant business or promotion detail.
class VisitorPushNotificationsScreen extends StatefulWidget {
  const VisitorPushNotificationsScreen({
    super.key,
    this.repositoryOverride,
    this.notificationsStreamOverride,
    this.visitorOverride,
  });

  final VisitorNotificationRepository? repositoryOverride;
  final Stream<List<VisitorNotificationRecord>>? notificationsStreamOverride;
  final VisitorUser? visitorOverride;

  @override
  State<VisitorPushNotificationsScreen> createState() =>
      _VisitorPushNotificationsScreenState();
}

class _VisitorPushNotificationsScreenState
    extends State<VisitorPushNotificationsScreen> {
  VisitorNotificationRepository? _repo;

  VisitorNotificationRepository get _effectiveRepo {
    return _repo ??= widget.repositoryOverride ??
        VisitorNotificationRepository(
          userEmail: widget.visitorOverride?.email ??
              VisitorAuth.currentVisitor?.email ??
              '',
        );
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repositoryOverride;
  }

  Future<void> _markAllAsRead() async {
    if (widget.notificationsStreamOverride != null &&
        widget.repositoryOverride == null) {
      return;
    }
    await _effectiveRepo.markAllAsRead();
  }

  Future<void> _delete(VisitorNotificationRecord record) async {
    if (widget.notificationsStreamOverride != null &&
        widget.repositoryOverride == null) {
      return;
    }
    await _effectiveRepo.deleteNotification(record.id);
  }

  void _openDetail(VisitorNotificationRecord record) {
    final route = record.actionRoute;
    final relatedId = record.relatedItemId;

    if (route == null || route.isEmpty) {
      _delete(record);
      return;
    }

    if (!mounted) return;

    // Build arguments based on route type
    final arguments = _buildArguments(route, relatedId, record);
    Navigator.of(context).pushNamed(route, arguments: arguments).catchError((error) {
      debugPrint('[VisitorNotifications] Navigation error for route $route: $error');
      return null;
    });
    // Clear it from the list once acted on, instead of leaving it read.
    _delete(record);
  }

  /// Build arguments based on route destination
  Object? _buildArguments(String route, String? relatedId, VisitorNotificationRecord record) {
    if (relatedId == null || relatedId.isEmpty) {
      return null;
    }

    switch (route) {
      case '/business/view':
      case '/promotion/detail':
        // These routes expect a plain String ID
        return relatedId;
      case '/visitor/notifications':
      case '/visitor/portal':
        // These routes might expect a Map with additional context
        return <String, dynamic>{
          'notificationId': record.id,
          'relatedItemId': relatedId,
          'relatedItemType': record.relatedItemType,
        };
      default:
        // For any other route, pass the ID as-is
        return relatedId;
    }
  }

  IconData _iconFor(VisitorNotificationType type) {
    switch (type) {
      case VisitorNotificationType.nearbyPromotion:
        return Icons.local_offer_rounded;
      case VisitorNotificationType.savedBusinessUpdate:
        return Icons.store_rounded;
      case VisitorNotificationType.trendingBusiness:
        return Icons.trending_up_rounded;
      case VisitorNotificationType.promotionExpiryReminder:
        return Icons.timer_rounded;
      case VisitorNotificationType.newBusinessDiscovery:
        return Icons.explore_rounded;
      case VisitorNotificationType.personalisedRecommendation:
        return Icons.star_rounded;
      case VisitorNotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColorFor(VisitorNotificationType type) {
    switch (type) {
      case VisitorNotificationType.nearbyPromotion:
      case VisitorNotificationType.promotionExpiryReminder:
        return AppPalette.ochre;
      case VisitorNotificationType.savedBusinessUpdate:
      case VisitorNotificationType.newBusinessDiscovery:
        return AppPalette.deepBlue;
      case VisitorNotificationType.trendingBusiness:
      case VisitorNotificationType.personalisedRecommendation:
        return AppPalette.gold;
      case VisitorNotificationType.unknown:
        return AppPalette.mutedText;
    }
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitorOverride ?? VisitorAuth.currentVisitor;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: visitor == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please log in as a Visitor to view notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : StreamBuilder<List<VisitorNotificationRecord>>(
              stream: widget.notificationsStreamOverride ??
                  _effectiveRepo.watchNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    '[VisitorPushNotificationsScreen] stream error: ${snapshot.error}',
                  );
                  final message = AppErrorMessages.fromException(
                    snapshot.error,
                    fallback: 'Could not sync notifications right now.',
                  );
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: InlineStatusMessage(
                        message: message,
                        type: InlineStatusType.info,
                        actionLabel: 'Retry',
                        onAction: () => setState(() {}),
                      ),
                    ),
                  );
                }

                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No notifications yet.\nSave businesses and enable alerts to stay in the loop.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppPalette.mutedText),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final icon = _iconFor(record.type);
                    final iconColor = _iconColorFor(record.type);

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: record.isRead ? 0.7 : 1.0,
                      child: Dismissible(
                        key: ValueKey(record.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _delete(record),
                        child: Card(
                          color: AppPalette.surface,
                          child: InkWell(
                            onTap: () => _openDetail(record),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppPalette.surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: iconColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                record.typeLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: iconColor,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _timeAgo(record.createdAt),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppPalette.mutedText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          record.title,
                                          style: TextStyle(
                                            fontWeight: record.isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: AppPalette.charcoal,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          record.message,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppPalette.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!record.isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(
                                        left: 8,
                                        top: 4,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppPalette.ochre,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
