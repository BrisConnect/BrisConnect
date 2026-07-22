import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/widgets/reviews_display_widget.dart';

void main() {
  group('ReviewsDisplayWidget', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReviewService reviewService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      reviewService = ReviewService(firestore: fakeFirestore);
    });

    testWidgets('shows delete option for review author',
        (WidgetTester tester) async {
      const businessId = 'business_1';
      const visitorId = 'visitor_1';

      await fakeFirestore.collection('reviews').add({
        'businessId': businessId,
        'visitorId': visitorId,
        'visitorName': 'Alice',
        'rating': 5,
        'comment': 'Excellent!',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'isReported': false,
        'reportReason': null,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsDisplayWidget(
              businessId: businessId,
              currentVisitorId: visitorId,
              reviewService: reviewService,
            ),
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Open the more-options menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('hides delete option for non-author',
        (WidgetTester tester) async {
      const businessId = 'business_1';

      await fakeFirestore.collection('reviews').add({
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsDisplayWidget(
              businessId: businessId,
              currentVisitorId: 'visitor_2',
              reviewService: reviewService,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();

      expect(find.text('Delete'), findsNothing);
    });
  });
}
