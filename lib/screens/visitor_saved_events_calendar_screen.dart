import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class _SavedCalendarEvent {
  final String id;
  final String title;
  final String location;
  final DateTime start;
  final Map<String, dynamic> rawItem;

  const _SavedCalendarEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.start,
    required this.rawItem,
  });
}

class _UnscheduledSavedEvent {
  final String id;
  final String title;
  final String location;
  final String scheduleText;
  final Map<String, dynamic> rawItem;

  const _UnscheduledSavedEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.scheduleText,
    required this.rawItem,
  });
}

class VisitorSavedEventsCalendarScreen extends StatefulWidget {
  const VisitorSavedEventsCalendarScreen({
    super.key,
    required this.savedItems,
    this.embedded = false,
  });

  final List<Map<String, dynamic>> savedItems;
  final bool embedded;

  @override
  State<VisitorSavedEventsCalendarScreen> createState() =>
      _VisitorSavedEventsCalendarScreenState();
}

class _VisitorSavedEventsCalendarScreenState
    extends State<VisitorSavedEventsCalendarScreen> {
  late List<_SavedCalendarEvent> _events;
  late List<_UnscheduledSavedEvent> _unscheduledEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _rebuildEvents();
  }

  @override
  void didUpdateWidget(covariant VisitorSavedEventsCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedItems != widget.savedItems) {
      _rebuildEvents();
    }
  }

  void _rebuildEvents() {
    _events = _buildUpcomingEvents(widget.savedItems);
    _unscheduledEvents = _buildUnscheduledEvents(widget.savedItems);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Event lookup by day for TableCalendar's eventLoader.
  List<_SavedCalendarEvent> _eventsForDay(DateTime date) {
    return _events.where((event) {
      final d = event.start;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  List<_SavedCalendarEvent> _buildUpcomingEvents(
    List<Map<String, dynamic>> items,
  ) {
    final parsed = <_SavedCalendarEvent>[];

    for (final item in items) {
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      if (section != 'events') {
        continue;
      }

      final parsedStart = _tryParseEventStartFromItem(item);
      if (parsedStart == null) {
        continue;
      }

      final id = (item['id'] as String?)?.trim() ?? '';
      final title = (item['title'] as String?)?.trim();
      if (id.isEmpty || title == null || title.isEmpty) {
        continue;
      }

      parsed.add(
        _SavedCalendarEvent(
          id: id,
          title: title,
          location: (item['location'] as String?)?.trim() ?? 'Location TBA',
          start: parsedStart,
          rawItem: item,
        ),
      );
    }

    parsed.sort((a, b) => a.start.compareTo(b.start));
    return parsed;
  }

  List<_UnscheduledSavedEvent> _buildUnscheduledEvents(
    List<Map<String, dynamic>> items,
  ) {
    final parsed = <_UnscheduledSavedEvent>[];

    for (final item in items) {
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      if (section != 'events') {
        continue;
      }

      final id = (item['id'] as String?)?.trim() ?? '';
      final title = (item['title'] as String?)?.trim();
      if (id.isEmpty || title == null || title.isEmpty) {
        continue;
      }

      final dateTimeRaw = _displayScheduleText(item);
      final parsedStart = _tryParseEventStartFromItem(item);
      if (parsedStart != null) {
        continue;
      }

      parsed.add(
        _UnscheduledSavedEvent(
          id: id,
          title: title,
          location: (item['location'] as String?)?.trim() ?? 'Location TBA',
          scheduleText: dateTimeRaw.isEmpty ? 'Schedule to be confirmed' : dateTimeRaw,
          rawItem: item,
        ),
      );
    }

    parsed.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return parsed;
  }

  DateTime? _tryParseEventStart(String dateTimeText) {
    if (dateTimeText.isEmpty) {
      return null;
    }

    final directParsed = DateTime.tryParse(dateTimeText.trim());
    if (directParsed != null) {
      return directParsed;
    }

    final compactDateTime = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})$',
    ).firstMatch(dateTimeText.trim());
    if (compactDateTime != null) {
      final year = int.tryParse(compactDateTime.group(1)!);
      final month = int.tryParse(compactDateTime.group(2)!);
      final day = int.tryParse(compactDateTime.group(3)!);
      final hour = int.tryParse(compactDateTime.group(4)!);
      final minute = int.tryParse(compactDateTime.group(5)!);
      if (year != null &&
          month != null &&
          day != null &&
          hour != null &&
          minute != null) {
        return DateTime(year, month, day, hour, minute);
      }
    }

    final parts = dateTimeText
      .split(RegExp(r'\s*[•·]|ΓÇó|\|\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
    final datePart = parts.first.trim();
    final timePart = parts.length > 1 ? parts[1].trim() : '';

    final date = _tryParseDate(datePart);
    if (date == null) {
      return null;
    }

    final time = _tryParseTime(timePart);
    if (time == null) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }

    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }

  DateTime? _tryParseEventStartFromItem(Map<String, dynamic> item) {
    final dateTimeRaw = (item['dateTime'] as String? ?? '').trim();
    final fromDateTime = _tryParseEventStart(dateTimeRaw);
    if (fromDateTime != null) {
      return fromDateTime;
    }

    final dateRaw = (item['date'] as String? ?? '').trim();
    if (dateRaw.isEmpty) {
      return null;
    }

    final date = _tryParseDate(dateRaw);
    if (date == null) {
      return null;
    }

    final timeRaw = (item['time'] as String? ?? '').trim();
    final parsedTime = _tryParseTime(timeRaw);
    if (parsedTime == null) {
      return DateTime(date.year, date.month, date.day, 9, 0);
    }

    return DateTime(date.year, date.month, date.day, parsedTime.$1, parsedTime.$2);
  }

  String _displayScheduleText(Map<String, dynamic> item) {
    final dateTimeRaw = (item['dateTime'] as String? ?? '').trim();
    if (dateTimeRaw.isNotEmpty) {
      return dateTimeRaw;
    }

    final dateRaw = (item['date'] as String? ?? '').trim();
    final timeRaw = (item['time'] as String? ?? '').trim();
    if (dateRaw.isEmpty && timeRaw.isEmpty) {
      return 'Schedule to be confirmed';
    }

    final normalizedDate = dateRaw.isEmpty ? 'Date TBA' : dateRaw;
    final normalizedTime = timeRaw.isEmpty ? 'Time TBA' : timeRaw;
    return '$normalizedDate • $normalizedTime';
  }

  DateTime? _tryParseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final directParsed = DateTime.tryParse(trimmed);
    if (directParsed != null) {
      return DateTime(directParsed.year, directParsed.month, directParsed.day);
    }

    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
    if (iso != null) {
      final year = int.tryParse(iso.group(1)!);
      final month = int.tryParse(iso.group(2)!);
      final day = int.tryParse(iso.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final slash = raw.split('/');
    if (slash.length == 3) {
      final day = int.tryParse(slash[0]);
      final month = int.tryParse(slash[1]);
      final year = int.tryParse(slash[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }

      final isoLikeYear = int.tryParse(slash[0]);
      final isoLikeMonth = int.tryParse(slash[1]);
      final isoLikeDay = int.tryParse(slash[2]);
      if (isoLikeYear != null && isoLikeMonth != null && isoLikeDay != null) {
        return DateTime(isoLikeYear, isoLikeMonth, isoLikeDay);
      }
    }

    final words = raw.split(RegExp(r'\s+'));
    if (words.length >= 3) {
      final day = int.tryParse(words[0]);
      final month = _monthFromText(words[1]);
      final year = int.tryParse(words[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final monthNameFirst = RegExp(
      r'^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(trimmed);
    if (monthNameFirst != null) {
      final month = _monthFromText(monthNameFirst.group(1)!);
      final day = int.tryParse(monthNameFirst.group(2)!);
      final year = int.tryParse(monthNameFirst.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  int? _monthFromText(String raw) {
    const monthMap = {
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
    return monthMap[raw.toLowerCase().substring(0, 3)];
  }

  (int, int)? _tryParseTime(String raw) {
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw.toLowerCase().trim();
    final firstSegment = normalized.split(RegExp(r'\s*(?:-|to|–)\s*')).first.trim();

    final withMinutes =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)$').firstMatch(firstSegment);
    if (withMinutes != null) {
      final hourRaw = int.tryParse(withMinutes.group(1)!);
      final minute = int.tryParse(withMinutes.group(2)!);
      final meridiem = withMinutes.group(3)!;
      if (hourRaw == null || minute == null) {
        return null;
      }

      var hour = hourRaw % 12;
      if (meridiem == 'pm') {
        hour += 12;
      }
      return (hour, minute);
    }

    final hourOnly = RegExp(r'^(\d{1,2})\s*(am|pm)$').firstMatch(firstSegment);
    if (hourOnly != null) {
      final hourRaw = int.tryParse(hourOnly.group(1)!);
      final meridiem = hourOnly.group(2)!;
      if (hourRaw == null) {
        return null;
      }

      var hour = hourRaw % 12;
      if (meridiem == 'pm') {
        hour += 12;
      }
      return (hour, 0);
    }

    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(firstSegment);
    if (twentyFourHour == null) {
      return null;
    }

    final hourRaw = int.tryParse(twentyFourHour.group(1)!);
    final minute = int.tryParse(twentyFourHour.group(2)!);
    if (hourRaw == null || minute == null) {
      return null;
    }

    if (hourRaw < 0 || hourRaw > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return (hourRaw, minute);
  }

  String _formatDate(DateTime d) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${names[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }

  bool _removeInterestedEvent(String eventId) {
    final normalized = eventId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    if (VisitorAuth.currentVisitor != null) {
      if (!VisitorAuth.isInterestedInEvent(normalized)) {
        return true;
      }
      return VisitorAuth.toggleInterestedEvent(normalized);
    }

    if (LocalAuth.currentLocal != null) {
      if (!LocalAuth.isInterestedInEvent(normalized)) {
        return true;
      }
      return LocalAuth.toggleInterestedEvent(normalized);
    }

    return false;
  }

  void _removeFromSaved(_SavedCalendarEvent event) {
    final removed = _removeInterestedEvent(event.id);
    if (!removed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove this saved event.')),
      );
      return;
    }

    setState(() {
      _events.removeWhere((e) => e.id == event.id);
      _unscheduledEvents.removeWhere((e) => e.id == event.id);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${event.title} removed from saved events.')),
    );
  }

  void _removeUnscheduledFromSaved(_UnscheduledSavedEvent event) {
    final removed = _removeInterestedEvent(event.id);
    if (!removed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove this saved event.')),
      );
      return;
    }

    setState(() {
      _events.removeWhere((e) => e.id == event.id);
      _unscheduledEvents.removeWhere((e) => e.id == event.id);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${event.title} removed from saved events.')),
    );
  }

  Widget _buildEventList(List<_SavedCalendarEvent> events,
      {required String emptyLabel}) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: Text(
          emptyLabel,
          style: const TextStyle(color: AppPalette.mutedText),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: events
          .map(
            (event) => InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisitorEventDetailScreen(event: event.rawItem),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTime(event.start),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppPalette.deepBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          const SizedBox(height: 4),
                          Text(
                            event.location,
                            style: const TextStyle(color: AppPalette.mutedText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from saved',
                      onPressed: () => _removeFromSaved(event),
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildUnscheduledList() {
    if (_unscheduledEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        const Text(
          'Saved Events Awaiting Confirmed Date/Time',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppPalette.charcoal,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'These events are saved, but their schedule is not yet published.',
          style: TextStyle(color: AppPalette.mutedText),
        ),
        ..._unscheduledEvents.map(
          (event) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitorEventDetailScreen(event: event.rawItem),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.border),
              ),
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
                  const SizedBox(height: 4),
                  Text(
                    event.location,
                    style: const TextStyle(color: AppPalette.mutedText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.scheduleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _removeUnscheduledFromSaved(event),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _eventsForDay(_selectedDay);

    final body = SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              color: AppPalette.surface.withValues(alpha: 0.78),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TableCalendar<_SavedCalendarEvent>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 730)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _eventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = _dateOnly(selectedDay);
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: AppPalette.deepBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: const TextStyle(
                      color: AppPalette.deepBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    titleTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppPalette.charcoal,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: AppPalette.charcoal,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.mutedText,
                      fontSize: 13,
                    ),
                    weekendStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.mutedText,
                      fontSize: 13,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppPalette.deepBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.deepBlue,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppPalette.deepBlue,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    outsideDaysVisible: true,
                    outsideTextStyle: const TextStyle(
                      color: Color(0xFFA8A8A8),
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 6,
                    markersMaxCount: 3,
                    markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: const Text(
                  'No upcoming saved events with confirmed dates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              )
            else ...[
              Text(
                'Events on ${_formatDate(_selectedDay)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              _buildEventList(
                dayEvents,
                emptyLabel: 'No saved events on this date.',
              ),
            ],
            _buildUnscheduledList(),
          ],
        ),
      );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Saved Events Calendar'),
      ),
      body: body,
    );
  }
}
