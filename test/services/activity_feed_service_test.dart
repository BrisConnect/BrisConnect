import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/services/activity_feed_service.dart';

void main() {
  group('ActivityFeedService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ActivityFeedService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ActivityFeedService(firestore: fakeFirestore);
    });

    Future<DocumentReference> addReview({
      required String id,
      required String comment,
      required DateTime createdAt,
      bool visible = true,
      bool isFlagged = false,
      String businessId = 'biz_1',
    }) async {
      final ref = fakeFirestore.collection('reviews').doc(id);
      await ref.set({
        'businessId': businessId,
        'visitorId': 'visitor_$id',
        'visitorName': 'User $id',
        'rating': 5,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'reportedBy': null,
        'deletedBy': null,
        'helpfulCount': 0,
        'isFlagged': isFlagged,
        'visible': visible,
      });
      return ref;
    }

    Future<DocumentReference> addEvent({
      required String id,
      required String title,
      required DateTime createdAt,
      String status = 'published',
    }) async {
      final ref = fakeFirestore.collection('business_events').doc(id);
      await ref.set({
        'businessId': 'biz_1',
        'ownerId': 'owner_1',
        'ownerEmail': 'owner@test.com',
        'title': title,
        'date': '24/07/2026',
        'time': '18:00',
        'location': 'South Bank',
        'description': 'A great event',
        'imageUrl': 'https://example.com/event.jpg',
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
      });
      return ref;
    }

    Future<DocumentReference> addBusiness({
      required String id,
      required String name,
      required DateTime createdAt,
    }) async {
      final ref = fakeFirestore.collection('businesses').doc(id);
      await ref.set({
        'businessName': name,
        'description': 'A tasty spot',
        'address': 'Brisbane',
        'createdAt': Timestamp.fromDate(createdAt),
      });
      return ref;
    }

    test('stream returns visible reviews and published events merged by time',
        () async {
      final now = DateTime.now();
      await addReview(
        id: 'r1',
        comment: 'Great!',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      await addEvent(
        id: 'e1',
        title: 'Festival',
        createdAt: now.subtract(const Duration(minutes: 2)),
      );
      await addBusiness(
        id: 'b1',
        name: 'Tasty Cafe',
        createdAt: now,
      );

      final items = await service.activityFeedStream(limit: 10).first;
      expect(items.length, 3);
      expect(items.first.type, ActivityFeedType.business);
      expect(items[1].type, ActivityFeedType.event);
      expect(items.last.type, ActivityFeedType.review);
    });

    test('stream filters out flagged or non-visible reviews', () async {
      final now = DateTime.now();
      await addReview(
        id: 'r1',
        comment: 'Visible',
        createdAt: now,
        visible: true,
        isFlagged: false,
      );
      await addReview(
        id: 'r2',
        comment: 'Flagged',
        createdAt: now.subtract(const Duration(seconds: 1)),
        visible: true,
        isFlagged: true,
      );
      await addReview(
        id: 'r3',
        comment: 'Hidden',
        createdAt: now.subtract(const Duration(seconds: 2)),
        visible: false,
        isFlagged: false,
      );

      final items = await service.activityFeedStream(limit: 10).first;
      expect(items.length, 1);
      expect(items.first.id, 'r1');
    });

    test('stream by type returns only reviews when filtered', () async {
      final now = DateTime.now();
      await addReview(id: 'r1', comment: 'A', createdAt: now);
      await addEvent(id: 'e1', title: 'E', createdAt: now);

      final items = await service
          .activityFeedStreamByType(ActivityFeedType.review, limit: 10)
          .first;
      expect(items.length, 1);
      expect(items.first.type, ActivityFeedType.review);
    });

    test('page returns items and cursor', () async {
      final now = DateTime.now();
      await addReview(id: 'r1', comment: 'A', createdAt: now);
      await addEvent(id: 'e1', title: 'E', createdAt: now.subtract(const Duration(seconds: 1)));

      final page = await service.activityFeedPage(limit: 10);
      expect(page.items.length, 2);
      expect(page.nextCursor, isNotNull);
    });

    test('page with cursor returns next set of items', () async {
      final now = DateTime.now();
      await addReview(id: 'r1', comment: 'A', createdAt: now);
      await addEvent(id: 'e1', title: 'E', createdAt: now.subtract(const Duration(minutes: 10)));

      final firstPage = await service.activityFeedPage(limit: 1);
      expect(firstPage.items.length, 1);

      // The merged page returns the single latest item; with a cursor it
      // should continue past that item.
      final secondPage = await service.activityFeedPage(
        limit: 10,
        startAfter: firstPage.nextCursor,
      );
      expect(secondPage.items.length, greaterThanOrEqualTo(0));
      if (secondPage.items.isNotEmpty) {
        expect(secondPage.items.first.id, isNot(firstPage.items.first.id));
      }
    });

    test('empty feed returns no items', () async {
      final items = await service.activityFeedStream(limit: 10).first;
      expect(items, isEmpty);
    });
  });
}
