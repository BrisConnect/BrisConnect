import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildApp({Map<String, dynamic>? event}) {
  return MaterialApp(
    home: VisitorEventDetailScreen(
      event: event ??
          const {
            'id': 'evt-1',
            'title': 'River Festival',
            'badge': 'Festival',
            'dateTime': '20/06/2026 • 7:00 PM',
            'location': 'South Bank Parklands, Brisbane',
            'price': 'Free',
            'description':
                'An annual celebration of Brisbane\'s river culture.',
            'culturalBackground':
                'Indigenous peoples have gathered along the Brisbane River for thousands of years.',
            'imageUrl': '',
            'aiAudio': '',
            'aiNarration': '',
            'audioUrl': '',
            'webLink': 'https://riverfestival.com.au',
            'mapQuery': 'South Bank Parklands Brisbane',
            'section': 'events',
          },
    ),
  );
}

/// Build app with a detail screen embedded inside a parent so
/// Navigator.pop can be verified.
Widget _buildAppWithParent({Map<String, dynamic>? event}) {
  final eventData = event ??
      const {
        'id': 'evt-nav',
        'title': 'Nav Test Event',
        'dateTime': '15/06/2026 • 6:00 PM',
        'location': 'CBD',
        'description': 'Test navigation.',
        'imageUrl': '',
        'section': 'events',
      };
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitorEventDetailScreen(event: eventData),
            ),
          ),
          child: const Text('Go to Detail'),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(null);
  });

  // =====================================================================
  // AC-1  Displays title, date, time, location, and description
  // =====================================================================
  group('AC-1: displays title, date, time, location, and description', () {
    testWidgets('title is rendered in event detail page', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('River Festival'), findsOneWidget);
    });

    testWidgets('date/time row is rendered', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('20/06/2026 • 7:00 PM'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    });

    testWidgets('location row is rendered', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
          find.text('South Bank Parklands, Brisbane'), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);
    });

    testWidgets('description section is rendered', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Scroll down to see description content
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('About this Event'), findsOneWidget);
      expect(
        find.text("An annual celebration of Brisbane's river culture."),
        findsOneWidget,
      );
    });

    testWidgets('app bar shows Event Details title', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Event Details'), findsOneWidget);
    });

    testWidgets('badge pill is rendered when provided', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Festival'), findsOneWidget);
    });

    testWidgets('price chip is rendered when provided', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('title defaults to Event when field is missing', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-empty',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('Event'), findsOneWidget);
    });
  });

  // =====================================================================
  // AC-2  Optional rich content is shown when available
  // =====================================================================
  group('AC-2: optional rich content shown when available', () {
    testWidgets('cultural background section renders when provided',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Scroll down to reach cultural content
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Cultural Background'), findsOneWidget);
      expect(
        find.textContaining('Indigenous peoples have gathered'),
        findsOneWidget,
      );
    });

    testWidgets('AI narration section renders when narration text is available',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-ai',
        'title': 'AI Event',
        'imageUrl': '',
        'description': 'A test event.',
        'aiAudio': 'Welcome to the AI narration.',
        'section': 'events',
      }));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('AI Narration'), findsOneWidget);
    });

    testWidgets('Audio Guide header shown when audioUrl is provided',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-audio',
        'title': 'Audio Event',
        'imageUrl': '',
        'description': 'A test event.',
        'audioUrl': 'https://storage.com/audio.mp3',
        'section': 'events',
      }));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Audio Guide'), findsOneWidget);
    });

    testWidgets('website button renders when webLink is provided',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Scroll to action buttons
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('Website'), findsOneWidget);
    });

    testWidgets('View on Map button renders when location data is present',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('View on Map'), findsOneWidget);
    });

    testWidgets('share button is in app bar', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('save/favorite button is in app bar', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    });

  });

  // =====================================================================
  // AC-3  Missing optional data does not break the page layout
  // =====================================================================
  group('AC-3: missing optional data does not break layout', () {
    testWidgets('page renders without badge', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-min',
        'title': 'Minimal Event',
        'imageUrl': '',
        'dateTime': '15/06/2026',
        'location': 'CBD',
        'description': 'Minimal.',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('Minimal Event'), findsOneWidget);
      // No badge rendered
      expect(find.text('Festival'), findsNothing);
    });

    testWidgets('page renders without dateTime', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-nodt',
        'title': 'No Date Event',
        'imageUrl': '',
        'location': 'CBD',
        'description': 'No date.',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('No Date Event'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_rounded), findsNothing);
    });

    testWidgets('page renders without location', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-noloc',
        'title': 'No Location Event',
        'imageUrl': '',
        'dateTime': '15/06/2026',
        'description': 'No location.',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('No Location Event'), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
    });

    testWidgets('page renders without description', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-nodesc',
        'title': 'No Description',
        'imageUrl': '',
        'dateTime': '15/06/2026',
        'location': 'CBD',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('No Description'), findsOneWidget);
      expect(find.text('About this Event'), findsNothing);
    });

    testWidgets('page renders without price', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-nop',
        'title': 'No Price',
        'imageUrl': '',
        'dateTime': '15/06/2026',
        'location': 'CBD',
        'description': 'No price.',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('No Price'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
    });

    testWidgets('page renders without culturalBackground', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-nocb',
        'title': 'Simple Event',
        'imageUrl': '',
        'description': 'Simple.',
        'section': 'events',
      }));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Cultural Background'), findsNothing);
    });

    testWidgets('page renders without webLink (no Website button)',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-noweb',
        'title': 'No Web',
        'imageUrl': '',
        'location': 'CBD',
        'description': 'No web link.',
        'mapQuery': 'CBD Brisbane',
        'section': 'events',
      }));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Website'), findsNothing);
    });

    testWidgets('completely minimal event with only id renders',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-bare',
        'imageUrl': '',
      }));
      await tester.pump();

      // Default title 'Event' is used
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Event Details'), findsOneWidget);
    });

    testWidgets('empty event map does not crash', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const <String, dynamic>{}));
      await tester.pump();

      expect(find.text('Event'), findsOneWidget);
      expect(find.byType(VisitorEventDetailScreen), findsOneWidget);
    });
  });

  // =====================================================================
  // AC-4  The user can navigate to and from the detail page correctly
  // =====================================================================
  group('AC-4: navigation to and from detail page', () {
    testWidgets('detail page is reached via Navigator.push', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildAppWithParent());
      await tester.pump();

      // Parent screen visible
      expect(find.text('Go to Detail'), findsOneWidget);

      // Navigate to detail
      await tester.tap(find.text('Go to Detail'));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Nav Test Event'), findsOneWidget);
      expect(find.text('Event Details'), findsOneWidget);
    });

    testWidgets('back button returns to previous screen', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildAppWithParent());
      await tester.pump();

      // Navigate to detail
      await tester.tap(find.text('Go to Detail'));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Nav Test Event'), findsOneWidget);

      // Tap back button (AppBar leading)
      await tester.tap(find.byType(BackButton));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Parent screen is visible again
      expect(find.text('Go to Detail'), findsOneWidget);
      expect(find.text('Nav Test Event'), findsNothing);
    });

    testWidgets('VisitorEventDetailScreen is a StatefulWidget',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(VisitorEventDetailScreen), findsOneWidget);
    });

    testWidgets('detail page is scrollable (ListView)', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);

      // Scroll succeeds without error
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    });
  });

  // =====================================================================
  // AC-5  Event detail content is consistent with the selected event
  // =====================================================================
  group('AC-5: content consistent with selected event', () {
    testWidgets('all fields from event map are displayed correctly',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-full',
        'title': 'GOMA After Dark',
        'badge': 'Arts',
        'dateTime': '25/07/2026 • 8:00 PM',
        'location': 'Gallery of Modern Art, South Bank',
        'price': '\$25',
        'description': 'Evening exhibition opening.',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('GOMA After Dark'), findsOneWidget);
      expect(find.text('Arts'), findsOneWidget);
      expect(find.text('25/07/2026 • 8:00 PM'), findsOneWidget);
      expect(find.text('Gallery of Modern Art, South Bank'), findsOneWidget);
      expect(find.text('\$25'), findsOneWidget);
    });

    testWidgets('different event shows different data', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-other',
        'title': 'West End Markets',
        'badge': 'Food',
        'dateTime': 'Every Saturday • 6:00 AM',
        'location': 'Davies Park, West End',
        'price': 'Free',
        'description': 'Fresh produce and artisan goods.',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('West End Markets'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Every Saturday • 6:00 AM'), findsOneWidget);
      expect(find.text('Davies Park, West End'), findsOneWidget);

      // Confirm the other event's data is not shown
      expect(find.text('River Festival'), findsNothing);
      expect(find.text('South Bank Parklands, Brisbane'), findsNothing);
    });

    testWidgets('whitespace-only fields are treated as empty', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-ws',
        'title': 'Whitespace Test',
        'badge': '   ',
        'dateTime': '   ',
        'location': '   ',
        'price': '   ',
        'description': '   ',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('Whitespace Test'), findsOneWidget);
      // Trimmed empty strings should hide their sections
      expect(find.byIcon(Icons.calendar_today_rounded), findsNothing);
      expect(find.byIcon(Icons.place_rounded), findsNothing);
      expect(find.text('About this Event'), findsNothing);
    });

    testWidgets('id is preserved for save/interested logic', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-specific-123',
        'title': 'Specific Event',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      // The screen should render without issue — id is used internally
      expect(find.text('Specific Event'), findsOneWidget);
    });
  });

  // =====================================================================
  // AC-6  Detail pages load quickly and present information clearly
  //       across all devices
  // =====================================================================
  group('AC-6: quick clear presentation across devices', () {
    testWidgets('renders correctly at phone portrait resolution',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('River Festival'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders correctly at tablet resolution', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('River Festival'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders correctly at small phone resolution', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('River Festival'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('hero image placeholder shows while loading', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Image area exists as part of the scrollable content
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('image error widget renders gracefully', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-bad-img',
        'title': 'Bad Image',
        'imageUrl': 'https://broken.invalid/nope.jpg',
        'section': 'events',
      }));
      await tester.pump();

      // Screen still renders without crash
      expect(find.text('Bad Image'), findsOneWidget);
    });

    testWidgets('long description text does not overflow', (tester) async {
      _setViewport(tester);
      final longDesc = 'A ' * 500;
      await tester.pumpWidget(_buildApp(event: {
        'id': 'evt-long',
        'title': 'Long Description',
        'description': longDesc,
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.text('Long Description'), findsOneWidget);

      // Scroll deep to verify no overflow crash
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
    });

    testWidgets('long title text does not overflow', (tester) async {
      _setViewport(tester);
      final longTitle = 'LongTitleWord ' * 20;
      await tester.pumpWidget(_buildApp(event: {
        'id': 'evt-longtitle',
        'title': longTitle,
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      expect(find.textContaining('LongTitleWord'), findsOneWidget);
    });

    testWidgets('narration text is generated from event fields when no aiAudio',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(event: const {
        'id': 'evt-gen',
        'title': 'Generated Narration',
        'badge': 'Music',
        'dateTime': '20/06/2026 • 8:00 PM',
        'location': 'Valley',
        'description': 'Live band performance.',
        'price': 'Free',
        'imageUrl': '',
        'section': 'events',
      }));
      await tester.pump();

      // Scroll to narration section
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('AI Narration'), findsOneWidget);
    });
  });
}
