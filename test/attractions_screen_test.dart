import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/attractions_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedAttractions(FakeFirebaseFirestore firestore) async {
    await firestore.collection('attractions').doc('attraction_city_hall').set({
      'name': 'Brisbane City Hall',
      'description': 'Historic civic venue in the CBD.',
      'location': '64 Adelaide Street, Brisbane City QLD 4000',
      'latitude': -27.4688,
      'longitude': 153.0235,
      'category': 'Cultural',
      'approvalStatus': 'approved',
    });

    await firestore.collection('attractions').doc('pending_attraction').set({
      'name': 'Unapproved Place',
      'description': 'Should not be visible to visitors/locals.',
      'location': 'Hidden Street',
      'latitude': -27.48,
      'longitude': 153.0,
      'approvalStatus': 'pending',
    });
  }

  Widget buildApp(ApprovedAttractionService service) {
    return MaterialApp(
      home: AttractionsScreen(attractionService: service),
    );
  }

  testWidgets('shows only admin-approved attractions in list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedAttractions(firestore);

    final service = ApprovedAttractionService(firestore: firestore);
    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Brisbane City Hall'), findsOneWidget);
    expect(find.text('Unapproved Place'), findsNothing);
  });

  testWidgets('opens detail page and shows core attraction information',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedAttractions(firestore);

    final service = ApprovedAttractionService(firestore: firestore);
    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Brisbane City Hall'));
    await tester.pumpAndSettle();

    expect(find.text('Brisbane City Hall'), findsWidgets);
    expect(find.text('Cultural'), findsWidgets);
    expect(find.text('Historic civic venue in the CBD.'), findsOneWidget);
    Future<void> scrollToText(String text) async {
      for (var i = 0; i < 8; i++) {
        if (find.text(text).evaluate().isNotEmpty) {
          return;
        }
        await tester.dragFrom(const Offset(400, 520), const Offset(0, -520));
        await tester.pumpAndSettle();
      }
    }

    await scrollToText('Location & Planning');

    expect(find.text('Location & Planning'), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);

    await scrollToText('Facilities & Accessibility');

    expect(find.text('Facilities & Accessibility'), findsOneWidget);
    expect(find.text('Facilities'), findsOneWidget);
    expect(find.text('Amenities'), findsOneWidget);

  });
}
