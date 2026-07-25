import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('ReviewService report and severity', () {
    late FakeFirebaseFirestore firestore;
    late ReviewService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ReviewService(
        firestore: firestore,
        useFirebaseAuth: false,
      );
    });

    test('reportReview stores severity and reporter', () async {
      final doc = await firestore.collection('reviews').add({
        'businessId': 'business-1',
        'visitorId': 'visitor-1',
        'visitorName': 'Visitor',
        'rating': 4,
        'buzzRating': 3,
        'comment': 'Good',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'reportedBy': null,
        'severity': 'medium',
        'deletedBy': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
      });

      await service.reportReview(
        doc.id,
        'Inappropriate language',
        reporterId: 'reporter-1',
        severity: 'high',
      );

      final updated = await doc.get();
      final data = updated.data()!;
      expect(data['isReported'], isTrue);
      expect(data['reportReason'], 'Inappropriate language');
      expect(data['reportedBy'], 'reporter-1');
      expect(data['severity'], 'high');
      expect(data['visible'], isFalse);
    });

    test('moderateReview dismiss clears report fields', () async {
      final doc = await firestore.collection('reviews').add({
        'businessId': 'business-1',
        'visitorId': 'visitor-1',
        'visitorName': 'Visitor',
        'rating': 4,
        'buzzRating': 3,
        'comment': 'Good',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'deletedAt': null,
        'isReported': true,
        'reportReason': 'Spam',
        'reportedBy': 'reporter-1',
        'severity': 'high',
        'deletedBy': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': false,
      });

      await service.moderateReview(
        reviewId: doc.id,
        decision: ModerationDecision.dismiss,
        adminEmail: 'admin@example.com',
        reason: 'No issue found',
      );

      final updated = await doc.get();
      final data = updated.data()!;
      expect(data['isReported'], isFalse);
      expect(data['reportReason'], isNull);
      expect(data['reportedBy'], isNull);
      expect(data['severity'], 'medium');
      expect(data['visible'], isTrue);
    });

    test('Review model serializes severity', () {
      final review = Review(
        id: 'r1',
        businessId: 'b1',
        visitorId: 'v1',
        visitorName: 'Visitor',
        rating: 5,
        comment: 'Test',
        createdAt: DateTime(2025, 1, 1),
        severity: 'critical',
      );

      expect(review.toFirestore()['severity'], 'critical');
      expect(review.copyWith(severity: 'low').severity, 'low');
    });
  });
}
