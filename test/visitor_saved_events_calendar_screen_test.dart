import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brisconnect/screens/visitor_saved_events_calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> buildSavedItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayFutureTime = now.add(const Duration(hours: 1));
    final tomorrowTime = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      10,
      0,
    );

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    String fmtTime(DateTime d) {
      final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final minute = d.minute.toString().padLeft(2, '0');
      final suffix = d.hour >= 12 ? 'PM' : 'AM';
      return '$hour12:$minute $suffix';
    }

    return [
      {
        'id': 'event-1',
        'section': 'events',
        'title': 'Opening Ceremony Watch Party',
        'location': 'South Bank',
        'dateTime': '${fmtDate(today)} • ${fmtTime(todayFutureTime)}',
      },
      {
        'id': 'event-2',
        'section': 'events',
        'title': 'Swimming Finals Meetup',
        'location': 'Brisbane Aquatic Centre',
        'dateTime': '${fmtDate(tomorrow)} • ${fmtTime(tomorrowTime)}',
      },
      {
        'id': 'food-1',
        'section': 'food',
        'title': 'Should Not Be Shown',
        'location': 'Food Court',
        'dateTime': '11/10/2032 • 12:00 PM',
      },
    ];
  }

  testWidgets('calendar renders and view mode switching works', (tester) async {
    final started = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: VisitorSavedEventsCalendarScreen(savedItems: buildSavedItems()),
      ),
    );
    await tester.pumpAndSettle();

    final elapsed = DateTime.now().difference(started);
    expect(elapsed.inSeconds, lessThan(3));

    expect(find.text('Saved Events Calendar'), findsOneWidget);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(find.text('Opening Ceremony Watch Party'), findsOneWidget);
    expect(find.text('Should Not Be Shown'), findsNothing);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Events this week'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Events on'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting another date updates daily event list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorSavedEventsCalendarScreen(savedItems: buildSavedItems()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Swimming Finals Meetup'), findsOneWidget);
  });

  testWidgets('unscheduled liked events are still shown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorSavedEventsCalendarScreen(
          savedItems: const [
            {
              'id': 'event-unscheduled',
              'section': 'events',
              'title': 'Clock Tower Tours at Brisbane City Hall',
              'location': 'Brisbane City Hall',
              'dateTime': 'Check official schedule',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Saved Events Awaiting Confirmed Date/Time'),
      findsOneWidget,
    );
    expect(find.text('Clock Tower Tours at Brisbane City Hall'), findsOneWidget);
    expect(find.text('Check official schedule'), findsOneWidget);
  });
}
