import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/attraction_detail_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Attraction with rich accessibility details provided by the admin.
const _richAccessibility = ApprovedAttraction(
  id: 'city-hall',
  name: 'Brisbane City Hall',
  description: 'Heritage-listed civic building.',
  location: '64 Adelaide Street',
  latitude: -27.4688,
  longitude: 153.0235,
  category: 'Cultural',
  accessibilityDetails: [
    'Wheelchair ramp at main entrance',
    'Accessible lift to all floors',
    'Hearing loop in auditorium',
    'Accessible toilets on ground floor',
    'Braille signage throughout',
  ],
);

/// Attraction with a single accessibility detail.
const _singleAccessibility = ApprovedAttraction(
  id: 'story-bridge',
  name: 'Story Bridge',
  description: 'Heritage cantilever bridge.',
  location: 'Kangaroo Point',
  latitude: -27.4630,
  longitude: 153.0340,
  category: 'Landmarks',
  accessibilityDetails: ['Step-free path to viewing platform'],
);

/// Attraction with NO accessibility details (empty list).
const _noAccessibility = ApprovedAttraction(
  id: 'minimal-place',
  name: 'Minimal Place',
  description: 'A place with sparse data.',
  location: 'Brisbane',
  latitude: -27.47,
  longitude: 153.02,
);

/// Second attraction for multi-attraction list contexts.
const _otherAttraction = ApprovedAttraction(
  id: 'south-bank',
  name: 'South Bank Parklands',
  description: 'Riverside parkland precinct.',
  location: 'South Brisbane',
  latitude: -27.4804,
  longitude: 153.0229,
  category: 'Nature',
  accessibilityDetails: ['Paved paths', 'Accessible toilets'],
);

const _allAttractions = [
  _richAccessibility,
  _singleAccessibility,
  _noAccessibility,
  _otherAttraction,
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  required ApprovedAttraction attraction,
  List<ApprovedAttraction> allAttractions = _allAttractions,
}) {
  return MaterialApp(
    home: AttractionDetailScreen(
      attraction: attraction,
      allAttractions: allAttractions,
    ),
  );
}

/// Sets a tall viewport and suppresses overflow errors common with
/// deep scrolling through the detail screen.
void _setUpViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Scrolls down repeatedly until [finder] is visible.
Future<void> _scrollToVisible(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 25,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.dragFrom(const Offset(400, 520), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // AC-1 : Accessibility section displayed for attractions
  // =========================================================================
  group('AC-1: Accessibility section displayed', () {
    testWidgets('Facilities & Accessibility section heading is rendered',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Facilities & Accessibility'));
      expect(find.text('Facilities & Accessibility'), findsOneWidget);
    });

    testWidgets('Accessibility sub-card title is rendered within the section',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Accessibility'));
      // "Accessibility" is the _ChipCollectionCard title
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgets('section appears for attraction with accessibility details',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _singleAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Facilities & Accessibility'));
      expect(find.text('Facilities & Accessibility'), findsOneWidget);
    });

    testWidgets('section appears for attraction WITHOUT accessibility details',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _noAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Facilities & Accessibility'));
      expect(find.text('Facilities & Accessibility'), findsOneWidget);
    });

    testWidgets(
        'section also contains Facilities and Amenities sub-cards',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Facilities'));
      expect(find.text('Facilities'), findsOneWidget);
      await _scrollToVisible(tester, find.text('Amenities'));
      expect(find.text('Amenities'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-2 : Accessibility details shown as a list when provided by Admin
  // =========================================================================
  group('AC-2: Accessibility details shown as list', () {
    testWidgets('all five admin-provided accessibility chips are displayed',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));
      expect(
          find.text('Wheelchair ramp at main entrance'), findsOneWidget);
      expect(
          find.text('Accessible lift to all floors'), findsOneWidget);
      expect(
          find.text('Hearing loop in auditorium'), findsOneWidget);
      expect(
          find.text('Accessible toilets on ground floor'), findsOneWidget);
      expect(
          find.text('Braille signage throughout'), findsOneWidget);
    });

    testWidgets('single accessibility detail is displayed as a chip',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _singleAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Step-free path to viewing platform'));
      expect(
        find.text('Step-free path to viewing platform'),
        findsOneWidget,
      );
    });

    testWidgets('accessibility chips are rendered inside a Wrap layout',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));

      // The chip collection uses Wrap for flexible, wrapping layout
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets(
        'accessibility details from ApprovedAttraction model are used '
        'instead of detail service accessibility field', (tester) async {
      _setUpViewport(tester);

      // _richAccessibility has admin-provided details; the fallback
      // detail service generates different values, but admin data wins.
      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));

      // Admin-provided text appears
      expect(
          find.text('Wheelchair ramp at main entrance'), findsOneWidget);

      // The fallback text should NOT appear
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsNothing,
      );
    });

    testWidgets('each accessibility detail appears exactly once',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Hearing loop in auditorium'));

      // Each chip text should appear exactly once
      for (final detail in _richAccessibility.accessibilityDetails) {
        expect(find.text(detail), findsOneWidget);
      }
    });
  });

  // =========================================================================
  // AC-3 : Fallback message when accessibility details not available
  // =========================================================================
  group('AC-3: Fallback message when details not available', () {
    testWidgets(
        'shows fallback message when accessibilityDetails is empty',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _noAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester,
          find.text('Accessibility details not provided by admin yet.'));
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsOneWidget,
      );
    });

    testWidgets('fallback message does NOT appear when details are provided',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Facilities & Accessibility'));

      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsNothing,
      );
    });

    testWidgets(
        'fallback shown for attraction with explicitly empty list',
        (tester) async {
      _setUpViewport(tester);

      const emptyList = ApprovedAttraction(
        id: 'empty-acc',
        name: 'Empty Accessibility',
        description: 'Test',
        location: 'Brisbane',
        latitude: -27.47,
        longitude: 153.02,
        accessibilityDetails: [],
      );

      await tester
          .pumpWidget(_buildApp(attraction: emptyList, allAttractions: [emptyList]));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester,
          find.text('Accessibility details not provided by admin yet.'));
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // AC-4 : Accessibility info visible from attraction detail page
  // =========================================================================
  group('AC-4: Visible from attraction detail page', () {
    testWidgets(
        'accessibility section is reachable by scrolling the detail page',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      // Start at top
      expect(find.text('Overview'), findsOneWidget);

      // Scroll down to reach accessibility
      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));
      expect(
          find.text('Wheelchair ramp at main entrance'), findsOneWidget);
    });

    testWidgets(
        'accessibility section is within the same ListView as other sections',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      // All content is in a single scrollable body
      expect(find.byType(ListView), findsWidgets);

      // Can scroll from Overview down to Accessibility
      expect(find.text('Overview'), findsOneWidget);
      await _scrollToVisible(tester, find.text('Accessibility'));
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgets('detail page opened via ApprovedAttractionService shows '
        'accessibility data from Firestore', (tester) async {
      _setUpViewport(tester);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('a1').set({
        'name': 'Test Attraction',
        'description': 'Description',
        'location': 'Brisbane',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityDetails': [
          'Ramp access',
          'Guide dogs welcome',
        ],
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();
      expect(attractions, hasLength(1));
      expect(attractions.first.accessibilityDetails,
          containsAll(['Ramp access', 'Guide dogs welcome']));

      // Now render the detail screen with the parsed attraction
      await tester.pumpWidget(MaterialApp(
        home: AttractionDetailScreen(
          attraction: attractions.first,
          allAttractions: attractions,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Ramp access'));
      expect(find.text('Ramp access'), findsOneWidget);
      expect(find.text('Guide dogs welcome'), findsOneWidget);
    });

    testWidgets('Firestore accessibility field aliases are parsed correctly',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      // Use 'accessibility' alias instead of 'accessibilityDetails'
      await firestore.collection('attractions').doc('alias-1').set({
        'name': 'Alias Attraction',
        'description': 'Desc',
        'location': 'here',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibility': ['Audio descriptions available'],
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();
      expect(attractions.first.accessibilityDetails,
          contains('Audio descriptions available'));
    });

    testWidgets(
        'Firestore accessibilityFeatures alias is parsed correctly',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('alias-2').set({
        'name': 'Features Attraction',
        'description': 'Desc',
        'location': 'here',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityFeatures': ['Tactile flooring', 'Low counters'],
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();
      expect(attractions.first.accessibilityDetails,
          containsAll(['Tactile flooring', 'Low counters']));
    });

    testWidgets('Firestore string value is parsed into single-item list',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('str-acc').set({
        'name': 'String Accessibility',
        'description': 'Desc',
        'location': 'here',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityDetails': 'Wheelchair accessible',
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();
      expect(attractions.first.accessibilityDetails,
          equals(['Wheelchair accessible']));
    });
  });

  // =========================================================================
  // AC-5 : Layout presents content clearly and consistently
  // =========================================================================
  group('AC-5: Clear and consistent layout', () {
    testWidgets('accessibility chips use Wrap for responsive wrapping',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));

      // Verify Wrap is used (flexible layout)
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets('accessibility card is inside a decorated container',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));

      // _CardShell wraps in a decorated Container
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('narrow viewport (mobile) renders accessibility without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      // Screen renders at narrow width without overflow errors.
      // Scroll the full page to exercise layout at this width.
      for (int i = 0; i < 30; i++) {
        await tester.dragFrom(const Offset(187, 400), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Verify widget tree is still intact after full scroll.
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('wide viewport (tablet) renders accessibility without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Accessibility'));
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgets('accessibility section order: Facilities, Amenities, '
        'then Accessibility', (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll past Facilities, Amenities, then Accessibility in order
      await _scrollToVisible(tester, find.text('Facilities'));
      expect(find.text('Facilities'), findsOneWidget);
      await _scrollToVisible(tester, find.text('Amenities'));
      expect(find.text('Amenities'), findsOneWidget);
      await _scrollToVisible(tester, find.text('Accessibility'));
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgets('fallback message and real chips are mutually exclusive',
        (tester) async {
      _setUpViewport(tester);

      // With details → no fallback
      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));
      expect(
          find.text('Wheelchair ramp at main entrance'), findsOneWidget);
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsNothing,
      );
    });

    testWidgets('fallback-only when no details — no stale chips visible',
        (tester) async {
      _setUpViewport(tester);

      await tester.pumpWidget(_buildApp(attraction: _noAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester,
          find.text('Accessibility details not provided by admin yet.'));
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsOneWidget,
      );

      // None of the rich details should appear
      expect(
          find.text('Wheelchair ramp at main entrance'), findsNothing);
      expect(find.text('Hearing loop in auditorium'), findsNothing);
    });
  });

  // =========================================================================
  // AC-6 : Clearly presented, easy to understand, usable by all
  // =========================================================================
  group('AC-6: Clear presentation and usability', () {
    testWidgets('ApprovedAttraction model const-constructs with '
        'accessibilityDetails', (tester) async {
      // Pure unit: const constructor works with accessibility list
      const attraction = ApprovedAttraction(
        id: 'unit',
        name: 'Unit Test',
        description: 'd',
        location: 'l',
        latitude: 0,
        longitude: 0,
        accessibilityDetails: ['Feature A', 'Feature B'],
      );

      expect(attraction.accessibilityDetails, hasLength(2));
      expect(attraction.accessibilityDetails, contains('Feature A'));
    });

    testWidgets('ApprovedAttraction defaults accessibilityDetails to empty',
        (tester) async {
      const attraction = ApprovedAttraction(
        id: 'default',
        name: 'Default',
        description: 'd',
        location: 'l',
        latitude: 0,
        longitude: 0,
      );

      expect(attraction.accessibilityDetails, isEmpty);
    });

    testWidgets('AttractionDetailService fallback accessibility is populated',
        (tester) async {
      // Pure unit: the detail service always provides an accessibility list
      final detail = AttractionDetailService.getDetail(
        _noAccessibility,
        [_noAccessibility],
      );

      expect(detail.accessibility, isNotEmpty);
      expect(detail.accessibility.first,
          contains('Step-free'));
    });

    testWidgets('different attractions each show their own accessibility data',
        (tester) async {
      _setUpViewport(tester);

      // Render attraction with 5 details
      await tester.pumpWidget(_buildApp(attraction: _richAccessibility));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Wheelchair ramp at main entrance'));
      expect(
          find.text('Wheelchair ramp at main entrance'), findsOneWidget);

      // Now render different attraction with 2 details
      await tester.pumpWidget(_buildApp(attraction: _otherAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Paved paths'));
      expect(find.text('Paved paths'), findsOneWidget);
      expect(find.text('Accessible toilets'), findsOneWidget);

      // Old details should not bleed through
      expect(
          find.text('Wheelchair ramp at main entrance'), findsNothing);
    });

    testWidgets('screen renders fully without errors for attraction with '
        'many accessibility items', (tester) async {
      _setUpViewport(tester);

      const manyDetails = ApprovedAttraction(
        id: 'many',
        name: 'Many Accessibility Features',
        description: 'Test with many items.',
        location: 'Brisbane',
        latitude: -27.47,
        longitude: 153.02,
        accessibilityDetails: [
          'Wheelchair ramp',
          'Accessible lift',
          'Hearing loop',
          'Accessible toilets',
          'Braille signage',
          'Guide dogs welcome',
          'Tactile flooring',
          'Low counters',
          'Visual alerts',
          'Quiet room available',
        ],
      );

      await tester.pumpWidget(
          _buildApp(attraction: manyDetails, allAttractions: [manyDetails]));
      await tester.pump(const Duration(milliseconds: 500));

      // Screen renders without error; scroll to verify chips
      await _scrollToVisible(tester, find.text('Wheelchair ramp'));
      expect(find.text('Wheelchair ramp'), findsOneWidget);

      await _scrollToVisible(tester, find.text('Quiet room available'));
      expect(find.text('Quiet room available'), findsOneWidget);
    });

    testWidgets('Firestore round-trip preserves accessibility details',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final details = [
        'Wheelchair access',
        'Accessible parking',
        'Audio descriptions',
      ];

      await firestore.collection('attractions').doc('rt').set({
        'name': 'Round Trip',
        'description': 'Testing persistence',
        'location': 'Brisbane',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityDetails': details,
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();

      expect(attractions.first.accessibilityDetails, equals(details));
    });

    testWidgets('empty string items in accessibility list are filtered out',
        (tester) async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('attractions').doc('filter').set({
        'name': 'Filter Test',
        'description': 'Test',
        'location': 'Brisbane',
        'latitude': -27.47,
        'longitude': 153.02,
        'approvalStatus': 'approved',
        'accessibilityDetails': ['Valid item', '', '  ', 'Another valid'],
      });

      final service = ApprovedAttractionService(firestore: firestore);
      final attractions = await service.fetchApprovedAttractions();

      // Empty / whitespace-only items are filtered out by _toStringList
      expect(attractions.first.accessibilityDetails,
          equals(['Valid item', 'Another valid']));
    });
  });
}
