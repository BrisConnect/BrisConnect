import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:brisconnect/screens/approved_attractions_map_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';

class _FakeApprovedAttractionService extends ApprovedAttractionService {
  _FakeApprovedAttractionService(this._stream)
      : super(firestore: FakeFirebaseFirestore());

  final Stream<List<ApprovedAttraction>> _stream;

  @override
  Stream<List<ApprovedAttraction>> watchApprovedAttractions() => _stream;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const ApprovedAttraction _cultural = ApprovedAttraction(
  id: 'c1',
  name: 'Museum of Brisbane',
  description: 'City heritage and exhibitions.',
  location: 'Brisbane City',
  latitude: -27.468,
  longitude: 153.023,
  category: 'Cultural',
);

const ApprovedAttraction _historical = ApprovedAttraction(
  id: 'h1',
  name: 'Old Government House',
  description: 'Historic government building.',
  location: 'QUT Gardens Point',
  latitude: -27.475,
  longitude: 153.028,
  category: 'Historical',
);

const ApprovedAttraction _nature = ApprovedAttraction(
  id: 'n1',
  name: 'South Bank Parklands',
  description: 'Riverside parkland attraction.',
  location: 'South Brisbane',
  latitude: -27.476,
  longitude: 153.020,
  category: 'Nature',
);

Widget buildApp(ApprovedAttractionService service) {
  return MaterialApp(
    home: ApprovedAttractionsMapScreen(attractionService: service),
  );
}

void main() {

  testWidgets('shows empty state when no approved attractions are available',
      (WidgetTester tester) async {
    final service =
        _FakeApprovedAttractionService(Stream.value(const <ApprovedAttraction>[]));

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.text('No approved attractions available yet.'), findsOneWidget);
  });

  testWidgets('renders markers and shows attraction details on selection',
      (WidgetTester tester) async {
    const ApprovedAttraction one = ApprovedAttraction(
      id: 'a1',
      name: 'Museum of Brisbane',
      description: 'City heritage and exhibitions.',
      location: 'Brisbane City',
      latitude: -27.468,
      longitude: 153.023,
    );

    const ApprovedAttraction two = ApprovedAttraction(
      id: 'a2',
      name: 'South Bank Parklands',
      description: 'Riverside parkland attraction.',
      location: 'South Brisbane',
      latitude: -27.475,
      longitude: 153.020,
    );

    final service =
        _FakeApprovedAttractionService(Stream.value(const <ApprovedAttraction>[one, two]));

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attraction-marker-a1')), findsOneWidget);
    expect(find.byKey(const Key('attraction-marker-a2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('attraction-marker-a1')));
    await tester.pumpAndSettle();

    expect(find.text('Museum of Brisbane'), findsOneWidget);
    expect(find.text('City heritage and exhibitions.'), findsOneWidget);
    expect(find.text('Brisbane City'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Category filter tests
  // -------------------------------------------------------------------------

  group('Category filter chips', () {
    testWidgets('single category selection shows only matching markers',
        (WidgetTester tester) async {
      final service = _FakeApprovedAttractionService(
        Stream.value(const <ApprovedAttraction>[_cultural, _historical, _nature]),
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      // All three markers visible initially.
      expect(find.byKey(const Key('attraction-marker-c1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-h1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-n1')), findsOneWidget);

      // Tap the "Cultural" chip.
      await tester.tap(find.byKey(const Key('category-chip-cultural')));
      await tester.pumpAndSettle();

      // Only the cultural marker remains.
      expect(find.byKey(const Key('attraction-marker-c1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-h1')), findsNothing);
      expect(find.byKey(const Key('attraction-marker-n1')), findsNothing);
    });

    testWidgets('multiple category selection shows all matching markers',
        (WidgetTester tester) async {
      final service = _FakeApprovedAttractionService(
        Stream.value(const <ApprovedAttraction>[_cultural, _historical, _nature]),
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      // Select Cultural and Historical.
      await tester.tap(find.byKey(const Key('category-chip-cultural')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-chip-historical')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attraction-marker-c1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-h1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-n1')), findsNothing);
    });

    testWidgets('no results shows message and clear-filter button',
        (WidgetTester tester) async {
      // Only a Cultural attraction exists; select Nature — no results.
      final service = _FakeApprovedAttractionService(
        Stream.value(const <ApprovedAttraction>[_cultural]),
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-chip-nature')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no-filter-results')), findsOneWidget);
      expect(find.text('No attractions found'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      // Cultural marker is gone.
      expect(find.byKey(const Key('attraction-marker-c1')), findsNothing);
    });

    testWidgets('deselecting all chips restores all markers',
        (WidgetTester tester) async {
      final service = _FakeApprovedAttractionService(
        Stream.value(const <ApprovedAttraction>[_cultural, _historical]),
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      // Select Cultural.
      await tester.tap(find.byKey(const Key('category-chip-cultural')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attraction-marker-h1')), findsNothing);

      // Deselect Cultural (back to no filter selected).
      await tester.tap(find.byKey(const Key('category-chip-cultural')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attraction-marker-c1')), findsOneWidget);
      expect(find.byKey(const Key('attraction-marker-h1')), findsOneWidget);
    });

    testWidgets('clear-filter button restores all markers from no-results state',
        (WidgetTester tester) async {
      final service = _FakeApprovedAttractionService(
        Stream.value(const <ApprovedAttraction>[_cultural]),
      );

      await tester.pumpWidget(buildApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-chip-nature')));
      await tester.pumpAndSettle();

      expect(find.text('No attractions found'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      // No-results overlay gone; original marker is back.
      expect(find.byKey(const Key('no-filter-results')), findsNothing);
      expect(find.byKey(const Key('attraction-marker-c1')), findsOneWidget);
    });
  });
}
