import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved attractions are separate from saved events and removable',
      (tester) async {
    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Visitor Tester',
        email: 'visitor@test.com',
        password: 'Password123',
        interestedEventIds: ['event-1'],
        savedAttractionIds: ['attraction-1'],
      ),
    );

    final discoverStream = Stream<List<Map<String, dynamic>>>.value(
      const [
        {
          'id': 'event-1',
          'section': 'events',
          'title': 'Community Music Night',
          'description': 'Saved event.',
          'dateTime': '10/06/2026 • 6:00 PM',
          'location': 'South Bank',
          'price': 'Free',
          'badge': 'EVENT',
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'attraction-1',
          'section': 'historical',
          'title': 'City Hall Tour',
          'description': 'Saved attraction.',
          'dateTime': 'Daily',
          'location': 'Brisbane City',
          'price': 'Free',
          'badge': 'Attraction',
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'attraction-2',
          'section': 'historical',
          'title': 'Unsaved Attraction',
          'description': 'Not saved.',
          'dateTime': 'Daily',
          'location': 'Brisbane City',
          'price': 'Free',
          'badge': 'Attraction',
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VisitorPortalScreen(discoverItemsStreamOverride: discoverStream),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    await tester.tap(find.text('Saved'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Saved Events'), findsOneWidget);
    expect(find.byKey(const Key('saved-event-card-event-1')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Saved Attractions'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Saved Attractions'), findsOneWidget);
    expect(find.byKey(const Key('saved-attraction-card-attraction-1')),
        findsOneWidget);
    expect(find.text('Unsaved Attraction'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('saved-attraction-card-attraction-1')),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byKey(const Key('saved-attraction-card-attraction-1')),
        findsNothing);

    VisitorAuth.debugSetCurrentVisitorForTesting(null);
  });
}
