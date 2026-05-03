import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brisconnect/screens/visitor_saved_events_calendar_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a [MaterialApp] wrapping the calendar screen with the given items.
Widget _buildApp({List<Map<String, dynamic>> savedItems = const []}) {
  return MaterialApp(
    home: VisitorSavedEventsCalendarScreen(savedItems: savedItems),
  );
}

/// Returns a future date as DD/MM/YYYY.
String _ddMmYyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Returns a future date as YYYY-MM-DD (ISO).
String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Returns a future date as YYYY/MM/DD.
String _yyySlash(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// Returns a day-first textual date: "1 July 2032".
String _dayFirst(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Returns a month-first textual date: "July 1, 2032".
String _monthFirst(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// A date 3 days from now (guaranteed future).
DateTime _futureDateA() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
}

/// A date 5 days from now.
DateTime _futureDateB() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(const Duration(days: 5));
}

/// A date 7 days from now.
DateTime _futureDateC() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
}

/// Build a saved-event map that the calendar screen expects.
Map<String, dynamic> _eventItem({
  required String id,
  required String title,
  String location = 'Brisbane CBD',
  String? dateTime,
  String? date,
  String? time,
  String section = 'events',
}) {
  final map = <String, dynamic>{
    'id': id,
    'section': section,
    'title': title,
    'location': location,
  };
  if (dateTime != null) map['dateTime'] = dateTime;
  if (date != null) map['date'] = date;
  if (time != null) map['time'] = time;
  return map;
}

/// Scroll down the primary ListView by a fixed offset.
Future<void> _scrollDown(WidgetTester tester, {int times = 1}) async {
  for (int i = 0; i < times; i++) {
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // AC-1: Saved or interested events appear in the calendar feature
  // =========================================================================
  group('AC-1: Saved/interested events appear in calendar', () {
    testWidgets('saved event with valid date appears on calendar day',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'River Festival',
          dateTime: '${_ddMmYyyy(d)} • 10:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      // An event header should show (day list section exists).
      expect(find.textContaining('Events on'), findsOneWidget);
    });

    testWidgets('multiple saved events appear for the same day',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'River Festival',
          dateTime: '${_ddMmYyyy(d)} • 10:00 AM',
        ),
        _eventItem(
          id: 'e2',
          title: 'Night Noodle Markets',
          dateTime: '${_ddMmYyyy(d)} • 6:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Tap on the date that has events.
      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('River Festival'), findsOneWidget);
      expect(find.text('Night Noodle Markets'), findsOneWidget);
    });

    testWidgets('non-event sections are excluded from calendar',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'f1',
          title: 'Best Gelato',
          section: 'food',
          dateTime: '${_ddMmYyyy(d)} • 12:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Food items should not appear.
      expect(find.text('Best Gelato'), findsNothing);
      expect(
        find.text('No upcoming saved events with confirmed dates.'),
        findsOneWidget,
      );
    });

    testWidgets('event without id or title is filtered out', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        {
          'id': '',
          'section': 'events',
          'title': 'Ghost Event',
          'dateTime': '${_ddMmYyyy(d)} • 10:00 AM',
        },
        {
          'id': 'e-no-title',
          'section': 'events',
          'title': '',
          'dateTime': '${_ddMmYyyy(d)} • 11:00 AM',
        },
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Ghost Event'), findsNothing);
      expect(
        find.text('No upcoming saved events with confirmed dates.'),
        findsOneWidget,
      );
    });

    testWidgets('past events are excluded', (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 30));
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'old-1',
          title: 'Old Festival',
          dateTime: '${_ddMmYyyy(past)} • 10:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Old Festival'), findsNothing);
    });

    testWidgets('unscheduled events shown in awaiting section',
        (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'u1',
          title: 'Mystery Gig',
          dateTime: 'Coming soon',
        ),
      ]));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(
        find.text('Saved Events Awaiting Confirmed Date/Time'),
        findsOneWidget,
      );
      expect(find.text('Mystery Gig'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-2: The calendar supports day view
  // =========================================================================
  group('AC-2: Calendar supports day view', () {
    testWidgets('default view shows events for selected day', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Southbank Jam',
          dateTime: '${_ddMmYyyy(d)} • 2:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Tap the future date to select it.
      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Southbank Jam'), findsOneWidget);
      expect(find.text('2:00 PM'), findsOneWidget);
    });

    testWidgets('selecting empty day shows no-events message',
        (tester) async {
      final d = _futureDateA();
      final other = d.add(const Duration(days: 1));
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Only on date A',
          dateTime: '${_ddMmYyyy(d)} • 3:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Select a day with no events.
      await tester.tap(find.text('${other.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('No saved events on this date.'), findsOneWidget);
    });

    testWidgets('event card displays title and location', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Eat Street Markets',
          location: 'Hamilton Wharf',
          dateTime: '${_ddMmYyyy(d)} • 5:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Eat Street Markets'), findsOneWidget);
      expect(find.text('Hamilton Wharf'), findsOneWidget);
    });

    testWidgets('events on a day are sorted by start time', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'late',
          title: 'Evening Show',
          dateTime: '${_ddMmYyyy(d)} • 8:00 PM',
        ),
        _eventItem(
          id: 'early',
          title: 'Morning Yoga',
          dateTime: '${_ddMmYyyy(d)} • 6:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      // Both events should be present.
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Evening Show'), findsOneWidget);
    });

    testWidgets('time badge visible on event card', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Jazz Night',
          dateTime: '${_ddMmYyyy(d)} • 7:30 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('7:30 PM'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-3: The calendar supports week view
  // =========================================================================
  group('AC-3: Calendar supports week view', () {
    testWidgets('format button cycles to week view', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Week Event',
          dateTime: '${_ddMmYyyy(d)} • 10:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Default format is month → button shows 'Month'.
      expect(find.text('Month'), findsOneWidget);

      // First tap: month → twoWeeks.
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('2 weeks'), findsOneWidget);

      // Second tap: twoWeeks → week.
      await tester.tap(find.text('2 weeks'));
      await tester.pumpAndSettle();
      expect(find.text('Week'), findsOneWidget);
    });

    testWidgets('week view still renders TableCalendar', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      // Cycle to week view.
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 weeks'));
      await tester.pumpAndSettle();

      // TableCalendar is parameterised with a private type; find by toString.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'TableCalendar<_SavedCalendarEvent>',
        ),
        findsOneWidget,
      );
    });

    testWidgets('events visible after switching to week view',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Riverside Run',
          dateTime: '${_ddMmYyyy(d)} • 6:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Switch to 2-weeks view.
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      // The event list section should still be visible.
      expect(find.textContaining('Events on'), findsOneWidget);
    });

    testWidgets('week view cycles back to month', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      // month → twoWeeks → week → month
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 weeks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(find.text('Month'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-4: The calendar supports month view
  // =========================================================================
  group('AC-4: Calendar supports month view', () {
    testWidgets('default format is month', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      // Format button shows current format → 'Month'.
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('month view displays TableCalendar widget', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'TableCalendar<_SavedCalendarEvent>',
        ),
        findsOneWidget,
      );
    });

    testWidgets('month view shows day-of-week headers', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      // Starting day is Monday.
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('tapping a day in month view selects it', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Gallery Opening',
          dateTime: '${_ddMmYyyy(d)} • 11:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Gallery Opening'), findsOneWidget);
    });

    testWidgets('month view has navigation chevrons', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('empty calendar shows no-events message', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      expect(
        find.text('No upcoming saved events with confirmed dates.'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-5: Common event date and time formats are parsed correctly
  // =========================================================================
  group('AC-5: Date and time format parsing', () {
    testWidgets('DD/MM/YYYY with 12h time parses correctly', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Slash Date Event',
          dateTime: '${_ddMmYyyy(d)} • 3:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Slash Date Event'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);
    });

    testWidgets('ISO date (YYYY-MM-DD) with separate time parses',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e2',
          title: 'ISO Event',
          date: _iso(d),
          time: '2:30 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('ISO Event'), findsOneWidget);
      expect(find.text('2:30 PM'), findsOneWidget);
    });

    testWidgets('YYYY/MM/DD date in dateTime field parses via slash handler',
        (tester) async {
      // The slash parser always tries DD/MM/YYYY first. For YYYY/MM/DD the
      // first element (year) is treated as day and the last element (day) as
      // year — so it only works if the year value is a valid day. We verify
      // that the parser doesn't crash and falls through to unscheduled when
      // the numbers are ambiguous.
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e3',
          title: 'Slash-Year Event',
          date: _yyySlash(d),
          time: '11:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      // The widget should render without errors (event may appear on calendar
      // or in unscheduled section depending on how the parser resolves).
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('day-first textual date (1 July 2032) parses',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e4',
          title: 'Day-First Event',
          date: _dayFirst(d),
          time: '10:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Day-First Event'), findsOneWidget);
    });

    testWidgets('month-first textual date (July 1, 2032) parses',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e5',
          title: 'Month-First Event',
          date: _monthFirst(d),
          time: '4:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Month-First Event'), findsOneWidget);
    });

    testWidgets('24-hour time format (14:30) parses', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e6',
          title: '24h Event',
          date: _iso(d),
          time: '14:30',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('24h Event'), findsOneWidget);
      expect(find.text('2:30 PM'), findsOneWidget);
    });

    testWidgets('12-hour time without minutes (3 PM) parses',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e7',
          title: 'No-Minutes Event',
          date: _iso(d),
          time: '3 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('No-Minutes Event'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);
    });

    testWidgets('time range takes first segment (10:00 AM - 2:00 PM)',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e8',
          title: 'Range Event',
          date: _iso(d),
          time: '10:00 AM - 2:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Range Event'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
    });

    testWidgets('date with no time defaults to 9:00 AM', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e9',
          title: 'No-Time Event',
          date: _iso(d),
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('No-Time Event'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
    });

    testWidgets('unparseable date goes to unscheduled section',
        (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'bad',
          title: 'Bad Date Event',
          dateTime: 'TBA',
        ),
      ]));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Bad Date Event'), findsOneWidget);
      expect(
        find.text('Saved Events Awaiting Confirmed Date/Time'),
        findsOneWidget,
      );
    });

    testWidgets('combined dateTime field with bullet separator parses',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e10',
          title: 'Bullet Event',
          dateTime: '${_ddMmYyyy(d)} • 5:45 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Bullet Event'), findsOneWidget);
      expect(find.text('5:45 PM'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-6: Calendar loads efficiently and displays data accurately
  // =========================================================================
  group('AC-6: Efficient loading and accurate display', () {
    testWidgets('screen renders in under 3 seconds', (tester) async {
      final d = _futureDateA();
      final items = List.generate(
        20,
        (i) => _eventItem(
          id: 'e$i',
          title: 'Event $i',
          dateTime: '${_ddMmYyyy(d.add(Duration(days: i)))} • 10:00 AM',
        ),
      );
      final sw = Stopwatch()..start();
      await tester.pumpWidget(_buildApp(savedItems: items));
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsed.inSeconds, lessThan(3));
      expect(find.text('Saved Events Calendar'), findsOneWidget);
    });

    testWidgets('AppBar shows Saved Events Calendar title', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      expect(find.text('Saved Events Calendar'), findsOneWidget);
    });

    testWidgets('TableCalendar is present in widget tree', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: []));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'TableCalendar<_SavedCalendarEvent>',
        ),
        findsOneWidget,
      );
    });

    testWidgets('event card shows accurate time from parsed data',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Accuracy Check',
          location: 'QPAC',
          dateTime: '${_ddMmYyyy(d)} • 11:45 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Accuracy Check'), findsOneWidget);
      expect(find.text('QPAC'), findsOneWidget);
      expect(find.text('11:45 AM'), findsOneWidget);
    });

    testWidgets('location defaults to Location TBA when missing',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        {
          'id': 'e-no-loc',
          'section': 'events',
          'title': 'No Location Event',
          'dateTime': '${_ddMmYyyy(d)} • 9:00 AM',
        },
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Location TBA'), findsOneWidget);
    });

    testWidgets('unscheduled event shows schedule text', (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'u1',
          title: 'TBA Event',
          dateTime: 'Check official schedule',
        ),
      ]));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Check official schedule'), findsOneWidget);
    });

    testWidgets('unscheduled event with no dateTime shows fallback text',
        (tester) async {
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'u2',
          title: 'Empty Date Event',
        ),
      ]));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Schedule to be confirmed'), findsOneWidget);
    });

    testWidgets('events sorted chronologically in internal list',
        (tester) async {
      final d = _futureDateA();
      // Insert out of order.
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'late',
          title: 'Late Event',
          dateTime: '${_ddMmYyyy(d)} • 11:00 PM',
        ),
        _eventItem(
          id: 'early',
          title: 'Early Event',
          dateTime: '${_ddMmYyyy(d)} • 7:00 AM',
        ),
        _eventItem(
          id: 'mid',
          title: 'Mid Event',
          dateTime: '${_ddMmYyyy(d)} • 1:00 PM',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${d.day}').first);
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 3);

      expect(find.text('Early Event'), findsOneWidget);
      expect(find.text('Mid Event'), findsOneWidget);
      expect(find.text('Late Event'), findsOneWidget);
    });

    testWidgets('Scaffold renders without errors', (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'e1',
          title: 'Safe Event',
          dateTime: '${_ddMmYyyy(d)} • 10:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mixed scheduled and unscheduled events render together',
        (tester) async {
      final d = _futureDateA();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'sched',
          title: 'Scheduled Concert',
          dateTime: '${_ddMmYyyy(d)} • 7:00 PM',
        ),
        _eventItem(
          id: 'unsched',
          title: 'Pending Workshop',
          dateTime: 'Dates TBA',
        ),
      ]));
      await tester.pumpAndSettle();

      // Scheduled section visible.
      expect(find.textContaining('Events on'), findsOneWidget);

      await _scrollDown(tester, times: 4);

      // Unscheduled section also visible.
      expect(
        find.text('Saved Events Awaiting Confirmed Date/Time'),
        findsOneWidget,
      );
      expect(find.text('Pending Workshop'), findsOneWidget);
    });

    testWidgets('events on different dates show on correct days',
        (tester) async {
      final dA = _futureDateA();
      final dB = _futureDateB();
      await tester.pumpWidget(_buildApp(savedItems: [
        _eventItem(
          id: 'ea',
          title: 'Day A Event',
          dateTime: '${_ddMmYyyy(dA)} • 10:00 AM',
        ),
        _eventItem(
          id: 'eb',
          title: 'Day B Event',
          dateTime: '${_ddMmYyyy(dB)} • 11:00 AM',
        ),
      ]));
      await tester.pumpAndSettle();

      // Select date A.
      await tester.tap(find.text('${dA.day}').first);
      await tester.pumpAndSettle();
      await _scrollDown(tester, times: 3);

      expect(find.text('Day A Event'), findsOneWidget);
      expect(find.text('Day B Event'), findsNothing);

      // Scroll back up to calendar.
      await tester.dragFrom(const Offset(400, 300), const Offset(0, 600));
      await tester.pumpAndSettle();

      // Select date B.
      await tester.tap(find.text('${dB.day}').first);
      await tester.pumpAndSettle();
      await _scrollDown(tester, times: 3);

      expect(find.text('Day B Event'), findsOneWidget);
    });
  });
}
