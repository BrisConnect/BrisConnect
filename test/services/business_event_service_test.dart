import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brisconnect/services/business_event_service.dart';

class _FakeFirebaseStorage extends Fake implements FirebaseStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessEventService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BusinessEventService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = BusinessEventService(
        firestore: fakeFirestore,
        storage: _FakeFirebaseStorage(),
      );
    });

    group('createBusinessEvent', () {
      test('creates published event with required fields', () async {
        final eventId = await service.createBusinessEvent(
          businessId: 'biz_1',
          ownerId: 'owner_1',
          ownerEmail: 'Owner@Example.com',
          title: 'Wine Tasting',
          date: '25/07/2026',
          time: '18:30',
          location: 'Cellar Door',
          description: 'An evening of local wines',
        );

        expect(eventId, isNotNull);

        final doc =
            await fakeFirestore.collection('business_events').doc(eventId).get();
        final data = doc.data()!;
        expect(data['businessId'], 'biz_1');
        expect(data['ownerId'], 'owner_1');
        expect(data['ownerEmail'], 'owner@example.com');
        expect(data['title'], 'Wine Tasting');
        expect(data['date'], '25/07/2026');
        expect(data['time'], '18:30');
        expect(data['location'], 'Cellar Door');
        expect(data['description'], 'An evening of local wines');
        expect(data['status'], 'published');
        expect(data['imageUrl'], isNull);
      });

      test('returns null and does not create on empty title', () async {
        final eventId = await service.createBusinessEvent(
          businessId: 'biz_1',
          ownerId: 'owner_1',
          ownerEmail: 'owner@example.com',
          title: '   ',
          date: '25/07/2026',
          time: '18:30',
          location: 'Cellar Door',
          description: 'Description',
        );

        expect(eventId, isNull);
        final snapshot = await fakeFirestore.collection('business_events').get();
        expect(snapshot.docs, isEmpty);
      });

      test('returns null and does not create on empty location', () async {
        final eventId = await service.createBusinessEvent(
          businessId: 'biz_1',
          ownerId: 'owner_1',
          ownerEmail: 'owner@example.com',
          title: 'Wine Tasting',
          date: '25/07/2026',
          time: '18:30',
          location: '  ',
          description: 'Description',
        );

        expect(eventId, isNull);
        final snapshot = await fakeFirestore.collection('business_events').get();
        expect(snapshot.docs, isEmpty);
      });
    });

    group('updateBusinessEvent', () {
      test('updates event when owner and business match', () async {
        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Old Title',
          'date': '01/01/2026',
          'time': '12:00',
          'location': 'Old Location',
          'description': 'Old description',
          'status': 'published',
          'imageUrl': null,
          'imageStoragePath': null,
        });

        final success = await service.updateBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_1',
          ownerEmail: 'owner@example.com',
          title: 'New Title',
          date: '25/07/2026',
          time: '18:30',
          location: 'New Location',
          description: 'New description',
          imageUrl: 'https://example.com/image.jpg',
          imageStoragePath: 'events/image.jpg',
        );

        expect(success, true);

        final updated = await doc.get();
        final data = updated.data()!;
        expect(data['title'], 'New Title');
        expect(data['date'], '25/07/2026');
        expect(data['time'], '18:30');
        expect(data['location'], 'New Location');
        expect(data['description'], 'New description');
        expect(data['imageUrl'], 'https://example.com/image.jpg');
        expect(data['imageStoragePath'], 'events/image.jpg');
      });

      test('rejects update when owner email does not match', () async {
        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Old Title',
          'date': '01/01/2026',
          'time': '12:00',
          'location': 'Old Location',
          'description': 'Old description',
          'status': 'published',
        });

        final success = await service.updateBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_1',
          ownerEmail: 'other@example.com',
          title: 'New Title',
          date: '25/07/2026',
          time: '18:30',
          location: 'New Location',
          description: 'New description',
        );

        expect(success, false);

        final updated = await doc.get();
        expect(updated.data()!['title'], 'Old Title');
      });

      test('rejects update when business id does not match', () async {
        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Old Title',
          'date': '01/01/2026',
          'time': '12:00',
          'location': 'Old Location',
          'description': 'Old description',
          'status': 'published',
        });

        final success = await service.updateBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_2',
          ownerEmail: 'owner@example.com',
          title: 'New Title',
          date: '25/07/2026',
          time: '18:30',
          location: 'New Location',
          description: 'New description',
        );

        expect(success, false);
      });
    });

    group('deleteBusinessEvent', () {
      test('soft delete marks event as cancelled', () async {
        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Wine Tasting',
          'date': '25/07/2026',
          'time': '18:30',
          'location': 'Cellar Door',
          'description': 'Description',
          'status': 'published',
        });

        final success = await service.deleteBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_1',
          ownerEmail: 'owner@example.com',
          softDelete: true,
        );

        expect(success, true);

        final updated = await doc.get();
        expect(updated.data()!['status'], 'cancelled');
      });

      test('hard delete removes event document and storage path', () async {
        final fakeStorage = _FakeFirebaseStorage();
        final serviceWithFakeStorage = BusinessEventService(
          firestore: fakeFirestore,
          storage: fakeStorage,
        );

        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Wine Tasting',
          'date': '25/07/2026',
          'time': '18:30',
          'location': 'Cellar Door',
          'description': 'Description',
          'status': 'published',
          'imageStoragePath': 'events/hero.jpg',
        });

        final success = await serviceWithFakeStorage.deleteBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_1',
          ownerEmail: 'owner@example.com',
          softDelete: false,
        );

        expect(success, true);

        final after = await doc.get();
        expect(after.exists, false);
      });

      test('rejects delete when owner does not match', () async {
        final doc = await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'ownerId': 'owner_1',
          'ownerEmail': 'owner@example.com',
          'title': 'Wine Tasting',
          'date': '25/07/2026',
          'time': '18:30',
          'location': 'Cellar Door',
          'description': 'Description',
          'status': 'published',
        });

        final success = await service.deleteBusinessEvent(
          eventId: doc.id,
          businessId: 'biz_1',
          ownerEmail: 'other@example.com',
          softDelete: true,
        );

        expect(success, false);
        expect((await doc.get()).data()!['status'], 'published');
      });
    });

    group('getBusinessEvents', () {
      test('returns only published events by default', () async {
        await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'title': 'Published Event',
          'date': '25/07/2026',
          'time': '18:30',
          'location': 'Here',
          'description': 'Description',
          'status': 'published',
        });
        await fakeFirestore.collection('business_events').add({
          'businessId': 'biz_1',
          'title': 'Cancelled Event',
          'date': '24/07/2026',
          'time': '18:30',
          'location': 'Here',
          'description': 'Description',
          'status': 'cancelled',
        });

        final events = await service.getBusinessEvents(businessId: 'biz_1');
        expect(events.length, 1);
        expect(events.first.title, 'Published Event');
      });
    });

    group('uploadEventImage', () {
      test('returns null and does not crash on upload failure', () async {
        final fakeStorage = _FakeFirebaseStorage();
        final serviceWithFakeStorage = BusinessEventService(
          firestore: fakeFirestore,
          storage: fakeStorage,
        );

        final result = await serviceWithFakeStorage.uploadEventImage(
          businessId: 'biz_1',
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'photo.jpg',
        );

        expect(result, isNull);
      });
    });
  });
}
