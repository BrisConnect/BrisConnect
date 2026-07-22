import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/review_service.dart';

class FakeConnectivityAlwaysOnline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      <ConnectivityResult>[ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(
        <ConnectivityResult>[ConnectivityResult.wifi],
      );
}

class FakeConnectivityAlwaysOffline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      <ConnectivityResult>[ConnectivityResult.none];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(
        <ConnectivityResult>[ConnectivityResult.none],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReviewService reviewService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      reviewService = ReviewService(
        firestore: fakeFirestore,
        connectivity: FakeConnectivityAlwaysOnline(),
        useFirebaseAuth: false,
      );
    });

    Future<DocumentReference<Map<String, dynamic>>> seedReview(
      String comment, {
      String visitorId = 'visitor_1',
      bool isReported = false,
      bool isFlagged = false,
      DateTime? createdAt,
    }) async {
      return fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': visitorId,
        'visitorName': 'Alice',
        'rating': 5,
        'comment': comment,
        'createdAt': createdAt == null
            ? Timestamp.now()
            : Timestamp.fromDate(createdAt),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': isReported,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': isFlagged,
        'visible': !isReported && !isFlagged,
      });
    }

    test('createReview persists recommendation and updates business metrics',
        () async {
      const businessId = 'business_1';
      await fakeFirestore.collection('businesses').doc(businessId).set({
        'name': 'Test Business',
        'reviewCount': 0,
        'rating': 0.0,
      });

      final reviewId = await reviewService.createReview(
        businessId: businessId,
        visitorId: 'visitor_1',
        visitorName: 'Alice',
        rating: 4,
        comment: 'Great place!',
      );

      final reviewDoc =
          await fakeFirestore.collection('reviews').doc(reviewId).get();
      expect(reviewDoc.exists, true);
      final data = reviewDoc.data()!;
      expect(data['businessId'], businessId);
      expect(data['visitorId'], 'visitor_1');
      expect(data['visitorName'], 'Alice');
      expect(data['rating'], 4);
      expect(data['comment'], 'Great place!');
      expect(data['isReported'], false);
      expect(data['isFlagged'], false);
      expect(data['helpfulCount'], 0);
      expect(data['deletedAt'], null);
      expect(data['visible'], true);

      final businessDoc =
          await fakeFirestore.collection('businesses').doc(businessId).get();
      final businessData = businessDoc.data()!;
      expect(businessData['reviewCount'], 1);
      expect(businessData['rating'], 4.0);
    });

    test('createReview throws when offline', () async {
      final offlineService = ReviewService(
        firestore: fakeFirestore,
        connectivity: FakeConnectivityAlwaysOffline(),
        useFirebaseAuth: false,
      );

      expect(
        () => offlineService.createReview(
          businessId: 'business_1',
          visitorId: 'visitor_1',
          visitorName: 'Alice',
          rating: 5,
          comment: 'Nice!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No internet connection'),
        )),
      );

      final snapshot = await fakeFirestore.collection('reviews').get();
      expect(snapshot.docs.length, 0);
    });

    test('createReview rejects invalid rating or empty comment', () async {
      expect(
        () => reviewService.createReview(
          businessId: 'business_1',
          visitorId: 'visitor_1',
          visitorName: 'Alice',
          rating: 6,
          comment: 'Good',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Rating must be between 1 and 5'),
        )),
      );

      expect(
        () => reviewService.createReview(
          businessId: 'business_1',
          visitorId: 'visitor_1',
          visitorName: 'Alice',
          rating: 4,
          comment: '   ',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Comment cannot be empty'),
        )),
      );
    });

    test('canCreateReview returns true for new visitor', () async {
      final canCreate = await reviewService.canCreateReview(
        businessId: 'business_1',
        visitorId: 'visitor_1',
      );
      expect(canCreate, true);
    });

    test('canCreateReview returns false after recent recommendation', () async {
      await reviewService.createReview(
        businessId: 'business_1',
        visitorId: 'visitor_1',
        visitorName: 'Alice',
        rating: 5,
        comment: 'Great!',
      );

      final canCreateSameBusiness = await reviewService.canCreateReview(
        businessId: 'business_1',
        visitorId: 'visitor_1',
      );
      expect(canCreateSameBusiness, false);

      final canCreateOtherBusiness = await reviewService.canCreateReview(
        businessId: 'business_2',
        visitorId: 'visitor_1',
      );
      expect(canCreateOtherBusiness, false);
    });

    test('canCreateReview returns true after cooldown elapsed', () async {
      await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 5,
        'comment': 'Great!',
        'createdAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
      });

      final canCreate = await reviewService.canCreateReview(
        businessId: 'business_2',
        visitorId: 'visitor_1',
      );
      expect(canCreate, true);
    });

    test('deleteReview soft-deletes and updates metrics', () async {
      const businessId = 'business_1';
      await fakeFirestore.collection('businesses').doc(businessId).set({
        'reviewCount': 1,
        'rating': 5.0,
      });

      final reviewRef = await fakeFirestore.collection('reviews').add({
        'businessId': businessId,
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 5,
        'comment': 'Excellent!',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
      });

      await reviewService.deleteReview(reviewRef.id, visitorId: 'visitor_1');

      final reviewDoc =
          await fakeFirestore.collection('reviews').doc(reviewRef.id).get();
      final data = reviewDoc.data()!;
      expect(data['deletedAt'], isNotNull);
      expect(data['deletedBy'], 'visitor_1');

      final businessDoc =
          await fakeFirestore.collection('businesses').doc(businessId).get();
      final businessData = businessDoc.data()!;
      expect(businessData['reviewCount'], 0);
      expect(businessData['rating'], 0.0);
    });

    test('reportReview marks recommendation as reported', () async {
      final reviewRef = await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 2,
        'comment': 'Spam',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
      });

      await reviewService.reportReview(
        reviewRef.id,
        'Inappropriate content',
        reporterId: 'visitor_2',
      );

      final reviewDoc =
          await fakeFirestore.collection('reviews').doc(reviewRef.id).get();
      final data = reviewDoc.data()!;
      expect(data['isReported'], true);
      expect(data['reportReason'], 'Inappropriate content');
      expect(data['reportedBy'], 'visitor_2');
    });

    test('getBusinessReviews excludes reported, flagged and deleted', () async {
      await seedReview('Good', isReported: false, isFlagged: false);
      await seedReview('Reported', isReported: true, isFlagged: false);
      await seedReview('Flagged', isReported: false, isFlagged: true);
      await seedReview('Deleted', isReported: false, isFlagged: false);

      // Soft-delete the last one.
      final snapshot = await fakeFirestore
          .collection('reviews')
          .where('comment', isEqualTo: 'Deleted')
          .get();
      await fakeFirestore
          .collection('reviews')
          .doc(snapshot.docs.first.id)
          .update({'deletedAt': Timestamp.now(), 'visible': false});

      final reviews = await reviewService.getBusinessReviews('business_1');
      expect(reviews.length, 1);
      expect(reviews.first.comment, 'Good');
    });

    test('getBusinessReviewsPage paginates results', () async {
      for (var i = 0; i < 5; i++) {
        await fakeFirestore.collection('reviews').add({
          'businessId': 'business_1',
          'visitorId': 'visitor_$i',
          'visitorName': 'User $i',
          'rating': 5,
          'comment': 'Comment $i',
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(Duration(minutes: i)),
          ),
          'updatedAt': null,
          'deletedAt': null,
          'isReported': false,
          'reportReason': null,
          'helpfulCount': 0,
          'isFlagged': false,
          'visible': true,
        });
      }

      final firstPage = await reviewService.getBusinessReviewsPage(
        'business_1',
        limit: 10,
      );
      expect(firstPage.items.length, 5);
      expect(firstPage.lastDocument, isNotNull);

      final secondPage = await reviewService.getBusinessReviewsPage(
        'business_1',
        limit: 10,
        startAfterDocument: firstPage.lastDocument,
      );
      expect(secondPage.items.length, 0);
    });

    test('hasVisitorReviewedBusiness returns true when visitor has reviewed',
        () async {
      await seedReview('Good');

      final hasReviewed = await reviewService.hasVisitorReviewedBusiness(
        'business_1',
        'visitor_1',
      );
      expect(hasReviewed, true);

      final hasNotReviewed = await reviewService.hasVisitorReviewedBusiness(
        'business_1',
        'visitor_2',
      );
      expect(hasNotReviewed, false);
    });

    test('markHelpful increments helpful count', () async {
      final reviewRef = await seedReview('Good');

      await reviewService.markHelpful(reviewRef.id);
      await reviewService.markHelpful(reviewRef.id);

      final reviewDoc =
          await fakeFirestore.collection('reviews').doc(reviewRef.id).get();
      expect(reviewDoc.data()!['helpfulCount'], 2);
    });

    test('getVisitorRecommendationHistory includes deleted items', () async {
      final reviewRef = await seedReview('Good', visitorId: 'visitor_1');
      await fakeFirestore
          .collection('reviews')
          .doc(reviewRef.id)
          .update({'deletedAt': Timestamp.now()});

      final history = await reviewService.getVisitorRecommendationHistory(
        'visitor_1',
        limit: 10,
      );
      expect(history.length, 1);
      expect(history.first.isDeleted, true);
    });
  });
}
