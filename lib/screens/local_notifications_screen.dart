import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocalNotificationsScreen extends StatelessWidget {
  const LocalNotificationsScreen({
    super.key,
    this.localEventService,
    this.notificationRepository,
    this.profileVersionListenable,
    this.localUserOverride,
    this.notificationsStreamOverride,
  });

  final LocalEventService? localEventService;
  final NotificationRepository? notificationRepository;
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
