import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/business_notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessNotificationSettingsScreen', () {
    testWidgets('renders all four notification toggles', (tester) async {
      LocalAuth.debugSetCurrentLocalForTesting(
        const LocalUser(
          name: 'Test Owner',
          email: 'owner@test.com',
          password: 'pass',
          phone: '0000000000',
          suburb: 'Brisbane',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BusinessNotificationSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Business Notifications'), findsOneWidget);
      expect(find.text('Trending promotions'), findsOneWidget);
      expect(find.text('Offer expiry reminders'), findsOneWidget);
      expect(find.text('New reviews'), findsOneWidget);
      expect(find.text('Business updates'), findsOneWidget);

      // Four switches should be present and enabled by default.
      final switches = find.byType(SwitchListTile);
      expect(switches, findsNWidgets(4));

      LocalAuth.debugSetCurrentLocalForTesting(null);
    });

    testWidgets('toggles reflect current local preferences', (tester) async {
      LocalAuth.debugSetCurrentLocalForTesting(
        const LocalUser(
          name: 'Test Owner',
          email: 'owner@test.com',
          password: 'pass',
          phone: '0000000000',
          suburb: 'Brisbane',
          notifyNewReview: false,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BusinessNotificationSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final switchWidgets = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidgets.elementAt(2).value, isFalse);

      LocalAuth.debugSetCurrentLocalForTesting(null);
    });
  });
}
