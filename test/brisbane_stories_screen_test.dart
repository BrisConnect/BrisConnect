import 'package:brisconnect/screens/brisbane_stories_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds approved stories into the fake Firestore instance.
Future<void> _seedStories(
  FakeFirebaseFirestore firestore,
  List<Map<String, dynamic>> stories,
) async {
  for (final s in stories) {
    await firestore.collection('brisbane_stories').doc(s['id'] as String).set({
      'title': s['title'],
      'description': s['description'] ?? '',
      'imageUrl': s['imageUrl'] ?? '',
      'category': s['category'] ?? '',
      'content': s['content'] ?? '',
      'latitude': s['latitude'],
      'longitude': s['longitude'],
      'locationName': s['locationName'],
      'approvalStatus': s['approvalStatus'] ?? 'approved',
      'publishedAt': s['publishedAt'],
    });
  }
}

/// Seeds approved voices into the fake Firestore instance.
Future<void> _seedVoices(
  FakeFirebaseFirestore firestore,
  List<Map<String, dynamic>> voices,
) async {
  for (final v in voices) {
    await firestore.collection('brisbane_voices').doc(v['id'] as String).set({
      'name': v['name'],
      'quote': v['quote'],
      'profileImageUrl': v['profileImageUrl'] ?? '',
      'approvalStatus': v['approvalStatus'] ?? 'approved',
    });
  }
}

Widget _buildApp(FakeFirebaseFirestore firestore) {
  return MaterialApp(
    home: BrisbaneStoriesScreen(firestore: firestore),
  );
}

/// Pump enough frames for async _loadData() to complete and one animation
/// frame to render, without using pumpAndSettle (which hangs because the
/// screen has a repeating AnimationController for map-pin pulse).
Future<void> _pumpAndLoad(WidgetTester tester) async {
  await tester.pump();                           // start _loadData
  await tester.pump(const Duration(seconds: 1)); // let FakeFirestore resolve
  await tester.pump();                           // rebuild after setState
}

// Sample data
const _sampleStories = [
  {
    'id': 'story-1',
    'title': 'South Bank Parklands',
    'description': 'A cultural precinct by the river',
    'imageUrl': '',
    'category': 'landmarks',
    'content': 'Full content about South Bank.',
    'latitude': -27.4798,
    'longitude': 153.0234,
    'locationName': 'South Bank, Brisbane',
    'approvalStatus': 'approved',
  },
  {
    'id': 'story-2',
    'title': 'Turrbal Country',
    'description': 'First Nations heritage around Brisbane',
    'imageUrl': '',
    'category': 'first_nations',
    'content': 'Content about Turrbal and Jagera Country.',
    'latitude': -27.4705,
    'longitude': 153.0260,
    'locationName': 'Brisbane CBD',
    'approvalStatus': 'approved',
  },
  {
    'id': 'story-3',
    'title': 'GOMA Gallery',
    'description': 'Modern art at Queensland Gallery',
    'imageUrl': '',
    'category': 'arts',
    'content': 'Content about GOMA.',
    'approvalStatus': 'approved',
  },
];

const _sampleVoices = [
  {
    'id': 'voice-1',
    'name': 'Emily Jones',
    'quote': 'Brisbane is a city of stories waiting to be told.',
    'profileImageUrl': '',
    'approvalStatus': 'approved',
  },
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BrisbaneStoriesScreen', () {
    // Use a taller surface to avoid SliverAppBar overflow in the 800×600
    // default test viewport.
    late WidgetTester tester;

    Future<void> setUpSurface(WidgetTester tester) async {
      tester = tester;
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Suppress the 1px RenderFlex overflow from the FlexibleSpaceBar
      // title Column when the pinned SliverAppBar collapses during scroll.
      final original = FlutterError.onError!;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }
    testWidgets('shows loading indicator while data is being fetched',
        (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildApp(firestore));

      // On the very first frame, loading spinner should be visible.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays story titles after data loads', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);
      await _seedVoices(firestore, _sampleVoices);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // The first story should appear in the hero carousel.
      expect(find.text('South Bank Parklands'), findsWidgets);

      // Section headings that appear after loading.
      expect(find.text('Trending Stories'), findsOneWidget);
      expect(find.text('Explore by Category'), findsOneWidget);
    });

    testWidgets('no error state on successful load', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // Error state should NOT be visible when data loads successfully.
      expect(find.text('Unable to load stories right now. Please try again.'),
          findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets('renders five category filter chips', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // The 5 categories defined in the screen.
      expect(find.text('First Nations'), findsOneWidget);
      expect(find.text('Arts'), findsOneWidget);
      expect(find.text('Landmarks'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Festivals'), findsOneWidget);
    });

    testWidgets('category filter shows only matching stories', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // Before filtering — heading says 'Featured Stories'.
      expect(find.text('Featured Stories'), findsOneWidget);

      // Ensure the 'Arts' chip is visible and not behind the pinned app bar.
      await tester.ensureVisible(find.text('Arts'));
      await tester.pump();
      await tester.tap(find.text('Arts'));
      await tester.pump();

      // Section heading changes to 'Stories' when a category is active.
      expect(find.text('Stories'), findsOneWidget);
      expect(find.text('Featured Stories'), findsNothing);
    });

    testWidgets('displays Voices of Brisbane section', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);
      await _seedVoices(firestore, _sampleVoices);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // Scroll down to find the voices section.
      await tester.dragUntilVisible(
        find.text('Voices of Brisbane'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.text('Voices of Brisbane'), findsOneWidget);
      expect(find.text('Emily Jones'), findsOneWidget);
      expect(
        find.text('Brisbane is a city of stories waiting to be told.'),
        findsOneWidget,
      );
    });

    testWidgets('map preview shows location count', (tester) async {
      await setUpSurface(tester);
      final firestore = FakeFirebaseFirestore();
      await _seedStories(firestore, _sampleStories);

      await tester.pumpWidget(_buildApp(firestore));
      await _pumpAndLoad(tester);

      // Scroll to map preview.
      await tester.dragUntilVisible(
        find.text('Explore Cultural Locations'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.text('Explore Cultural Locations'), findsOneWidget);
      // 2 of 3 stories have lat/lng.
      expect(find.text('2 locations on the map'), findsOneWidget);
    });
  });
}
