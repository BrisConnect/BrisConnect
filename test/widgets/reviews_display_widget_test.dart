import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/widgets/reviews_display_widget.dart';

class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      <ConnectivityResult>[ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(
        <ConnectivityResult>[ConnectivityResult.wifi],
      );
}

void main() {
  group('ReviewsDisplayWidget', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReviewService reviewService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      reviewService = ReviewService(
        firestore: fakeFirestore,
        connectivity: _FakeConnectivity(),
        useFirebaseAuth: false,
      );
    });

    Future<void> pumpAndSettle(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewsDisplayWidget(
              businessId: 'business_1',
              reviewService: reviewService,
            ),
          ),
        ),
      );
      // Pagination loads asynchronously in initState.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('renders recommendations heading', (WidgetTester tester) async {
      await pumpAndSettle(tester);
      expect(find.text('Visitor Recommendations'), findsOneWidget);
      expect(find.text('No recommendations yet'), findsOneWidget);
    });

    testWidgets('shows delete option for recommendation author',
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
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

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
        'deletedAt': null,
        'isReported': false,
        'reportReason': null,
        'helpfulCount': 0,
        'isFlagged': false,
        'visible': true,
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();

      expect(find.text('Delete'), findsNothing);
    });
  });
}
