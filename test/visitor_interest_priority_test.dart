import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'discover events are ordered by interest priority and UI shows rank',
      (tester) async {
    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Priority Tester',
        email: 'priority@test.com',
        password: 'Password123',
        interestedEventIds: ['seed-music', 'seed-sports'],
        interestPriorities: ['music', 'sports'],
      ),
    );

    final discoverStream = Stream<List<Map<String, dynamic>>>.value(
      const [
        {
          'id': 'seed-music',
          'section': 'events',
          'title': 'Seed Music Interest',
          'description': 'Seed for selected interests.',
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
          'title': 'Seed Sports Interest',
          'description': 'Seed for selected interests.',
          'dateTime': '10/06/2026 • 6:30 PM',
          'location': 'Suncorp',
          'price': 'Free',
          'badge': 'Sports Event',
          'categories': ['Sports'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'music-priority-item',
          'section': 'events',
          'title': 'Music Headliner',
          'description': 'Music event should rank first.',
          'dateTime': '11/06/2026 • 6:00 PM',
          'location': 'Riverstage',
          'price': 'Paid',
          'badge': 'Music Event',
          'categories': ['Music'],
          'approvalStatus': 'approved',
          'imageUrl': '',
        },
        {
          'id': 'sports-priority-item',
          'section': 'events',
          'title': 'Sports Finals',
          'description': 'Sports event should rank after music.',
          'dateTime': '12/06/2026 • 6:00 PM',
          'location': 'Suncorp',
          'price': 'Paid',
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('interest-priority-panel')), findsOneWidget);
    expect(
        find.byKey(const Key('interest-priority-chip-music')), findsOneWidget);

    final musicY = tester
        .getTopLeft(
            find.byKey(const Key('recommended-card-music-priority-item')))
        .dy;
    final sportsY = tester
        .getTopLeft(
            find.byKey(const Key('recommended-card-sports-priority-item')))
        .dy;
    expect(musicY, lessThan(sportsY));

    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Priority Tester',
        email: 'priority@test.com',
        password: 'Password123',
        interestedEventIds: ['seed-music', 'seed-sports'],
        interestPriorities: ['sports', 'music'],
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final musicAfterY = tester
        .getTopLeft(
            find.byKey(const Key('recommended-card-music-priority-item')))
        .dy;
    final sportsAfterY = tester
        .getTopLeft(
            find.byKey(const Key('recommended-card-sports-priority-item')))
        .dy;
    expect(sportsAfterY, lessThan(musicAfterY));

    VisitorAuth.debugSetCurrentVisitorForTesting(null);
  });
}
