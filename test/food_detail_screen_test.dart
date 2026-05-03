import 'package:brisconnect/screens/food_detail_screen.dart';
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

Widget _buildApp({
  String title = 'Howard Smith Wharves',
  String description = 'A vibrant dining precinct under the Story Bridge.',
  String location = 'Howard Smith Wharves, Brisbane',
  String cuisine = 'Asian Fusion & Modern Australian',
  String imageUrl = '',
  List<String> categories = const ['Waterfront', 'Fine Dining', 'Live Music'],
  double? rating = 4.6,
  String? badge = 'Must Try',
  String? dateTime = 'Daily 11 AM – 11 PM',
  String? price = '\$\$\$ – Premium',
  String? mapQuery = 'Howard Smith Wharves Brisbane',
  String? webLink,
  String? aiAudio,
}) {
  return MaterialApp(
    home: FoodDetailScreen(
      title: title,
      description: description,
      location: location,
      cuisine: cuisine,
      imageUrl: imageUrl,
      categories: categories,
      rating: rating,
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
  group('FoodDetailScreen – Core Display', () {
    testWidgets('TC-01 app bar shows Food Details title', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Food Details'), findsOneWidget);
    });

    testWidgets('TC-02 displays title, cuisine, location, and description',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Howard Smith Wharves'), findsOneWidget);
      expect(find.text('Asian Fusion & Modern Australian'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_menu_rounded), findsOneWidget);
      expect(find.text('Howard Smith Wharves, Brisbane'), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('About this Food Experience'), findsOneWidget);
      expect(
        find.text('A vibrant dining precinct under the Story Bridge.'),
        findsOneWidget,
      );
    });

    testWidgets('TC-03 shows rating, price, and badge when provided',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        rating: 4.6,
        price: '\$\$\$ – Premium',
        badge: 'Must Try',
      ));
      await tester.pump();

      expect(find.text('Must Try'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('\$\$\$ – Premium'), findsOneWidget);
      expect(find.byIcon(Icons.sell_rounded), findsOneWidget);
    });

    testWidgets('TC-04 shows date/time with schedule icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        dateTime: 'Daily 11 AM – 11 PM',
      ));
      await tester.pump();

      expect(find.text('Daily 11 AM – 11 PM'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('TC-05 renders category highlight chips', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        categories: ['Waterfront', 'Fine Dining', 'Live Music'],
      ));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Waterfront'), findsOneWidget);
      expect(find.text('Fine Dining'), findsOneWidget);
      expect(find.text('Live Music'), findsOneWidget);
    });
  });

  group('FoodDetailScreen – Optional Fields Hidden', () {
    testWidgets('TC-06 hides badge chip when badge is null', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(badge: null));
      await tester.pump();

      expect(find.text('Must Try'), findsNothing);
    });

    testWidgets('TC-07 hides rating row when rating is null', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(rating: null));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('TC-08 hides rating row when rating is zero', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(rating: 0));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('TC-09 hides price row when price is null', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(price: null));
      await tester.pump();

      expect(find.byIcon(Icons.sell_rounded), findsNothing);
    });

    testWidgets('TC-10 hides date/time when null', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(dateTime: null));
      await tester.pump();

      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('TC-11 hides description section when empty', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(description: ''));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('About this Food Experience'), findsNothing);
    });

    testWidgets('TC-12 hides Highlights when categories list is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(categories: []));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Highlights'), findsNothing);
    });
  });

  group('FoodDetailScreen – Action Buttons', () {
    testWidgets('TC-13 shows View on Map button', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        mapQuery: 'Howard Smith Wharves Brisbane',
      ));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('View on Map'), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
    });

    testWidgets('TC-14 shows Website button when webLink is provided',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        webLink: 'https://example.com',
      ));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('Website'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_browser_rounded), findsOneWidget);
    });

    testWidgets('TC-15 hides Website button when webLink is null',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(webLink: null));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('Website'), findsNothing);
      expect(find.byIcon(Icons.open_in_browser_rounded), findsNothing);
    });

    testWidgets('TC-16 shows share button in app bar', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });
  });

  group('FoodDetailScreen – Audio & Image', () {
    testWidgets('TC-17 shows Audio Guide section', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(
        aiAudio: null,
        description: 'Great riverside food experience.',
      ));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();

      expect(find.text('Audio Guide'), findsOneWidget);
    });

    testWidgets('TC-18 shows fallback container when image URL is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(imageUrl: ''));
      await tester.pump();

      final containers = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints != null &&
              w.constraints!.maxHeight == 230,
        ),
      );
      expect(containers.isNotEmpty, isTrue);
    });
  });
}
