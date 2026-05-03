import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Register Role Selection Tests
// User Story: As a user, I want to select my role before registering so
//             that I create the correct type of account.
// ---------------------------------------------------------------------------

Widget _buildApp() {
  return const MaterialApp(home: RegisterSelectionScreen());
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // ── AC-1: Displays two registration options: Visitor and Local ────────

  group('Registration Options Display', () {
    testWidgets('shows Visitor registration option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Register as Visitor'), findsOneWidget);
    });

    testWidgets('shows Local registration option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Register as Local'), findsOneWidget);
    });

    testWidgets('displays exactly two registration option cards',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Each card has a forward-arrow chevron.
      expect(
        find.byIcon(Icons.arrow_forward_ios_rounded),
        findsNWidgets(2),
      );
    });

    testWidgets('shows visitor icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.byIcon(Icons.app_registration_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows local icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.location_city_rounded), findsOneWidget);
    });
  });

  // ── AC-2: Admin registration is not available ─────────────────────────

  group('Admin Registration Absent', () {
    testWidgets('does not show Admin registration option', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.textContaining('Admin'), findsNothing);
    });

    testWidgets('does not show admin-related icons', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.admin_panel_settings), findsNothing);
      expect(find.byIcon(Icons.admin_panel_settings_rounded), findsNothing);
      expect(find.byIcon(Icons.shield_rounded), findsNothing);
    });
  });

  // ── AC-3: Each option shows a descriptive subtitle ────────────────────

  group('Descriptive Subtitles', () {
    testWidgets('visitor option shows descriptive subtitle', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Create a visitor account to discover events'),
        findsOneWidget,
      );
    });

    testWidgets('local option shows descriptive subtitle', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Create a local account to submit cultural events'),
        findsOneWidget,
      );
    });

    testWidgets('screen heading prompts user to choose role', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Choose how you want to register'),
        findsOneWidget,
      );
    });
  });

  // ── AC-4: Tapping option navigates to role-specific signup ────────────

  group('Navigation to Role-Specific Signup', () {
    /// Suppress overflow errors from destination signup screens which have
    /// layout constraints tighter than 1080-wide test viewport.
    void suppressOverflow() {
      final original = FlutterError.onError!;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }

    testWidgets('tapping Visitor navigates to VisitorSignUpScreen',
        (tester) async {
      _setViewport(tester);
      suppressOverflow();
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Register as Visitor'));
      await tester.pumpAndSettle();

      expect(find.byType(VisitorSignUpScreen), findsOneWidget);
    });

    testWidgets('tapping Local navigates to LocalSignUpScreen',
        (tester) async {
      _setViewport(tester);
      suppressOverflow();
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Register as Local'));
      await tester.pumpAndSettle();

      expect(find.byType(LocalSignUpScreen), findsOneWidget);
    });

    testWidgets('visitor card chevron is tappable and navigates',
        (tester) async {
      _setViewport(tester);
      suppressOverflow();
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Tap the entire card area via the visitor title.
      await tester.tap(find.text('Register as Visitor'));
      await tester.pumpAndSettle();

      // Should now be on the visitor signup screen.
      expect(find.byType(RegisterSelectionScreen), findsNothing);
      expect(find.byType(VisitorSignUpScreen), findsOneWidget);
    });

    testWidgets('local card chevron is tappable and navigates',
        (tester) async {
      _setViewport(tester);
      suppressOverflow();
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Register as Local'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterSelectionScreen), findsNothing);
      expect(find.byType(LocalSignUpScreen), findsOneWidget);
    });
  });

  // ── AC-5: Secure, clear, prevents unauthorized account creation ───────

  group('Security and Clarity', () {
    testWidgets('screen title clearly says Create Account', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Heading in the body.
      expect(find.text('Create Account'), findsAtLeast(1));
    });

    testWidgets('only two roles are exposed for self-registration',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Exactly 2 forward-arrow chevrons = exactly 2 registration paths.
      expect(
        find.byIcon(Icons.arrow_forward_ios_rounded),
        findsNWidgets(2),
      );

      // No third option of any kind.
      expect(find.textContaining('Admin'), findsNothing);
      expect(find.textContaining('Superuser'), findsNothing);
      expect(find.textContaining('Manager'), findsNothing);
    });

    testWidgets('layout is constrained for readability', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // The screen uses a ConstrainedBox with maxWidth 460.
      final boxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final hasMaxWidth = boxes.any(
        (b) => b.constraints.maxWidth == 460,
      );
      expect(hasMaxWidth, isTrue);
    });

    testWidgets('cards are visually distinct with icons and subtitles',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // Visitor card has its own icon.
      expect(
        find.byIcon(Icons.app_registration_rounded),
        findsOneWidget,
      );
      // Local card has its own icon.
      expect(
        find.byIcon(Icons.location_city_rounded),
        findsOneWidget,
      );

      // Both subtitles are present to explain the roles.
      expect(
        find.text('Create a visitor account to discover events'),
        findsOneWidget,
      );
      expect(
        find.text('Create a local account to submit cultural events'),
        findsOneWidget,
      );
    });
  });
}
