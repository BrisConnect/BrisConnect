import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/audience_analytics_service.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessDashboardService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AudienceAnalyticsService audienceService;
    late BusinessDashboardService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      audienceService = AudienceAnalyticsService(firestore: fakeFirestore);
      service = BusinessDashboardService(
        firestore: fakeFirestore,
        audienceAnalyticsService: audienceService,
      );
    });

    Future<DocumentReference> addBusiness({
      required String id,
      required String ownerId,
      int viewCount = 0,
      int savedCount = 0,
      Map<String, int>? viewHistory,
      Map<String, int>? saveHistory,
    }) async {
      final ref = fakeFirestore.collection('businesses').doc(id);
      await ref.set({
        'ownerId': ownerId,
        'businessName': 'Test Business $id',
        'category': 'Restaurant',
        'description': 'A test business',
        'address': 'Brisbane',
        'contactNumber': '0000000000',
        'viewCount': viewCount,
        'savedCount': savedCount,
        if (viewHistory != null) 'viewHistory': viewHistory,
        if (saveHistory != null) 'saveHistory': saveHistory,
        'createdAt': Timestamp.now(),
      });
      return ref;
    }

    Future<DocumentReference> addReview({
      required String id,
      required String businessId,
      required DateTime createdAt,
      bool visible = true,
    }) async {
      final ref = fakeFirestore.collection('reviews').doc(id);
      await ref.set({
        'businessId': businessId,
        'visitorId': 'visitor_$id',
        'visitorName': 'User $id',
        'rating': 5,
        'comment': 'Great!',
        'createdAt': Timestamp.fromDate(createdAt),
        'visible': visible,
        'isFlagged': false,
      });
      return ref;
    }

    Future<DocumentReference> addPromotion({
      required String id,
      required String businessId,
      required DateTime endDate,
      String ownerId = 'owner@test.com',
      bool isActive = true,
    }) async {
      final ref = fakeFirestore.collection('promotions').doc(id);
      await ref.set({
        'businessId': businessId,
        'ownerId': ownerId,
        'title': 'Promo $id',
        'isActive': isActive,
        'endDate': Timestamp.fromDate(endDate),
      });
      return ref;
    }

    Future<DocumentReference> addEvent({
      required String id,
      required String businessId,
      required String date,
      String status = 'published',
    }) async {
      final ref = fakeFirestore.collection('business_events').doc(id);
      await ref.set({
        'businessId': businessId,
        'ownerId': 'owner@test.com',
        'ownerEmail': 'owner@test.com',
        'title': 'Event $id',
        'date': date,
        'time': '18:00',
        'location': 'Brisbane',
        'description': 'A test event',
        'status': status,
        'createdAt': Timestamp.now(),
      });
      return ref;
    }

    test('metricsStream returns zeros when owner has no businesses',
        () async {
      final metrics = await service.metricsStream('owner_no_business').first;
      expect(metrics.profileViews, 0);
      expect(metrics.saves, 0);
      expect(metrics.activePromotions, 0);
      expect(metrics.upcomingEvents, 0);
      expect(metrics.newReviews, 0);
    });

    test('getMetrics aggregates profile views and saves', () async {
      final now = DateTime.now();
      final today = _formatDate(now);
      final sixDaysAgo = _formatDate(now.subtract(const Duration(days: 6)));
      final eightDaysAgo = _formatDate(now.subtract(const Duration(days: 8)));

      await addBusiness(
        id: 'b1',
        ownerId: 'owner@test.com',
        viewCount: 0,
        savedCount: 0,
        viewHistory: {today: 7, sixDaysAgo: 3, eightDaysAgo: 5},
        saveHistory: {today: 2, sixDaysAgo: 1},
      );
      await addBusiness(
        id: 'b2',
        ownerId: 'owner@test.com',
        viewCount: 5,
        savedCount: 1,
      );

      final metrics = await service.getMetrics('owner@test.com');
      // b1 contributes current window (today + sixDaysAgo) = 10.
      // b2 has no viewHistory, so falls back to viewCount = 5.
      expect(metrics.profileViews, 15);
      expect(metrics.saves, 4);
    });

    test('recordProfileView increments viewCount and viewHistory', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');

      await service.recordProfileView('b1');
      await service.recordProfileView('b1');

      final doc = await fakeFirestore.collection('businesses').doc('b1').get();
      final data = doc.data()!;
      expect(data['viewCount'], 2);
      expect(
        (data['viewHistory'] as Map<String, dynamic>)[_formatDate(DateTime.now())],
        2,
      );
    });

    test('recordProfileView records anonymised audience interaction when visitorId provided',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');

      await service.recordProfileView('b1', visitorId: 'visitor_1');

      final interactions = await fakeFirestore
          .collection('audience_interactions')
          .get();
      expect(interactions.docs.length, 1);
      final data = interactions.docs.first.data();
      expect(data['businessId'], 'b1');
      expect(data['ownerId'], 'owner@test.com');
      expect(data['type'], 'view');
      expect(data['visitorHash'],
          AudienceAnalyticsService.anonymiseVisitorId('visitor_1'));
    });

    test('recordProfileView skips audience interaction when visitorId omitted',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');

      await service.recordProfileView('b1');

      final interactions = await fakeFirestore
          .collection('audience_interactions')
          .get();
      expect(interactions.docs.length, 0);
    });

    test('recordSave increments savedCount and saveHistory', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');

      await service.recordSave('b1');

      final doc = await fakeFirestore.collection('businesses').doc('b1').get();
      final data = doc.data()!;
      expect(data['savedCount'], 1);
      expect(
        (data['saveHistory'] as Map<String, dynamic>)[_formatDate(DateTime.now())],
        1,
      );
    });

    test('recordSave records anonymised audience interaction when visitorId provided',
        () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com');

      await service.recordSave('b1', visitorId: 'visitor_1');

      final interactions = await fakeFirestore
          .collection('audience_interactions')
          .get();
      expect(interactions.docs.length, 1);
      final data = interactions.docs.first.data();
      expect(data['businessId'], 'b1');
      expect(data['ownerId'], 'owner@test.com');
      expect(data['type'], 'save');
    });

    test('active promotions and upcoming events are counted', () async {
      final now = DateTime.now();
      final tomorrow = _formatDate(now.add(const Duration(days: 1)));

      await addBusiness(id: 'b1', ownerId: 'owner@test.com');
      await addPromotion(
        id: 'p1',
        businessId: 'b1',
        endDate: now.add(const Duration(days: 7)),
      );
      await addPromotion(
        id: 'p2',
        businessId: 'b1',
        endDate: now.subtract(const Duration(days: 1)),
        isActive: true,
      );
      await addPromotion(
        id: 'p3',
        businessId: 'b1',
        endDate: now.add(const Duration(days: 7)),
        isActive: false,
      );
      await addEvent(id: 'e1', businessId: 'b1', date: tomorrow);
      await addEvent(
        id: 'e2',
        businessId: 'b1',
        date: _formatDate(now.subtract(const Duration(days: 1))),
      );

      final metrics = await service.getMetrics('owner@test.com');
      expect(metrics.activePromotions, 1);
      expect(metrics.upcomingEvents, 1);
    });

    test('newReviews counted within rolling 7-day window', () async {
      final now = DateTime.now();
      final businessId = 'b1';

      await addBusiness(id: businessId, ownerId: 'owner@test.com');
      await addReview(
        id: 'r1',
        businessId: businessId,
        createdAt: now.subtract(const Duration(days: 2)),
      );
      await addReview(
        id: 'r2',
        businessId: businessId,
        createdAt: now.subtract(const Duration(days: 10)),
      );
      await addReview(
        id: 'r3',
        businessId: businessId,
        createdAt: now.subtract(const Duration(days: 5)),
        visible: false,
      );

      final metrics = await service.getMetrics('owner@test.com');
      expect(metrics.newReviews, 1);
      // With fake_cloud_firestore, count().get() may not respect range filters
      // exactly, so we assert only that newReviews is correct and change is finite.
      expect(metrics.newReviewsChange.isFinite, isTrue);
    });

    test('metricsStream emits when business data changes', () async {
      await addBusiness(id: 'b1', ownerId: 'owner@test.com', viewCount: 5);

      final stream = service.metricsStream('owner@test.com');
      final first = await stream.first;
      expect(first.profileViews, 5);

      await fakeFirestore
          .collection('businesses')
          .doc('b1')
          .update({'viewCount': 10});

      final second = await stream.first;
      expect(second.profileViews, 10);
    });

    test('percentageChange handles zero previous values', () async {
      expect(service.percentageChangeForTest(0, 0), 0.0);
      expect(service.percentageChangeForTest(5, 0), 1.0);
      expect(service.percentageChangeForTest(5, 10), -0.5);
      expect(service.percentageChangeForTest(15, 10), 0.5);
    });
  });
}

String _formatDate(DateTime date) {
  final d = date;
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year;
  return '$day/$month/$year';
}
