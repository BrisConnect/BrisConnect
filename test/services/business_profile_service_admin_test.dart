import 'package:brisconnect/services/business_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFirebaseStorage extends Fake implements FirebaseStorage {}

void main() {
  group('BusinessProfileService admin operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BusinessProfileService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = BusinessProfileService(
        firestore: fakeFirestore,
        storage: _FakeFirebaseStorage(),
      );
    });

    Future<String> seedBusiness({
      String businessName = 'Test Business',
      bool isVerified = false,
      bool isActive = true,
    }) async {
      final doc = await fakeFirestore.collection('businesses').add({
        'ownerId': 'owner@example.com',
        'businessName': businessName,
        'category': 'Restaurant',
        'description': 'A test business',
        'address': '123 Main St',
        'contactNumber': '555-1234',
        'isVerified': isVerified,
        'isActive': isActive,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      return doc.id;
    }

    test('verifyBusiness sets isVerified and writes audit log', () async {
      final id = await seedBusiness();

      await service.verifyBusiness(businessId: id, adminEmail: 'admin@example.com', notes: 'Looks legit');

      final doc = await fakeFirestore.collection('businesses').doc(id).get();
      expect(doc.data()?['isVerified'], true);
      expect(doc.data()?['verifiedBy'], 'admin@example.com');

      final log = await fakeFirestore
          .collection('business_verification_log')
          .where('businessId', isEqualTo: id)
          .get();
      expect(log.docs.length, 1);
      expect(log.docs.first.data()['action'], 'verify');
      expect(log.docs.first.data()['notes'], 'Looks legit');
    });

    test('unverifyBusiness clears isVerified and writes audit log', () async {
      final id = await seedBusiness(isVerified: true);

      await service.unverifyBusiness(businessId: id, adminEmail: 'admin@example.com');

      final doc = await fakeFirestore.collection('businesses').doc(id).get();
      expect(doc.data()?['isVerified'], false);
      expect(doc.data()?['verifiedBy'], isNull);
    });

    test('deactivateBusiness sets isActive false', () async {
      final id = await seedBusiness();

      await service.deactivateBusiness(
        businessId: id,
        adminEmail: 'admin@example.com',
        reason: 'Outdated info',
      );

      final doc = await fakeFirestore.collection('businesses').doc(id).get();
      expect(doc.data()?['isActive'], false);
      expect(doc.data()?['deactivationReason'], 'Outdated info');
    });

    test('reactivateBusiness sets isActive true', () async {
      final id = await seedBusiness(isActive: false);

      await service.reactivateBusiness(businessId: id, adminEmail: 'admin@example.com');

      final doc = await fakeFirestore.collection('businesses').doc(id).get();
      expect(doc.data()?['isActive'], true);
    });

    test('archiveBusiness soft-deletes and copies to archive', () async {
      final id = await seedBusiness();

      await service.archiveBusiness(
        businessId: id,
        adminEmail: 'admin@example.com',
        reason: 'Duplicate',
      );

      final live = await fakeFirestore.collection('businesses').doc(id).get();
      expect(live.data()?['deletedAt'], isNotNull);
      expect(live.data()?['isActive'], false);

      final archived = await fakeFirestore.collection('business_archive').doc(id).get();
      expect(archived.exists, true);
      expect(archived.data()?['originalId'], id);
      expect(archived.data()?['archiveExpiresAt'], isNotNull);
    });

    test('restoreBusiness moves archived data back to live', () async {
      final id = await seedBusiness();
      await service.archiveBusiness(
        businessId: id,
        adminEmail: 'admin@example.com',
        reason: 'Mistake',
      );

      await service.restoreBusiness(businessId: id, adminEmail: 'admin@example.com');

      final live = await fakeFirestore.collection('businesses').doc(id).get();
      expect(live.data()?['deletedAt'], isNull);
      expect(live.data()?['isActive'], true);

      final archived = await fakeFirestore.collection('business_archive').doc(id).get();
      expect(archived.exists, false);
    });

    test('Business.fromFirestore parses status fields', () async {
      final doc = await fakeFirestore.collection('businesses').add({
        'ownerId': 'owner@example.com',
        'businessName': 'Archived Biz',
        'category': 'Retail',
        'description': 'Archived',
        'address': '456 Other St',
        'contactNumber': '555-5678',
        'isVerified': true,
        'isActive': false,
        'deletedAt': Timestamp.now(),
        'deletedBy': 'admin@example.com',
        'duplicateOf': 'canonical-id',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final business = await service.getBusinessProfile(doc.id);
      expect(business, isNotNull);
      expect(business!.isDeleted, true);
      expect(business.statusLabel, 'Archived');
      expect(business.duplicateOf, 'canonical-id');
    });

    test('public streams exclude inactive and deleted businesses', () async {
      final activeVerified = await seedBusiness(isVerified: true);
      final inactive = await seedBusiness(isActive: false);
      final archived = await seedBusiness();
      await service.archiveBusiness(businessId: archived, adminEmail: 'admin@example.com');

      final stream = service.getVerifiedBusinessesStream();
      final businesses = await stream.first;
      final ids = businesses.map((b) => b.id).toSet();

      expect(ids, contains(activeVerified));
      expect(ids, isNot(contains(inactive)));
      expect(ids, isNot(contains(archived)));
    });
  });
}
