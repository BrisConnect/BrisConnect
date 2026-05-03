import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/admin_login_screen.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';

// ---------------------------------------------------------------------------
// Login Selection Screen Tests
// User Story: As a User, I want to select my role before logging in so that
//             I am directed to the correct login screen.
// ---------------------------------------------------------------------------

Widget _buildApp() {
  return const MaterialApp(home: LoginSelectionScreen());
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // ── AC-1: Three login options — Visitor, Local, Admin ─────────────────

  group('LoginSelectionScreen – Role Options', () {
    testWidgets('displays Visitor Login option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Visitor Login'), findsOneWidget);
    });

    testWidgets('displays Local Login option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Local Login'), findsOneWidget);
    });

    testWidgets('Admin Login is hidden by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Admin option is gated behind a 5-tap easter egg.
      expect(find.text('Admin Login'), findsNothing);
    });

    testWidgets('Admin Login appears after tapping title five times',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // The "Log In" heading is wrapped in a GestureDetector.
      final heading = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.text('Log In'),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(heading);
        await tester.pump();
      }

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Admin login unlocked'), findsOneWidget);
    });
  });

  // ── AC-2: Descriptive subtitles for each role ─────────────────────────

  group('LoginSelectionScreen – Descriptive Subtitles', () {
    testWidgets('Visitor option shows descriptive subtitle', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Browse events, culture, and local experiences'),
        findsOneWidget,
      );
    });

    testWidgets('Local option shows descriptive subtitle', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Manage local submissions and community events'),
        findsOneWidget,
      );
    });

    testWidgets('Admin option shows descriptive subtitle after unlock',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final heading = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.text('Log In'),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(heading);
        await tester.pump();
      }

      expect(
        find.text('Access review and management tools'),
        findsOneWidget,
      );
    });

    testWidgets('shows instructional text "Choose your account type"',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Choose your account type'), findsOneWidget);
    });
  });

  // ── AC-3: Tapping option navigates to role-specific login ─────────────

  group('LoginSelectionScreen – Navigation', () {
    testWidgets('tapping Visitor Login navigates to VisitorLoginScreen',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Visitor Login'));
      await tester.pumpAndSettle();

      expect(find.byType(VisitorLoginScreen), findsOneWidget);
    });

    testWidgets('tapping Local Login navigates to LocalLoginScreen',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Local Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LocalLoginScreen), findsOneWidget);
    });

    testWidgets('tapping Admin Login navigates to AdminLoginScreen',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Unlock admin first.
      final heading = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.text('Log In'),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(heading);
        await tester.pump();
      }

      await tester.tap(find.text('Admin Login'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });
  });

  // ── AC-4: Responsive centred layout ───────────────────────────────────

  group('LoginSelectionScreen – Responsive Layout', () {
    testWidgets('content is centred with max width constraint',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // ConstrainedBox limits width to 460.
      final boxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final has460 = boxes.any((b) => b.constraints.maxWidth == 460.0);
      expect(has460, isTrue);
    });

    testWidgets('body is scrollable for smaller screens', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('body is wrapped in Center widget', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SafeArea),
          matching: find.byType(Center),
        ),
        findsAtLeast(1),
      );
    });
  });

  // ── AC-5: User-friendly, loads quickly ────────────────────────────────

  group('LoginSelectionScreen – UX & Theme', () {
    testWidgets('displays role icons for each option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.travel_explore_rounded), findsOneWidget);
      expect(find.byIcon(Icons.location_city_rounded), findsOneWidget);
    });

    testWidgets('displays forward arrow icons on option cards',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Each visible card has an arrow_forward_ios_rounded icon.
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNWidgets(2));
    });

    testWidgets('uses branded background colour', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // AppPalette.background = Color(0xFFF7F4ED)
      expect(scaffold.backgroundColor, const Color(0xFFF7F4ED));
    });

    testWidgets('app bar title shows Log In', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // LogoAppBarTitle wraps the text.
      expect(find.text('Log In'), findsAtLeast(1));
    });
  });
}
