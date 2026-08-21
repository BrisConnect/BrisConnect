import 'package:flutter/material.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/owner_notification_record.dart';
import 'package:brisconnect/services/owner_notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

/// Notification centre for business owners.
class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({
    super.key,
    this.repositoryOverride,
    this.notificationsStreamOverride,
    this.ownerOverride,
  });

  final OwnerNotificationRepository? repositoryOverride;
  final Stream<List<OwnerNotificationRecord>>? notificationsStreamOverride;
  final LocalUser? ownerOverride;

  @override
  State<OwnerNotificationsScreen> createState() =>
      _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  OwnerNotificationRepository? _repo;

  OwnerNotificationRepository get _effectiveRepo {
    return _repo ??= widget.repositoryOverride ??
        OwnerNotificationRepository(userEmail: _ownerEmail);
  }

  String get _ownerEmail {
    final owner = widget.ownerOverride ?? LocalAuth.currentLocal;
    return owner?.email.trim().toLowerCase() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repositoryOverride;
  }

  Future<void> _markAllAsRead() async {
    await _effectiveRepo.markAllAsRead();
  }

  Future<void> _toggleRead(OwnerNotificationRecord record) async {
    if (widget.notificationsStreamOverride != null &&
        widget.repositoryOverride == null) {
      return;
    }
    if (record.isRead) return;
    await _effectiveRepo.markAsRead(record.id);
  }

  Future<void> _delete(OwnerNotificationRecord record) async {
    if (widget.notificationsStreamOverride != null &&
        widget.repositoryOverride == null) {
      return;
    }
    await _effectiveRepo.deleteNotification(record.id);
  }

  void _navigateFor(OwnerNotificationRecord record) {
    final route = record.actionRoute;
    if (route == null || route.isEmpty) {
      _delete(record);
      return;
    }

    if (!mounted) return;
    Navigator.of(context)
        .pushNamed(route, arguments: _argumentsFor(route, record))
        .catchError((error) {
      debugPrint('[OwnerNotifications] Navigation error for route $route: $error');
      return null;
    });
    // Clear it from the list once acted on, instead of leaving it read.
    _delete(record);
  }

  /// Builds route arguments matching what each destination screen actually
  /// expects. `/business/view` and `/promotion/detail` require a plain
  /// String id (not a Map) or the route crashes to a blank page.
  Object? _argumentsFor(String route, OwnerNotificationRecord record) {
    switch (route) {
      case '/business/view':
        return record.businessId ?? '';
      case '/promotion/detail':
        return (record.relatedItemType == 'promotion'
                ? record.relatedItemId
                : null) ??
            '';
      case '/local/portal':
        return <String, dynamic>{
          'notificationId': record.id,
          if (record.businessId != null) 'businessId': record.businessId,
          'initialTabIndex': _dashboardTabFor(record),
        };
      default:
        return <String, dynamic>{
          'notificationId': record.id,
          if (record.businessId != null) 'businessId': record.businessId,
          if (record.relatedItemId != null)
            'relatedItemId': record.relatedItemId,
          if (record.relatedItemType != null)
            'relatedItemType': record.relatedItemType,
        };
    }
  }

  /// Maps a notification to the matching LocalPortalScreen tab index
  /// (0=Dashboard, 1=Feed, 2=Reviews, 3=Business) so tapping it lands on the
  /// content that was actually notified, instead of always the dashboard.
  int _dashboardTabFor(OwnerNotificationRecord record) {
    switch (record.rawType) {
      case 'new_review':
        return 2;
      case 'new_comment':
        return record.postType == 'review' ? 2 : 1;
      case 'buzz_vote':
        return 1;
      default:
        return 0;
    }
  }

  Widget _buildIconFor(OwnerNotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case OwnerNotificationType.verificationApproved:
        icon = Icons.verified_rounded;
        color = Colors.green;
      case OwnerNotificationType.verificationRejected:
      case OwnerNotificationType.verificationNeedsInfo:
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
      case OwnerNotificationType.newReview:
        icon = Icons.star_rounded;
        color = AppPalette.ochre;
      case OwnerNotificationType.buzzMilestone:
      case OwnerNotificationType.profileEngagement:
        icon = Icons.trending_up_rounded;
        color = AppPalette.deepBlue;
      case OwnerNotificationType.promotionApproved:
      case OwnerNotificationType.promotionPublished:
      case OwnerNotificationType.promotionPerformance:
        icon = Icons.campaign_rounded;
        color = Colors.green;
      case OwnerNotificationType.promotionRejected:
      case OwnerNotificationType.promotionExpiring:
        icon = Icons.campaign_rounded;
        color = Colors.orange;
      case OwnerNotificationType.subscriptionSuccess:
      case OwnerNotificationType.subscriptionRenewal:
      case OwnerNotificationType.subscriptionRenewalSuccess:
        icon = Icons.workspace_premium_rounded;
        color = AppPalette.deepBlue;
      case OwnerNotificationType.subscriptionPaymentFailed:
      case OwnerNotificationType.subscriptionCancelled:
        icon = Icons.credit_card_off_rounded;
        color = Colors.red;
      case OwnerNotificationType.adminMessage:
        icon = Icons.admin_panel_settings_rounded;
        color = AppPalette.deepBlue;
      case OwnerNotificationType.reportedContent:
        icon = Icons.report_problem_rounded;
        color = Colors.red;
      case OwnerNotificationType.unknown:
        icon = Icons.notifications_rounded;
        color = AppPalette.mutedText;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppPalette.mutedText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.ownerOverride ?? LocalAuth.currentLocal;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _ownerEmail.isEmpty ? null : _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Mark all read'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.deepBlue,
            ),
          ),
        ],
      ),
      body: owner == null
          ? _buildEmptyState(
              'Please log in as a business owner to view notifications.')
          : StreamBuilder<List<OwnerNotificationRecord>>(
              stream: widget.notificationsStreamOverride ??
                  _effectiveRepo.watchNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    '[OwnerNotificationsScreen] stream error: ${snapshot.error}',
                  );
                  final message = AppErrorMessages.fromException(
                    snapshot.error,
                    fallback:
                        'Could not sync notifications right now. Showing available data.',
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
                  return _buildEmptyState(
                    'No notifications yet.\nAccount, payment, and business updates will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: record.isRead ? 0.7 : 1,
                      child: Card(
                        color: AppPalette.surface,
                        child: ListTile(
                          onTap: () => _navigateFor(record),
                          leading: _buildIconFor(record.type),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.charcoal,
                                  ),
                                ),
                              ),
                              if (!record.isRead)
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
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.message,
                                  style: const TextStyle(
                                    color: AppPalette.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.surfaceAlt,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        record.typeLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.deepBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimeAgo(record.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppPalette.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'read') {
                                _toggleRead(record);
                              } else if (value == 'delete') {
                                _delete(record);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'read',
                                child: Text(
                                  record.isRead
                                      ? 'Mark as unread'
                                      : 'Mark as read',
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
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
