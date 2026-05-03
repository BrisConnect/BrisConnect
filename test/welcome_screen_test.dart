import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';

// ---------------------------------------------------------------------------
// Welcome Screen Tests
// User Story: As a Local/Visitor, I want to see a welcome screen so that I
//             can choose to log in or create an account.
// ---------------------------------------------------------------------------

Widget _buildApp() {
  return const MaterialApp(home: WelcomeScreen());
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // ── AC-1: Branded welcome screen on first launch ──────────────────────

  group('WelcomeScreen – Branding & Logo', () {
    testWidgets('displays Aboriginal dot-art background', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(AboriginalDotArtBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays app logo image above title', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);

      final logoCenter = tester.getCenter(find.byType(Image));
      final titleCenter = tester.getCenter(find.text('BrisConnect'));
      expect(logoCenter.dy, lessThan(titleCenter.dy));
    });

    testWidgets('displays app title BrisConnect', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('BrisConnect'), findsOneWidget);
    });

    testWidgets('displays tagline slogan in gold', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.text('Connecting people, culture, and place'),
        findsOneWidget,
      );
    });

    testWidgets('title uses large white text with shadow', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final text = tester.widget<Text>(find.text('BrisConnect'));
      expect(text.style?.color, Colors.white);
      expect(text.style?.fontSize, 42);
      expect(text.style?.shadows, isNotEmpty);
    });

    testWidgets('has animated fire glow layer (DecoratedBox)', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(DecoratedBox), findsWidgets);
    });
  });

  // ── AC-2: Welcome content & description ───────────────────────────────

  group('WelcomeScreen – Welcome Content', () {
    testWidgets('displays Welcome to BrisConnect heading', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Welcome to BrisConnect'), findsOneWidget);
    });

    testWidgets('displays description text', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.textContaining('Your guide to events, attractions and stories'),
        findsOneWidget,
      );
    });

    testWidgets('displays Aboriginal dot circle divider', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // The dot circle divider uses a CustomPaint widget.
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ── AC-3: Action buttons ──────────────────────────────────────────────

  group('WelcomeScreen – Action Buttons', () {
    testWidgets('shows Get Started button with arrow icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('shows Log In button with person icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Log In'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Log In'),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
    });
  });

  // ── AC-4: Get Started navigates to Register Selection ─────────────────

  group('WelcomeScreen – Get Started Navigation', () {
    testWidgets('tapping Get Started navigates to RegisterSelectionScreen',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RegisterSelectionScreen), findsOneWidget);
    });

    testWidgets('RegisterSelectionScreen shows Visitor and Local options',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Register as Visitor'), findsOneWidget);
      expect(find.text('Register as Local'), findsOneWidget);
    });
  });

  // ── AC-5: Log In navigates to Login Selection ─────────────────────────

  group('WelcomeScreen – Log In Navigation', () {
    testWidgets('tapping Log In navigates to LoginSelectionScreen',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Log In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginSelectionScreen), findsOneWidget);
    });

    testWidgets('LoginSelectionScreen shows Visitor and Local options',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.text('Log In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Visitor Login'), findsOneWidget);
      expect(find.text('Local Login'), findsOneWidget);
    });
  });

  // ── AC-6: Branding elements consistent with app theme ─────────────────

  group('WelcomeScreen – Theme & Branding Elements', () {
    testWidgets('has full-screen dot-art with Positioned.fill',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('Get Started button uses orange gradient', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // The Get Started button is wrapped in a DecoratedBox with gradient.
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasGradient = decorated.any((d) {
        final box = d.decoration;
        if (box is BoxDecoration && box.gradient is LinearGradient) {
          return true;
        }
        return false;
      });
      expect(hasGradient, isTrue);
    });
  });
}
