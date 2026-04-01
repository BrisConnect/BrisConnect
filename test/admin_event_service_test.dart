import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/admin_event_service.dart';

void main() {
  group('AdminEventService', () {
    test('watchAllEvents maps Firebase documents into EventItem values', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('event-1').set({
        'title': 'Riverstage Jazz Night',
        'date': '12/05/2026',
        'time': '7:00 PM',
        'location': 'Riverstage',
        'description': 'Live jazz by the river.',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
      });

      final AdminEventService service = AdminEventService(firestore: firestore);
      final List<EventItem> events = await service.watchAllEvents().first;

      expect(events, hasLength(1));
      expect(events.first.id, 'event-1');
      expect(events.first.title, 'Riverstage Jazz Night');
      expect(events.first.location, 'Riverstage');
      expect(events.first.reviewStatus, EventReviewStatus.pending);
      expect(events.first.createdByLocalEmail, 'local@brisconnect.com');
    });

    test('updateEvent writes edited fields back to Firebase immediately', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('event-2').set({
        'title': 'Old Title',
        'date': '10/05/2026',
        'time': '6:30 PM',
        'location': 'Old Location',
        'description': 'Old description',
        'dateTime': '10/05/2026 • 6:30 PM',
        'reviewStatus': 'approved',
      });

      final AdminEventService service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'event-2',
        title: 'New Title',
        date: '15/05/2026',
        location: 'New Farm Park',
        description: 'Updated description',
      );

      final snapshot = await firestore.collection('events').doc('event-2').get();
      final data = snapshot.data();

      expect(data, isNotNull);
      expect(data!['title'], 'New Title');
      expect(data['date'], '15/05/2026');
      expect(data['location'], 'New Farm Park');
      expect(data['description'], 'Updated description');
      expect(data['dateTime'], '15/05/2026 • 6:30 PM');
      expect(data['updatedAt'], isNotNull);
    });

    test('deleteEvent fully removes the event document from Firebase', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('event-3').set({
        'title': 'Delete Me',
        'date': '18/05/2026',
        'location': 'South Bank',
        'description': 'Temporary event',
      });

      final AdminEventService service = AdminEventService(firestore: firestore);
      await service.deleteEvent('event-3');

      final snapshot = await firestore.collection('events').doc('event-3').get();
      expect(snapshot.exists, isFalse);
    });
  });
}
