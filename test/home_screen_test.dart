import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/home_screen.dart';

void main() {
  Widget buildTestApp() {
    return const MaterialApp(home: HomeScreen());
  }

  testWidgets('Discover screen shows required sections and tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Brisbane City Council Events'), findsOneWidget);
    expect(
      find.text('Historical Sights in Brisbane', skipOffstage: false),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Authentic Brisbane Food'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Authentic Brisbane Food'), findsOneWidget);

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Search filters discover content', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'nonexistent_query_123',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('No matching council events. Try changing your search or filters.'),
      findsOneWidget,
    );
    expect(find.text('No matching historical sights found.'), findsOneWidget);
    expect(find.text('No matching food places found.'), findsOneWidget);
  });

  testWidgets('Filter sheet opens with section options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Filter Discover'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Historical Sights'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);

    expect(find.text('Apply'), findsOneWidget);
  });
}
