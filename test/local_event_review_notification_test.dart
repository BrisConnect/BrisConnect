import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/screens/local_notifications_screen.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:brisconnect/services/notification_repository.dart';
import 'package:brisconnect/services/sms_notification_service.dart';

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
  String name = 'Test Local',
  String email = 'local@test.com',
  String phone = '0412345678',
}) {
  return LocalUser(
    name: name,
    email: email,
    password: 'pw',
    phone: phone,
    suburb: 'Brisbane CBD',
    approvalStatus: status,
  );
}

/// Seeds events into the 'events' collection for the given local email.
Future<void> _seedEvents(
  FakeFirebaseFirestore firestore,
  String localEmail,
  List<Map<String, dynamic>> events,
) async {
  for (final e in events) {
    await firestore.collection('events').doc(e['id'] as String).set({
      'title': e['title'],
      'date': e['date'] ?? '',
      'time': e['time'] ?? '',
      'category': e['category'] ?? 'General',
      'location': e['location'] ?? 'Brisbane',
      'description': e['description'] ?? '',
      'reviewStatus': e['reviewStatus'] ?? 'pending',
      'createdByLocalEmail': localEmail.trim().toLowerCase(),
    });
  }
}

Widget _buildScreen({
  required LocalUser localUser,
  FakeFirebaseFirestore? firestore,
  LocalEventService? localEventService,
  NotificationRepository? notificationRepository,
  Stream<List<NotificationRecord>>? notificationsStreamOverride,
}) {
  final fs = firestore ?? FakeFirebaseFirestore();
  return MaterialApp(
    home: LocalNotificationsScreen(
      localUserOverride: localUser,
      localEventService: localEventService ?? LocalEventService(firestore: fs),
      notificationRepository:
          notificationRepository ?? NotificationRepository(firestore: fs),
      profileVersionListenable: ValueNotifier<int>(0),
      notificationsStreamOverride: notificationsStreamOverride,
    ),
  );
}

/// Scroll down in the primary ListView.
Future<void> _scrollDown(WidgetTester tester, {int times = 1}) async {
  for (int i = 0; i < times; i++) {
    await tester.dragFrom(const Offset(400, 600), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

NotificationRecord _makeNotification({
  String id = 'n1',
  String eventId = 'ev1',
  String userEmail = 'local@test.com',
  String userType = 'local',
  String eventTitle = 'River Festival',
  String eventDateTime = '2026-05-01 10:00',
  String eventLocation = 'South Bank',
  String scheduleType = 'event_time',
  bool isRead = false,
}) {
  return NotificationRecord(
    id: id,
    eventId: eventId,
    userEmail: userEmail,
    userType: userType,
    eventTitle: eventTitle,
    eventDateTime: eventDateTime,
    eventLocation: eventLocation,
    scheduleType: scheduleType,
    createdAt: DateTime(2026, 4, 10),
    isRead: isRead,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // AC-1: Event review notifications for pending, approved, and rejected
  // =========================================================================
  group('AC-1: Event review status displayed for pending/approved/rejected',
      () {
    testWidgets('pending event shows Pending chip and schedule icon',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'River Fest',
          'date': '2026-05-01',
          'location': 'South Bank',
          'reviewStatus': 'pending',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsWidgets);
    });

    testWidgets('approved event shows Approved chip and check icon',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Art Walk',
          'date': '2026-06-15',
          'location': 'Gallery Precinct',
          'reviewStatus': 'approved',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Approved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('rejected event shows Rejected chip and cancel icon',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Test Party',
          'date': '2026-07-01',
          'location': 'Fortitude Valley',
          'reviewStatus': 'rejected',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('multiple events with different statuses all visible',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Event Alpha',
          'date': '2026-05-01',
          'location': 'CBD',
          'reviewStatus': 'pending',
        },
        {
          'id': 'e2',
          'title': 'Event Bravo',
          'date': '2026-05-02',
          'location': 'South Bank',
          'reviewStatus': 'approved',
        },
        {
          'id': 'e3',
          'title': 'Event Charlie',
          'date': '2026-05-03',
          'location': 'West End',
          'reviewStatus': 'rejected',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Event Alpha'), findsOneWidget);
      expect(find.text('Event Bravo'), findsOneWidget);
      expect(find.text('Event Charlie'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('event tile shows date and location subtitle',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Markets Morning',
          'date': '2026-08-15',
          'location': 'Jan Powers Market',
          'reviewStatus': 'approved',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('2026-08-15'), findsOneWidget);
      expect(find.textContaining('Jan Powers Market'), findsWidgets);
    });

    testWidgets('empty event list shows placeholder message', (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No events submitted yet.'), findsOneWidget);
      expect(
        find.text(
            'Submit an event from the Dashboard to track its approval status here.'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-2: Local user can view event review updates in Notifications screen
  // =========================================================================
  group('AC-2: Event review updates visible in Notifications screen', () {
    testWidgets('Event Status Updates section heading is present',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);
    });

    testWidgets('Notification History section heading is present',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      await _scrollDown(tester);
      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
    });

    testWidgets('not-logged-in user sees login prompt', (tester) async {
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

    testWidgets('events from another local user are not shown',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      // Seed events for a different local email.
      await _seedEvents(fs, 'other@test.com', [
        {
          'id': 'e-other',
          'title': 'Someone Elses Event',
          'date': '2026-10-01',
          'location': 'Elsewhere',
          'reviewStatus': 'approved',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(), // local@test.com
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Someone Elses Event'), findsNothing);
      expect(find.text('No events submitted yet.'), findsOneWidget);
    });

    testWidgets('pending events sort before approved and rejected',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Zebra Concert',
          'date': '2026-05-01',
          'location': 'CBD',
          'reviewStatus': 'approved',
        },
        {
          'id': 'e2',
          'title': 'Alpha Festival',
          'date': '2026-05-02',
          'location': 'CBD',
          'reviewStatus': 'pending',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      // Both should be visible — pending first.
      final pendingCenter =
          tester.getCenter(find.text('Alpha Festival'));
      final approvedCenter =
          tester.getCenter(find.text('Zebra Concert'));
      expect(pendingCenter.dy, lessThan(approvedCenter.dy));
    });
  });

  // =========================================================================
  // AC-3: Notification history includes event review status entries
  // =========================================================================
  group('AC-3: Notification history includes event review entries', () {
    testWidgets('notification history tile shows event title and details',
        (tester) async {
      _setViewport(tester);
      final record = _makeNotification(
        eventTitle: 'Story Bridge Run',
        eventDateTime: '2026-06-01 08:00',
        eventLocation: 'Story Bridge',
      );

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('Story Bridge Run'), findsOneWidget);
      expect(find.textContaining('2026-06-01 08:00'), findsOneWidget);
      expect(find.textContaining('Story Bridge'), findsWidgets);
    });

    testWidgets('unread notification shows active bell icon', (tester) async {
      _setViewport(tester);
      final record = _makeNotification(isRead: false);

      await tester.pumpWidget(_buildScreen(
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

    testWidgets('read notification shows outlined bell icon', (tester) async {
      _setViewport(tester);
      final record = _makeNotification(isRead: true);

      await tester.pumpWidget(_buildScreen(
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

    testWidgets('empty notification history shows placeholder',
        (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('No notifications yet.'), findsOneWidget);
      expect(
        find.text('Notifications from event interactions will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('multiple notification records render in list',
        (tester) async {
      _setViewport(tester);
      final records = [
        _makeNotification(
          id: 'n1',
          eventTitle: 'Event One',
          eventDateTime: '2026-04-01 09:00',
          eventLocation: 'Location A',
        ),
        _makeNotification(
          id: 'n2',
          eventTitle: 'Event Two',
          eventDateTime: '2026-04-02 10:00',
          eventLocation: 'Location B',
        ),
      ];

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('Event One'), findsOneWidget);
      expect(find.text('Event Two'), findsOneWidget);
    });

    testWidgets(
        'notification tile shows schedule type badge in debug mode',
        (tester) async {
      _setViewport(tester);
      final record = _makeNotification(scheduleType: 'event_time');

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      // In debug mode (kDebugMode), the schedule type badge is shown.
      if (kDebugMode) {
        expect(find.text('Schedule: Event-time'), findsOneWidget);
      }
    });

    testWidgets('fallback schedule type shows correct badge', (tester) async {
      _setViewport(tester);
      final record = _makeNotification(scheduleType: 'fallback');

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      if (kDebugMode) {
        expect(find.text('Schedule: Fallback'), findsOneWidget);
      }
    });
  });

  // =========================================================================
  // AC-4: Review message clearly explains the current event status
  // =========================================================================
  group('AC-4: Review message clearly explains event status', () {
    testWidgets('approved email contains visible-to-users text',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'River Fest',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      final html =
          (snapshot.docs.first.data()['message'] as Map)['html'] as String;

      expect(html, contains('approved'));
      expect(html, contains('River Fest'));
      expect(html, contains('visible to all users'));
    });

    testWidgets('rejected email contains contact-support text',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Bad Event',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      final html =
          (snapshot.docs.first.data()['message'] as Map)['html'] as String;

      expect(html, contains('rejected'));
      expect(html, contains('Bad Event'));
      expect(html, contains('contact support'));
    });

    testWidgets('approved email subject includes approved label',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Sunset Session',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      final subject =
          (snapshot.docs.first.data()['message'] as Map)['subject'] as String;

      expect(subject, equals('Your BrisConnect event was approved'));
    });

    testWidgets('rejected email subject includes rejected label',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Blocked Event',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      final subject =
          (snapshot.docs.first.data()['message'] as Map)['subject'] as String;

      expect(subject, equals('Your BrisConnect event was rejected'));
    });

    testWidgets('approved SMS clearly states approval', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'River Fest',
        reviewStatus: 'approved',
      );

      final snapshot = await fs.collection('sms_queue').get();
      final msg = snapshot.docs.first.data()['message'] as String;

      expect(msg, contains('River Fest'));
      expect(msg, contains('APPROVED'));
    });

    testWidgets('rejected SMS clearly states rejection', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'Bad Event',
        reviewStatus: 'rejected',
      );

      final snapshot = await fs.collection('sms_queue').get();
      final msg = snapshot.docs.first.data()['message'] as String;

      expect(msg, contains('Bad Event'));
      expect(msg, contains('REJECTED'));
    });

    testWidgets('HTML in event title is escaped in email', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: '<script>alert("xss")</script>',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      final html =
          (snapshot.docs.first.data()['message'] as Map)['html'] as String;

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
    });
  });

  // =========================================================================
  // AC-5: Notification flow works alongside account approval notifications
  // =========================================================================
  group('AC-5: Coexistence with account approval notifications', () {
    testWidgets(
        'account status card and event tiles appear on same screen',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Cozy Gig',
          'date': '2026-09-01',
          'location': 'The Tivoli',
          'reviewStatus': 'approved',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      // Account status card
      expect(find.text('Account Approved'), findsOneWidget);
      // Event section heading
      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);
      // Event tile
      expect(find.text('Cozy Gig'), findsOneWidget);
    });

    testWidgets(
        'pending account still shows event status section',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Market Morning',
          'date': '2026-08-01',
          'location': 'Jan Powers',
          'reviewStatus': 'pending',
        },
      ]);

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        firestore: fs,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Pending Approval'), findsOneWidget);
      expect(find.text('Market Morning'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets(
        'notification history section visible alongside event tiles',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await _seedEvents(fs, 'local@test.com', [
        {
          'id': 'e1',
          'title': 'Gallery Walk',
          'date': '2026-06-05',
          'location': 'GOMA',
          'reviewStatus': 'approved',
        },
      ]);
      final record = _makeNotification(eventTitle: 'Gallery Walk');

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(),
        firestore: fs,
        notificationsStreamOverride: Stream.value([record]),
      ));
      await tester.pumpAndSettle();

      // Event tile should be visible.
      expect(find.text('Gallery Walk'), findsWidgets);

      // Scroll to see notification history.
      await _scrollDown(tester);
      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
    });

    testWidgets(
        'account review email and event review email use different meta types',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final emailService = LocalEmailNotificationService(firestore: fs);

      await emailService.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Biz',
        approved: true,
      );
      await emailService.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'River Fest',
        approved: true,
      );

      final docs = (await fs.collection('mail').get()).docs;
      expect(docs.length, equals(2));

      final metaTypes =
          docs.map((d) => (d.data()['meta'] as Map)['type']).toSet();
      expect(metaTypes, contains('local_account_review'));
      expect(metaTypes, contains('local_event_review'));
    });

    testWidgets(
        'account review SMS and event review SMS use different meta types',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final smsService = SmsNotificationService(firestore: fs);

      await smsService.queueLocalAccountReviewSms(
        recipientPhone: '0412345678',
        businessName: 'Test Biz',
        approved: true,
      );
      await smsService.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'River Fest',
        reviewStatus: 'approved',
      );

      final docs = (await fs.collection('sms_queue').get()).docs;
      expect(docs.length, equals(2));

      final metaTypes =
          docs.map((d) => (d.data()['meta'] as Map)['type']).toSet();
      expect(metaTypes, contains('local_account_review_sms'));
      expect(metaTypes, contains('local_event_review_sms'));
    });
  });

  // =========================================================================
  // AC-6: Event review notifications delivered accurately and timely
  // =========================================================================
  group('AC-6: Accurate and timely event review notification delivery', () {
    testWidgets('event review email queued to mail collection',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'River Fest',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], equals('local@test.com'));
      expect((data['meta'] as Map)['type'], equals('local_event_review'));
      expect((data['meta'] as Map)['approved'], isTrue);
      expect((data['meta'] as Map)['eventTitle'], equals('River Fest'));
    });

    testWidgets('rejected event review email has correct meta',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Blocked Gig',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      final data = snapshot.docs.first.data();
      expect((data['meta'] as Map)['approved'], isFalse);
      expect((data['meta'] as Map)['eventTitle'], equals('Blocked Gig'));
    });

    testWidgets('email doc ID contains slugified event title',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'River Fest',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      final docId = snapshot.docs.first.id;

      expect(docId, startsWith('event-review-approved-'));
      expect(docId, contains('river-fest'));
    });

    testWidgets('rejected email doc ID uses rejected prefix',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Bad Show',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      final docId = snapshot.docs.first.id;

      expect(docId, startsWith('event-review-rejected-'));
      expect(docId, contains('bad-show'));
    });

    testWidgets('event review SMS queued to sms_queue collection',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'River Fest',
        reviewStatus: 'approved',
      );

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], equals('+61412345678'));
      expect(
        (data['meta'] as Map)['type'],
        equals('local_event_review_sms'),
      );
      expect(
        (data['meta'] as Map)['reviewStatus'],
        equals('approved'),
      );
    });

    testWidgets('SMS doc ID contains slugified event title', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'River Fest',
        reviewStatus: 'approved',
      );

      final snapshot = await fs.collection('sms_queue').get();
      final docId = snapshot.docs.first.id;

      expect(docId, startsWith('event-review-approved-'));
      expect(docId, contains('river-fest'));
    });

    testWidgets('phone normalised from 04xx to +614xx format',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: '0412345678',
        eventTitle: 'Norm Test',
        reviewStatus: 'approved',
      );

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs.first.data()['to'], equals('+61412345678'));
    });

    testWidgets('invalid phone skips SMS silently', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: fs);

      await service.queueLocalEventReviewSms(
        recipientPhone: 'not-a-phone',
        eventTitle: 'Skip Test',
        reviewStatus: 'approved',
      );

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, isEmpty);
    });

    testWidgets('notification repository saves event review record',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      final result = await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-123',
        eventTitle: 'River Festival',
        eventDateTime: '2026-05-01 10:00',
        eventLocation: 'South Bank',
        scheduleType: 'event_time',
      );

      expect(result, isTrue);

      final snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['eventTitle'], equals('River Festival'));
      expect(data['userType'], equals('local'));
      expect(data['eventLocation'], equals('South Bank'));
      expect(data['scheduleType'], equals('event_time'));
      expect(data['isRead'], isFalse);
    });

    testWidgets('duplicate notification merges via deterministic ID',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Same Event',
        eventDateTime: '2026-05-01',
        eventLocation: 'Place A',
      );
      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Same Event',
        eventDateTime: '2026-05-01',
        eventLocation: 'Place B',
      );

      final snapshot = await fs.collection('user_notifications').get();
      // Deterministic ID → same doc overwritten.
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['eventLocation'], equals('Place B'));
    });

    testWidgets('setReadStatus updates isRead field', (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Read Test',
        eventDateTime: '2026-05-01',
        eventLocation: 'CBD',
      );

      final docs = (await fs.collection('user_notifications').get()).docs;
      final id = docs.first.id;
      expect(docs.first.data()['isRead'], isFalse);

      await repo.setReadStatus(id, isRead: true);

      final updated =
          (await fs.collection('user_notifications').doc(id).get()).data()!;
      expect(updated['isRead'], isTrue);
    });

    testWidgets('deleteNotificationForEvent removes the document',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Delete Me',
        eventDateTime: '2026-05-01',
        eventLocation: 'CBD',
      );

      var snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      await repo.deleteNotificationForEvent(
        userEmail: 'local@test.com',
        eventTitle: 'Delete Me',
        eventDateTime: '2026-05-01',
      );

      snapshot = await fs.collection('user_notifications').get();
      expect(snapshot.docs, isEmpty);
    });

    testWidgets('watchNotificationsForUser returns stream of records',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Stream Test',
        eventDateTime: '2026-05-01',
        eventLocation: 'CBD',
      );

      final records =
          await repo.watchNotificationsForUser('local@test.com').first;
      expect(records, hasLength(1));
      expect(records.first.eventTitle, equals('Stream Test'));
      expect(records.first.userType, equals('local'));
    });

    testWidgets('NotificationRecord fromDoc and toMap round-trip',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-rt',
        eventTitle: 'Roundtrip',
        eventDateTime: '2026-06-01',
        eventLocation: 'Kangaroo Point',
        scheduleType: 'event_time',
      );

      final records =
          await repo.watchNotificationsForUser('local@test.com').first;
      final record = records.first;

      expect(record.eventId, equals('evt-rt'));
      expect(record.eventTitle, equals('Roundtrip'));
      expect(record.eventLocation, equals('Kangaroo Point'));
      expect(record.scheduleType, equals('event_time'));
      expect(record.isRead, isFalse);
    });
  });
}
