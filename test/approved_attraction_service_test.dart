import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';

void main() {
  group('ApprovedAttractionService', () {
    test('returns only approved attractions with valid coordinates', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('a1').set({
        'name': 'Approved Attraction',
        'description': 'Shown on map',
        'location': 'South Bank',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
      });

      await firestore.collection('attractions').doc('a2').set({
        'name': 'Pending Attraction',
        'description': 'Must not be shown',
        'location': 'City',
        'latitude': -27.46,
        'longitude': 153.03,
        'approvalStatus': 'pending',
      });

      await firestore.collection('attractions').doc('a3').set({
        'name': 'Approved But Invalid Coordinate',
        'description': 'Must not be shown',
        'location': 'Invalid',
        'approvalStatus': 'approved',
      });

      final ApprovedAttractionService service =
          ApprovedAttractionService(firestore: firestore);

      final List<ApprovedAttraction> results =
          await service.watchApprovedAttractions().first;

      expect(results.length, 1);
      expect(results.first.id, 'a1');
      expect(results.first.name, 'Approved Attraction');
    });

    test('accepts approval from status/reviewStatus/isApproved fields',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('r1').set({
        'title': 'Review Approved Attraction',
        'description': 'Approved through review status',
        'address': 'Fortitude Valley',
        'lat': -27.45,
        'lng': 153.04,
        'reviewStatus': 'approved',
      });

      await firestore.collection('attractions').doc('r2').set({
        'title': 'Boolean Approved Attraction',
        'description': 'Approved through boolean',
        'address': 'West End',
        'lat': -27.48,
        'lng': 153.00,
        'isApproved': true,
      });

      final ApprovedAttractionService service =
          ApprovedAttractionService(firestore: firestore);

      final List<ApprovedAttraction> results =
          await service.watchApprovedAttractions().first;

      expect(results.length, 2);
      expect(results.map((item) => item.id).toSet(), {'r1', 'r2'});
    });

    test('parses category field from Firestore document', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('c1').set({
        'name': 'Cultural Museum',
        'description': 'A cultural venue',
        'location': 'City',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'category': 'Cultural',
      });

      await firestore.collection('attractions').doc('c2').set({
        'name': 'Nature Park',
        'description': 'Green space',
        'location': 'West End',
        'latitude': -27.48,
        'longitude': 153.01,
        'approvalStatus': 'approved',
        // no category field
      });

      final ApprovedAttractionService service =
          ApprovedAttractionService(firestore: firestore);

      final List<ApprovedAttraction> results =
          await service.watchApprovedAttractions().first;

      final ApprovedAttraction cultural =
          results.firstWhere((r) => r.id == 'c1');
      final ApprovedAttraction noCat = results.firstWhere((r) => r.id == 'c2');

      expect(cultural.category, 'Cultural');
      expect(noCat.category, isNull);
    });

    test('parses accessibility details from approved attraction data',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('acc1').set({
        'name': 'Accessible Attraction',
        'description': 'Accessibility enabled location',
        'location': 'CBD',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityDetails': [
          'Wheelchair access',
          'Accessible toilets',
        ],
      });

      final ApprovedAttractionService service =
          ApprovedAttractionService(firestore: firestore);

      final List<ApprovedAttraction> results =
          await service.watchApprovedAttractions().first;

      expect(results.length, 1);
      expect(
        results.first.accessibilityDetails,
        ['Wheelchair access', 'Accessible toilets'],
      );
    });
  });
}
