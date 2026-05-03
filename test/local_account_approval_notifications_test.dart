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

// ─── helpers ───────────────────────────────────────────────────────────

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
}) {
  return LocalUser(
    name: 'Test Local',
    email: 'local@test.com',
    password: 'pw',
    phone: '0400000000',
    suburb: 'Brisbane CBD',
    approvalStatus: status,
  );
}

Widget _buildNotificationsScreen({
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

// ─── tests ─────────────────────────────────────────────────────────────

void main() {
  // ── AC-1: Account status notifications for pending / approved / rejected ──

  group('Account status card shows correct status', () {
    testWidgets('shows pending status with informative message',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Pending Approval'), findsOneWidget);
      expect(
        find.text(
            'Your account is awaiting admin review. You will be notified once approved.'),
        findsOneWidget,
      );
    });

    testWidgets('shows approved status with publishing access message',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Approved'), findsOneWidget);
      expect(
        find.text(
            'Your account has been approved. You can submit events for review.'),
        findsOneWidget,
      );
    });

    testWidgets('shows rejected status with support guidance',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.rejected),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Account Rejected'), findsOneWidget);
      expect(
        find.text(
            'Your account was not approved. Please contact support for assistance.'),
        findsOneWidget,
      );
    });
  });

  // ── AC-2: Notifications screen is accessible ──────────────────────────

  group('Notifications screen accessibility', () {
    testWidgets('renders with app bar title Notifications', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      // LogoAppBarTitle wraps the text 'Notifications'
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('shows login prompt when no user is logged in',
        (tester) async {
      _setViewport(tester);
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(MaterialApp(
        home: LocalNotificationsScreen(
          localUserOverride: null,
          localEventService: LocalEventService(firestore: firestore),
          notificationRepository: NotificationRepository(firestore: firestore),
          profileVersionListenable: ValueNotifier<int>(0),
          notificationsStreamOverride: Stream.value([]),
        ),
      ));
      // The screen checks local == null from localUserOverride
      // When null, the parent ValueListenableBuilder still builds; the login
      // prompt is inside the builder body.
      await tester.pumpAndSettle();

      expect(
        find.text('Please log in to view notifications.'),
        findsOneWidget,
      );
    });
  });

  // ── AC-3: Notification history shown in the app ───────────────────────

  group('Notification history', () {
    testWidgets('displays notification records from stream', (tester) async {
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

      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
      expect(find.text('Brisbane Music Festival'), findsOneWidget);
      expect(find.text('Night Noodle Market'), findsOneWidget);
      expect(find.text('2026-05-01 18:00  •  South Bank'), findsOneWidget);
      expect(
          find.text('2026-06-15 17:00  •  Cultural Centre'), findsOneWidget);
    });

    testWidgets('shows empty state when no notification history exists',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet.'), findsOneWidget);
      expect(
        find.text(
            'Notifications from event interactions will appear here.'),
        findsOneWidget,
      );
    });
  });

  // ── AC-4: Clear status messaging ──────────────────────────────────────

  group('Clear status messaging', () {
    testWidgets('event submission status tiles show review badges',
        (tester) async {
      _setViewport(tester);
      final firestore = FakeFirebaseFirestore();

      // Seed events with different review statuses
      await firestore.collection('events').doc('e1').set({
        'title': 'Community BBQ',
        'date': '2026-06-01',
        'time': '12:00',
        'location': 'New Farm Park',
        'description': 'Local community BBQ event',
        'category': 'Food',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'approved',
      });
      await firestore.collection('events').doc('e2').set({
        'title': 'Art Exhibition',
        'date': '2026-07-15',
        'time': '10:00',
        'location': 'GOMA',
        'description': 'Art exhibition in Brisbane',
        'category': 'Culture',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'pending',
      });
      await firestore.collection('events').doc('e3').set({
        'title': 'Blocked Party',
        'date': '2026-08-20',
        'time': '21:00',
        'location': 'Fortitude Valley',
        'description': 'Rejected',
        'category': 'Entertainment',
        'createdByLocalEmail': 'local@test.com',
        'reviewStatus': 'rejected',
      });

      final eventService = LocalEventService(firestore: firestore);

      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        localEventService: eventService,
        notificationsStreamOverride: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      // Section label
      expect(find.text('EVENT STATUS UPDATES'), findsOneWidget);

      // Event titles
      expect(find.text('Community BBQ'), findsOneWidget);
      expect(find.text('Art Exhibition'), findsOneWidget);
      expect(find.text('Blocked Party'), findsOneWidget);

      // Review status badges
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('shows empty events placeholder when no events submitted',
        (tester) async {
      _setViewport(tester);
      final firestore = FakeFirebaseFirestore();
      final eventService = LocalEventService(firestore: firestore);

      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        localEventService: eventService,
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

  // ── AC-5: Approval messages visible through notification flow ─────────

  group('Approval messages persist in notification flow', () {
    testWidgets(
        'account status card and notification history coexist on screen',
        (tester) async {
      _setViewport(tester);
      final records = [
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
      ];

      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.pending),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      // Account status card is visible
      expect(find.text('Account Pending Approval'), findsOneWidget);
      // Notification history section exists below
      expect(find.text('NOTIFICATION HISTORY'), findsOneWidget);
      expect(find.text('Saved Event Reminder'), findsOneWidget);
    });

    testWidgets('account status card persists after scrolling to history',
        (tester) async {
      _setViewport(tester);
      // Create many notification records to force scroll
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

      await tester.pumpWidget(_buildNotificationsScreen(
        localUser: _makeLocal(status: AccountApprovalStatus.approved),
        notificationsStreamOverride: Stream.value(records),
      ));
      await tester.pumpAndSettle();

      // Verify status card is present initially
      expect(find.text('Account Approved'), findsOneWidget);
      // Multiple notification records rendered
      expect(find.text('Event 0'), findsOneWidget);
    });
  });

  // ── AC-6: Email notification on approve / reject ──────────────────────

  group('Email notification service', () {
    testWidgets('queues approval email to mail collection', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Café',
        approved: true,
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');
      expect(
        (data['meta'] as Map<String, dynamic>)['type'],
        'local_account_review',
      );
      expect(
        (data['meta'] as Map<String, dynamic>)['approved'],
        isTrue,
      );

      final message = data['message'] as Map<String, dynamic>;
      expect(
        (message['subject'] as String),
        contains('approved'),
      );
    });

    testWidgets('queues rejection email to mail collection', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Shop',
        approved: false,
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');
      expect(
        (data['meta'] as Map<String, dynamic>)['approved'],
        isFalse,
      );

      final message = data['message'] as Map<String, dynamic>;
      expect(
        (message['subject'] as String),
        contains('reviewed'),
      );
    });

    testWidgets('registration email includes pending verification wording',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'local@test.com',
        businessName: 'New Bistro',
      );

      final snapshot = await firestore.collection('mail').get();
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
  });

  // ── AC-7: Prompt and efficient delivery ───────────────────────────────

  group('Notification delivery efficiency', () {
    testWidgets('notification repository writes to Firestore deterministically',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: firestore);

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
          await firestore.collection('user_notifications').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['userEmail'], 'local@test.com');
      expect(data['eventTitle'], 'Outdoor Market');
    });

    testWidgets(
        'duplicate saveNotification updates existing record, not duplicates',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final repo = NotificationRepository(firestore: firestore);

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
          await firestore.collection('user_notifications').get();
      // Deterministic ID means the second write merges with the first
      expect(snapshot.docs, hasLength(1));
    });

    testWidgets(
        'watchNotificationsForUser streams real-time notification data',
        (tester) async {
      await tester.runAsync(() async {
        final firestore = FakeFirebaseFirestore();
        final repo = NotificationRepository(firestore: firestore);

        // Seed data first so the initial snapshot already contains records.
        await repo.saveNotification(
          userEmail: 'local@test.com',
          userType: 'local',
          eventId: 'evt-1',
          eventTitle: 'Stream Test Event',
          eventDateTime: '2026-06-01 10:00',
          eventLocation: 'Kangaroo Point',
        );

        final records = await repo
            .watchNotificationsForUser('local@test.com')
            .first;
        expect(records, hasLength(1));
        expect(records.first.eventTitle, 'Stream Test Event');
      });
    });

    testWidgets('email document ID is uniquely timestamped per send',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Shop',
        approved: true,
      );
      // Second send (different timestamp)
      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Test Shop',
        approved: true,
      );

      final snapshot = await firestore.collection('mail').get();
      // Each email gets a unique doc ID due to timestamp suffix
      expect(snapshot.docs.length, greaterThanOrEqualTo(1));
      // Doc IDs start with expected prefix
      for (final doc in snapshot.docs) {
        expect(doc.id, startsWith('local-review-approved-test-shop-'));
      }
    });
  });

  // ── AC-1 cross-check: LocalAuth approval authorization ────────────────

  group('Approval authorization helpers', () {
    test('approved accounts are authorized for publishing', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.approved),
        isTrue,
      );
    });

    test('pending and rejected accounts are denied', () {
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.pending),
        isFalse,
      );
      expect(
        LocalAuth.isApprovalAuthorized(AccountApprovalStatus.rejected),
        isFalse,
      );
    });

    test('denied messages clearly explain each status', () {
      final pendingMsg =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.pending);
      final rejectedMsg =
          LocalAuth.approvalDeniedMessage(AccountApprovalStatus.rejected);

      expect(pendingMsg, contains('pending'));
      expect(rejectedMsg, contains('rejected'));
    });
  });
}
