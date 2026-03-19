import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/event_detail_screen.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class VisitorNotificationsScreen extends StatelessWidget {
  const VisitorNotificationsScreen({super.key});

  DateTime? _parseEventDate(String value) {
    final trimmed = value.trim();

    final slashMatch = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(trimmed);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final year = int.parse(slashMatch.group(3)!);
      return DateTime(year, month, day);
    }

    final wordMatch = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$').firstMatch(trimmed);
    if (wordMatch != null) {
      final day = int.parse(wordMatch.group(1)!);
      final year = int.parse(wordMatch.group(3)!);
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
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  List<EventItem> _getReminderEvents() {
    final interestedIds = VisitorAuth.getInterestedEventIds();
    final approvedEvents = EventRepository.getApprovedEvents();
    final reminderEvents = approvedEvents
        .where((event) => interestedIds.contains(event.id))
        .toList();

    reminderEvents.sort((a, b) {
      final aDate = _parseEventDate(a.date);
      final bDate = _parseEventDate(b.date);
      if (aDate == null && bDate == null) {
        return a.title.compareTo(b.title);
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return aDate.compareTo(bDate);
    });

    return reminderEvents;
  }

  @override
  Widget build(BuildContext context) {
    final visitor = VisitorAuth.currentVisitor;
    final reminderEvents = _getReminderEvents();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Notifications'),
      ),
      body: visitor == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please log in as a Visitor to view event reminders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : reminderEvents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No reminders yet. Save an event as Interested to see it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.mutedText),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reminderEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = reminderEvents[index];
                    return Card(
                      color: AppPalette.surface,
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppPalette.ochre,
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reminder date: ${event.date}'),
                              Text(
                                event.location,
                                style: const TextStyle(color: AppPalette.mutedText),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}