import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/error_messages.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class VisitorNotificationsScreen extends StatefulWidget {
  const VisitorNotificationsScreen({
    super.key,
    this.repositoryOverride,
    this.notificationsStreamOverride,
    this.visitorOverride,
  });

  final NotificationRepository? repositoryOverride;
  final Stream<List<NotificationRecord>>? notificationsStreamOverride;
  final VisitorUser? visitorOverride;

  @override
  State<VisitorNotificationsScreen> createState() =>
      _VisitorNotificationsScreenState();
}

class _VisitorNotificationsScreenState
    extends State<VisitorNotificationsScreen> {
  NotificationRepository? _repo;

  NotificationRepository get _effectiveRepo {
    return _repo ??= widget.repositoryOverride ?? NotificationRepository();
  }

  Set<String> _interestedIds() {
    final override = widget.visitorOverride;
    if (override != null) {
      return Set<String>.from(override.interestedEventIds);
    }
    return VisitorAuth.getInterestedEventIds();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repositoryOverride;
    final visitor = widget.visitorOverride ?? VisitorAuth.currentVisitor;
    if (visitor != null && widget.notificationsStreamOverride == null) {
      _effectiveRepo
          .migrateNotificationIdsForUser(visitor.email)
          .then((migratedCount) {
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
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
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

  DateTime? _parseEventStart(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    final parts = text.split('•');
    final date = _parseEventDate(parts.first);
    if (date == null) {
      return null;
    }

    final timeRaw = parts.length > 1 ? parts.sublist(1).join('•').trim() : '';
    if (timeRaw.isEmpty) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(timeRaw);
    if (match == null) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }

    final rawHour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final suffix = match.group(3)!.toUpperCase();
    if (rawHour == null || minute == null) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }

    var hour = rawHour % 12;
    if (suffix == 'PM') {
      hour += 12;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  (String, String) _splitDateTime(String raw) {
    final parts = raw.split('•');
    final date = parts.isNotEmpty ? parts.first.trim() : raw.trim();
    final time =
        parts.length > 1 ? parts.sublist(1).join('•').trim() : 'Time TBA';
    return (date, time.isEmpty ? 'Time TBA' : time);
  }

  List<NotificationRecord> _upcomingRecords(
    List<NotificationRecord> records,
    Set<String> interestedIds,
  ) {
    final now = DateTime.now();
    final filtered = records.where((record) {
      if (record.eventId.isNotEmpty &&
          !interestedIds.contains(record.eventId)) {
        return false;
      }

      final start = _parseEventStart(record.eventDateTime);
      if (start == null) {
        return true;
      }
      return !start.isBefore(now);
    }).toList(growable: false);

    filtered.sort((a, b) {
      final aStart = _parseEventStart(a.eventDateTime);
      final bStart = _parseEventStart(b.eventDateTime);

      if (aStart == null && bStart == null) {
        return a.createdAt.compareTo(b.createdAt);
      }
      if (aStart == null) {
        return 1;
      }
      if (bStart == null) {
        return -1;
      }
      return aStart.compareTo(bStart);
    });

    return filtered;
  }

  String _timeLabelFor(String dateTimeText) {
    final parsed = _parseEventDate(dateTimeText);
    if (parsed == null) return 'Upcoming';
    final today = DateTime.now();
    final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDiff = eventDay
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
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
    if (widget.notificationsStreamOverride != null &&
        widget.repositoryOverride == null) {
      return;
    }
    await _effectiveRepo.setReadStatus(record.id, isRead: !record.isRead);
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

  Future<void> _openEventDetails(NotificationRecord record) async {
    final eventId = record.eventId.trim().isEmpty
        ? 'notification-${record.id}'
        : record.eventId.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorEventDetailScreen(
          event: {
            'id': eventId,
            'section': 'events',
            'title': record.eventTitle,
            'dateTime': record.eventDateTime,
            'location': record.eventLocation,
            'description': '',
            'webLink': '',
            'badge': 'REMINDER',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitor = widget.visitorOverride ?? VisitorAuth.currentVisitor;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Reminder Schedule'),
      ),
      body: visitor == null
          ? _buildEmptyState('Please log in as a Visitor to view reminders.')
          : ValueListenableBuilder<int>(
              valueListenable: VisitorAuth.interestedEventsVersion,
              builder: (context, _, __) {
                final interestedIds = _interestedIds();
                final notificationsStream =
                    widget.notificationsStreamOverride ??
                        _effectiveRepo.watchNotificationsForUser(visitor.email);

                return StreamBuilder<List<NotificationRecord>>(
                  stream: notificationsStream,
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
                            'Could not sync reminder schedule right now. Showing available data.',
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

                    final records = _upcomingRecords(
                      snapshot.data ?? const [],
                      interestedIds,
                    );

                    if (records.isEmpty) {
                      return _buildEmptyState(
                        'No upcoming reminders yet.\nMark events as Interested to build your schedule.',
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
                        final split = _splitDateTime(record.eventDateTime);

                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: record.isRead ? 0.7 : 1,
                          child: Card(
                            color: AppPalette.surface,
                            child: ListTile(
                              onTap: () => _openEventDetails(record),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: AppPalette.deepBlue,
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
                                    Text('Date: ${split.$1}'),
                                    const SizedBox(height: 2),
                                    Text('Time: ${split.$2}'),
                                    const SizedBox(height: 2),
                                    Text(
                                      record.eventLocation,
                                      style: const TextStyle(
                                        color: AppPalette.mutedText,
                                      ),
                                    ),
                                    if (kDebugMode) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          _scheduleTypeLabel(
                                              record.scheduleType),
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
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
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
                                    child: Text(
                                      record.isRead
                                          ? 'Mark as unread'
                                          : 'Mark as read',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
