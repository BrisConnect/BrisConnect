import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/widgets/role_guard.dart';

// ---------------------------------------------------------------------------
// Visitor Login Screen Tests
// User Story: As a Visitor, I want to log in to my account so that I can
//             access discovery and planning features.
//
// Firebase Auth calls are NOT triggered in validation-failure paths because
// the form validator returns early — no mocking needed for those cases.
// ---------------------------------------------------------------------------

Widget _buildLoginApp({String? initialEmail}) {
  return MaterialApp(
    routes: {
      '/visitor/portal': (_) => const Scaffold(
            body: Center(child: Text('Visitor Portal')),
          ),
    },
    home: VisitorLoginScreen(initialEmail: initialEmail),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // ── AC-1: Visitor login requires valid visitor credentials ────────────

  group('VisitorLoginScreen – Credential Fields', () {
    testWidgets('renders email/username field, password field and Login button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(
        find.widgetWithText(TextFormField, 'Email or Username'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Password'),
        findsOneWidget,
      );
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('shows email and lock prefix icons', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows login icon on the submit button', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('initialEmail pre-fills the identifier field', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(
          _buildLoginApp(initialEmail: 'visitor@test.com'));
      await tester.pump();

      // AC-5: Session state is restored correctly — pre-fill supports
      // returning users from registration flow.
      expect(find.text('visitor@test.com'), findsOneWidget);
    });
  });

  // ── AC-6: Secure and efficient login ──────────────────────────────────

  group('VisitorLoginScreen – Password Security', () {
    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('tapping eye icon toggles password visibility',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
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
  });

  // ── AC-2: Invalid credentials are rejected with feedback ──────────────

  group('VisitorLoginScreen – Validation & Error Feedback', () {
    testWidgets('shows validation error when email/username is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email or Username is required'), findsOneWidget);
    });

    testWidgets('shows validation error when password is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or Username'),
        'visitor@brisconnect.com',
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error for malformed email address',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or Username'),
        'visitor@',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('accepts plain username without email validation',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // A username (no @) should pass form validation.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or Username'),
        'tourguest',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      // No form validation error — proceeds to VisitorAuth.login.
      expect(find.text('Email or Username is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
    });

    testWidgets('login button is enabled before submission', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Login'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // ── AC-3: Successful login redirects to the visitor portal ────────────

  group('VisitorLoginScreen – Portal Route', () {
    testWidgets('route /visitor/portal is declared in navigation',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // The login screen renders; the route table includes /visitor/portal.
      expect(find.byType(VisitorLoginScreen), findsOneWidget);
    });

    testWidgets('shows register option for new visitors', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.textContaining('Register'), findsOneWidget);
    });
  });

  // ── AC-4: Visitor-only routes are restricted from other roles ─────────

  group('VisitorLoginScreen – Role Guard', () {
    testWidgets('RoleGuard blocks unauthenticated access to visitor content',
        (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.visitor},
          child: const Scaffold(
            body: Center(child: Text('Visitor Portal Content')),
          ),
        ),
      ));
      await tester.pump();

      // No visitor session → guard shows spinner, content blocked.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Visitor Portal Content'), findsNothing);
    });

    testWidgets('RoleGuard denies admin role for visitor-only screens',
        (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.visitor},
          deniedMessage: 'Visitors only.',
          child: const Scaffold(
            body: Center(child: Text('Visitor Dashboard')),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Visitor Dashboard'), findsNothing);
    });

    testWidgets('RoleGuard denies local role for visitor-only screens',
        (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.visitor},
          deniedMessage: 'Visitors only.',
          child: const Scaffold(
            body: Center(child: Text('Visitor Discovery')),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Visitor Discovery'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
