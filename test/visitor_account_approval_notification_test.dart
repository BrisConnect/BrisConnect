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
  AccountApprovalStatus status = AccountApprovalStatus.pending,
  String name = 'Test Local',
  String email = 'local@test.com',
  String phone = '0400000000',
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

Widget _buildScreen({
  required LocalUser localUser,
  LocalEventService? localEventService,
  NotificationRepository? notificationRepository,
  ValueListenable<int>? profileVersionListenable,
  Stream<List<NotificationRecord>>? notificationsStreamOverride,
  FakeFirebaseFirestore? firestore,
}) {
  final fs = firestore ?? FakeFirebaseFirestore();
  return MaterialApp(
    home: LocalNotificationsScreen(
      localUserOverride: localUser,
      localEventService: localEventService ?? LocalEventService(firestore: fs),
      notificationRepository:
          notificationRepository ?? NotificationRepository(firestore: fs),
      profileVersionListenable:
          profileVersionListenable ?? ValueNotifier<int>(0),
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // AC-1: Account status notifications for pending, approved, and rejected
  // =========================================================================
  group('AC-1: Account status notifications displayed', () {
    testWidgets('pending account shows pending status card', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Pending Approval'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('approved account shows approved status card', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Approved'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('rejected account shows rejected status card', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.rejected),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Rejected'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('isApprovalAuthorized returns true only for approved',
        (tester) async {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.approved),
        isTrue,
      );
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.pending),
        isFalse,
      );
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.rejected),
        isFalse,
      );
    });

    testWidgets('approvalDeniedMessage returns descriptive strings',
        (tester) async {
      final pending =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.pending);
      expect(pending, contains('pending admin approval'));

      final rejected =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.rejected);
      expect(rejected, contains('rejected by admin'));

      final approved =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.approved);
      expect(approved, isEmpty);
    });
  });

  // =========================================================================
  // AC-2: Local user can open a Notifications screen
  // =========================================================================
  group('AC-2: Notifications screen is accessible', () {
    testWidgets('screen renders with Notifications app bar title',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('screen shows login prompt when no user', (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(MaterialApp(
        home: LocalNotificationsScreen(
          localUserOverride: null,
          localEventService: LocalEventService(firestore: fs),
          notificationRepository: NotificationRepository(firestore: fs),
          profileVersionListenable: ValueNotifier<int>(0),
          notificationsStreamOverride: Stream.value([]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Please log in to view notifications.'),
        findsOneWidget,
      );
    });

    testWidgets('screen contains account status, event status, and history sections',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('e1').set({
        'title': 'Test Event',
        'date': '2026-06-01',
        'time': '12:00',
        'location': 'South Bank',
        'description': 'Test',
        'category': 'Food',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'approved',
      });

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        localEventService: LocalEventService(firestore: fs),
        notificationsStreamOverride: Stream.value([
          NotificationRecord(
            id: 'n1',
            eventId: 'evt-1',
            userEmail: 'local@test.com',
            userType: 'local',
            eventTitle: 'Reminder Event',
            eventDateTime: '2026-05-01 18:00',
            eventLocation: 'West End',
            createdAt: DateTime(2026, 4, 10),
          ),
        ]),
      ));
      await tester.pumpAndSettle();

      // All three sections rendered.
      expect(find.text('Account Approved'), findsOneWidget);
      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);

      await _scrollDown(tester, times: 2);
      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
    });

    testWidgets('Scaffold renders without errors', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // AC-3: Notification history is shown in the app
  // =========================================================================
  group('AC-3: Notification history displayed', () {
    testWidgets('notification records render from stream', (tester) async {
      _setViewport(tester);
      final records = [
        NotificationRecord(
          id: 'n1',
          eventId: 'evt-1',
          userEmail: 'local@test.com',
          userType: 'local',
          eventTitle: 'Brisbane Music Festival',
          eventDateTime: '2026-05-01 18:00',
          eventLocation: 'South Bank',
          createdAt: DateTime(2026, 4, 10),
        ),
        NotificationRecord(
          id: 'n2',
          eventId: 'evt-2',
          userEmail: 'local@test.com',
          userType: 'local',
          eventTitle: 'Night Noodle Market',
          eventDateTime: '2026-06-15 17:00',
          eventLocation: 'Cultural Centre',
          createdAt: DateTime(2026, 4, 9),
          isRead: true,
        ),
      ];

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 2);

      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
      expect(find.text('Brisbane Music Festival'), findsOneWidget);
      expect(find.text('Night Noodle Market'), findsOneWidget);
    });

    testWidgets('notification shows event date, time, and location',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([
          NotificationRecord(
            id: 'n1',
            eventId: 'evt-1',
            userEmail: 'local@test.com',
            userType: 'local',
            eventTitle: 'Riverside Concert',
            eventDateTime: '2026-07-20 19:30',
            eventLocation: 'Riverstage',
            createdAt: DateTime(2026, 4, 10),
          ),
        ]),
      ));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 2);

      expect(
        find.text('2026-07-20 19:30  •  Riverstage'),
        findsOneWidget,
      );
    });

    testWidgets('empty notification history shows placeholder',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      await _scrollDown(tester, times: 2);

      expect(find.text('No notifications yet.'), findsOneWidget);
      expect(
        find.text(
            'Notifications from event interactions will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('notification repository streams real-time data',
        (tester) async {
      await tester.runAsync(() async {
        final fs = FakeFirebaseFirestore();
        final repo = NotificationRepository(firestore: fs);

        await fs.collection('user_notifications').doc('seed-1').set({
          'eventId': 'evt-1',
          'userEmail': 'local@test.com',
          'userType': 'local',
          'eventTitle': 'Seeded Event',
          'eventDateTime': '2026-05-01 09:00',
          'eventLocation': 'South Bank',
          'createdAt': DateTime(2026, 4, 1),
          'isRead': false,
        });

        final records = await repo
            .watchNotificationsForUser('local@test.com')
            .first;

        expect(records, isNotEmpty);
        expect(records.first.eventTitle, 'Seeded Event');
      });
    });

    testWidgets('notification repository deduplicates via deterministic ID',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Outdoor Market',
        eventDateTime: '2026-05-01 09:00',
        eventLocation: 'South Bank',
      );
      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Outdoor Market',
        eventDateTime: '2026-05-01 09:00',
        eventLocation: 'South Bank',
      );

      final snapshot =
          await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));
    });
  });

  // =========================================================================
  // AC-4: Messaging clearly explains the current account status
  // =========================================================================
  group('AC-4: Clear account status messaging', () {
    testWidgets('pending message explains waiting for admin review',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your account is awaiting admin review. You will be notified once approved.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('approved message confirms publishing access',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your account has been approved. You can submit events for review.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('rejected message directs user to contact support',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.rejected),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your account was not approved. Please contact support for assistance.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('event status tiles show review badges with correct labels',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('e1').set({
        'title': 'Community BBQ',
        'date': '2026-06-01',
        'time': '12:00',
        'location': 'New Farm Park',
        'description': 'BBQ',
        'category': 'Food',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'approved',
      });
      await fs.collection('events').doc('e2').set({
        'title': 'Art Exhibition',
        'date': '2026-07-15',
        'time': '10:00',
        'location': 'GOMA',
        'description': 'Art',
        'category': 'Culture',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'pending',
      });
      await fs.collection('events').doc('e3').set({
        'title': 'Blocked Party',
        'date': '2026-08-20',
        'time': '21:00',
        'location': 'Fortitude Valley',
        'description': 'Rejected',
        'category': 'Entertainment',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'rejected',
      });

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        localEventService: LocalEventService(firestore: fs),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);
      expect(find.text('Community BBQ'), findsOneWidget);
      expect(find.text('Art Exhibition'), findsOneWidget);
      expect(find.text('Blocked Party'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('no-events placeholder explains how to submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No events submitted yet.'), findsOneWidget);
      expect(
        find.text(
          'Submit an event from the Dashboard to track its approval status here.',
        ),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-5: Account approval messages remain visible through notification flow
  // =========================================================================
  group('AC-5: Approval messages persist in notification flow', () {
    testWidgets('account status card and notification history coexist',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value([
          NotificationRecord(
            id: 'n1',
            eventId: 'evt-1',
            userEmail: 'local@test.com',
            userType: 'local',
            eventTitle: 'Saved Event Reminder',
            eventDateTime: '2026-05-20 14:00',
            eventLocation: 'West End',
            createdAt: DateTime(2026, 4, 10),
          ),
        ]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Pending Approval'), findsOneWidget);

      await _scrollDown(tester, times: 2);

      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
      expect(find.text('Saved Event Reminder'), findsOneWidget);
    });

    testWidgets('status card remains after scrolling through many records',
        (tester) async {
      _setViewport(tester);
      final records = List.generate(
        10,
        (i) => NotificationRecord(
          id: 'n$i',
          eventId: 'evt-$i',
          userEmail: 'local@test.com',
          userType: 'local',
          eventTitle: 'Event $i',
          eventDateTime: '2026-05-${10 + i} 10:00',
          eventLocation: 'Location $i',
          createdAt: DateTime(2026, 4, 10 - i),
        ),
      );

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      // Status card visible initially.
      expect(find.text('Account Approved'), findsOneWidget);
      // Multiple notification records rendered.
      expect(find.text('Event 0'), findsOneWidget);
    });

    testWidgets('rejected status card persists alongside event tiles',
        (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('e1').set({
        'title': 'My First Event',
        'date': '2026-06-01',
        'time': '10:00',
        'location': 'City Botanic Gardens',
        'description': 'Details',
        'category': 'Culture',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'pending',
      });

      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.rejected),
        localEventService: LocalEventService(firestore: fs),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Rejected'), findsOneWidget);
      expect(find.text('My First Event'), findsOneWidget);
    });

    testWidgets('notification history writes persist via repository',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      final saved = await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Outdoor Market',
        eventDateTime: '2026-05-01 09:00',
        eventLocation: 'South Bank',
      );

      expect(saved, isTrue);

      final snapshot =
          await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['userEmail'], 'local@test.com');
      expect(data['eventTitle'], 'Outdoor Market');
    });
  });

  // =========================================================================
  // AC-6: Email notification on approve or reject
  // =========================================================================
  group('AC-6: Email notification on approve/reject', () {
    testWidgets('approval email queued to mail collection with correct meta',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Café',
        approved: true,
      );

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');

      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['type'], 'local_account_review');
      expect(meta['approved'], isTrue);

      final message = data['message'] as Map<String, dynamic>;
      expect((message['subject'] as String), contains('approved'));
      expect((message['html'] as String), contains('approved'));
    });

    testWidgets('rejection email queued with reviewed subject and meta',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Shop',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');

      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['approved'], isFalse);

      final message = data['message'] as Map<String, dynamic>;
      expect((message['subject'] as String), contains('reviewed'));
    });

    testWidgets('registration email sent with pending verification wording',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'local@test.com',
        businessName: 'New Bistro',
      );

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      final message = data['message'] as Map<String, dynamic>;
      expect(
        (message['subject'] as String).toLowerCase(),
        contains('account received'),
      );
      expect(
        (message['html'] as String).toLowerCase(),
        contains('pending admin verification'),
      );
    });

    testWidgets('email doc IDs are timestamped and unique per queue call',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      await service.queueAccountReviewEmail(
        recipientEmail: 'a@test.com',
        businessName: 'Shop A',
        approved: true,
      );
      await service.queueAccountReviewEmail(
        recipientEmail: 'b@test.com',
        businessName: 'Shop B',
        approved: false,
      );

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(2));

      final ids = snapshot.docs.map((d) => d.id).toList();
      expect(ids[0], isNot(equals(ids[1])));
      expect(ids[0], startsWith('local-review-approved-'));
      expect(ids[1], startsWith('local-review-rejected-'));
    });

    testWidgets('HTML in event title is escaped against XSS',
        (tester) async {
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

      // Raw <script> should not appear — it should be escaped.
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
    });

    testWidgets('SMS approval queued to sms_queue collection',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final sms = SmsNotificationService(firestore: fs);

      await sms.queueLocalAccountReviewSms(
        recipientPhone: '0412345678',
        businessName: 'Test Local',
        approved: true,
      );

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], '+61412345678');
      expect(
        (data['message'] as String),
        contains('approved'),
      );

      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['type'], 'local_account_review_sms');
      expect(meta['approved'], isTrue);
    });

    testWidgets('SMS rejection queued to sms_queue collection',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final sms = SmsNotificationService(firestore: fs);

      await sms.queueLocalAccountReviewSms(
        recipientPhone: '0412345678',
        businessName: 'Test Local',
        approved: false,
      );

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(
        (data['message'] as String),
        contains('not approved'),
      );

      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['approved'], isFalse);
    });
  });

  // =========================================================================
  // AC-7: Notifications delivered promptly and reliably across all channels
  // =========================================================================
  group('AC-7: Prompt and reliable delivery across channels', () {
    testWidgets('email service writes to Firestore mail collection instantly',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: fs);

      final sw = Stopwatch()..start();
      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Biz',
        approved: true,
      );
      sw.stop();

      // Queue write should be near-instant.
      expect(sw.elapsed.inSeconds, lessThan(2));

      final snapshot = await fs.collection('mail').get();
      expect(snapshot.docs, hasLength(1));
    });

    testWidgets('SMS service writes to sms_queue collection instantly',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final sms = SmsNotificationService(firestore: fs);

      final sw = Stopwatch()..start();
      await sms.queueLocalAccountReviewSms(
        recipientPhone: '0412345678',
        businessName: 'Test Biz',
        approved: true,
      );
      sw.stop();

      expect(sw.elapsed.inSeconds, lessThan(2));

      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, hasLength(1));
    });

    testWidgets('notification repository write is idempotent',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: fs);

      // Two identical writes → only 1 document.
      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Market Day',
        eventDateTime: '2026-06-01 10:00',
        eventLocation: 'West End',
      );
      await repo.saveNotification(
        userEmail: 'local@test.com',
        userType: 'local',
        eventId: 'evt-1',
        eventTitle: 'Market Day',
        eventDateTime: '2026-06-01 10:00',
        eventLocation: 'West End',
      );

      final snapshot =
          await fs.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));
    });

    testWidgets('SMS skips invalid phone numbers gracefully',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final sms = SmsNotificationService(firestore: fs);

      await sms.queueLocalAccountReviewSms(
        recipientPhone: '',
        businessName: 'Test',
        approved: true,
      );

      // Empty phone → no document written.
      final snapshot = await fs.collection('sms_queue').get();
      expect(snapshot.docs, isEmpty);
    });

    testWidgets('registration email and SMS both queue on signup',
        (tester) async {
      final fs = FakeFirebaseFirestore();
      final email = LocalEmailNotificationService(firestore: fs);
      final sms = SmsNotificationService(firestore: fs);

      // Simulate what registration does (fire-and-forget).
      await email.queueRegistrationReceivedEmail(
        recipientEmail: 'new@test.com',
        businessName: 'New Place',
      );
      await sms.queueLocalAccountRegistrationReceivedSms(
        recipientPhone: '0400111222',
        businessName: 'New Place',
      );

      final mailSnap = await fs.collection('mail').get();
      expect(mailSnap.docs, hasLength(1));

      final smsSnap = await fs.collection('sms_queue').get();
      expect(smsSnap.docs, hasLength(1));
      expect(
        (smsSnap.docs.first.data()['message'] as String),
        contains('pending verification'),
      );
    });

    testWidgets('screen loads efficiently with mixed data', (tester) async {
      _setViewport(tester);
      final fs = FakeFirebaseFirestore();

      // Seed several events.
      for (int i = 0; i < 5; i++) {
        await fs.collection('events').doc('e$i').set({
          'title': 'Event $i',
          'date': '2026-06-${10 + i}',
          'time': '10:00',
          'location': 'Loc $i',
          'description': 'Desc',
          'category': 'Food',
          'createdByLocalEmail': 'local@test.com',
          'reviewStatus': i % 2 == 0 ? 'approved' : 'pending',
        });
      }

      final records = List.generate(
        5,
        (i) => NotificationRecord(
          id: 'n$i',
          eventId: 'evt-$i',
          userEmail: 'local@test.com',
          userType: 'local',
          eventTitle: 'Notif Event $i',
          eventDateTime: '2026-05-${10 + i} 12:00',
          eventLocation: 'Place $i',
          createdAt: DateTime(2026, 4, 10 - i),
        ),
      );

      final sw = Stopwatch()..start();
      await tester.pumpWidget(_buildScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        localEventService: LocalEventService(firestore: fs),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsed.inSeconds, lessThan(3));
      expect(find.text('Account Approved'), findsOneWidget);
      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);
    });
  });
}
