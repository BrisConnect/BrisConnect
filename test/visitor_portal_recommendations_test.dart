import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Visitor Tester',
        email: 'visitor@test.com',
        password: 'Password123',
        interestedEventIds: ['seed-music'],
      ),
    );
  });

  tearDown(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(null);
  });

  testWidgets(
      'shows dedicated recommendation section for matching approved events',
      (tester) async {
    final discoverStream = Stream<List<Map<String, dynamic>>>.value(
      const [
        {
          'id': 'seed-music',
          'section': 'events',
          'title': 'Music Seed Event',
          'description': 'Saved to establish interests.',
          'dateTime': '10/06/2026 • 6:00 PM',
          'location': 'South Bank',
          'price': 'Free',
          'badge': 'Cultural Event',
          'categories': ['Music', 'Culture'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'rec-approved-match',
          'section': 'events',
          'title': 'Jazz River Night',
          'description': 'Live music event.',
          'dateTime': '12/06/2026 • 7:00 PM',
          'location': 'Brisbane Riverstage',
          'price': 'Paid',
          'badge': 'Cultural Event',
          'categories': ['Music'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'rec-approved-nonmatch',
          'section': 'events',
          'title': 'Sports Meetup',
          'description': 'Community sports event.',
          'dateTime': '13/06/2026 • 4:00 PM',
          'location': 'Stadium',
          'price': 'Free',
          'badge': 'Sports Event',
          'categories': ['Sports'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'rec-unapproved-match',
          'section': 'events',
          'title': 'Unapproved Music Event',
          'description': 'Should not be recommended.',
          'dateTime': '14/06/2026 • 7:00 PM',
          'location': 'Fortitude Valley',
          'price': 'Paid',
          'badge': 'Cultural Event',
          'categories': ['Music'],
          'approvalStatus': 'pending',
          'imageUrl': '',
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VisitorPortalScreen(discoverItemsStreamOverride: discoverStream),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('recommended-section')), findsOneWidget);
    expect(find.text('Recommended for You'), findsOneWidget);
    expect(find.byKey(const Key('recommended-card-rec-approved-match')),
        findsOneWidget);
    expect(find.byKey(const Key('recommended-card-rec-approved-nonmatch')),
        findsNothing);
    expect(find.byKey(const Key('recommended-card-rec-unapproved-match')),
        findsNothing);
  });

  testWidgets('updates recommendations when interests change', (tester) async {
    final discoverStream = Stream<List<Map<String, dynamic>>>.value(
      const [
        {
          'id': 'seed-music',
          'section': 'events',
          'title': 'Music Seed Event',
          'description': 'Saved to establish interests.',
          'dateTime': '10/06/2026 • 6:00 PM',
          'location': 'South Bank',
          'price': 'Free',
          'badge': 'Cultural Event',
          'categories': ['Music'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'seed-sports',
          'section': 'events',
          'title': 'Sports Seed Event',
          'description': 'Alternate interest seed.',
          'dateTime': '10/06/2026 • 6:00 PM',
          'location': 'Brisbane Stadium',
          'price': 'Free',
          'badge': 'Sports Event',
          'categories': ['Sports'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'rec-music',
          'section': 'events',
          'title': 'River Concert',
          'description': 'Music recommendation.',
          'dateTime': '12/06/2026 • 7:00 PM',
          'location': 'Riverstage',
          'price': 'Paid',
          'badge': 'Cultural Event',
          'categories': ['Music'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'rec-sports',
          'section': 'events',
          'title': 'City Sports Carnival',
          'description': 'Sports recommendation.',
          'dateTime': '15/06/2026 • 3:00 PM',
          'location': 'Suncorp',
          'price': 'Free',
          'badge': 'Sports Event',
          'categories': ['Sports'],
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
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('recommended-card-rec-music')), findsOneWidget);
    expect(find.byKey(const Key('recommended-card-rec-sports')), findsNothing);

    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Visitor Tester',
        email: 'visitor@test.com',
        password: 'Password123',
        interestedEventIds: ['seed-sports'],
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('recommended-card-rec-music')), findsNothing);
    expect(
        find.byKey(const Key('recommended-card-rec-sports')), findsOneWidget);
  });
}
