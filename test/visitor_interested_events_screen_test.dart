import 'dart:async';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_interested_events_screen.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test-only DiscoverDataService backed by FakeFirebaseFirestore.
// ---------------------------------------------------------------------------
class TestDiscoverDataService extends DiscoverDataService {
  final Stream<List<Map<String, dynamic>>> _stream;

  TestDiscoverDataService(this._stream)
      : super(firestore: FakeFirebaseFirestore(), enableSeedDefaults: false);

  @override
  Stream<List<Map<String, dynamic>>> watchApprovedDiscoverItems() => _stream;
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------
const _approvedEvents = [
  {
    'id': 'evt-1',
    'section': 'events',
    'title': 'Riverfire 2026',
    'dateTime': '15/06/2026 • 7:00 PM',
    'location': 'South Bank Parklands',
    'approvalStatus': 'approved',
  },
  {
    'id': 'evt-2',
    'section': 'events',
    'title': 'Jazz Night',
    'dateTime': '20/07/2026 • 8:00 PM',
    'location': 'Fortitude Valley',
    'approvalStatus': 'approved',
  },
  {
    'id': 'evt-3',
    'section': 'events',
    'title': 'Hidden Event',
    'dateTime': '01/08/2026 • 5:00 PM',
    'location': 'CBD',
    'approvalStatus': 'approved',
  },
  {
    'id': 'attr-1',
    'section': 'attractions',
    'title': 'Lone Pine Koala Sanctuary',
    'dateTime': '',
    'location': 'Fig Tree Pocket',
    'approvalStatus': 'approved',
  },
];

Widget _buildApp(TestDiscoverDataService service) {
  return MaterialApp(
    home: VisitorInterestedEventsScreen(
      discoverDataService: service,
    ),
  );
}

void main() {
  group('VisitorInterestedEventsScreen', () {
    setUp(() {
      // Reset visitor state before each test.
      VisitorAuth.debugSetCurrentVisitorForTesting(null);
    });

    tearDown(() {
      VisitorAuth.debugSetCurrentVisitorForTesting(null);
    });

    testWidgets('shows empty state when visitor has no interested events',
        (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: [],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No interested events yet. Tap the heart icon on an event to save it for later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while stream is waiting',
        (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['evt-1'],
        ),
      );

      // StreamController that never emits — stays in ConnectionState.waiting
      final controller = StreamController<List<Map<String, dynamic>>>();
      addTearDown(controller.close);
      final service = TestDiscoverDataService(controller.stream);
      await tester.pumpWidget(_buildApp(service));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading interested events...'), findsOneWidget);
    });

    testWidgets('displays only events the visitor has marked as interested',
        (tester) async {
      // Visitor interested in evt-1 and evt-2 but NOT evt-3
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['evt-1', 'evt-2'],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      expect(find.text('Riverfire 2026'), findsOneWidget);
      expect(find.text('Jazz Night'), findsOneWidget);
      // Not interested in this one
      expect(find.text('Hidden Event'), findsNothing);
      // Attractions are filtered out
      expect(find.text('Lone Pine Koala Sanctuary'), findsNothing);
    });

    testWidgets('filters out non-event sections (attractions)',
        (tester) async {
      // Visitor interested in an attraction ID — should not appear
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['attr-1'],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // attr-1 has section 'attractions', so it's filtered out
      expect(find.text('Lone Pine Koala Sanctuary'), findsNothing);
      expect(
        find.text(
          'No interested events yet. Tap the heart icon on an event to save it for later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows event details — date and location on each card',
        (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['evt-1'],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      expect(find.text('Riverfire 2026'), findsOneWidget);
      expect(find.text('Date: 15/06/2026 • 7:00 PM'), findsOneWidget);
      expect(find.text('Location: South Bank Parklands'), findsOneWidget);
    });

    testWidgets('shows remove button with tooltip on each event card',
        (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['evt-1'],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Remove button present with tooltip
      expect(find.byTooltip('Remove from interested'), findsOneWidget);

      // The tooltip wraps an IconButton that is tappable
      final iconButton = find.ancestor(
        of: find.byTooltip('Remove from interested'),
        matching: find.byType(IconButton),
      );
      expect(iconButton, findsOneWidget);
    });

    testWidgets('each card has a favourite heart icon', (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(
        const VisitorUser(
          name: 'Test Visitor',
          email: 'visitor@test.com',
          password: 'Password123',
          interestedEventIds: ['evt-1', 'evt-2'],
        ),
      );

      final service =
          TestDiscoverDataService(Stream.value(List.from(_approvedEvents)));
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Leading favourite icon + trailing remove icon = 2 per card × 2 cards
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(4));
    });
  });
}
