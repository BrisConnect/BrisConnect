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
      );
    });

    test('createReview persists review and updates business metrics', () async {
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

      final reviewDoc = await fakeFirestore.collection('reviews').doc(reviewId).get();
      expect(reviewDoc.exists, true);
      final data = reviewDoc.data()!;
      expect(data['businessId'], businessId);
      expect(data['visitorId'], 'visitor_1');
      expect(data['visitorName'], 'Alice');
      expect(data['rating'], 4);
      expect(data['comment'], 'Great place!');
      expect(data['isReported'], false);

      final businessDoc = await fakeFirestore.collection('businesses').doc(businessId).get();
      final businessData = businessDoc.data()!;
      expect(businessData['reviewCount'], 1);
      expect(businessData['rating'], 4.0);
    });

    test('createReview throws when offline', () async {
      final offlineService = ReviewService(
        firestore: fakeFirestore,
        connectivity: FakeConnectivityAlwaysOffline(),
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

    test('deleteReview removes review owned by visitor and updates metrics',
        () async {
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
        'isReported': false,
        'reportReason': null,
      });

      await reviewService.deleteReview(reviewRef.id);

      final reviewDoc = await fakeFirestore.collection('reviews').doc(reviewRef.id).get();
      expect(reviewDoc.exists, false);

      final businessDoc = await fakeFirestore.collection('businesses').doc(businessId).get();
      final businessData = businessDoc.data()!;
      expect(businessData['reviewCount'], 0);
      expect(businessData['rating'], 0.0);
    });

    test('reportReview marks review as reported', () async {
      final reviewRef = await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 2,
        'comment': 'Spam',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'isReported': false,
        'reportReason': null,
      });

      await reviewService.reportReview(reviewRef.id, 'Inappropriate content');

      final reviewDoc = await fakeFirestore.collection('reviews').doc(reviewRef.id).get();
      final data = reviewDoc.data()!;
      expect(data['isReported'], true);
      expect(data['reportReason'], 'Inappropriate content');
    });

    test('getBusinessReviews excludes reported reviews', () async {
      await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 5,
        'comment': 'Good',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'isReported': false,
        'reportReason': null,
      });
      await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_2',
        'visitorName': 'Bob',
        'rating': 1,
        'comment': 'Bad',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'isReported': true,
        'reportReason': 'Spam',
      });

      final reviews = await reviewService.getBusinessReviews('business_1');
      expect(reviews.length, 1);
      expect(reviews.first.comment, 'Good');
    });

    test('hasVisitorReviewedBusiness returns true when visitor has reviewed',
        () async {
      await fakeFirestore.collection('reviews').add({
        'businessId': 'business_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'rating': 5,
        'comment': 'Good',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'isReported': false,
        'reportReason': null,
      });

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
  });
}
