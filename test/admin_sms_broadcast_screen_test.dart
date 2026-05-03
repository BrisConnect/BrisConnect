import 'package:brisconnect/screens/admin_sms_broadcast_screen.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock service backed by FakeFirebaseFirestore.
// ---------------------------------------------------------------------------
class TestSmsNotificationService extends SmsNotificationService {
  int? lastQueuedCount;
  String? lastAudience;
  String? lastMessage;
  bool? lastApprovedLocalsOnly;
  bool shouldThrow = false;

  TestSmsNotificationService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<int> queueAdminBroadcastSms({
    required String audience,
    required String message,
    bool approvedLocalsOnly = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    lastAudience = audience;
    lastMessage = message;
    lastApprovedLocalsOnly = approvedLocalsOnly;
    return lastQueuedCount ?? 3;
  }
}

Widget _buildApp(TestSmsNotificationService service) {
  return MaterialApp(
    home: AdminSmsBroadcastScreen(
      smsService: service,
      enforceRoleGuard: false,
    ),
  );
}

void main() {
  group('AdminSmsBroadcastScreen', () {
    testWidgets('renders form with audience dropdown, switch, and send button',
        (tester) async {
      final service = TestSmsNotificationService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      expect(find.text('Audience'), findsOneWidget);
      expect(find.text('Approved locals only'), findsOneWidget);
      expect(find.text('SMS message'), findsOneWidget);
      expect(
        find.text('Messages are sent via Twilio to the selected audience.'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error when message is empty', (tester) async {
      final service = TestSmsNotificationService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Tap send without entering a message.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an SMS message.'), findsOneWidget);
      expect(service.lastMessage, isNull);
    });

    testWidgets('shows validation error when message is too short',
        (tester) async {
      final service = TestSmsNotificationService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Hi');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(
        find.text('Message should be at least 8 characters.'),
        findsOneWidget,
      );
      expect(service.lastMessage, isNull);
    });

    testWidgets('sends broadcast and shows success snackbar', (tester) async {
      final service = TestSmsNotificationService()..lastQueuedCount = 5;
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'Service update tonight at 10 PM.',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(find.text('SMS sent to 5 recipient(s).'), findsOneWidget);
      expect(service.lastAudience, 'both');
      expect(service.lastMessage, 'Service update tonight at 10 PM.');
      expect(service.lastApprovedLocalsOnly, isTrue);
    });

    testWidgets('shows no-recipients snackbar when queued count is 0',
        (tester) async {
      final service = TestSmsNotificationService()..lastQueuedCount = 0;
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'Hello world from admin!',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(
        find.text('No recipients found with valid phone numbers.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error snackbar on send failure', (tester) async {
      final service = TestSmsNotificationService()..shouldThrow = true;
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'Broadcast message text',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to send SMS'), findsOneWidget);
    });

    testWidgets('approved locals switch is on by default', (tester) async {
      final service = TestSmsNotificationService()..lastQueuedCount = 2;
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // The SwitchListTile should default to true.
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);
      final switchTile =
          tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isTrue);

      // Toggle it off.
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Now send a valid message to verify the flag propagated.
      await tester.enterText(
        find.byType(TextFormField),
        'An important broadcast message',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send SMS Broadcast'));
      await tester.pumpAndSettle();

      expect(service.lastApprovedLocalsOnly, isFalse);
    });
  });
}
