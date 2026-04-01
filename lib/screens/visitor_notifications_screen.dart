import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class VisitorNotificationsScreen extends StatefulWidget {
  const VisitorNotificationsScreen({super.key});

  @override
  State<VisitorNotificationsScreen> createState() =>
      _VisitorNotificationsScreenState();
}

class _VisitorNotificationsScreenState
    extends State<VisitorNotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository();

  @override
  void initState() {
    super.initState();
    final visitor = VisitorAuth.currentVisitor;
    if (visitor != null) {
      _repo.migrateNotificationIdsForUser(visitor.email).then((migratedCount) {
        if (migratedCount > 0 && mounted) {
          setState(() {});
        }
      });
    }
  }

  DateTime? _parseEventDate(String value) {
    final trimmed = value.trim();
    final slashMatch =
        RegExp(r'^(\d{1,2})\/(\d{2})\/(\d{4})').firstMatch(trimmed);
    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(3)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(1)!),
      );
    }
    final wordMatch =
        RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})').firstMatch(trimmed);
    if (wordMatch != null) {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
        'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
        'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final month = months[wordMatch.group(2)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(wordMatch.group(3)!),
          month,
          int.parse(wordMatch.group(1)!),
        );
      }
    }
    return null;
  }

  String _timeLabelFor(String dateTimeText) {
    final parsed = _parseEventDate(dateTimeText);
    if (parsed == null) return 'Upcoming';
    final today = DateTime.now();
    final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDiff =
        eventDay.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (dayDiff < 0) return 'Passed';
    if (dayDiff == 0) return 'Today';
    if (dayDiff <= 7) return 'This week';
    return 'Later';
  }

  Color _chipColorFor(String label) {
    switch (label) {
      case 'Today':
        return AppPalette.ochre;
      case 'This week':
        return AppPalette.deepBlue;
      case 'Passed':
        return AppPalette.mutedText;
      default:
        return AppPalette.charcoal;
    }
  }

  String _scheduleTypeLabel(String scheduleType) {
    switch (scheduleType) {
      case 'event_time':
        return 'Schedule: Event-time';
      case 'fallback':
        return 'Schedule: Fallback';
      default:
        return 'Schedule: Unknown';
    }
  }

  Future<void> _toggleRead(NotificationRecord record) async {
    await _repo.setReadStatus(record.id, isRead: !record.isRead);
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
    final visitor = VisitorAuth.currentVisitor;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Notifications'),
      ),
      body: visitor == null
          ? _buildEmptyState(
              'Please log in as a Visitor to view notifications.')
          : StreamBuilder<List<NotificationRecord>>(
              stream: _repo.watchNotificationsForUser(visitor.email),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    '[VisitorNotificationsScreen] stream error: ${snapshot.error}',
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
                    'No notifications yet.\nMark events as Interested to receive reminders.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final statusLabel = _timeLabelFor(record.eventDateTime);
                    final chipColor = _chipColorFor(statusLabel);

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: record.isRead ? 0.65 : 1,
                      child: Card(
                        color: AppPalette.surface,
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              record.isRead
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                              color: record.isRead
                                  ? AppPalette.mutedText
                                  : AppPalette.ochre,
                            ),
                          ),
                          title: Text(
                            record.eventTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${record.eventDateTime}'),
                                const SizedBox(height: 2),
                                Text(
                                  record.eventLocation,
                                  style: const TextStyle(
                                      color: AppPalette.mutedText),
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
                                      _scheduleTypeLabel(record.scheduleType),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppPalette.deepBlue,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        chipColor.withValues(alpha: 0.12),
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
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (_) => _toggleRead(record),
                            itemBuilder: (_) => [
                              PopupMenuItem<String>(
                                value: 'toggle',
                                child: Text(record.isRead
                                    ? 'Mark as unread'
                                    : 'Mark as read'),
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