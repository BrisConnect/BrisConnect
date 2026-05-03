import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(null);
    LocalAuth.debugSetCurrentLocalForTesting(null);
  });

  Future<void> expectScreenLoadsQuickly(
    WidgetTester tester,
    Widget screen,
  ) async {
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle().timeout(const Duration(seconds: 2));

    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  }

  Future<void> expectNotificationControls(WidgetTester tester) async {
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Enable All Notifications'), findsOneWidget);
    expect(find.text('Event Reminders'), findsWidgets);
    expect(find.text('Reminder Timing'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Recommended Events'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Event Updates'), findsOneWidget);
    expect(find.text('Nearby Events'), findsOneWidget);
    expect(find.text('Recommended Events'), findsOneWidget);
  }

  testWidgets('visitor notification settings render within 2 seconds',
      (tester) async {
    VisitorAuth.debugSetCurrentVisitorForTesting(
      const VisitorUser(
        name: 'Visitor Tester',
        email: 'visitor@test.com',
        password: 'Password123',
        notificationsEnabled: true,
        eventRemindersEnabled: true,
        reminderTiming: '24h',
        eventUpdatesEnabled: true,
        nearbyEventsEnabled: true,
        recommendedEventsEnabled: true,
      ),
    );

    await expectScreenLoadsQuickly(
      tester,
      const NotificationSettingsScreen.visitor(),
    );

    expect(
      find.text('Control your event updates in one place'),
      findsOneWidget,
    );
    await expectNotificationControls(tester);
  });

  testWidgets('local notification settings render within 2 seconds',
      (tester) async {
    LocalAuth.debugSetCurrentLocalForTesting(
      const LocalUser(
        name: 'Local Tester',
        email: 'local@test.com',
        password: 'Password123',
        phone: '0400000000',
        suburb: 'South Bank',
        notificationsEnabled: true,
        eventRemindersEnabled: true,
        reminderTiming: '1h',
        eventUpdatesEnabled: true,
        nearbyEventsEnabled: false,
        recommendedEventsEnabled: true,
      ),
    );

    await expectScreenLoadsQuickly(
      tester,
      const NotificationSettingsScreen.local(),
    );

    await expectNotificationControls(tester);
    expect(find.text('Current: 1 hour before'), findsOneWidget);
  });

  testWidgets('logged out state shows guidance message', (tester) async {
    await expectScreenLoadsQuickly(
      tester,
      const NotificationSettingsScreen.visitor(),
    );

    expect(
      find.text('Please log in to manage notification settings.'),
      findsOneWidget,
    );
  });
}
