import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:brisconnect/widgets/submit_review_bottom_sheet.dart';

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
  group('SubmitReviewBottomSheet', () {
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

    Future<void> openSheet(WidgetTester tester) async {
      // Use a tall viewport so the submit button is reachable.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SubmitReviewBottomSheet(
                        businessId: 'business_1',
                        visitorId: 'visitor_1',
                        visitorName: 'Alice',
                        onReviewSubmitted: (_) {},
                        reviewService: reviewService,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('blocks submission when privacy consent is unchecked',
        (WidgetTester tester) async {
      await openSheet(tester);

      // Enter a comment
      await tester.enterText(find.byType(TextField).first, 'Great experience!');
      await tester.pump();

      // Do not check the consent box; tap submit
      await tester.tap(find.text('Submit Recommendation'));
      await tester.pump();

      // SnackBar should indicate consent is required
      expect(find.text('Please agree to the privacy notice'), findsOneWidget);
    });

    testWidgets('allows submission when privacy consent is checked',
        (WidgetTester tester) async {
      await openSheet(tester);

      // Enter a comment
      await tester.enterText(find.byType(TextField).first, 'Great experience!');
      await tester.pump();

      // Check the consent checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Verify the checkbox is checked by tapping submit and ensuring the
      // consent error is NOT shown (actual submission hits the fake service
      // and would succeed; service tests cover the actual write path).
      await tester.tap(find.text('Submit Recommendation'));
      await tester.pump();

      expect(find.text('Please agree to the privacy notice'), findsNothing);
    });
  });
}
