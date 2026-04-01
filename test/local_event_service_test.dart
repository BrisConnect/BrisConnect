import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/local_event_service.dart';

void main() {
  group('LocalEventService', () {
    test('watchSubmittedEvents only returns events created by this local', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('local-event').set({
        'title': 'Local Market Night',
        'date': '22/05/2026',
        'time': '6:00 PM',
        'location': 'South Bank',
        'description': 'Submitted by local user.',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
      });
      await firestore.collection('events').doc('other-event').set({
        'title': 'Other Event',
        'date': '23/05/2026',
        'time': '7:00 PM',
        'location': 'Roma Street',
        'description': 'Submitted by another local.',
        'reviewStatus': 'approved',
        'createdByLocalEmail': 'other@brisconnect.com',
      });

      final LocalEventService service = LocalEventService(firestore: firestore);
      final List<EventItem> events =
          await service.watchSubmittedEvents('local@brisconnect.com').first;

      expect(events, hasLength(1));
      expect(events.first.id, 'local-event');
      expect(events.first.createdByLocalEmail, 'local@brisconnect.com');
      expect(events.first.reviewStatus, EventReviewStatus.pending);
    });

    test('watchSubmittedEvents emits status updates within two seconds', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('event-1').set({
        'title': 'River Lights Festival',
        'date': '25/05/2026',
        'time': '8:00 PM',
        'location': 'Brisbane River',
        'description': 'Awaiting review.',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
      });

      final LocalEventService service = LocalEventService(firestore: firestore);
      final statusStream = service
          .watchSubmittedEvents('local@brisconnect.com')
          .where((events) => events.isNotEmpty)
          .map((events) => events.first.reviewStatus);
      final orderedStatuses = expectLater(
        statusStream,
        emitsInOrder([
          EventReviewStatus.pending,
          EventReviewStatus.approved,
        ]),
      );

      await firestore.collection('events').doc('event-1').update({
        'reviewStatus': 'approved',
      });

      await orderedStatuses.timeout(const Duration(seconds: 2));
    });

    test('updateSubmittedEvent resets edited events to pending status', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('event-2').set({
        'title': 'Original Title',
        'date': '30/05/2026',
        'time': '5:00 PM',
        'location': 'Original Location',
        'description': 'Original description',
        'reviewStatus': 'approved',
        'createdByLocalEmail': 'local@brisconnect.com',
      });

      final LocalEventService service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'event-2',
        localEmail: 'local@brisconnect.com',
        title: 'Edited Title',
        date: '31/05/2026',
        location: 'Edited Location',
        description: 'Edited description',
      );

      final snapshot = await firestore.collection('events').doc('event-2').get();
      final data = snapshot.data();

      expect(didUpdate, isTrue);
      expect(data, isNotNull);
      expect(data!['title'], 'Edited Title');
      expect(data['date'], '31/05/2026');
      expect(data['location'], 'Edited Location');
      expect(data['description'], 'Edited description');
      expect(data['reviewStatus'], 'pending');
    });
  });
}
