import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/admin_attraction_service.dart';

void main() {
  group('AdminAttractionService', () {
    test('watchAllAttractions maps attraction documents', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('a1').set({
        'name': 'City Hall',
        'description': 'Historic building in Brisbane CBD',
        'location': 'King George Square',
        'latitude': -27.4688,
        'longitude': 153.0235,
        'approvalStatus': 'approved',
      });

      final AdminAttractionService service =
          AdminAttractionService(firestore: firestore);

      final items = await service.watchAllAttractions().first;
      expect(items.length, 1);
      expect(items.first.id, 'a1');
      expect(items.first.name, 'City Hall');
      expect(items.first.isApproved, isTrue);
    });

    test('addAttraction writes approved attraction fields', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final AdminAttractionService service =
          AdminAttractionService(firestore: firestore);

      await service.addAttraction(
        name: 'South Bank Parklands',
        description: 'Riverfront park area',
        location: 'South Brisbane',
        latitude: -27.4804,
        longitude: 153.0229,
        category: 'Nature',
      );

      final snapshot = await firestore.collection('attractions').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();

      expect(data['name'], 'South Bank Parklands');
      expect(data['approvalStatus'], 'approved');
      expect(data['isApproved'], true);
      expect(data['latitude'], -27.4804);
      expect(data['longitude'], 153.0229);
    });

    test('updateAttraction updates values in Firestore', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('a2').set({
        'name': 'Old Name',
        'description': 'Old description',
        'location': 'Old location',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
      });

      final AdminAttractionService service =
          AdminAttractionService(firestore: firestore);

      await service.updateAttraction(
        attractionId: 'a2',
        name: 'New Name',
        description: 'New description',
        location: 'New location',
        latitude: -27.48,
        longitude: 153.03,
        category: 'Cultural',
      );

      final updated = await firestore.collection('attractions').doc('a2').get();
      final data = updated.data();

      expect(data, isNotNull);
      expect(data!['name'], 'New Name');
      expect(data['description'], 'New description');
      expect(data['location'], 'New location');
      expect(data['latitude'], -27.48);
      expect(data['longitude'], 153.03);
      expect(data['category'], 'Cultural');
    });

    test('deleteAttraction removes the document', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('a3').set({
        'name': 'Delete me',
        'description': 'temp',
        'location': 'Somewhere',
        'latitude': -27.45,
        'longitude': 153.01,
      });

      final AdminAttractionService service =
          AdminAttractionService(firestore: firestore);
      await service.deleteAttraction('a3');

      final deleted = await firestore.collection('attractions').doc('a3').get();
      expect(deleted.exists, isFalse);
    });
  });
}
