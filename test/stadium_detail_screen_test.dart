import 'package:brisconnect/screens/stadium_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  String title = 'Suncorp Stadium',
  String description = 'A world-class rectangular stadium in Milton.',
  String location = '40 Castlemaine St, Milton QLD 4064',
  String imageUrl = '',
  List<String> categories = const ['Stadium', 'Sports', 'Live Music'],
  String? badge = 'Stadium',
  String? dateTime = 'Event days only',
  String? price = '\$\$ – Varies by event',
  String? mapQuery = 'Suncorp Stadium Brisbane',
  String? webLink,
  String? aiAudio,
}) {
  return MaterialApp(
    home: StadiumDetailScreen(
      title: title,
      description: description,
      location: location,
      imageUrl: imageUrl,
      categories: categories,
      badge: badge,
      dateTime: dateTime,
      price: price,
      mapQuery: mapQuery,
      webLink: webLink,
      aiAudio: aiAudio,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StadiumDetailScreen', () {
    testWidgets('displays title, description, and location', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Title
      expect(find.text('Suncorp Stadium'), findsOneWidget);

      // Location row with icon
      expect(find.text('40 Castlemaine St, Milton QLD 4064'), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);

      // Scroll to description section
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('About this Venue'), findsOneWidget);
      expect(
        find.text('A world-class rectangular stadium in Milton.'),
        findsOneWidget,
      );
    });

    testWidgets('shows event dates, pricing, and category information',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        dateTime: 'Event days only',
        price: '\$\$ – Varies by event',
        categories: ['Stadium', 'Sports', 'Live Music'],
      ));
      await tester.pump();

      // Date/time row
      expect(find.text('Event days only'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      // Price row
      expect(find.text('\$\$ – Varies by event'), findsOneWidget);
      expect(find.byIcon(Icons.sell_rounded), findsOneWidget);

      // Scroll to categories
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Stadium'), findsAtLeastNWidgets(1));
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Live Music'), findsOneWidget);
    });

    testWidgets('defaults to placeholder label when location is empty',
        (tester) async {
      await tester.pumpWidget(_buildApp(location: ''));
      await tester.pump();

      expect(find.text('Location TBA'), findsOneWidget);
    });

    testWidgets('missing optional fields do not break page layout',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        badge: null,
        dateTime: null,
        price: null,
        webLink: null,
        aiAudio: null,
        categories: const [],
        description: '',
      ));
      await tester.pump();

      // Title still renders
      expect(find.text('Suncorp Stadium'), findsOneWidget);

      // Location still renders
      expect(
        find.text('40 Castlemaine St, Milton QLD 4064'),
        findsOneWidget,
      );

      // Optional sections absent
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.sell_rounded), findsNothing);
      expect(find.text('Categories'), findsNothing);
      expect(find.text('About this Venue'), findsNothing);

      // View on Map button still present
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.text('View on Map'), findsOneWidget);
    });

    testWidgets('shows badge chip and share button', (tester) async {
      await tester.pumpWidget(_buildApp(badge: 'Stadium'));
      await tester.pump();

      // Badge chip
      expect(find.text('Stadium'), findsAtLeastNWidgets(1));

      // Share icon in the AppBar actions
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets('shows Audio Guide section', (tester) async {
      await tester.pumpWidget(_buildApp(
        aiAudio: null,
        description: 'Home of the Brisbane Broncos.',
      ));
      await tester.pump();

      // Scroll to Audio Guide section
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('Audio Guide'), findsOneWidget);
    });

    testWidgets('shows View on Map and Website buttons when webLink provided',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        webLink: 'https://www.suncorpstadium.com.au/',
      ));
      await tester.pump();

      // Scroll to bottom action buttons
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('View on Map'), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_browser_rounded), findsOneWidget);
    });
  });
}
