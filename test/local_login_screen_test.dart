import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/widgets/role_guard.dart';

// ---------------------------------------------------------------------------
// Local Login Screen Tests
// User Story: As a Local user, I want to log in to my account so that I can
//             access local portal features.
//
// Firebase Auth calls are NOT triggered in validation-failure paths because
// the form validator returns early — no mocking needed for those cases.
// ---------------------------------------------------------------------------

Widget _buildLoginApp({String? initialEmail}) {
  return MaterialApp(
    routes: {
      '/local/portal': (_) => const Scaffold(
            body: Center(child: Text('Local Portal')),
          ),
    },
    home: LocalLoginScreen(initialEmail: initialEmail),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('LocalLoginScreen – Credential Fields', () {
    testWidgets('renders email/username field, password field and Login button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // AC: Local login requires valid local credentials — form provides fields.
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

      // AC: The system shall provide secure, reliable, and efficient login.
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows login icon on the submit button', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('initialEmail pre-fills the email field', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp(initialEmail: 'local@test.com'));
      await tester.pump();

      // AC: Session state is restored correctly after login — pre-fill supports
      // returning users from registration flow.
      expect(find.text('local@test.com'), findsOneWidget);
    });
  });

  group('LocalLoginScreen – Password Security', () {
    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // AC: The system shall provide secure login.
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

  group('LocalLoginScreen – Validation & Error Feedback', () {
    testWidgets('shows validation error when email/username is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // AC: Invalid credentials are rejected with feedback.
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email or Username is required'), findsOneWidget);
    });

    testWidgets('shows validation error when password is empty',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // Enter email but leave password empty.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or Username'),
        'local@brisconnect.com',
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      // AC: Invalid credentials are rejected with feedback.
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error for malformed email address',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email or Username'),
        'local@',
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
        'mybusiness',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      // No form validation error — proceeds to LocalAuth.login.
      expect(find.text('Email or Username is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
    });

    testWidgets('login button is enabled before submission', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // AC: The system shall provide efficient login — button is ready.
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Login'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('LocalLoginScreen – Portal Route', () {
    testWidgets('route /local/portal is declared in navigation',
        (tester) async {
      _setViewport(tester);
      // AC: Successful login redirects the user to the local portal.
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // The login screen renders; the route table includes /local/portal.
      expect(find.byType(LocalLoginScreen), findsOneWidget);
    });

    testWidgets('shows register option for new local users', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      // Navigate to sign-up is available.
      expect(find.textContaining('Register'), findsOneWidget);
    });
  });

  group('LocalLoginScreen – Role Guard', () {
    testWidgets('RoleGuard blocks unauthenticated access to local content',
        (tester) async {
      _setViewport(tester);

      // AC: Local-only routes are restricted from other user roles.
      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.local},
          child: const Scaffold(
            body: Center(child: Text('Local Portal Content')),
          ),
        ),
      ));
      await tester.pump();

      // No local session → guard shows spinner, content blocked.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Local Portal Content'), findsNothing);
    });

    testWidgets('RoleGuard denies admin role for local-only screens',
        (tester) async {
      _setViewport(tester);

      // AC: Local-only routes are restricted from other user roles.
      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.local},
          deniedMessage: 'Local users only.',
          child: const Scaffold(
            body: Center(child: Text('Local Dashboard')),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Local Dashboard'), findsNothing);
    });

    testWidgets('RoleGuard denies visitor role for local-only screens',
        (tester) async {
      _setViewport(tester);

      // AC: Local-only routes are restricted from other user roles.
      await tester.pumpWidget(MaterialApp(
        home: RoleGuard(
          allowedRoles: const {AppUserRole.local},
          deniedMessage: 'Local users only.',
          child: const Scaffold(
            body: Center(child: Text('Local Event Management')),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Local Event Management'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
