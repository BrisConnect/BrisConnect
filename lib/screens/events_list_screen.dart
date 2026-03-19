import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/event_detail_screen.dart';
import 'package:brisconnect/screens/event_list_screen.dart';
import 'package:brisconnect/screens/event_map_screen.dart';
import 'package:brisconnect/screens/visitor_interested_events_screen.dart';
import 'package:brisconnect/screens/visitor_notifications_screen.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  DateTime? _selectedDate;

  void _toggleInterested(EventItem event) {
    if (!VisitorAuth.isVisitorLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a Visitor to save interested events.'),
        ),
      );
      return;
    }

    final wasInterested = VisitorAuth.isInterestedInEvent(event.id);
    final didUpdate = VisitorAuth.toggleInterestedEvent(event.id);
    if (!didUpdate) {
      return;
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasInterested
              ? '${event.title} removed from Interested.'
              : '${event.title} saved to Interested.',
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
  }

  DateTime? _parseEventDate(String value) {
    final trimmed = value.trim();

    // Supports format: dd/MM/yyyy
    final slashMatch = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(trimmed);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final year = int.parse(slashMatch.group(3)!);
      return DateTime(year, month, day);
    }

    // Supports format: dd MMM yyyy (e.g. 22 Mar 2026)
    final wordMatch = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$').firstMatch(trimmed);
    if (wordMatch != null) {
      final day = int.parse(wordMatch.group(1)!);
      final monthText = wordMatch.group(2)!.toLowerCase();
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

      final month = months[monthText];
      if (month != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatSelectedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  List<EventItem> _getFilteredEvents() {
    final approved = EventRepository.getApprovedEvents();
    if (_selectedDate == null) {
      return approved;
    }

    return approved.where((event) {
      final parsed = _parseEventDate(event.date);
      return parsed != null && _isSameDate(parsed, _selectedDate!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _getFilteredEvents();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Cultural Events'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitorNotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            tooltip: 'Interested events',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitorInterestedEventsScreen(),
                ),
              );
              if (mounted) {
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Filter by date',
            onPressed: _pickDate,
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear date filter',
              onPressed: _clearDateFilter,
            ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View on map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventMapScreen(
                    events: EventListScreen.allEvents
                        .where((e) => e.isApproved)
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDate != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 18, color: AppPalette.ochre),
                  const SizedBox(width: 8),
                  Text(
                    'Selected date: ${_formatSelectedDate(_selectedDate!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: events.isEmpty
                ? const Center(child: Text('No events available'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card(
                        color: AppPalette.surface,
                        child: ListTile(
                          leading: const Icon(Icons.event, color: AppPalette.ochre),
                          title: Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${event.date}'),
                                Text('Location: ${event.location}'),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Mark interested',
                                onPressed: () => _toggleInterested(event),
                                icon: Icon(
                                  VisitorAuth.isInterestedInEvent(event.id)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: VisitorAuth.isInterestedInEvent(event.id)
                                      ? AppPalette.ochre
                                      : AppPalette.deepBlue,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
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
          ),
        ],
      ),
    );
  }
}
