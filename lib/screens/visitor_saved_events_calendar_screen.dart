import 'package:flutter/material.dart';

import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

enum _CalendarViewMode { day, week, month }

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
  });

  final List<Map<String, dynamic>> savedItems;

  @override
  State<VisitorSavedEventsCalendarScreen> createState() =>
      _VisitorSavedEventsCalendarScreenState();
}

class _VisitorSavedEventsCalendarScreenState
    extends State<VisitorSavedEventsCalendarScreen> {
  late final List<_SavedCalendarEvent> _events;
  late final List<_UnscheduledSavedEvent> _unscheduledEvents;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _events = _buildUpcomingEvents(widget.savedItems);
    _unscheduledEvents = _buildUnscheduledEvents(widget.savedItems);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<_SavedCalendarEvent> _buildUpcomingEvents(
    List<Map<String, dynamic>> items,
  ) {
    final now = DateTime.now();
    final parsed = <_SavedCalendarEvent>[];

    for (final item in items) {
      final section = (item['section'] as String? ?? '').trim().toLowerCase();
      if (section != 'events') {
        continue;
      }

      final dateTimeRaw = (item['dateTime'] as String? ?? '').trim();
      final parsedStart = _tryParseEventStart(dateTimeRaw);
      if (parsedStart == null || parsedStart.isBefore(now)) {
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

      final dateTimeRaw = (item['dateTime'] as String? ?? '').trim();
      final parsedStart = _tryParseEventStart(dateTimeRaw);
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

    final parts = dateTimeText.split('•');
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

  DateTime? _tryParseDate(String raw) {
    final slash = raw.split('/');
    if (slash.length == 3) {
      final day = int.tryParse(slash[0]);
      final month = int.tryParse(slash[1]);
      final year = int.tryParse(slash[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
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

    final normalized = raw.toLowerCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)$').firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final hourRaw = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final meridiem = match.group(3)!;
    if (hourRaw == null || minute == null) {
      return null;
    }

    var hour = hourRaw % 12;
    if (meridiem == 'pm') {
      hour += 12;
    }

    return (hour, minute);
  }

  List<_SavedCalendarEvent> _eventsForDay(DateTime date) {
    return _events.where((event) {
      final d = event.start;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  List<_SavedCalendarEvent> _eventsForWeek(DateTime selected) {
    final start = _startOfWeek(selected);
    final endExclusive = start.add(const Duration(days: 7));
    return _events
        .where((event) =>
            !event.start.isBefore(start) && event.start.isBefore(endExclusive))
        .toList();
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  void _moveRange(int offset) {
    setState(() {
      switch (_viewMode) {
        case _CalendarViewMode.day:
          _selectedDate = _selectedDate.add(Duration(days: offset));
          break;
        case _CalendarViewMode.week:
          _selectedDate = _selectedDate.add(Duration(days: 7 * offset));
          break;
        case _CalendarViewMode.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + offset,
            1,
          );
          break;
      }
    });
  }

  String _rangeTitle() {
    switch (_viewMode) {
      case _CalendarViewMode.day:
        return _formatDate(_selectedDate);
      case _CalendarViewMode.week:
        final start = _startOfWeek(_selectedDate);
        final end = start.add(const Duration(days: 6));
        return '${_formatDate(start)} - ${_formatDate(end)}';
      case _CalendarViewMode.month:
        return _monthYear(_selectedDate);
    }
  }

  String _monthYear(DateTime d) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  String _formatDate(DateTime d) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${names[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }

  Widget _buildViewSwitcher() {
    return SegmentedButton<_CalendarViewMode>(
      segments: const [
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.day,
          label: Text('Day'),
        ),
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.week,
          label: Text('Week'),
        ),
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.month,
          label: Text('Month'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (selection) {
        setState(() {
          _viewMode = selection.first;
        });
      },
    );
  }

  Widget _buildMonthGrid() {
    final firstOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final firstCell = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Center(child: Text('Mon'))),
              Expanded(child: Center(child: Text('Tue'))),
              Expanded(child: Center(child: Text('Wed'))),
              Expanded(child: Center(child: Text('Thu'))),
              Expanded(child: Center(child: Text('Fri'))),
              Expanded(child: Center(child: Text('Sat'))),
              Expanded(child: Center(child: Text('Sun'))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: _buildMonthCell(
                    firstCell.add(Duration(days: week * 7 + day)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMonthCell(DateTime date) {
    final isCurrentMonth = date.month == _selectedDate.month;
    final isSelected = _dateOnly(date) == _dateOnly(_selectedDate);
    final dayEvents = _eventsForDay(date);

    return InkWell(
      onTap: () => setState(() => _selectedDate = _dateOnly(date)),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.deepBlue.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isCurrentMonth ? AppPalette.charcoal : AppPalette.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            if (dayEvents.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dayEvents.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.charcoal,
                  ),
                ),
              )
            else
              const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<_SavedCalendarEvent> events, {required String emptyLabel}) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.surface,
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
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
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
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.surface,
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
    final dayEvents = _eventsForDay(_selectedDate);
    final weekEvents = _eventsForWeek(_selectedDate);

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Saved Events Calendar'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'View your saved upcoming events in a calendar format.',
              style: TextStyle(color: AppPalette.mutedText),
            ),
            const SizedBox(height: 12),
            _buildViewSwitcher(),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous',
                  onPressed: () => _moveRange(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _rangeTitle(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: () => _moveRange(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: const Text(
                  'No upcoming saved events with confirmed dates are available for calendar view.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              )
            else if (_viewMode == _CalendarViewMode.month) ...[
              _buildMonthGrid(),
              const SizedBox(height: 10),
              Text(
                'Events on ${_formatDate(_selectedDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              _buildEventList(
                dayEvents,
                emptyLabel: 'No saved events on this date.',
              ),
            ] else if (_viewMode == _CalendarViewMode.week) ...[
              Text(
                'Events this week',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              _buildEventList(
                weekEvents,
                emptyLabel: 'No saved events in this week.',
              ),
              const SizedBox(height: 12),
              Text(
                'Events on ${_formatDate(_selectedDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.charcoal,
                ),
              ),
              _buildEventList(
                dayEvents,
                emptyLabel: 'No saved events on this date.',
              ),
            ] else ...[
              Text(
                'Events on ${_formatDate(_selectedDate)}',
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
      ),
    );
  }
}
