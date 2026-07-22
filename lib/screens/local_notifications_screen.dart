import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/services/admin_message_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocalNotificationsScreen extends StatelessWidget {
  const LocalNotificationsScreen({
    super.key,
    this.localEventService,
    this.notificationRepository,
    this.adminMessageService,
    this.profileVersionListenable,
    this.localUserOverride,
    this.notificationsStreamOverride,
  });

  final LocalEventService? localEventService;
  final NotificationRepository? notificationRepository;
  final AdminMessageService? adminMessageService;
  final ValueListenable<int>? profileVersionListenable;
  final LocalUser? localUserOverride;
  final Stream<List<NotificationRecord>>? notificationsStreamOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Notifications'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: profileVersionListenable ?? LocalAuth.profileVersion,
        builder: (context, _, __) {
          final eventService = localEventService ?? LocalEventService();
          final local = localUserOverride ?? LocalAuth.currentLocal;
          if (local == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please log in to view notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Admin Messages ──────────────────────────────────
              const _SectionLabel('Messages from Admin'),
              const SizedBox(height: 8),
              _AdminMessagesSection(
                email: local.email,
                messageService: adminMessageService ?? AdminMessageService(),
              ),
              const SizedBox(height: 24),

              // ── Account status card ──────────────────────────────
              _AccountStatusCard(status: local.approvalStatus),
              const SizedBox(height: 24),

              // ── Event status notifications ───────────────────────
              const _SectionLabel('Event Status Updates'),
              const SizedBox(height: 8),
              StreamBuilder<List<EventItem>>(
                stream: eventService.watchSubmittedEvents(local.email),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildEmptyCard(
                      'Unable to load event statuses.',
                      'Please try again shortly to refresh your submitted events.',
                    );
                  }

                  final myEvents = snapshot.data ?? const <EventItem>[];
                  if (myEvents.isEmpty) {
                    return _buildEmptyCard(
                      'No events submitted yet.',
                      'Submit an event from the Dashboard to track its approval status here.',
                    );
                  }

                  return Column(
                    children:
                        myEvents.map((event) => _EventStatusTile(event: event)).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Notification history ──────────────────────────────
              const _SectionLabel('Notification History'),
              const SizedBox(height: 8),
              
              StreamBuilder<List<NotificationRecord>>(
                stream: notificationsStreamOverride ??
                  (notificationRepository ?? NotificationRepository())
                    .watchNotificationsForUser(local.email),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final records = snapshot.data ?? const [];
                  if (records.isEmpty) {
                    return _buildEmptyCard(
                      'No notifications yet.',
                      'Notifications from event interactions will appear here.',
                    );
                  }
                  return Column(
                    children: records
                        .map((r) => _NotificationHistoryTile(record: r))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppPalette.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppPalette.mutedText,
      ),
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  final AccountApprovalStatus status;
  const _AccountStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color borderColor, Color iconColor, IconData icon,
        String title, String subtitle) = switch (status) {
      AccountApprovalStatus.approved => (
          Colors.green.withValues(alpha: 0.08),
          Colors.green.withValues(alpha: 0.5),
          Colors.green.shade700,
          Icons.verified_rounded,
          'Account Approved',
          'Your account has been approved. You can submit events for review.',
        ),
      AccountApprovalStatus.rejected => (
          Colors.red.withValues(alpha: 0.08),
          Colors.red.withValues(alpha: 0.5),
          Colors.red.shade700,
          Icons.block_rounded,
          'Account Rejected',
          'Your account was not approved. Please contact support for assistance.',
        ),
      AccountApprovalStatus.pending => (
          Colors.orange.withValues(alpha: 0.08),
          Colors.orange.withValues(alpha: 0.5),
          Colors.orange.shade700,
          Icons.schedule_rounded,
          'Account Pending Approval',
          'Your account is awaiting admin review. You will be notified once approved.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStatusTile extends StatelessWidget {
  final EventItem event;
  const _EventStatusTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final (Color chipColor, IconData statusIcon, String statusLabel) =
        switch (event.reviewStatus) {
      EventReviewStatus.approved => (
          Colors.green.shade700,
          Icons.check_circle_rounded,
          'Approved',
        ),
      EventReviewStatus.rejected => (
          Colors.red.shade700,
          Icons.cancel_rounded,
          'Rejected',
        ),
      EventReviewStatus.pending => (
          Colors.orange.shade700,
          Icons.schedule_rounded,
          'Pending',
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: chipColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.date}  •  ${event.location}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHistoryTile extends StatelessWidget {
  final NotificationRecord record;
  const _NotificationHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppPalette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              record.isRead
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color:
                  record.isRead ? AppPalette.mutedText : AppPalette.ochre,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.eventTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.eventDateTime}  •  ${record.eventLocation}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedText,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      record.scheduleType == 'event_time'
                          ? 'Schedule: Event-time'
                          : record.scheduleType == 'fallback'
                              ? 'Schedule: Fallback'
                              : 'Schedule: Unknown',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.deepBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin Messages Section ────────────────────────────────────────────────────

class _AdminMessagesSection extends StatelessWidget {
  final String email;
  final AdminMessageService messageService;

  const _AdminMessagesSection({
    required this.email,
    required this.messageService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminMessage>>(
      stream: messageService.watchMessagesForLocal(email),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final messages = snapshot.data ?? const [];
        if (messages.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.border),
            ),
            child: const Text(
              'No messages from admin yet.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
          );
        }
        return Column(
          children: messages
              .map((msg) => _AdminMessageTile(
                    message: msg,
                    messageService: messageService,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _AdminMessageTile extends StatelessWidget {
  final AdminMessage message;
  final AdminMessageService messageService;

  const _AdminMessageTile({
    required this.message,
    required this.messageService,
  });

  IconData get _typeIcon {
    switch (message.type) {
      case AdminMessageType.reportNotice:
        return Icons.flag_rounded;
      case AdminMessageType.contentRequest:
        return Icons.edit_note_rounded;
      case AdminMessageType.general:
        return Icons.message_rounded;
    }
  }

  Color get _typeColor {
    switch (message.type) {
      case AdminMessageType.reportNotice:
        return Colors.red.shade600;
      case AdminMessageType.contentRequest:
        return AppPalette.deepBlue;
      case AdminMessageType.general:
        return AppPalette.ochre;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;
    return GestureDetector(
      onTap: () async {
        if (isUnread) {
          await messageService.markAsRead(message.id);
        }
        if (!context.mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppPalette.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _AdminMessageDetail(message: message),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? _typeColor.withValues(alpha: 0.06)
              : AppPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? _typeColor.withValues(alpha: 0.35)
                : AppPalette.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.subject,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          message.type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(message.createdAt),
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
            const Icon(Icons.chevron_right_rounded,
                color: AppPalette.mutedText, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _AdminMessageDetail extends StatelessWidget {
  final AdminMessage message;
  const _AdminMessageDetail({required this.message});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message.subject,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  message.type.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ochre,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'From Admin • ${message.createdAt.day}/${message.createdAt.month}/${message.createdAt.year}',
                style: const TextStyle(
                    fontSize: 12, color: AppPalette.mutedText),
              ),
            ],
          ),
          if (message.eventTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.ochre.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppPalette.ochre.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded,
                      color: AppPalette.ochre, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Event: ${message.eventTitle}',
                      style: const TextStyle(
                        color: AppPalette.ochre,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            message.message,
            style: const TextStyle(
              fontSize: 15,
              color: AppPalette.charcoal,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
