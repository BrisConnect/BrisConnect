import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/screens/local_notifications_screen.dart';
import 'package:brisconnect/screens/visitor_notifications_screen.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/services/notification_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

LocalUser _makeLocal({
  AccountApprovalStatus status = AccountApprovalStatus.approved,
  String email = 'local@test.com',
}) {
  return LocalUser(
    name: 'Test Local',
    email: email,
    password: 'pw',
    phone: '0412345678',
    suburb: 'Brisbane CBD',
    approvalStatus: status,
  );
}

VisitorUser _makeVisitor({
  String email = 'visitor@test.com',
  List<String> interestedEventIds = const ['e1', 'e2', 'e3', 'e4', 'e5'],
}) {
  return VisitorUser(
    name: 'Test Visitor',
    email: email,
    password: 'pw',
    interestedEventIds: interestedEventIds,
  );
}

/// Format a date as DD/MM/YYYY • H:MM AM/PM for the visitor screen parser.
String _fmtDateTime(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  final isPm = dt.hour >= 12;
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  final suffix = isPm ? 'PM' : 'AM';
  return '$d/$m/$y • $h:$min $suffix';
}

NotificationRecord _makeRecord({
  String id = 'n1',
  String eventId = 'e1',
  String userEmail = 'visitor@test.com',
  String userType = 'visitor',
  String eventTitle = 'River Festival',
  String? eventDateTime,
  String eventLocation = 'South Bank',
  String scheduleType = 'event_time',
  bool isRead = false,
  DateTime? createdAt,
}) {
  return NotificationRecord(
    id: id,
    eventId: eventId,
    userEmail: userEmail,
    userType: userType,
    eventTitle: eventTitle,
    eventDateTime: eventDateTime ??
        _fmtDateTime(DateTime.now().add(const Duration(days: 5))),
    eventLocation: eventLocation,
    scheduleType: scheduleType,
    createdAt: createdAt ?? DateTime(2026, 4, 10),
    isRead: isRead,
  );
}

Widget _buildVisitorScreen({
  required VisitorUser visitor,
  Stream<List<NotificationRecord>>? stream,
  NotificationRepository? repo,
}) {
  return MaterialApp(
    home: VisitorNotificationsScreen(
      visitorOverride: visitor,
      notificationsStreamOverride: stream,
      repositoryOverride: repo,
    ),
  );
}

Widget _buildLocalScreen({
  required LocalUser localUser,
  FakeFirebaseFirestore? firestore,
  Stream<List<NotificationRecord>>? notificationsStreamOverride,
}) {
  final fs = firestore ?? FakeFirebaseFirestore();
  return MaterialApp(
    home: LocalNotificationsScreen(
      localUserOverride: localUser,
      localEventService: LocalEventService(firestore: fs),
      notificationRepository: NotificationRepository(firestore: fs),
      profileVersionListenable: ValueNotifier<int>(0),
      notificationsStreamOverride: notificationsStreamOverride,
    ),
  );
}

Future<void> _scrollDown(WidgetTester tester, {int times = 1}) async {
  for (int i = 0; i < times; i++) {
    await tester.dragFrom(const Offset(400, 600), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // AC-1: Notification screen provided for supported roles
  // =========================================================================
  group('AC-1: Notification screen for supported roles', () {
    testWidgets('visitor sees Reminder Schedule screen', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reminder Schedule'), findsOneWidget);
    });

    testWidgets('local user sees Notifications screen', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
    });

    testWidgets('visitor not logged in sees login prompt', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(const MaterialApp(
        home: VisitorNotificationsScreen(visitorOverride: null),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Please log in as a Visitor to view reminders.'),
        findsOneWidget,
      );
    });

    testWidgets('local not logged in sees login prompt', (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(MaterialApp(
        home: LocalNotificationsScreen(
          localUserOverride: null,
          localEventService: LocalEventService(firestore: fs),
          notificationRepository: NotificationRepository(firestore: fs),
          profileVersionListenable: ValueNotifier<int>(0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Please log in to view notifications.'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-2: Stored notification records displayed in the app
  // =========================================================================
  group('AC-2: Notification records displayed in the app', () {
    testWidgets('visitor screen shows notification record title and location',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        eventTitle: 'Art Walk Brisbane',
        eventLocation: 'Gallery Precinct',
      );

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Art Walk Brisbane'), findsOneWidget);
      expect(find.text('Gallery Precinct'), findsOneWidget);
    });

    testWidgets('visitor screen shows date and time split from record',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        eventDateTime: '15/06/2026 • 2:00 PM',
        eventTitle: 'Timed Event',
      );

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Date: 15/06/2026'), findsOneWidget);
      expect(find.textContaining('Time: 2:00 PM'), findsOneWidget);
    });

    testWidgets('local screen shows notification record title and details',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        userEmail: 'local@test.com',
        userType: 'local',
        eventTitle: 'Market Morning',
        eventDateTime: '2026-08-15 09:00',
        eventLocation: 'Jan Powers',
      );

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('Market Morning'), findsOneWidget);
      expect(find.textContaining('Jan Powers'), findsWidgets);
    });

    testWidgets('visitor screen shows multiple records', (tester) async {
      _setViewport(tester);
      final records = [
        _makeRecord(
          id: 'n1',
          eventId: 'e1',
          eventTitle: 'Event Alpha',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 2))),
        ),
        _makeRecord(
          id: 'n2',
          eventId: 'e2',
          eventTitle: 'Event Bravo',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 4))),
        ),
      ];

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Event Alpha'), findsOneWidget);
      expect(find.text('Event Bravo'), findsOneWidget);
    });

    testWidgets('local screen shows multiple notification records',
        (tester) async {
      _setViewport(tester);
      final records = [
        _makeRecord(
          id: 'n1',
          userType: 'local',
          userEmail: 'local@test.com',
          eventTitle: 'Local One',
        ),
        _makeRecord(
          id: 'n2',
          userType: 'local',
          userEmail: 'local@test.com',
          eventTitle: 'Local Two',
        ),
      ];

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('Local One'), findsOneWidget);
      expect(find.text('Local Two'), findsOneWidget);
    });

    testWidgets('visitor read records have reduced opacity', (tester) async {
      _setViewport(tester);
      final record = _makeRecord(isRead: true);

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, equals(0.7));
    });

    testWidgets('visitor unread records have full opacity', (tester) async {
      _setViewport(tester);
      final record = _makeRecord(isRead: false);

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, equals(1.0));
    });

    testWidgets('local screen unread shows active bell icon', (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        userType: 'local',
        userEmail: 'local@test.com',
        isRead: false,
      );

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(
        find.byIcon(Icons.notifications_active_rounded),
        findsOneWidget,
      );
    });

    testWidgets('local screen read shows outlined bell icon', (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        userType: 'local',
        userEmail: 'local@test.com',
        isRead: true,
      );

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(
        find.byIcon(Icons.notifications_none_rounded),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-3: Clear empty state when no notifications exist
  // =========================================================================
  group('AC-3: Empty state when no notifications exist', () {
    testWidgets('visitor screen shows empty state message', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('No upcoming reminders yet'), findsOneWidget);
      expect(
        find.textContaining('Mark events as Interested'),
        findsOneWidget,
      );
    });

    testWidgets('local screen shows empty state for notifications',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('No notifications yet.'), findsOneWidget);
      expect(
        find.text(
            'Notifications from event interactions will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('visitor screen shows spinner during loading', (tester) async {
      _setViewport(tester);
      // Never-completing stream keeps ConnectionState.waiting.
      final controller =
          StreamController<List<NotificationRecord>>.broadcast();

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: controller.stream,
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });

    testWidgets(
        'visitor empty state disappears when records arrive',
        (tester) async {
      _setViewport(tester);
      final controller =
          StreamController<List<NotificationRecord>>.broadcast();

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: controller.stream,
      ));

      controller.add([]);
      await tester.pumpAndSettle();
      expect(find.textContaining('No upcoming reminders yet'), findsOneWidget);

      controller.add([
        _makeRecord(
          eventTitle: 'New Event',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 3))),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('No upcoming reminders yet'), findsNothing);
      expect(find.text('New Event'), findsOneWidget);

      await controller.close();
    });
  });

  // =========================================================================
  // AC-4: Entries include event or schedule context
  // =========================================================================
  group('AC-4: Entries include event or schedule context', () {
    testWidgets('visitor tile shows schedule_rounded leading icon',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([_makeRecord()]),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('visitor tile shows time label chip (This week)',
        (tester) async {
      _setViewport(tester);
      final inThisWeek =
          DateTime.now().add(const Duration(days: 3));
      final record =
          _makeRecord(eventDateTime: _fmtDateTime(inThisWeek));

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('visitor tile shows Later chip for distant events',
        (tester) async {
      _setViewport(tester);
      final later = DateTime.now().add(const Duration(days: 30));
      final record = _makeRecord(eventDateTime: _fmtDateTime(later));

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('visitor shows schedule type badge in debug mode',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(scheduleType: 'event_time');

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      if (kDebugMode) {
        expect(find.text('Schedule: Event-time'), findsOneWidget);
      }
    });

    testWidgets('visitor shows fallback schedule type badge',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(scheduleType: 'fallback');

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      if (kDebugMode) {
        expect(find.text('Schedule: Fallback'), findsOneWidget);
      }
    });

    testWidgets('visitor shows unknown schedule type badge', (tester) async {
      _setViewport(tester);
      final record = _makeRecord(scheduleType: 'unknown');

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      if (kDebugMode) {
        expect(find.text('Schedule: Unknown'), findsOneWidget);
      }
    });

    testWidgets('local tile shows schedule type badge in debug mode',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        userType: 'local',
        userEmail: 'local@test.com',
        scheduleType: 'event_time',
      );

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      if (kDebugMode) {
        expect(find.text('Schedule: Event-time'), findsOneWidget);
      }
    });

    testWidgets('local tile shows event datetime and location context',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(
        userType: 'local',
        userEmail: 'local@test.com',
        eventDateTime: '2026-07-10 14:00',
        eventLocation: 'Kangaroo Point',
      );

      await tester.pumpWidget(_buildLocalScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.textContaining('2026-07-10 14:00'), findsOneWidget);
      expect(find.textContaining('Kangaroo Point'), findsWidgets);
    });

    testWidgets('visitor popup menu shows Mark as read for unread',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(isRead: false);

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      // Tap the popup menu button (three-dot icon).
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Mark as read'), findsOneWidget);
    });

    testWidgets('visitor popup menu shows Mark as unread for read',
        (tester) async {
      _setViewport(tester);
      final record = _makeRecord(isRead: true);

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Mark as unread'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-5: Notification history loads from persistent storage
  // =========================================================================
  group('AC-5: Notification history loads from persistent storage', () {
    testWidgets('saveNotification writes to user_notifications collection',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      final result = await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Persisted Event',
        eventDateTime: '2026-06-01 10:00',
        eventLocation: 'South Bank',
        scheduleType: 'event_time',
      );
      expect(result, isTrue);

      final snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['eventTitle'], equals('Persisted Event'));
      expect(data['userEmail'], equals('visitor@test.com'));
      expect(data['userType'], equals('visitor'));
      expect(data['isRead'], isFalse);
    });

    testWidgets('saveNotification with empty email returns false',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      final result = await repo.saveNotification(
        userEmail: '  ',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'No Email',
        eventDateTime: '2026-06-01',
        eventLocation: 'CBD',
      );
      expect(result, isFalse);

      final snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, isEmpty);
    });

    testWidgets('watchNotificationsForUser returns real-time stream',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Stream Event',
        eventDateTime: '2026-06-01',
        eventLocation: 'CBD',
      );

      final records =
          await repo.watchNotificationsForUser('visitor@test.com').first;
      expect(records, hasLength(1));
      expect(records.first.eventTitle, equals('Stream Event'));
    });

    testWidgets('deterministic ID deduplicates repeated saves',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Dedup Event',
        eventDateTime: '2026-06-01',
        eventLocation: 'Place A',
      );
      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Dedup Event',
        eventDateTime: '2026-06-01',
        eventLocation: 'Place B',
      );

      final snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));
      // Merge overwrites location.
      expect(snapshot.docs.first.data()['eventLocation'], equals('Place B'));
    });

    testWidgets('setReadStatus toggles isRead on stored record',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Toggle Read',
        eventDateTime: '2026-06-01',
        eventLocation: 'CBD',
      );

      final docs = (await fs.collection('user_notifications').get()).docs;
      final docId = docs.first.id;
      expect(docs.first.data()['isRead'], isFalse);

      await repo.setReadStatus(docId, isRead: true);

      final updated =
          (await fs.collection('user_notifications').doc(docId).get()).data()!;
      expect(updated['isRead'], isTrue);
    });

    testWidgets('deleteNotificationForEvent removes the document',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Delete Me',
        eventDateTime: '2026-06-01',
        eventLocation: 'CBD',
      );

      var snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      await repo.deleteNotificationForEvent(
        userEmail: 'visitor@test.com',
        eventTitle: 'Delete Me',
        eventDateTime: '2026-06-01',
      );

      snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, isEmpty);
    });

    testWidgets(
        'records saved with local userType persist alongside visitor records',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'visitor@test.com',
        userType: 'visitor',
        eventId: 'evt-1',
        eventTitle: 'Visitor Notif',
        eventDateTime: '2026-06-01',
        eventLocation: 'CBD',
      );
      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-2',
        eventTitle: 'Local Notif',
        eventDateTime: '2026-06-02',
        eventLocation: 'West End',
      );

      final allDocs = await fs.collection('user_notifications').get();
      expect(allDocs.docs, hasLength(2));

      final visitorRecords =
          await repo.watchNotificationsForUser('visitor@test.com').first;
      expect(visitorRecords, hasLength(1));
      expect(visitorRecords.first.userType, equals('visitor'));

      final localRecords =
          await repo.watchNotificationsForUser('local@test.com').first;
      expect(localRecords, hasLength(1));
      expect(localRecords.first.userType, equals('local'));
    });
  });

  // =========================================================================
  // AC-6: Reliable and quick retrieval without data loss
  // =========================================================================
  group('AC-6: Reliable retrieval without data loss', () {
    testWidgets('NotificationRecord fromDoc parses all fields',
        (tester) async {
      final fs = FakeFirebaseFirestore();

      await fs.collection('user_notifications').doc('test-id').set({
        'eventId': 'evt-1',
        'userEmail': 'visitor@test.com',
        'userType': 'visitor',
        'eventTitle': 'Parsed Event',
        'eventDateTime': '01/06/2026 • 10:00 AM',
        'eventLocation': 'South Bank',
        'scheduleType': 'event_time',
        'createdAt': null,
        'isRead': false,
      });

      final doc =
          await fs.collection('user_notifications').doc('test-id').get();
      final record = NotificationRecord.fromDoc(doc);

      expect(record.id, equals('test-id'));
      expect(record.eventId, equals('evt-1'));
      expect(record.userEmail, equals('visitor@test.com'));
      expect(record.userType, equals('visitor'));
      expect(record.eventTitle, equals('Parsed Event'));
      expect(record.eventDateTime, equals('01/06/2026 • 10:00 AM'));
      expect(record.eventLocation, equals('South Bank'));
      expect(record.scheduleType, equals('event_time'));
      expect(record.isRead, isFalse);
    });

    testWidgets('NotificationRecord fromDoc handles missing fields',
        (tester) async {
      final fs = FakeFirebaseFirestore();

      await fs.collection('user_notifications').doc('sparse').set({
        'eventId': 'evt-1',
      });

      final doc =
          await fs.collection('user_notifications').doc('sparse').get();
      final record = NotificationRecord.fromDoc(doc);

      expect(record.eventTitle, equals('Event'));
      expect(record.eventDateTime, equals('Date TBA'));
      expect(record.eventLocation, equals('Location TBA'));
      expect(record.userType, equals('visitor'));
      expect(record.scheduleType, equals('unknown'));
    });

    testWidgets('NotificationRecord copyWith preserves other fields',
        (tester) async {
      final original = _makeRecord(
        id: 'copy-test',
        eventTitle: 'Original Title',
        scheduleType: 'event_time',
        isRead: false,
      );

      final updated = original.copyWith(isRead: true);

      expect(updated.id, equals('copy-test'));
      expect(updated.eventTitle, equals('Original Title'));
      expect(updated.scheduleType, equals('event_time'));
      expect(updated.isRead, isTrue);
    });

    testWidgets('copyWith can update scheduleType', (tester) async {
      final original = _makeRecord(scheduleType: 'unknown');
      final updated = original.copyWith(scheduleType: 'fallback');

      expect(updated.scheduleType, equals('fallback'));
      expect(updated.isRead, equals(original.isRead));
    });

    testWidgets('visitor screen updates in real time when stream emits',
        (tester) async {
      _setViewport(tester);
      final controller =
          StreamController<List<NotificationRecord>>.broadcast();

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: controller.stream,
      ));

      controller.add([
        _makeRecord(
          id: 'n1',
          eventTitle: 'First Event',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 2))),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('First Event'), findsOneWidget);

      controller.add([
        _makeRecord(
          id: 'n2',
          eventId: 'e2',
          eventTitle: 'Replaced Event',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 3))),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('First Event'), findsNothing);
      expect(find.text('Replaced Event'), findsOneWidget);

      await controller.close();
    });

    testWidgets(
        'visitor screen filters out events not in interestedEventIds',
        (tester) async {
      _setViewport(tester);
      final records = [
        _makeRecord(
          id: 'n1',
          eventId: 'e1',
          eventTitle: 'Interested Event',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 2))),
        ),
        _makeRecord(
          id: 'n2',
          eventId: 'e999',
          eventTitle: 'Not Interested',
          eventDateTime: _fmtDateTime(
              DateTime.now().add(const Duration(days: 2))),
        ),
      ];

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(interestedEventIds: ['e1']),
        stream: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Interested Event'), findsOneWidget);
      expect(find.text('Not Interested'), findsNothing);
    });

    testWidgets('visitor screen sorts records by soonest first',
        (tester) async {
      _setViewport(tester);
      final soon = DateTime.now().add(const Duration(days: 1, hours: 1));
      final later = DateTime.now().add(const Duration(days: 5));

      final records = [
        _makeRecord(
          id: 'n-later',
          eventId: 'e2',
          eventTitle: 'Later Event',
          eventDateTime: _fmtDateTime(later),
        ),
        _makeRecord(
          id: 'n-soon',
          eventId: 'e1',
          eventTitle: 'Soon Event',
          eventDateTime: _fmtDateTime(soon),
        ),
      ];

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      final soonY = tester.getTopLeft(find.text('Soon Event')).dy;
      final laterY = tester.getTopLeft(find.text('Later Event')).dy;
      expect(soonY, lessThan(laterY));
    });

    testWidgets('visitor screen excludes past events', (tester) async {
      _setViewport(tester);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 3));

      final records = [
        _makeRecord(
          id: 'n-past',
          eventId: 'e1',
          eventTitle: 'Past Event',
          eventDateTime: _fmtDateTime(yesterday),
        ),
        _makeRecord(
          id: 'n-future',
          eventId: 'e2',
          eventTitle: 'Future Event',
          eventDateTime: _fmtDateTime(future),
        ),
      ];

      await tester.pumpWidget(_buildVisitorScreen(
        visitor: _makeVisitor(),
        stream: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Past Event'), findsNothing);
      expect(find.text('Future Event'), findsOneWidget);
    });

    testWidgets('NotificationRecord toMap includes all fields',
        (tester) async {
      final record = _makeRecord(
        eventId: 'evt-map',
        eventTitle: 'Map Test',
        eventLocation: 'West End',
        scheduleType: 'fallback',
        isRead: true,
      );

      final map = record.toMap();
      expect(map['eventId'], equals('evt-map'));
      expect(map['eventTitle'], equals('Map Test'));
      expect(map['eventLocation'], equals('West End'));
      expect(map['scheduleType'], equals('fallback'));
      expect(map['isRead'], isTrue);
      expect(map['userType'], equals('visitor'));
    });
  });
}
