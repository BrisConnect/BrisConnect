import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows admin-provided accessibility details clearly',
      (tester) async {
    const attraction = ApprovedAttraction(
      id: 'a1',
      name: 'City Hall',
      description: 'Historic building',
      location: 'Brisbane City',
      latitude: -27.4698,
      longitude: 153.0251,
      category: 'Historical',
      accessibilityDetails: ['Wheelchair access', 'Accessible toilets'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AttractionDetailScreen(
          attraction: attraction,
          allAttractions: [attraction],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('Facilities & Accessibility'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Facilities & Accessibility'), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.text('Wheelchair access'), findsOneWidget);
    expect(find.text('Accessible toilets'), findsOneWidget);
  });
}
