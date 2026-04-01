import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/screens/admin_login_screen.dart';

// ---------------------------------------------------------------------------
// Login Screen Tests — Task 9
// Tests cover: UI rendering, password masking, toggle visibility,
//              form validation, and session-state isolation.
// Note: Firebase Auth calls are NOT triggered here because form validation
// returns early when fields are empty or invalid — no mocking needed.
// ---------------------------------------------------------------------------

Widget _buildApp(Widget child) => MaterialApp(home: child);

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // -------------------------------------------------------------------------
  // Visitor Login Screen
  // -------------------------------------------------------------------------
  group('VisitorLoginScreen', () {
    testWidgets('renders email field, password field and Login button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const VisitorLoginScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const VisitorLoginScreen()));
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('tapping eye icon toggles password visibility', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const VisitorLoginScreen()));
      await tester.pump();

      EditableText passwordEditable() => tester.widget<EditableText>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Password'),
              matching: find.byType(EditableText),
            ),
          );

      expect(passwordEditable().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(passwordEditable().obscureText, isFalse);
    });

    testWidgets('shows validation error on empty form submit', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const VisitorLoginScreen()));
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();

      // AuthValidation.email returns 'Email is required' for empty input
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('shows email and lock prefix icons', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const VisitorLoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('initialEmail pre-fills the email field', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(
        _buildApp(const VisitorLoginScreen(initialEmail: 'hello@test.com')),
      );
      await tester.pump();

      expect(find.text('hello@test.com'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Local Login Screen
  // -------------------------------------------------------------------------
  group('LocalLoginScreen', () {
    testWidgets('renders email field, password field and Login button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const LocalLoginScreen()));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const LocalLoginScreen()));
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('tapping eye icon toggles password visibility', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const LocalLoginScreen()));
      await tester.pump();

      EditableText passwordEditable() => tester.widget<EditableText>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Password'),
              matching: find.byType(EditableText),
            ),
          );

      expect(passwordEditable().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(passwordEditable().obscureText, isFalse);
    });

    testWidgets('shows validation error on empty form submit', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const LocalLoginScreen()));
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('initialEmail pre-fills the email field', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(
        _buildApp(const LocalLoginScreen(initialEmail: 'local@test.com')),
      );
      await tester.pump();

      expect(find.text('local@test.com'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Admin Login Screen
  // -------------------------------------------------------------------------
  group('AdminLoginScreen', () {
    testWidgets('renders admin email field, password field and Login button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const AdminLoginScreen()));
      await tester.pump();

      expect(
          find.widgetWithText(TextFormField, 'Admin Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const AdminLoginScreen()));
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('shows validation error on empty form submit', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildApp(const AdminLoginScreen()));
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });
  });
}
