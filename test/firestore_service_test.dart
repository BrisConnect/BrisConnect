import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/firestore_service.dart';

void main() {
  group('FirestoreService', () {
    test('getEvents returns only approved event documents', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('approved-1').set({
        'title': 'Approved Event',
        'date': '02/06/2026',
        'reviewStatus': 'approved',
      });
      await firestore.collection('events').doc('pending-1').set({
        'title': 'Pending Event',
        'date': '03/06/2026',
        'reviewStatus': 'pending',
      });

      final service = FirestoreService(firestore: firestore);
      final events = await service.getEvents().first;

      expect(events, hasLength(1));
      expect(events.first['title'], 'Approved Event');
    });

    test('getEvents emits approved events within three seconds', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('approved-2').set({
        'title': 'Fast Event',
        'date': '04/06/2026',
        'reviewStatus': 'approved',
      });

      final service = FirestoreService(firestore: firestore);
      final events = await service.getEvents().first.timeout(
            const Duration(seconds: 3),
          );

      expect(events, isNotEmpty);
      expect(events.first['title'], 'Fast Event');
    });
  });
}
