import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/email_verification_screen.dart';
import 'package:brisconnect/services/email_verification_service.dart';
import 'package:brisconnect/utils/auth_validation.dart';

// ---------------------------------------------------------------------------
// Email Verification Tests
// User Story: As a user, I want to verify my email address so that I can
//             confirm my account is valid and receive important notifications.
// ---------------------------------------------------------------------------

/// Fake verification service for testing without Firebase.
class FakeEmailVerificationService extends EmailVerificationService {
  FakeEmailVerificationService({
    this.verifiedResult = false,
    this.sendResult = true,
  }) : super(auth: null);

  bool verifiedResult;
  bool sendResult;
  int sendCallCount = 0;
  int checkCallCount = 0;

  @override
  Future<bool> isEmailVerified() async {
    checkCallCount++;
    return verifiedResult;
  }

  @override
  Future<bool> sendVerificationEmail() async {
    sendCallCount++;
    return sendResult;
  }

  @override
  bool get isVerifiedCached => verifiedResult;
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildVerificationScreen({
  required FakeEmailVerificationService service,
  String email = 'test@example.com',
}) {
  return MaterialApp(
    routes: {
      '/visitor/portal': (_) => const Scaffold(body: Text('Portal')),
    },
    home: EmailVerificationScreen(
      email: email,
      verificationService: service,
    ),
  );
}

void main() {
  // ── AC-1: System requires valid email format during registration ──────

  group('Email Format Validation', () {
    test('rejects empty email', () {
      expect(AuthValidation.email(''), 'Email is required');
    });

    test('rejects null email', () {
      expect(AuthValidation.email(null), 'Email is required');
    });

    test('rejects email without @ symbol', () {
      expect(AuthValidation.email('noatsign'), 'Enter a valid email address');
    });

    test('rejects email without domain', () {
      expect(AuthValidation.email('user@'), 'Enter a valid email address');
    });

    test('rejects email without TLD', () {
      expect(AuthValidation.email('user@domain'), 'Enter a valid email address');
    });

    test('accepts standard email format', () {
      expect(AuthValidation.email('user@example.com'), isNull);
    });

    test('accepts email with dots and hyphens', () {
      expect(AuthValidation.email('first.last@my-domain.com.au'), isNull);
    });
  });

  // ── AC-2: System sends verification email upon account creation ───────

  group('Verification Email Sending', () {
    testWidgets('verification screen displays sent message on load',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(
        service: service,
        email: 'jane@example.com',
      ));
      await tester.pump();

      expect(find.text('A verification email has been sent to:'),
          findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('verification screen shows Verify Your Email heading',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      expect(find.text('Verify Your Email'), findsOneWidget);
    });

    testWidgets('email icon is shown for unverified state', (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });
  });

  // ── AC-3: User must verify email before accessing key features ────────

  group('Email Verification Check', () {
    testWidgets('check button calls isEmailVerified on the service',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: false);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(service.checkCallCount, 1);
    });

    testWidgets('shows not-verified message when email is not yet verified',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: false);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(
        find.text('Email not yet verified. Please check your inbox.'),
        findsOneWidget,
      );
    });
  });

  // ── AC-4: Unverified email blocks access to restricted features ───────

  group('Feature Blocking for Unverified Email', () {
    testWidgets('unverified state keeps user on verification screen',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: false);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      // Still on verification screen.
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(find.text('Portal'), findsNothing);
    });

    testWidgets('verify and resend buttons remain visible when unverified',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: false);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(find.text("I've Verified My Email"), findsOneWidget);
      expect(find.text('Resend Verification Email'), findsOneWidget);
    });

    testWidgets('instructions text guides user to check inbox',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      expect(
        find.textContaining('check your inbox and click the verification link'),
        findsOneWidget,
      );
    });
  });

  // ── AC-5: System allows user to resend the verification email ─────────

  group('Resend Verification Email', () {
    testWidgets('resend button is present on verification screen',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      expect(find.text('Resend Verification Email'), findsOneWidget);
    });

    testWidgets('tapping resend calls sendVerificationEmail on service',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(sendResult: true);

      await tester.pumpWidget(_buildVerificationScreen(
        service: service,
        email: 'user@test.com',
      ));
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(service.sendCallCount, 1);
    });

    testWidgets('shows success message after successful resend',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(sendResult: true);

      await tester.pumpWidget(_buildVerificationScreen(
        service: service,
        email: 'user@test.com',
      ));
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(
        find.text('Verification email sent to user@test.com'),
        findsOneWidget,
      );
    });

    testWidgets('shows error message when resend fails', (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(sendResult: false);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(
        find.text('Could not send verification email. Try again later.'),
        findsOneWidget,
      );
    });
  });

  // ── AC-6: Confirmation message displayed once verified ────────────────

  group('Verification Confirmation Message', () {
    testWidgets('shows success message when email is verified',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: true);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(find.text('Email verified successfully!'), findsOneWidget);

      // Drain the 2-second delayed navigation timer.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows verified icon after successful verification',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: true);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(find.byIcon(Icons.mark_email_read_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('heading changes to Email Verified after success',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: true);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(find.text('Email Verified!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows Your account is confirmed after verification',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService(verifiedResult: true);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();

      expect(find.text('Your account is confirmed.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });

  // ── AC-7: Secure and reliable email verification ──────────────────────

  group('Security and Reliability', () {
    test('email validation rejects dangerous input patterns', () {
      expect(
        AuthValidation.email('user@<script>alert(1)</script>.com'),
        'Enter a valid email address',
      );
      expect(
        AuthValidation.email('user@domain com'),
        'Enter a valid email address',
      );
    });

    testWidgets('email address is displayed as read-only on screen',
        (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(
        service: service,
        email: 'secure@test.com',
      ));
      await tester.pump();

      // Email is shown but not in an editable field.
      expect(find.text('secure@test.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('verification check and resend buttons are independent',
        (tester) async {
      _setViewport(tester);
      final service =
          FakeEmailVerificationService(verifiedResult: false, sendResult: true);

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      // Tap check first.
      await tester.tap(find.text("I've Verified My Email"));
      await tester.pump();
      expect(service.checkCallCount, 1);
      expect(service.sendCallCount, 0);

      // Then tap resend.
      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();
      expect(service.checkCallCount, 1);
      expect(service.sendCallCount, 1);
    });

    testWidgets('screen is wrapped in constrained layout', (tester) async {
      _setViewport(tester);
      final service = FakeEmailVerificationService();

      await tester.pumpWidget(_buildVerificationScreen(service: service));
      await tester.pump();

      final boxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final hasMaxWidth = boxes.any((b) => b.constraints.maxWidth == 460);
      expect(hasMaxWidth, isTrue);
    });
  });
}
