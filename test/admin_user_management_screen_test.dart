import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';

Future<void> _tapVisibleDeactivateButton(WidgetTester tester) async {
  final buttonFinder = find.widgetWithText(OutlinedButton, 'Deactivate Account');
  expect(buttonFinder, findsOneWidget);
  final button = tester.widget<OutlinedButton>(buttonFinder.first);
  expect(button.onPressed, isNotNull);
  button.onPressed!.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late LocalEmailNotificationService fakeEmailService;
  late SmsNotificationService fakeSmsService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeEmailService = LocalEmailNotificationService(firestore: fakeFirestore);
    fakeSmsService = SmsNotificationService(firestore: fakeFirestore);
  });

  Widget buildScreen({TestAdminUserManagementService? service}) {
    return MaterialApp(
      home: AdminUserManagementScreen(
        userManagementService: service ?? TestAdminUserManagementService(),
        localEmailNotificationService: fakeEmailService,
        smsNotificationService: fakeSmsService,
      ),
    );
  }

  group('AdminUserManagementScreen Story 17', () {
    testWidgets('Renders UI elements for user management', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Verify search bar exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify filter chips exist
      expect(find.byType(FilterChip), findsWidgets);
      expect(find.text('All Roles'), findsOneWidget);
      expect(find.text('Visitors'), findsOneWidget);
      expect(find.text('Locals'), findsOneWidget);

      // Verify status filter chips exist
      expect(find.widgetWithText(FilterChip, 'Active'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Inactive'), findsOneWidget);

      // Verify AppBar with title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
    });

    testWidgets('Displays user list from stream', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Active Visitor sorts first and is visible
      expect(find.text('Active Visitor'), findsOneWidget);
    });

    testWidgets('Streams user data in real-time', (tester) async {
      final service = TestAdminUserManagementService();
      await tester.pumpWidget(buildScreen(service: service));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Initial state should have the active visitor with role chip
      expect(find.text('Active Visitor'), findsOneWidget);
      expect(find.text('VISITOR'), findsOneWidget);
    });

    testWidgets('Has deactivate action available on user cards',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Active Visitor card should show a Deactivate Account button
      await _tapVisibleDeactivateButton(tester);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Deactivate User Account'), findsOneWidget);
    });

    testWidgets('Deactivation dialog requires confirmation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Trigger deactivation dialog
      await _tapVisibleDeactivateButton(tester);
      await tester.pumpAndSettle();

      // Dialog should have confirmation buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('Filters users by status (active/inactive)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Apply the Inactive filter and verify only inactive users are shown.
      await tester.tap(find.widgetWithText(FilterChip, 'Inactive'));
      await tester.pumpAndSettle();

      expect(find.text('Inactive Local Business'), findsOneWidget);
      expect(find.text('Active Visitor'), findsNothing);
    });

    testWidgets('Supports role-based filtering', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Click Visitors filter
      await tester.tap(find.byWidgetPredicate(
        (widget) =>
            widget is FilterChip &&
            widget.label is Text &&
            (widget.label as Text).data == 'Visitors',
      ));
      await tester.pumpAndSettle();

      // Should show visitor users
      expect(find.text('Active Visitor'), findsOneWidget);
    });
  });
}

class TestAdminUserManagementService extends AdminUserManagementService {
  TestAdminUserManagementService() : super(firestore: FakeFirebaseFirestore());

  final _mockUsers = [
    AdminUserRecord(
      id: 'visitor@test.com',
      email: 'visitor@test.com',
      name: 'Active Visitor',
      role: 'visitor',
      active: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    AdminUserRecord(
      id: 'local@test.com',
      email: 'local@test.com',
      name: 'Inactive Local Business',
      role: 'local',
      active: false,
      createdAt: DateTime(2026, 1, 5),
    ),
  ];

  // Cache streams by search query so StreamBuilder sees the same object on
  // rebuilds and does not re-subscribe (which would cause an infinite loop).
  final Map<String, Stream<List<AdminUserRecord>>> _streamCache = {};

  @override
  Stream<List<AdminUserRecord>> watchAllUsers({String searchQuery = ''}) {
    return _streamCache.putIfAbsent(searchQuery, () {
      final filtered = searchQuery.isEmpty
          ? _mockUsers
          : _mockUsers
              .where((u) =>
                  u.email.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  u.name.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();
      return Stream.value(filtered);
    });
  }

  @override
  Future<void> deactivateUser(String email, String role) async {
    debugPrint('[TestService] Deactivating $email ($role)');
    return Future.value();
  }

  @override
  Future<void> reactivateUser(String email, String role) async {
    debugPrint('[TestService] Reactivating $email ($role)');
    return Future.value();
  }
}
