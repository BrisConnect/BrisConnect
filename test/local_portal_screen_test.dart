import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/local_portal_screen.dart';
import 'package:brisconnect/screens/visitor_saved_events_calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    required Stream<List<EventItem>> submittedEventsStream,
  }) {
    return MaterialApp(
      home: LocalPortalScreen(
        enforceRoleGuard: false,
        initialTabIndex: 1,
        submittedEventsStreamOverride: submittedEventsStream,
        discoverItemsStreamOverride:
            Stream<List<Map<String, dynamic>>>.value(const []),
      ),
    );
  }

  testWidgets('My Events status updates live when stream status changes',
      (tester) async {
    final controller = StreamController<List<EventItem>>();
    addTearDown(controller.close);

    final pendingEvent = EventItem(
      id: 'event-1',
      title: 'Local River Festival',
      date: '01/06/2026',
      time: '6:00 PM',
      location: 'South Bank',
      description: 'Community event awaiting approval.',
      reviewStatus: EventReviewStatus.pending,
      createdByLocalEmail: 'local@brisconnect.com',
    );

    await tester.pumpWidget(
      buildApp(submittedEventsStream: controller.stream),
    );

    controller.add([pendingEvent]);
    await tester.pump();

    expect(find.text('Local River Festival'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);

    final approvedEvent = pendingEvent.copyWith(
      reviewStatus: EventReviewStatus.approved,
    );
    controller.add([approvedEvent]);
    await tester.pump();

    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Pending Approval'), findsNothing);
  });

  testWidgets('Calendar & Personal Plans button opens calendar screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = StreamController<List<EventItem>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: LocalPortalScreen(
          enforceRoleGuard: false,
          initialTabIndex: 0,
          submittedEventsStreamOverride: controller.stream,
          discoverItemsStreamOverride:
              Stream<List<Map<String, dynamic>>>.value(const []),
        ),
      ),
    );
    controller.add(const []);
    await tester.pumpAndSettle();

    expect(find.text('Calendar & Personal Plans'), findsOneWidget);

    await tester.tap(find.text('Calendar & Personal Plans'));
    await tester.pumpAndSettle();

    expect(find.byType(VisitorSavedEventsCalendarScreen), findsOneWidget);
    expect(find.text('Saved Events Calendar'), findsOneWidget);
  });
}
