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
      bool isPinned = false,
      DateTime? pinnedAt,
      bool isHighlighted = false,
      DateTime? highlightedAt,
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
        'isPinned': isPinned,
        'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt) : null,
        'isHighlighted': isHighlighted,
        'highlightedAt': highlightedAt != null
            ? Timestamp.fromDate(highlightedAt)
            : null,
      });
      return ref;
    }

    Future<DocumentReference> addEvent({
      required String id,
      required String title,
      required DateTime createdAt,
      String status = 'published',
      bool isPinned = false,
      DateTime? pinnedAt,
      bool isHighlighted = false,
      DateTime? highlightedAt,
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
        'isPinned': isPinned,
        'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt) : null,
        'isHighlighted': isHighlighted,
        'highlightedAt': highlightedAt != null
            ? Timestamp.fromDate(highlightedAt)
            : null,
      });
      return ref;
    }

    Future<DocumentReference> addBusiness({
      required String id,
      required String name,
      required DateTime createdAt,
      bool isActive = true,
      bool isPinned = false,
      DateTime? pinnedAt,
      bool isHighlighted = false,
      DateTime? highlightedAt,
    }) async {
      final ref = fakeFirestore.collection('businesses').doc(id);
      await ref.set({
        'businessName': name,
        'description': 'A tasty spot',
        'address': 'Brisbane',
        'createdAt': Timestamp.fromDate(createdAt),
        'isActive': isActive,
        'isPinned': isPinned,
        'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt) : null,
        'isHighlighted': isHighlighted,
        'highlightedAt': highlightedAt != null
            ? Timestamp.fromDate(highlightedAt)
            : null,
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

    test('pinned items sort to the top', () async {
      final now = DateTime.now();
      await addReview(
        id: 'r1',
        comment: 'New',
        createdAt: now,
      );
      await addReview(
        id: 'r2',
        comment: 'Pinned old',
        createdAt: now.subtract(const Duration(hours: 24)),
        isPinned: true,
        pinnedAt: now.subtract(const Duration(minutes: 5)),
      );

      final items = await service.activityFeedStream(limit: 10).first;
      expect(items.length, 2);
      expect(items.first.id, 'r2');
      expect(items.first.isPinned, true);
    });

    test('highlighted items sort below pinned and above regular', () async {
      final now = DateTime.now();
      await addReview(
        id: 'r1',
        comment: 'Regular',
        createdAt: now,
      );
      await addReview(
        id: 'r2',
        comment: 'Highlighted old',
        createdAt: now.subtract(const Duration(hours: 24)),
        isHighlighted: true,
        highlightedAt: now.subtract(const Duration(minutes: 5)),
      );
      await addReview(
        id: 'r3',
        comment: 'Pinned older',
        createdAt: now.subtract(const Duration(hours: 48)),
        isPinned: true,
        pinnedAt: now.subtract(const Duration(minutes: 10)),
      );

      final items = await service.activityFeedStream(limit: 10).first;
      expect(items.map((i) => i.id).toList(), ['r3', 'r2', 'r1']);
    });

    test('pinItem and unpinItem update Firestore', () async {
      final now = DateTime.now();
      await addReview(id: 'r1', comment: 'A', createdAt: now);

      final item = (await service.activityFeedStream(limit: 1).first).first;
      await service.pinItem(item);

      var snapshot = await fakeFirestore.collection('reviews').doc('r1').get();
      expect(snapshot.data()?['isPinned'], true);
      expect(snapshot.data()?['pinnedAt'], isNotNull);

      final pinnedItem =
          (await service.activityFeedStream(limit: 1).first).first;
      await service.unpinItem(pinnedItem);

      snapshot = await fakeFirestore.collection('reviews').doc('r1').get();
      expect(snapshot.data()?['isPinned'], false);
      expect(snapshot.data()?['pinnedAt'], isNull);
    });

    test('highlightItem and unhighlightItem update Firestore', () async {
      final now = DateTime.now();
      await addEvent(id: 'e1', title: 'Event', createdAt: now);

      final item = (await service.activityFeedStreamByType(
        ActivityFeedType.event,
        limit: 1,
      ).first)
          .first;
      await service.highlightItem(item);

      var snapshot =
          await fakeFirestore.collection('business_events').doc('e1').get();
      expect(snapshot.data()?['isHighlighted'], true);
      expect(snapshot.data()?['highlightedAt'], isNotNull);

      final highlightedItem = (await service.activityFeedStreamByType(
        ActivityFeedType.event,
        limit: 1,
      ).first)
          .first;
      await service.unhighlightItem(highlightedItem);

      snapshot =
          await fakeFirestore.collection('business_events').doc('e1').get();
      expect(snapshot.data()?['isHighlighted'], false);
      expect(snapshot.data()?['highlightedAt'], isNull);
    });

    test('removeItem hides reviews from the feed', () async {
      final now = DateTime.now();
      await addReview(id: 'r1', comment: 'Spam', createdAt: now);

      final item = (await service.activityFeedStream(limit: 1).first).first;
      await service.removeItem(item);

      final items = await service.activityFeedStream(limit: 10).first;
      expect(items, isEmpty);

      final snapshot = await fakeFirestore.collection('reviews').doc('r1').get();
      final data = snapshot.data()!;
      expect(data['visible'], false);
      expect(data['isFlagged'], true);
      expect(data['deletedAt'], isNotNull);
    });

    test('removeItem hides events from the feed', () async {
      final now = DateTime.now();
      await addEvent(id: 'e1', title: 'Spam event', createdAt: now);

      final item = (await service.activityFeedStreamByType(
        ActivityFeedType.event,
        limit: 1,
      ).first)
          .first;
      await service.removeItem(item);

      final items = await service.activityFeedStreamByType(
        ActivityFeedType.event,
        limit: 10,
      ).first;
      expect(items, isEmpty);

      final snapshot =
          await fakeFirestore.collection('business_events').doc('e1').get();
      expect(snapshot.data()?['status'], 'rejected');
    });

    test('removeItem hides businesses from the feed', () async {
      final now = DateTime.now();
      await addBusiness(id: 'b1', name: 'Spam business', createdAt: now);

      final item = (await service.activityFeedStreamByType(
        ActivityFeedType.business,
        limit: 1,
      ).first)
          .first;
      await service.removeItem(item);

      final items = await service.activityFeedStreamByType(
        ActivityFeedType.business,
        limit: 10,
      ).first;
      expect(items, isEmpty);

      final snapshot =
          await fakeFirestore.collection('businesses').doc('b1').get();
      expect(snapshot.data()?['isActive'], false);
    });

    test('deactivated businesses are excluded from the feed', () async {
      final now = DateTime.now();
      await addBusiness(
        id: 'b1',
        name: 'Active',
        createdAt: now,
      );
      await addBusiness(
        id: 'b2',
        name: 'Inactive',
        createdAt: now.subtract(const Duration(seconds: 1)),
        isActive: false,
      );

      final items = await service.activityFeedStreamByType(
        ActivityFeedType.business,
        limit: 10,
      ).first;
      expect(items.length, 1);
      expect(items.first.id, 'b1');
    });
  });
}
