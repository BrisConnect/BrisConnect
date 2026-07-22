import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/audience_interaction.dart';
import 'package:brisconnect/services/audience_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudienceAnalyticsService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AudienceAnalyticsService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AudienceAnalyticsService(firestore: fakeFirestore);
    });

    Future<DocumentReference> addBusiness({
      required String id,
      required String ownerId,
    }) async {
      return fakeFirestore.collection('businesses').doc(id)
        ..set({
          'ownerId': ownerId,
          'businessName': 'Test Business $id',
          'category': 'Restaurant',
          'description': 'A test business',
          'address': 'Brisbane',
          'contactNumber': '0000000000',
        });
    }

    Future<DocumentReference> addInteraction({
      required String businessId,
      required String visitorId,
      required DateTime timestamp,
      AudienceInteractionType type = AudienceInteractionType.view,
    }) async {
      return fakeFirestore.collection('audience_interactions').add({
        'businessId': businessId,
        'visitorHash': AudienceAnalyticsService.anonymiseVisitorId(visitorId),
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
      });
    }

    test('anonymiseVisitorId returns stable truncated hash', () {
      final hash1 = AudienceAnalyticsService.anonymiseVisitorId('uid_123');
      final hash2 = AudienceAnalyticsService.anonymiseVisitorId('uid_123');
      expect(hash1, hash2);
      expect(hash1.length, 16);
      expect(hash1, isNot(equals('uid_123')));
    });

    test('isSampleMeaningful returns false below threshold', () {
      expect(AudienceAnalyticsService.isSampleMeaningful(19), isFalse);
      expect(AudienceAnalyticsService.isSampleMeaningful(20), isTrue);
      expect(AudienceAnalyticsService.isSampleMeaningful(100), isTrue);
    });

    test('recordInteraction stores anonymised interaction', () async {
      await service.recordInteraction(
        businessId: 'b1',
        visitorId: 'visitor_1',
        type: AudienceInteractionType.view,
        timestamp: DateTime(2026, 7, 20, 14, 0),
      );

      final snapshot = await fakeFirestore.collection('audience_interactions').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();
      expect(data['businessId'], 'b1');
      expect(data['visitorHash'],
          AudienceAnalyticsService.anonymiseVisitorId('visitor_1'));
      expect(data['type'], 'view');
    });

    test('getAudienceBreakdown returns all new for first-time visitors',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final now = DateTime.now();
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v1',
        timestamp: now.subtract(const Duration(days: 2)),
      );
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v2',
        timestamp: now.subtract(const Duration(days: 1)),
      );

      final breakdown = await service.getAudienceBreakdown(
        'owner@test.com',
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );

      expect(breakdown.newVisitors, 2);
      expect(breakdown.returningVisitors, 0);
      expect(breakdown.totalInteractions, 2);
    });

    test('getAudienceBreakdown detects returning viewers', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final now = DateTime.now();
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v1',
        timestamp: now.subtract(const Duration(days: 20)),
      );
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v1',
        timestamp: now.subtract(const Duration(days: 2)),
      );
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v2',
        timestamp: now.subtract(const Duration(days: 1)),
      );

      final breakdown = await service.getAudienceBreakdown(
        'owner@test.com',
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );

      expect(breakdown.newVisitors, 1);
      expect(breakdown.returningVisitors, 1);
      expect(breakdown.totalInteractions, 2);
    });

    test('getAudienceBreakdown ignores other owners', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      await addBusiness(id: 'b2', ownerId: 'other@test.com');
      final now = DateTime.now();
      await addInteraction(
        businessId: 'b2',
        visitorId: 'v1',
        timestamp: now,
      );

      final breakdown = await service.getAudienceBreakdown(
        'owner@test.com',
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );

      expect(breakdown.totalInteractions, 0);
    });

    test('getEngagementDistribution groups by hour and weekday', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final now = DateTime.now();
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v1',
        timestamp: DateTime(now.year, now.month, now.day, 9, 0),
      );
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v2',
        timestamp: DateTime(now.year, now.month, now.day, 9, 30),
      );
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v3',
        timestamp: DateTime(now.year, now.month, now.day, 18, 0),
      );

      final distribution = await service.getEngagementDistribution(
        'owner@test.com',
        start: now.subtract(const Duration(days: 7)),
        end: now.add(const Duration(days: 1)),
      );

      expect(distribution.total, 3);
      expect(distribution.byHour[9], 2);
      expect(distribution.byHour[18], 1);
      expect(distribution.byDayOfWeek[now.weekday], 3);
    });

    test('interactionsStream emits interactions for owner businesses',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      final now = DateTime.now();
      await addInteraction(
        businessId: 'b1',
        visitorId: 'v1',
        timestamp: now,
      );

      final items = await service
          .interactionsStream('owner@test.com')
          .first;

      expect(items.length, 1);
      expect(items.first.businessId, 'b1');
    });
  });
}
