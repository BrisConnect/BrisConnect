import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final String imageUrl;
  final String source; // 'local', 'discover', or ''
  final Map<String, dynamic> rawItem;

  const _SavedCalendarEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.start,
    this.imageUrl = '',
    this.source = '',
    required this.rawItem,
  });
}

class _UnscheduledSavedEvent {
  final String id;
  final String title;
  final String location;
  final String scheduleText;
  final String imageUrl;
  final String source; // 'local', 'discover', or ''
  final Map<String, dynamic> rawItem;

  const _UnscheduledSavedEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.scheduleText,
    this.imageUrl = '',
    this.source = '',
    required this.rawItem,
  });
}

class _PersonalPlan {
  final String id;
  final String title;
  final DateTime start;
  final String notes;

  const _PersonalPlan({
    required this.id,
    required this.title,
    required this.start,
    this.notes = '',
  });

  factory _PersonalPlan.fromJson(Map<String, dynamic> json) {
    final startIso = (json['startIso'] as String? ?? '').trim();
    final parsedStart = DateTime.tryParse(startIso) ?? DateTime.now();
    return _PersonalPlan(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      start: parsedStart,
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startIso': start.toIso8601String(),
      'notes': notes,
    };
  }
}

enum _CalendarViewMode { day, week }

class _PersonalPlanDialogResult {
  final _PersonalPlan? plan;
  final bool delete;

  const _PersonalPlanDialogResult.save(this.plan) : delete = false;
  const _PersonalPlanDialogResult.delete()
      : plan = null,
        delete = true;
}

class VisitorSavedEventsCalendarScreen extends StatefulWidget {
  const VisitorSavedEventsCalendarScreen({
    super.key,
    required this.savedItems,
    this.allEvents = const [],
    this.embedded = false,
  });

  final List<Map<String, dynamic>> savedItems;
  /// All events (saved + unsaved) — locals, Brisbane City Council, discover.
  final List<Map<String, dynamic>> allEvents;
  final bool embedded;

  @override
  State<VisitorSavedEventsCalendarScreen> createState() =>
      _VisitorSavedEventsCalendarScreenState();
}

class _VisitorSavedEventsCalendarScreenState
    extends State<VisitorSavedEventsCalendarScreen> {
  late List<_SavedCalendarEvent> _events;
  late Set<String> _savedIds;
  late List<_UnscheduledSavedEvent> _unscheduledEvents;
  List<_PersonalPlan> _personalPlans = const [];
  _CalendarViewMode _viewMode = _CalendarViewMode.day;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _rebuildEvents();
    _loadPersonalPlans();
  }

  @override
  void didUpdateWidget(covariant VisitorSavedEventsCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedItems != widget.savedItems ||
        oldWidget.allEvents != widget.allEvents) {
      _rebuildEvents();
    }
  }

  void _rebuildEvents() {
    // Merge allEvents + savedItems, deduplicated by id
    final combined = <String, Map<String, dynamic>>{};
    for (final item in widget.allEvents) {
      final id = (item['id'] as String?)?.trim() ?? '';
      if (id.isNotEmpty) combined[id] = item;
    }
    for (final item in widget.savedItems) {
      final id = (item['id'] as String?)?.trim() ?? '';
      if (id.isNotEmpty) combined[id] = item;
    }
    _savedIds = {
      for (final item in widget.savedItems)
        if (((item['id'] as String?)?.trim() ?? '').isNotEmpty)
          (item['id'] as String).trim(),
    };

    _events = _buildUpcomingEvents(combined.values.toList());
    _unscheduledEvents = _buildUnscheduledEvents(combined.values.toList());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _personalPlanStorageKey {
    final visitorEmail = VisitorAuth.currentVisitor?.email.trim().toLowerCase();
    if (visitorEmail != null && visitorEmail.isNotEmpty) {
      return 'personal_calendar_entries_${visitorEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    }

    final localEmail = LocalAuth.currentLocal?.email.trim().toLowerCase();
    if (localEmail != null && localEmail.isNotEmpty) {
      return 'personal_calendar_entries_${localEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    }

    return 'personal_calendar_entries_guest';
  }

  Future<void> _loadPersonalPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_personalPlanStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _personalPlans = const []);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final plans = decoded
          .whereType<Map>()
          .map((item) => _PersonalPlan.fromJson(Map<String, dynamic>.from(item)))
          .where((plan) => plan.id.isNotEmpty && plan.title.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => a.start.compareTo(b.start));

      if (!mounted) return;
      setState(() => _personalPlans = plans);
    } catch (_) {
      if (!mounted) return;
      setState(() => _personalPlans = const []);
    }
  }

  Future<void> _persistPersonalPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _personalPlans.map((plan) => plan.toJson()).toList(growable: false),
    );
    await prefs.setString(_personalPlanStorageKey, payload);
  }

  List<_PersonalPlan> _personalPlansForDay(DateTime date) {
    return _personalPlans.where((plan) {
      final start = plan.start;
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }).toList(growable: false)
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  DateTime _defaultPersonalPlanStart(DateTime date) {
    return DateTime(date.year, date.month, date.day, 9);
  }

  bool _hasPersonalPlanConflict(DateTime start, {String? excludingId}) {
    return _personalPlans.any((plan) {
      if (excludingId != null && plan.id == excludingId) {
        return false;
      }
      return plan.start.isAtSameMomentAs(start);
    });
  }

  Future<bool> _confirmPersonalPlanConflict() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduling conflict'),
        content: const Text(
          'There is already a personal plan scheduled at this time. Do you want to continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
    return shouldProceed == true;
  }

  Future<void> _savePersonalPlan(_PersonalPlan plan) async {
    final updated = [..._personalPlans.where((item) => item.id != plan.id), plan]
      ..sort((a, b) => a.start.compareTo(b.start));
    setState(() => _personalPlans = updated);
    await _persistPersonalPlans();
  }

  Future<void> _deletePersonalPlan(_PersonalPlan plan) async {
    setState(() {
      _personalPlans = _personalPlans.where((item) => item.id != plan.id).toList(growable: false);
    });
    await _persistPersonalPlans();
  }

  Future<void> _showPersonalPlanDialog({_PersonalPlan? existingPlan}) async {
    final titleController = TextEditingController(text: existingPlan?.title ?? '');
    final notesController = TextEditingController(text: existingPlan?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_PersonalPlanDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSave() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final start = existingPlan?.start ?? _defaultPersonalPlanStart(_selectedDay);
              final hasConflict = _hasPersonalPlanConflict(
                start,
                excludingId: existingPlan?.id,
              );
              if (hasConflict) {
                final proceed = await _confirmPersonalPlanConflict();
                if (!proceed) {
                  return;
                }
              }

              final savedPlan = _PersonalPlan(
                id: existingPlan?.id ?? 'personal-${DateTime.now().microsecondsSinceEpoch}',
                title: titleController.text.trim(),
                start: start,
                notes: notesController.text.trim(),
              );

              if (!context.mounted) return;
              Navigator.of(context).pop(_PersonalPlanDialogResult.save(savedPlan));
            }

            void handleDelete() {
              if (existingPlan == null) {
                return;
              }
              Navigator.of(context).pop(const _PersonalPlanDialogResult.delete());
            }

            return AlertDialog(
              title: Text(existingPlan == null ? 'Add Personal Plan' : 'Edit Personal Plan'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        key: const Key('personal-plan-title-field'),
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('personal-plan-notes-field'),
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (existingPlan != null)
                  TextButton(
                    onPressed: handleDelete,
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: handleSave,
                  child: Text(existingPlan == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    if (result.delete) {
      if (existingPlan != null) {
        await _deletePersonalPlan(existingPlan);
      }
      return;
    }
    if (result.plan != null) {
      await _savePersonalPlan(result.plan!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal entry saved.')),
      );
    }
  }

  List<_SavedCalendarEvent> _eventsForWeek(DateTime date) {
    final startOfDay = _dateOnly(date);
    final endExclusive = startOfDay.add(const Duration(days: 7));
    return _events.where((event) {
      return !event.start.isBefore(startOfDay) && event.start.isBefore(endExclusive);
    }).toList(growable: false)
      ..sort((a, b) => a.start.compareTo(b.start));
  }

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
          imageUrl: (item['imageUrl'] as String? ?? '').trim(),
          source: (item['_source'] as String? ?? '').trim(),
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
          imageUrl: (item['imageUrl'] as String? ?? '').trim(),
          source: (item['_source'] as String? ?? '').trim(),
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
      _savedIds.remove(event.id);
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
      _savedIds.remove(event.id);
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.border),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                color: AppPalette.mutedText.withValues(alpha: 0.5), size: 36),
            const SizedBox(height: 10),
            Text(emptyLabel,
                style: const TextStyle(color: AppPalette.mutedText),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: events.map((event) {
        final isSaved = _savedIds.contains(event.id);
        final source = event.source;
        final Color sourceColor =
            source == 'local' ? AppPalette.ochre : AppPalette.deepBlue;
        final String sourceLabel = source == 'local'
            ? 'LOCAL'
            : source == 'discover'
                ? 'BRISBANE'
                : '';
        final hasImage = event.imageUrl.isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VisitorEventDetailScreen(event: event.rawItem),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSaved
                    ? AppPalette.ochre.withValues(alpha: 0.6)
                    : AppPalette.border,
                width: isSaved ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image banner ──
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      if (hasImage)
                        Image.network(
                          event.imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(
                              sourceColor, 140),
                        )
                      else
                        _imagePlaceholder(sourceColor, 140),
                      // Gradient overlay on image
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Date chip bottom-left
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: sourceColor),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(event.start),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sourceColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Source badge top-right
                      if (sourceLabel.isNotEmpty)
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sourceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              sourceLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      // Bookmark top-left
                      if (isSaved)
                        Positioned(
                          top: 8,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppPalette.ochre,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bookmark_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Text content ──
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppPalette.charcoal,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13,
                              color: AppPalette.mutedText
                                  .withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppPalette.mutedText,
                                  fontSize: 12),
                            ),
                          ),
                          if (isSaved)
                            GestureDetector(
                              onTap: () => _removeFromSaved(event),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.red.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        color: Colors.red, size: 14),
                                    SizedBox(width: 3),
                                    Text('Remove',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _imagePlaceholder(Color color, double height, {double? width}) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: color.withValues(alpha: 0.12),
      child: Icon(Icons.event_rounded,
          color: color.withValues(alpha: 0.4), size: 48),
    );
  }

  Widget _buildUnscheduledList() {
    if (_unscheduledEvents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: AppPalette.ochre,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Saved Events Awaiting Confirmed Date/Time',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppPalette.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'These events do not yet have a published schedule.',
          style: TextStyle(color: AppPalette.mutedText, fontSize: 12),
        ),
        ..._unscheduledEvents.map((event) {
          final isSaved = _savedIds.contains(event.id);
          final source = event.source;
          final Color sourceColor =
              source == 'local' ? AppPalette.ochre : AppPalette.deepBlue;
          final String sourceLabel = source == 'local'
              ? 'LOCAL'
              : source == 'discover'
                  ? 'BRISBANE'
                  : '';
          final hasImage = event.imageUrl.isNotEmpty;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VisitorEventDetailScreen(event: event.rawItem),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSaved
                      ? AppPalette.ochre.withValues(alpha: 0.5)
                      : AppPalette.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                    child: hasImage
                        ? Image.network(
                            event.imageUrl,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imagePlaceholder(sourceColor, 88, width: 88),
                          )
                        : _imagePlaceholder(sourceColor, 88, width: 88),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sourceLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    sourceColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                sourceLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: sourceColor,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 11,
                                  color: AppPalette.mutedText),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event.scheduleText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppPalette.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isSaved) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () =>
                                  _removeUnscheduledFromSaved(event),
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 13),
                                  SizedBox(width: 3),
                                  Text('Remove',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPersonalPlansList(List<_PersonalPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.edit_calendar_rounded, size: 18, color: AppPalette.deepBlue),
            const SizedBox(width: 6),
            const Text(
              'Personal Plans',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppPalette.charcoal,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                await _showPersonalPlanDialog();
              },
              child: const Text('Add'),
            ),
          ],
        ),
        if (plans.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: const Text(
              'No personal plans on this date.',
              style: TextStyle(color: AppPalette.mutedText),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...plans.map(
            (plan) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showPersonalPlanDialog(existingPlan: plan),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.deepBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatTime(plan.start),
                        style: const TextStyle(
                          color: AppPalette.deepBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppPalette.charcoal,
                            ),
                          ),
                          if (plan.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              plan.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.mutedText,
                              ),
                            ),
                          ],
                        ],
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
    final dayPersonalPlans = _personalPlansForDay(_selectedDay);
    final weekEvents = _eventsForWeek(_selectedDay);

    final body = SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Day'),
                  selected: _viewMode == _CalendarViewMode.day,
                  onSelected: (_) {
                    setState(() => _viewMode = _CalendarViewMode.day);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Week'),
                  selected: _viewMode == _CalendarViewMode.week,
                  onSelected: (_) {
                    setState(() => _viewMode = _CalendarViewMode.week);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: AppPalette.surface,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppPalette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: TableCalendar<_SavedCalendarEvent>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 730)),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                  rowHeight: 58.0,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _eventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = _dateOnly(selectedDay);
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronVisible: true,
                    rightChevronVisible: true,
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
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
                      color: AppPalette.ochre,
                      shape: BoxShape.circle,
                    ),
                    markerSize: 7,
                    markersMaxCount: 4,
                    markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _viewMode == _CalendarViewMode.day
                      ? Icons.event_rounded
                      : Icons.view_week_rounded,
                  size: 18,
                  color: AppPalette.ochre,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _viewMode == _CalendarViewMode.day
                        ? 'Events on ${_formatDate(_selectedDay)}'
                        : 'Events this week',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppPalette.charcoal,
                    ),
                  ),
                ),
                const Spacer(),
                if (_viewMode == _CalendarViewMode.day) ...[
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: () {
                      setState(() {
                        _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                        _focusedDay = _selectedDay;
                      });
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () {
                      setState(() {
                        _selectedDay = _selectedDay.add(const Duration(days: 1));
                        _focusedDay = _selectedDay;
                      });
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
                if ((_viewMode == _CalendarViewMode.day ? dayEvents : weekEvents).isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.ochre,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(_viewMode == _CalendarViewMode.day ? dayEvents : weekEvents).length} event${(_viewMode == _CalendarViewMode.day ? dayEvents : weekEvents).length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_viewMode == _CalendarViewMode.day) _buildPersonalPlansList(dayPersonalPlans),
            if ((_viewMode == _CalendarViewMode.day ? dayEvents : weekEvents).isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Text(
                  _viewMode == _CalendarViewMode.day
                      ? 'No events on this date. Tap another day.'
                      : 'No events in the next 7 days.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              )
            else
              _buildEventList(
                _viewMode == _CalendarViewMode.day ? dayEvents : weekEvents,
                emptyLabel: _viewMode == _CalendarViewMode.day
                    ? 'No events on this date. Tap another day.'
                    : 'No events in the next 7 days.',
              ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showPersonalPlanDialog();
        },
        tooltip: 'Add personal plan',
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Plan'),
      ),
    );
  }
}
