import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/attractions_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/services/attraction_detail_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Fully-populated attraction for testing rich detail sections.
const _fullAttraction = ApprovedAttraction(
  id: 'city-hall',
  name: 'Brisbane City Hall',
  description: 'Heritage-listed civic building in the heart of Brisbane.',
  location: '64 Adelaide Street, Brisbane City QLD 4000',
  latitude: -27.4688,
  longitude: 153.0235,
  category: 'Cultural',
  accessibilityDetails: ['Wheelchair ramp', 'Accessible lift', 'Hearing loop'],
  webLink: 'https://www.brisbane.qld.gov.au/city-hall',
  imageUrl: 'https://example.com/city-hall.jpg',
  audioUrl: 'https://example.com/city-hall-guide.mp3',
  aiNarration: 'Welcome to Brisbane City Hall, a heritage civic landmark.',
);

/// Minimal attraction – no optional fields set.
const _minimalAttraction = ApprovedAttraction(
  id: 'minimal-place',
  name: 'Minimal Place',
  description: 'A place with sparse data.',
  location: 'Brisbane',
  latitude: -27.47,
  longitude: 153.02,
);

/// Second attraction for nearby/list tests.
const _secondAttraction = ApprovedAttraction(
  id: 'south-bank',
  name: 'South Bank Parklands',
  description: 'Iconic riverside parkland precinct.',
  location: 'South Brisbane QLD 4101',
  latitude: -27.4804,
  longitude: 153.0229,
  category: 'Nature',
  accessibilityDetails: ['Paved paths', 'Accessible toilets'],
);

/// Third attraction for nearby recommendations.
const _thirdAttraction = ApprovedAttraction(
  id: 'goma',
  name: 'Gallery of Modern Art',
  description: 'World-class modern art museum.',
  location: 'Stanley Place, South Brisbane QLD 4101',
  latitude: -27.4719,
  longitude: 153.0174,
  category: 'Cultural',
);

const _allAttractions = [_fullAttraction, _secondAttraction, _thirdAttraction];

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

/// Scrolls until [finder] is visible, with up to [maxScrolls] attempts.
/// Uses the primary Scrollable (the body ListView).
Future<void> _scrollToVisible(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 20,
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
  // AC-1 : Dedicated attraction detail screen
  // =========================================================================
  group('AC-1: Dedicated attraction detail screen', () {
    testWidgets('renders screen with attraction name in AppBar',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // AppBar title
      expect(find.text('Brisbane City Hall'), findsWidgets);
    });

    testWidgets('shows Overview section with description and category',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Overview'), findsOneWidget);
      expect(
        find.text('Heritage-listed civic building in the heart of Brisbane.'),
        findsOneWidget,
      );
      expect(find.text('Cultural'), findsWidgets);
    });

    testWidgets('shows Audio Guide section when narration text exists',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Audio Guide'));
      expect(find.text('Audio Guide'), findsOneWidget);
    });

    testWidgets('shows action bar with Save, Share, Itinerary buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Itinerary'), findsOneWidget);
    });

    testWidgets('shows Location & Planning section with map and address',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Location & Planning'));
      expect(find.text('Location & Planning'), findsOneWidget);
      expect(find.text('Open in Maps'), findsOneWidget);
    });

    testWidgets('shows Tickets & Booking section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Tickets & Booking'));
      expect(find.text('Tickets & Booking'), findsOneWidget);
    });

    testWidgets('shows Ratings & Reviews section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Ratings & Reviews'));
      expect(find.text('Ratings & Reviews'), findsOneWidget);
    });

    testWidgets('shows Contact section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Contact'));
      expect(find.text('Contact'), findsOneWidget);
    });

    testWidgets('shows Live Updates section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Live Updates'));
      expect(find.text('Live Updates'), findsOneWidget);
    });

    testWidgets('shows Nearby & Recommendations section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Nearby & Recommendations'));
      expect(find.text('Nearby & Recommendations'), findsOneWidget);
    });

    testWidgets('shows Languages & Audio section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Languages & Audio'));
      expect(find.text('Languages & Audio'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-2 : Opening hours when available
  // =========================================================================
  group('AC-2: Opening hours when available', () {
    testWidgets('shows Hours & Entry section heading', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Hours & Entry'));
      expect(find.text('Hours & Entry'), findsOneWidget);
    });

    testWidgets('shows Opening Hours card with fallback schedule lines',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Opening Hours'));
      expect(find.text('Opening Hours'), findsOneWidget);
    });

    testWidgets('shows Special Schedule card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Special Schedule'));
      expect(find.text('Special Schedule'), findsOneWidget);
    });

    testWidgets('shows Entry Requirements card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Entry Requirements'));
      expect(find.text('Entry Requirements'), findsOneWidget);
    });

    testWidgets('shows visit duration and best time to visit in planning card',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // Fallback detail generates visit duration text
      await _scrollToVisible(
          tester, find.textContaining('Estimated visit:'));
      expect(find.textContaining('Estimated visit:'), findsOneWidget);
      expect(find.textContaining('Best time to visit:'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-3 : Facilities and accessibility information
  // =========================================================================
  group('AC-3: Facilities and accessibility information', () {
    testWidgets('shows Facilities & Accessibility section heading',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Facilities & Accessibility'));
      expect(find.text('Facilities & Accessibility'), findsOneWidget);
    });

    testWidgets('shows Facilities chip collection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Facilities'));
      // Facilities is a _ChipCollectionCard title
      expect(find.text('Facilities'), findsOneWidget);
    });

    testWidgets('shows Amenities chip collection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Amenities'));
      expect(find.text('Amenities'), findsOneWidget);
    });

    testWidgets('shows Accessibility chip collection with admin-provided data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll to the Accessibility chip area
      await _scrollToVisible(tester, find.text('Wheelchair ramp'));
      expect(find.text('Wheelchair ramp'), findsOneWidget);
      expect(find.text('Accessible lift'), findsOneWidget);
      expect(find.text('Hearing loop'), findsOneWidget);
    });

    testWidgets(
        'shows fallback accessibility message when no details provided',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester,
          find.text('Accessibility details not provided by admin yet.'));
      expect(
        find.text('Accessibility details not provided by admin yet.'),
        findsOneWidget,
      );
    });

    testWidgets('shows fallback facility chips from detail service',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Fallback generates: 'Rest areas', 'Public access areas'
      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Rest areas'));
      expect(find.text('Rest areas'), findsOneWidget);
      expect(find.text('Public access areas'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-4 : Missing details handled without breaking layout
  // =========================================================================
  group('AC-4: Missing details handled without breaking layout', () {
    testWidgets('minimal attraction renders without errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        attraction: _minimalAttraction,
        allAttractions: [_minimalAttraction],
      ));
      await tester.pump(const Duration(milliseconds: 500));

      // Screen renders without throwing
      expect(find.text('Minimal Place'), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('contact section shows N/A buttons when no contact info',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        attraction: _minimalAttraction,
        allAttractions: [_minimalAttraction],
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Contact'));
      expect(find.text('Contact'), findsOneWidget);

      // Phone and email are null → shows 'Not available' and 'N/A' buttons
      expect(find.text('Not available'), findsWidgets);
      expect(find.text('N/A'), findsWidgets);
    });

    testWidgets('virtual tour shows Not available yet when URL is null',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Not available yet.'));
      expect(find.text('Not available yet.'), findsOneWidget);
    });

    testWidgets('booking button is disabled when no booking URL',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        attraction: _minimalAttraction,
        allAttractions: [_minimalAttraction],
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Tickets & Booking'));

      // The booking button should exist but be disabled (webLink is null)
      final bookingButton = find.widgetWithText(ElevatedButton, 'Official Website');
      expect(bookingButton, findsOneWidget);
      final ElevatedButton button = tester.widget(bookingButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('hero gallery falls back to stock image when no media',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // Even without media the gallery renders with a fallback label
      expect(find.text('Minimal Place'), findsWidgets);
      // A PageView is used for the gallery
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('attraction with no category uses Attraction as fallback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // Overview card uses 'Attraction' as category fallback
      expect(find.text('Attraction'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-5 : Open detail screen from attraction discovery flows
  // =========================================================================
  group('AC-5: Open detail from discovery flows', () {
    testWidgets('tapping attraction in list opens detail screen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('city-hall').set({
        'name': 'Brisbane City Hall',
        'description': 'Heritage-listed civic building.',
        'location': '64 Adelaide Street',
        'latitude': -27.4688,
        'longitude': 153.0235,
        'approvalStatus': 'approved',
        'category': 'Cultural',
      });

      final service = ApprovedAttractionService(firestore: firestore);
      await tester.pumpWidget(MaterialApp(
        home: AttractionsScreen(attractionService: service),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the attraction card
      await tester.tap(find.text('Brisbane City Hall'));
      await tester.pumpAndSettle();

      // Should now be on the detail screen
      expect(find.text('Brisbane City Hall'), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('detail screen shows back navigation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // AppBar renders with the attraction name as title
      expect(find.text('Brisbane City Hall'), findsWidgets);
      // The Scaffold has an AppBar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('nearby recommendations show other attraction names',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        attraction: _fullAttraction,
        allAttractions: _allAttractions,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Nearby Attractions'));

      // Nearby attractions should include the other two
      await _scrollToVisible(tester, find.text('South Bank Parklands'));
      expect(find.text('South Bank Parklands'), findsOneWidget);
    });

    testWidgets('personalised suggestions include same-category attractions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(
        attraction: _fullAttraction,
        allAttractions: _allAttractions,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Personalised Suggestions'));

      // GOMA is also 'Cultural' → should appear as a suggestion
      await _scrollToVisible(
          tester,
          find.textContaining('also try Gallery of Modern Art'));
      expect(find.textContaining('also try Gallery of Modern Art'), findsOneWidget);
    });
  });

  // =========================================================================
  // AC-6 : Loads quickly and presents information clearly across devices
  // =========================================================================
  group('AC-6: Clear presentation across devices', () {
    testWidgets('renders correctly on a narrow mobile viewport',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812); // iPhone-like
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Brisbane City Hall'), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('renders correctly on a wide tablet viewport',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1366); // iPad-like
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Brisbane City Hall'), findsWidgets);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('all major sections are scrollable in a single ListView',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      // body has ListView(s) — main vertical + possibly a horizontal media strip
      expect(find.byType(ListView), findsWidgets);

      // Scroll all the way down to the last section
      await _scrollToVisible(tester, find.text('Languages & Audio'));
      expect(find.text('Languages & Audio'), findsOneWidget);
    });

    testWidgets('live update card shows crowd, closure, events, weather lines',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Crowd level'));
      expect(find.text('Crowd level'), findsOneWidget);
      expect(find.text('Closures'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Weather'), findsOneWidget);
    });

    testWidgets('ratings section shows numeric rating and review count text',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _fullAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(tester, find.text('Ratings & Reviews'));
      // Fallback detail has rating 0.0 and 0 reviews
      expect(find.text('0.0'), findsOneWidget);
      expect(find.text('0 reviews'), findsOneWidget);
    });

    testWidgets('hours section shows fallback schedule for uncached attraction',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp(attraction: _minimalAttraction));
      await tester.pump(const Duration(milliseconds: 500));

      await _scrollToVisible(
          tester, find.text('Monday to Friday: Hours not published'));
      expect(
        find.text('Monday to Friday: Hours not published'),
        findsOneWidget,
      );
      expect(
        find.text('Saturday to Sunday: Check operator website'),
        findsOneWidget,
      );
    });

    testWidgets('detail service getDetail returns fallback data for unknown ID',
        (tester) async {
      // Pure unit test: service returns sensible fallback without Firestore
      const unknown = ApprovedAttraction(
        id: 'unknown-xyz',
        name: 'Unknown Place',
        description: 'Test',
        location: 'Anywhere',
        latitude: -27.47,
        longitude: 153.02,
        category: 'Nature',
      );

      final detail = AttractionDetailService.getDetail(unknown, [unknown]);

      expect(detail.address, 'Anywhere');
      expect(detail.openingHours, isNotEmpty);
      expect(detail.facilities, isNotEmpty);
      expect(detail.amenities, isNotEmpty);
      expect(detail.visitDuration, contains('45'));
      expect(detail.liveUpdate.crowdLevel, isNotEmpty);
    });

    testWidgets('detail service getDetail generates nearby from allAttractions',
        (tester) async {
      final detail = AttractionDetailService.getDetail(
        _fullAttraction,
        _allAttractions,
      );

      // Should include the other two, not the current attraction
      expect(detail.nearbyAttractions, contains('South Bank Parklands'));
      expect(detail.nearbyAttractions, contains('Gallery of Modern Art'));
      expect(detail.nearbyAttractions,
          isNot(contains('Brisbane City Hall')));
    });

    testWidgets('detail service getDetail generates personalised suggestions',
        (tester) async {
      final detail = AttractionDetailService.getDetail(
        _fullAttraction,
        _allAttractions,
      );

      // GOMA is also 'Cultural' → should generate a suggestion
      expect(
        detail.personalisedSuggestions.any(
            (s) => s.contains('Gallery of Modern Art')),
        isTrue,
      );
    });
  });
}
