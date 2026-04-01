import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Visitor filter sheet scrolls on small screens without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final discoverStream = Stream<List<Map<String, dynamic>>>.value(
      const [
        {
          'id': 'event-1',
          'section': 'events',
          'title': 'Brisbane Music Night',
          'description': 'Open-air concert in the city.',
          'dateTime': '01/06/2026 • 6:00 PM',
          'location': 'South Bank',
          'price': 'Free',
          'badge': 'EVENT',
          'imageUrl': '',
        }
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VisitorPortalScreen(
          discoverItemsStreamOverride: discoverStream,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Filter Events'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    final sheetScrollable = find.byType(Scrollable).last;
    await tester.drag(
      sheetScrollable,
      const Offset(0, -220),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Filter Events'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
