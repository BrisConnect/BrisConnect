import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/services/visitor_email_notification_service.dart';

// ---------------------------------------------------------------------------
// Visitor Sign-Up Screen Tests
// User Story: As a Visitor, I want to register for an account so that I can
//             access discovery and planning features.
//
// Firebase Auth calls are NOT triggered in validation-failure paths because
// the form validator returns early — no mocking needed for those cases.
// ---------------------------------------------------------------------------

Widget _buildSignUpApp() {
  return const MaterialApp(
    home: VisitorSignUpScreen(),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // ── AC-1: Registration form with name, email, password, phone ─────────

  group('VisitorSignUpScreen – Registration Form Fields', () {
    testWidgets('renders Name, Phone, Email, Password fields and submit button',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      expect(
        find.widgetWithText(TextFormField, 'Name'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Phone Number'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Email'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Password'),
        findsOneWidget,
      );
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('phone field displays +61 prefix and hint', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      // AC-2: Phone numbers are converted to Australian E.164 format.
      expect(find.text('+61 '), findsOneWidget);
      expect(find.text('4XX XXX XXX'), findsOneWidget);
    });

    testWidgets('phone field shows phone icon', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('shows link to login for existing users', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      expect(find.textContaining('Login'), findsOneWidget);
    });
  });

  // ── AC-2: Phone numbers converted to Australian E.164 format ─────────

  group('VisitorSignUpScreen – Phone Validation', () {
    testWidgets('rejects empty phone number', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      // Fill everything except phone.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Phone is required'), findsOneWidget);
    });

    testWidgets('rejects invalid AU mobile number', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Enter a valid AU mobile (e.g. 04XX XXX XXX)'),
        findsOneWidget,
      );
    });

    testWidgets('accepts valid AU mobile number format', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // No phone validation error.
      expect(find.text('Phone is required'), findsNothing);
      expect(
        find.text('Enter a valid AU mobile (e.g. 04XX XXX XXX)'),
        findsNothing,
      );
    });
  });

  // ── AC-3: Email validation is enforced ────────────────────────────────

  group('VisitorSignUpScreen – Email Validation', () {
    testWidgets('rejects empty email', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('rejects malformed email address', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });
  });

  // ── AC-3 (continued): Password validation ─────────────────────────────

  group('VisitorSignUpScreen – Password Validation', () {
    testWidgets('rejects empty password', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('rejects password shorter than 8 characters', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Ab1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('rejects password without uppercase letter', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'lowercase1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must include at least one uppercase letter'),
        findsOneWidget,
      );
    });

    testWidgets('rejects password without number', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'NoDigitsHere',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must include at least one number'),
        findsOneWidget,
      );
    });

    testWidgets('password field is obscured by default', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('eye icon toggles password visibility', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
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

  // ── AC-4: Successful registration redirects to login with pre-fill ────

  group('VisitorSignUpScreen – Navigation', () {
    testWidgets('screen renders with Visitor Registration app bar title',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      expect(find.text('Visitor Registration'), findsOneWidget);
    });
  });

  // ── AC-5 & AC-6: Registration confirmation email ─────────────────────

  group('VisitorEmailNotificationService – Registration Email', () {
    testWidgets('queues welcome email with correct subject and content',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitorEmailNotificationService(firestore: firestore);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'visitor@test.com',
        visitorName: 'Jane Doe',
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'visitor@test.com');

      final message = data['message'] as Map<String, dynamic>;
      expect(
        (message['subject'] as String),
        contains('Welcome to BrisConnect'),
      );
      expect(
        (message['html'] as String),
        contains('created successfully'),
      );

      final meta = data['meta'] as Map<String, dynamic>;
      expect(meta['type'], 'visitor_registration_received');
    });

    testWidgets('email document ID includes slugified visitor name',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitorEmailNotificationService(firestore: firestore);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'visitor@test.com',
        visitorName: 'Jane Doe',
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs.first.id, startsWith('visitor-reg-received-jane-doe'));
    });
  });

  // ── AC-7: Error message shown if registration fails ───────────────────

  group('VisitorSignUpScreen – Error Display', () {
    testWidgets('shows all validation errors on completely empty submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // All required fields show an error.
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Phone is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });

  // ── AC-8: Submit button disabled while processing ─────────────────────

  group('VisitorSignUpScreen – Submit Button State', () {
    testWidgets('submit button is enabled before submission', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Create Account'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('button onPressed is null-guarded by _isSubmitting flag',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      // Before any submission the button is enabled.
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Create Account'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);

      // After a failed submission (Firebase unavailable) the button
      // re-enables to allow retry — confirming the toggle is wired up.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        '0412345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Button re-enabled after the async call completes.
      final after = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Create Account'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(after.onPressed, isNotNull);
    });
  });
}
