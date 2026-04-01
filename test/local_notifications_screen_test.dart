import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/models/notification_record.dart';
import 'package:brisconnect/screens/local_notifications_screen.dart';
import 'package:brisconnect/services/local_event_service.dart';

class _FakeLocalEventService extends LocalEventService {
  _FakeLocalEventService(this._stream)
      : super(firestore: FakeFirebaseFirestore());

  final Stream<List<EventItem>> _stream;

  @override
  Stream<List<EventItem>> watchSubmittedEvents(String localEmail) => _stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    required Stream<List<EventItem>> eventsStream,
  }) {
    const local = LocalUser(
      name: 'Local Tester',
      email: 'local@test.com',
      password: 'Password123',
      phone: '0400000000',
      suburb: 'Brisbane City',
      approvalStatus: AccountApprovalStatus.approved,
    );

    return MaterialApp(
      home: LocalNotificationsScreen(
        localEventService: _FakeLocalEventService(eventsStream),
        localUserOverride: local,
        profileVersionListenable: ValueNotifier<int>(0),
        notificationsStreamOverride:
            Stream<List<NotificationRecord>>.value(const []),
      ),
    );
  }

  testWidgets('renders pending approved and rejected event statuses',
      (tester) async {
    final events = <EventItem>[
      const EventItem(
        id: 'pending-event',
        title: 'Pending Event',
        date: '01/06/2026',
        time: '6:00 PM',
        location: 'South Bank',
        description: 'Waiting for review',
        reviewStatus: EventReviewStatus.pending,
        createdByLocalEmail: 'local@test.com',
      ),
      const EventItem(
        id: 'approved-event',
        title: 'Approved Event',
        date: '02/06/2026',
        time: '7:00 PM',
        location: 'New Farm',
        description: 'Approved by admin',
        reviewStatus: EventReviewStatus.approved,
        createdByLocalEmail: 'local@test.com',
      ),
      const EventItem(
        id: 'rejected-event',
        title: 'Rejected Event',
        date: '03/06/2026',
        time: '8:00 PM',
        location: 'Fortitude Valley',
        description: 'Rejected by admin',
        reviewStatus: EventReviewStatus.rejected,
        createdByLocalEmail: 'local@test.com',
      ),
    ];

    await tester.pumpWidget(
      buildApp(eventsStream: Stream<List<EventItem>>.value(events)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Event'), findsOneWidget);
    expect(find.text('Approved Event'), findsOneWidget);
    expect(find.text('Rejected Event'), findsOneWidget);

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
  });
}
