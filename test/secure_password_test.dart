import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/utils/auth_validation.dart';

// ---------------------------------------------------------------------------
// Secure Password Tests
// User Story: As a user, I want to create a secure password so that my
//             account is protected from unauthorized access.
// ---------------------------------------------------------------------------

Widget _buildSignUpApp() {
  return const MaterialApp(home: VisitorSignUpScreen());
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Helper: fills all non-password fields so only the password field
/// validation is exercised.
Future<void> _fillOtherFields(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Name'),
    'Test User',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Phone Number'),
    '0412345678',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'test@example.com',
  );
}

void main() {
  // ── AC-1: Password must contain at least one letter ───────────────────

  group('Password – Letter Requirement', () {
    test('AuthValidation rejects password without uppercase letter', () {
      final result = AuthValidation.password('alllower1');
      expect(result, 'Password must include at least one uppercase letter');
    });

    test('AuthValidation rejects password without lowercase letter', () {
      final result = AuthValidation.password('ALLUPPER1');
      expect(result, 'Password must include at least one lowercase letter');
    });

    test('AuthValidation accepts password with both upper and lower', () {
      final result = AuthValidation.password('ValidPass1!');
      expect(result, isNull);
    });
  });

  // ── AC-2: Password must contain at least one number ───────────────────

  group('Password – Number Requirement', () {
    test('AuthValidation rejects password without a digit', () {
      final result = AuthValidation.password('NoDigitsHere!');
      expect(result, 'Password must include at least one number');
    });

    test('AuthValidation accepts password with a digit', () {
      final result = AuthValidation.password('HasDigit1!');
      expect(result, isNull);
    });
  });

  // ── AC-3: Password must contain at least one special character ────────

  group('Password – Special Character Requirement', () {
    test('AuthValidation rejects password without special character', () {
      final result = AuthValidation.password('NoSpecial1');
      expect(
        result,
        'Password must include at least one special character',
      );
    });

    test('AuthValidation accepts password with special character', () {
      final result = AuthValidation.password('HasSpecial1!');
      expect(result, isNull);
    });

    test('AuthValidation accepts various special characters', () {
      expect(AuthValidation.password('Password1@'), isNull);
      expect(AuthValidation.password('Password1#'), isNull);
      expect(AuthValidation.password('Password1\$'), isNull);
      expect(AuthValidation.password('Password1%'), isNull);
      expect(AuthValidation.password('Password1&'), isNull);
    });
  });

  // ── AC-4: Password must be at least 8 characters long ─────────────────

  group('Password – Minimum Length', () {
    test('AuthValidation rejects password shorter than 8 characters', () {
      final result = AuthValidation.password('Ab1');
      expect(result, 'Password must be at least 8 characters');
    });

    test('AuthValidation accepts password with exactly 8 characters', () {
      final result = AuthValidation.password('Abcdef1!');
      expect(result, isNull);
    });

    test('AuthValidation rejects empty password', () {
      final result = AuthValidation.password('');
      expect(result, 'Password is required');
    });

    test('AuthValidation rejects null password', () {
      final result = AuthValidation.password(null);
      expect(result, 'Password is required');
    });
  });

  // ── AC-5: Validation error displayed if requirements not met ──────────

  group('Password – Widget Validation Errors', () {
    testWidgets('shows error when password is empty on submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      // Leave password empty.
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows error for short password on submit', (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Sh1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('shows error for password missing uppercase on submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'alllower1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must include at least one uppercase letter'),
        findsOneWidget,
      );
    });

    testWidgets('shows error for password missing lowercase on submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'ALLUPPER1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must include at least one lowercase letter'),
        findsOneWidget,
      );
    });

    testWidgets('shows error for password missing number on submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
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

    testWidgets('shows error for password missing special character on submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'NoSpecial1',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Password must include at least one special character'),
        findsOneWidget,
      );
    });

    testWidgets('no validation error for a fully valid password',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1!',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // None of the password-specific errors should appear.
      expect(find.text('Password is required'), findsNothing);
      expect(
        find.text('Password must be at least 8 characters'),
        findsNothing,
      );
      expect(
        find.text('Password must include at least one uppercase letter'),
        findsNothing,
      );
      expect(
        find.text('Password must include at least one lowercase letter'),
        findsNothing,
      );
      expect(
        find.text('Password must include at least one number'),
        findsNothing,
      );
      expect(
        find.text('Password must include at least one special character'),
        findsNothing,
      );
    });
  });

  // ── AC-6: Real-time feedback while entering password ──────────────────

  group('Password – Real-Time Visual Feedback', () {
    testWidgets('password field is obscured by default for security',
        (tester) async {
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

    testWidgets('eye icon toggles password visibility for review',
        (tester) async {
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

      // Toggle back.
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(passwordEditable().obscureText, isTrue);
    });

    testWidgets('validation error updates when password is corrected',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      await _fillOtherFields(tester);

      // First submit with a short password.
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

      // Correct the password and re-submit.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'CorrectedPass1!',
      );
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Previous error should be gone.
      expect(
        find.text('Password must be at least 8 characters'),
        findsNothing,
      );
    });

    testWidgets('real-time validation shows error as user types without submit',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      // Type an invalid password — autovalidateMode.onUserInteraction
      // should show error without tapping Create Account.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );

      // Fix the password — error should clear automatically.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'FixedPass1!',
      );
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters'),
        findsNothing,
      );
    });
  });

  // ── AC-7: Secure authentication & account protection ──────────────────

  group('Password – Security Measures', () {
    test('validation enforces multiple complexity rules simultaneously', () {
      // A single-char password fails on length first.
      expect(
        AuthValidation.password('a'),
        'Password must be at least 8 characters',
      );

      // An 8-char all-lower fails on uppercase.
      expect(
        AuthValidation.password('abcdefg1!'),
        'Password must include at least one uppercase letter',
      );

      // An 8-char upper+lower fails on number.
      expect(
        AuthValidation.password('Abcdefgh!'),
        'Password must include at least one number',
      );

      // Upper+lower+number but no special char.
      expect(
        AuthValidation.password('Abcdefg1'),
        'Password must include at least one special character',
      );

      // All rules met returns null.
      expect(AuthValidation.password('Abcdefg1!'), isNull);
    });

    test('validator is used on registration forms (not login)', () {
      // Login only requires non-empty via requiredField.
      expect(
        AuthValidation.requiredField('anypassword', 'Password'),
        isNull,
      );

      // Registration enforces full strength rules.
      expect(
        AuthValidation.password('anypassword'),
        isNotNull,
      );
    });

    testWidgets('password field has obscured text for screen protection',
        (tester) async {
      _setViewport(tester);
      await tester.pumpWidget(_buildSignUpApp());
      await tester.pump();

      // Enter a password and verify it stays obscured.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'SecurePass1!',
      );
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });
  });
}
