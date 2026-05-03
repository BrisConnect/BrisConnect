import 'dart:async';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/screens/visitor_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _formatDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  return '$day/$month/$year';
}

String _formatTime(DateTime dt) {
  final isPm = dt.hour >= 12;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final suffix = isPm ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

NotificationRecord _record({
  required String id,
  required String eventId,
  required String title,
  required DateTime dateTime,
}) {
  return NotificationRecord(
    id: id,
    eventId: eventId,
    userEmail: 'visitor@test.com',
    userType: 'visitor',
    eventTitle: title,
    eventDateTime: '${_formatDate(dateTime)} • ${_formatTime(dateTime)}',
    eventLocation: 'Brisbane',
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const visitor = VisitorUser(
    name: 'Visitor Tester',
    email: 'visitor@test.com',
    password: 'Password123',
    interestedEventIds: ['e1', 'e2'],
  );

  Future<void> pumpWithStream(
    WidgetTester tester,
    Stream<List<NotificationRecord>> stream,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisitorNotificationsScreen(
          visitorOverride: visitor,
          notificationsStreamOverride: stream,
        ),
      ),
    );
  }

  testWidgets('shows upcoming reminders in chronological order',
      (tester) async {
    final now = DateTime.now();
    final controller = StreamController<List<NotificationRecord>>.broadcast();

    await pumpWithStream(tester, controller.stream);

    controller.add([
      _record(
        id: 'past',
        eventId: 'e1',
        title: 'Past Event',
        dateTime: now.subtract(const Duration(days: 1)),
      ),
      _record(
        id: 'later',
        eventId: 'e2',
        title: 'Later Event',
        dateTime: now.add(const Duration(days: 3, hours: 2)),
      ),
      _record(
        id: 'soon',
        eventId: 'e1',
        title: 'Soon Event',
        dateTime: now.add(const Duration(days: 1, hours: 1)),
      ),
      _record(
        id: 'not-interested',
        eventId: 'e999',
        title: 'Not Interested Event',
        dateTime: now.add(const Duration(days: 2)),
      ),
    ]);

    await tester.pumpAndSettle();

    expect(find.text('Past Event'), findsNothing);
    expect(find.text('Not Interested Event'), findsNothing);
    expect(find.text('Soon Event'), findsOneWidget);
    expect(find.text('Later Event'), findsOneWidget);

    final soonY = tester.getTopLeft(find.text('Soon Event')).dy;
    final laterY = tester.getTopLeft(find.text('Later Event')).dy;
    expect(soonY, lessThan(laterY));

    await controller.close();
  });

  testWidgets('opens event details when tapping a reminder', (tester) async {
    final now = DateTime.now();
    final stream = Stream<List<NotificationRecord>>.value([
      _record(
        id: 'open',
        eventId: 'e1',
        title: 'Open Me Event',
        dateTime: now.add(const Duration(days: 2)),
      ),
    ]);

    await pumpWithStream(tester, stream);
    await tester.pump();

    await tester.tap(find.text('Open Me Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Event Details'), findsOneWidget);
    expect(find.text('Open Me Event'), findsWidgets);
  });

  testWidgets('updates list when reminders are added or removed',
      (tester) async {
    final now = DateTime.now();
    final controller = StreamController<List<NotificationRecord>>.broadcast();

    await pumpWithStream(tester, controller.stream);

    controller.add([
      _record(
        id: 'initial',
        eventId: 'e1',
        title: 'Initial Event',
        dateTime: now.add(const Duration(days: 2)),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Initial Event'), findsOneWidget);

    controller.add([
      _record(
        id: 'new',
        eventId: 'e2',
        title: 'New Event',
        dateTime: now.add(const Duration(days: 1)),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Initial Event'), findsNothing);
    expect(find.text('New Event'), findsOneWidget);

    await controller.close();
  });
}
