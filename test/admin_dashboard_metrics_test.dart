import 'dart:async';

import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds baseline data into all relevant collections so every metric stream
/// has something to emit.
Future<void> _seedAll(FakeFirebaseFirestore fs) async {
  // Events: 3 total, 1 pending, 1 approved, 1 rejected
  await fs.collection('events').doc('e1').set({
    'title': 'Pending Event',
    'reviewStatus': 'pending',
  });
  await fs.collection('events').doc('e2').set({
    'title': 'Approved Event',
    'reviewStatus': 'approved',
  });
  await fs.collection('events').doc('e3').set({
    'title': 'Rejected Event',
    'reviewStatus': 'rejected',
  });

  // Event reports: 2 pending, 1 resolved
  await fs.collection('event_reports').doc('r1').set({
    'eventId': 'e2',
    'status': 'pending',
  });
  await fs.collection('event_reports').doc('r2').set({
    'eventId': 'e3',
    'status': 'pending',
  });
  await fs.collection('event_reports').doc('r3').set({
    'eventId': 'e1',
    'status': 'resolved',
  });

  // Local users: 3 total, 1 pending approval
  await fs.collection('local_users').doc('l1').set({
    'email': 'l1@test.com',
    'approvalStatus': 'pending',
  });
  await fs.collection('local_users').doc('l2').set({
    'email': 'l2@test.com',
    'approvalStatus': 'approved',
  });
  await fs.collection('local_users').doc('l3').set({
    'email': 'l3@test.com',
    'approvalStatus': 'approved',
  });

  // Visitor users: 2
  await fs.collection('visitor_users').doc('v1').set({
    'email': 'v1@test.com',
  });
  await fs.collection('visitor_users').doc('v2').set({
    'email': 'v2@test.com',
  });

  // Admins: 1
  await fs.collection('admins').doc('a1').set({
    'email': 'admin@test.com',
  });

  // App feedback: 1 pending_triage, 1 resolved
  await fs.collection('app_feedback').doc('f1').set({
    'message': 'Bug report',
    'status': 'pending_triage',
  });
  await fs.collection('app_feedback').doc('f2').set({
    'message': 'Resolved issue',
    'status': 'resolved',
  });
}

/// Collects the first value emitted by a stream.
Future<int> _first(Stream<int> stream) => stream.first;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =====================================================================
  // AC-1  The Admin dashboard displays total event counts.
  // =====================================================================
  group('AC-1: total event counts', () {
    test('totalEventsCount returns all events regardless of status', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.totalEventsCount()), 3);
    });

    test('totalEventsCount is zero when no events exist', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.totalEventsCount()), 0);
    });

    test('totalEventsCount includes pending, approved, and rejected', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('x1').set({
        'title': 'A',
        'reviewStatus': 'pending',
      });
      await fs.collection('events').doc('x2').set({
        'title': 'B',
        'reviewStatus': 'approved',
      });
      await fs.collection('events').doc('x3').set({
        'title': 'C',
        'reviewStatus': 'rejected',
      });
      await fs.collection('events').doc('x4').set({
        'title': 'D',
        'reviewStatus': 'approved',
      });

      final service = AdminDashboardService(firestore: fs);
      expect(await _first(service.totalEventsCount()), 4);
    });

    test('totalEventsCount updates when event is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalEventsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 3);

      await fs.collection('events').doc('e4').set({
        'title': 'Fourth',
        'reviewStatus': 'pending',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 4);
    });

    test('totalEventsCount updates when event is deleted', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalEventsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 3);

      await fs.collection('events').doc('e3').delete();

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);
    });

    test('totalEventsCount returns a Stream', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.totalEventsCount(), isA<Stream<int>>());
    });
  });

  // =====================================================================
  // AC-2  The Admin dashboard displays pending event counts.
  // =====================================================================
  group('AC-2: pending event counts', () {
    test('pendingEventsCount returns only events with reviewStatus pending',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // Only e1 is pending
      expect(await _first(service.pendingEventsCount()), 1);
    });

    test('pendingEventsCount is zero when all events are approved', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('a1').set({
        'title': 'Approved',
        'reviewStatus': 'approved',
      });
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.pendingEventsCount()), 0);
    });

    test('pendingEventsCount is zero when no events exist', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.pendingEventsCount()), 0);
    });

    test('pendingEventsCount does not count rejected events', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('events').doc('r1').set({
        'title': 'Rejected',
        'reviewStatus': 'rejected',
      });
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.pendingEventsCount()), 0);
    });

    test('pendingEventsCount updates when new pending event is added',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingEventsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('events').doc('e4').set({
        'title': 'New Pending',
        'reviewStatus': 'pending',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);
    });

    test('pendingEventsCount updates when pending event is approved',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingEventsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('events').doc('e1').update({
        'reviewStatus': 'approved',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);
    });

    test('pendingEventsCount returns a Stream', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.pendingEventsCount(), isA<Stream<int>>());
    });
  });

  // =====================================================================
  // AC-3  The Admin dashboard displays reported event counts.
  // =====================================================================
  group('AC-3: reported event counts', () {
    test('pendingEventReportsCount returns only pending reports', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // r1 + r2 pending, r3 resolved
      expect(await _first(service.pendingEventReportsCount()), 2);
    });

    test('pendingEventReportsCount is zero when no reports exist', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.pendingEventReportsCount()), 0);
    });

    test('resolved reports are not counted', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('event_reports').doc('r1').set({
        'eventId': 'e1',
        'status': 'resolved',
      });
      await fs.collection('event_reports').doc('r2').set({
        'eventId': 'e2',
        'status': 'resolved',
      });

      final service = AdminDashboardService(firestore: fs);
      expect(await _first(service.pendingEventReportsCount()), 0);
    });

    test('pendingEventReportsCount updates when report is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingEventReportsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);

      await fs.collection('event_reports').doc('r4').set({
        'eventId': 'e2',
        'status': 'pending',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 3);
    });

    test('pendingEventReportsCount updates when report status changes',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingEventReportsCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);

      await fs.collection('event_reports').doc('r1').update({
        'status': 'resolved',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);
    });

    test('pendingEventReportsCount returns a Stream', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.pendingEventReportsCount(), isA<Stream<int>>());
    });
  });

  // =====================================================================
  // AC-4  Displays user-related counts: Local, Visitor, Admin totals.
  // =====================================================================
  group('AC-4: user-related counts', () {
    test('totalLocalUsersCount returns all local users', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // 3 local users seeded (l1, l2, l3)
      expect(await _first(service.totalLocalUsersCount()), 3);
    });

    test('totalVisitorsCount returns all visitor users', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // 2 visitor users seeded (v1, v2)
      expect(await _first(service.totalVisitorsCount()), 2);
    });

    test('totalAdminsCount returns all admin accounts', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // 1 admin seeded (a1)
      expect(await _first(service.totalAdminsCount()), 1);
    });

    test('totalUsersCount sums Local + Visitor + Admin', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // 3 local + 2 visitor + 1 admin = 6
      expect(await _first(service.totalUsersCount()), 6);
    });

    test('pendingLocalUsersCount returns only pending approval locals',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // 1 pending local user (l1)
      expect(await _first(service.pendingLocalUsersCount()), 1);
    });

    test('user counts are zero when collections are empty', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.totalLocalUsersCount()), 0);
      expect(await _first(service.totalVisitorsCount()), 0);
      expect(await _first(service.totalAdminsCount()), 0);
      expect(await _first(service.totalUsersCount()), 0);
      expect(await _first(service.pendingLocalUsersCount()), 0);
    });

    test('totalUsersCount updates when visitor is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 6);

      await fs.collection('visitor_users').doc('v3').set({
        'email': 'v3@test.com',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 7);
    });

    test('totalUsersCount updates when local user is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 6);

      await fs.collection('local_users').doc('l4').set({
        'email': 'l4@test.com',
        'approvalStatus': 'approved',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 7);
    });

    test('totalUsersCount updates when admin is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 6);

      await fs.collection('admins').doc('a2').set({
        'email': 'admin2@test.com',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 7);
    });

    test('pendingLocalUsersCount updates when pending user is added',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingLocalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('local_users').doc('l4').set({
        'email': 'l4@test.com',
        'approvalStatus': 'pending',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);
    });

    test('pendingLocalUsersCount updates when user is approved', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingLocalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('local_users').doc('l1').update({
        'approvalStatus': 'approved',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);
    });

    test('totalVisitorsCount returns a Stream', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.totalVisitorsCount(), isA<Stream<int>>());
    });

    test('totalAdminsCount returns a Stream', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.totalAdminsCount(), isA<Stream<int>>());
    });
  });

  // =====================================================================
  // AC-5  Dashboard updates summaries from service-backed data streams.
  // =====================================================================
  group('AC-5: updates from service-backed data streams', () {
    test('all metric methods return streams backed by Firestore snapshots',
        () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service.totalEventsCount(), isA<Stream<int>>());
      expect(service.pendingEventsCount(), isA<Stream<int>>());
      expect(service.pendingEventReportsCount(), isA<Stream<int>>());
      expect(service.pendingFeedbackCount(), isA<Stream<int>>());
      expect(service.totalLocalUsersCount(), isA<Stream<int>>());
      expect(service.totalVisitorsCount(), isA<Stream<int>>());
      expect(service.totalAdminsCount(), isA<Stream<int>>());
      expect(service.totalUsersCount(), isA<Stream<int>>());
      expect(service.pendingLocalUsersCount(), isA<Stream<int>>());
    });

    test('pendingFeedbackCount returns only pending_triage feedback',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // f1 is pending_triage, f2 is resolved
      expect(await _first(service.pendingFeedbackCount()), 1);
    });

    test('pendingFeedbackCount is zero when no feedback exists', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(await _first(service.pendingFeedbackCount()), 0);
    });

    test('pendingFeedbackCount updates when feedback is added', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingFeedbackCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('app_feedback').doc('f3').set({
        'message': 'New issue',
        'status': 'pending_triage',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 2);
    });

    test('pendingFeedbackCount updates when feedback is resolved', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.pendingFeedbackCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 1);

      await fs.collection('app_feedback').doc('f1').update({
        'status': 'resolved',
      });

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);
    });

    test('multiple simultaneous data changes produce correct counts',
        () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      final totalEvents = <int>[];
      final pendingEvents = <int>[];
      final subTotal = service.totalEventsCount().listen(totalEvents.add);
      final subPending = service.pendingEventsCount().listen(pendingEvents.add);
      addTearDown(subTotal.cancel);
      addTearDown(subPending.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(totalEvents.last, 0);
      expect(pendingEvents.last, 0);

      // Add 5 events in rapid succession
      for (int i = 1; i <= 5; i++) {
        await fs.collection('events').doc('rapid_$i').set({
          'title': 'Event $i',
          'reviewStatus': i.isOdd ? 'pending' : 'approved',
        });
      }

      await Future<void>.delayed(Duration.zero);
      expect(totalEvents.last, 5);
      expect(pendingEvents.last, 3); // 3 odd numbers (1,3,5)
    });

    test('deleting a pending event updates both total and pending', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final totalValues = <int>[];
      final pendingValues = <int>[];
      final subT = service.totalEventsCount().listen(totalValues.add);
      final subP = service.pendingEventsCount().listen(pendingValues.add);
      addTearDown(subT.cancel);
      addTearDown(subP.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(totalValues.last, 3);
      expect(pendingValues.last, 1);

      // Delete the pending event
      await fs.collection('events').doc('e1').delete();

      await Future<void>.delayed(Duration.zero);
      expect(totalValues.last, 2);
      expect(pendingValues.last, 0);
    });

    test('service accepts injectable FirebaseFirestore', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      expect(service, isNotNull);
    });
  });

  // =====================================================================
  // AC-6  Metrics displayed in real-time, accessible with minimal delay.
  // =====================================================================
  group('AC-6: real-time display with minimal delay', () {
    test('streams emit initial values with zero manual delay', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // All streams should emit on first listen without artificial delay
      final results = await Future.wait([
        _first(service.totalEventsCount()),
        _first(service.pendingEventsCount()),
        _first(service.pendingEventReportsCount()),
        _first(service.pendingFeedbackCount()),
        _first(service.totalLocalUsersCount()),
        _first(service.totalVisitorsCount()),
        _first(service.totalAdminsCount()),
        _first(service.pendingLocalUsersCount()),
      ]);

      expect(results[0], 3); // total events
      expect(results[1], 1); // pending events
      expect(results[2], 2); // reported events
      expect(results[3], 1); // pending feedback
      expect(results[4], 3); // local users
      expect(results[5], 2); // visitor users
      expect(results[6], 1); // admins
      expect(results[7], 1); // pending local approvals
    });

    test('totalUsersCount emits initial value promptly', () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      // Combined stream also emits without manual delay
      expect(await _first(service.totalUsersCount()), 6);
    });

    test('streams react to data mutation within one event loop tick',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedAll(fs);
      final service = AdminDashboardService(firestore: fs);

      final completer = Completer<int>();
      var emitCount = 0;
      final sub = service.totalEventsCount().listen((v) {
        emitCount++;
        // After second emission (the update), complete.
        if (emitCount == 2) completer.complete(v);
      });
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);

      // Mutate
      await fs.collection('events').doc('newEvt').set({
        'title': 'Instant',
        'reviewStatus': 'approved',
      });

      final updatedCount = await completer.future;
      expect(updatedCount, 4);
    });

    test('each metric stream is independent', () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      // Subscribe to two streams
      final eventValues = <int>[];
      final userValues = <int>[];
      final subE = service.totalEventsCount().listen(eventValues.add);
      final subU = service.totalLocalUsersCount().listen(userValues.add);
      addTearDown(subE.cancel);
      addTearDown(subU.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(eventValues.last, 0);
      expect(userValues.last, 0);

      // Only add an event
      await fs.collection('events').doc('x1').set({
        'title': 'Test',
        'reviewStatus': 'pending',
      });

      await Future<void>.delayed(Duration.zero);
      expect(eventValues.last, 1);
      // User count unchanged
      expect(userValues.last, 0);
    });

    test('all 9 metric methods exist on AdminDashboardService', () {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      // Verify all methods are callable
      expect(service.totalEventsCount, isA<Function>());
      expect(service.pendingEventsCount, isA<Function>());
      expect(service.pendingEventReportsCount, isA<Function>());
      expect(service.pendingFeedbackCount, isA<Function>());
      expect(service.totalLocalUsersCount, isA<Function>());
      expect(service.totalVisitorsCount, isA<Function>());
      expect(service.totalAdminsCount, isA<Function>());
      expect(service.totalUsersCount, isA<Function>());
      expect(service.pendingLocalUsersCount, isA<Function>());
    });

    test('totalUsersCount correctly combines three independent streams',
        () async {
      final fs = FakeFirebaseFirestore();
      final service = AdminDashboardService(firestore: fs);

      final values = <int>[];
      final sub = service.totalUsersCount().listen(values.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values.last, 0);

      // Add one of each type
      await fs.collection('local_users').doc('l1').set({
        'email': 'l@test.com',
        'approvalStatus': 'approved',
      });
      await Future<void>.delayed(Duration.zero);

      await fs.collection('visitor_users').doc('v1').set({
        'email': 'v@test.com',
      });
      await Future<void>.delayed(Duration.zero);

      await fs.collection('admins').doc('a1').set({
        'email': 'a@test.com',
      });
      await Future<void>.delayed(Duration.zero);

      expect(values.last, 3);
    });
  });
}
