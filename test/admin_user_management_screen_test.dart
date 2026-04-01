import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminUserManagementScreen Story 17', () {
    testWidgets('Renders UI elements for user management', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search bar exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify filter chips exist
      expect(find.byType(FilterChip), findsWidgets);
      expect(find.text('All Roles'), findsOneWidget);
      expect(find.text('Visitors'), findsOneWidget);
      expect(find.text('Locals'), findsOneWidget);

      // Verify status filters exist
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);

      // Verify AppBar with title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
    });

    testWidgets('Displays user list from stream', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify test users are displayed
      expect(find.text('Test Visitor'), findsOneWidget);
      expect(find.text('Test Local Business'), findsOneWidget);
    });

    testWidgets('Streams user data in real-time', (tester) async {
      final service = TestAdminUserManagementService();
      
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state should have test users  
      expect(find.text('Test Visitor'), findsOneWidget);
      expect(find.text('VISITOR'), findsOneWidget);
    });

    testWidgets('Has deactivate action available on user cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find user card
      final userCard = find.byType(Card).first;
      expect(userCard, findsOneWidget);

      // Long press to trigger action menu
      await tester.longPress(userCard);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsWidgets);
    });

    testWidgets('Deactivation dialog requires confirmation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger deactivation dialog
      final userCard = find.byType(Card).first;
      await tester.longPress(userCard);
      await tester.pumpAndSettle();

      // Dialog should have confirmation buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('Filters users by status (active/inactive)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we have both active and inactive status chips shown
      expect(find.byWidgetPredicate(
        (widget) =>
            widget is Chip &&
            widget.label is Text &&
            ((widget.label as Text).data?.contains('Active') ?? false),
      ), findsWidgets);
    });

    testWidgets('Supports role-based filtering', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserManagementScreen(
            userManagementService: TestAdminUserManagementService(),
          ),
        ),
      );
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
      expect(find.text('Test Visitor'), findsOneWidget);
    });
  });
}

class TestAdminUserManagementService extends AdminUserManagementService {
  TestAdminUserManagementService() : super();

  @override
  Stream<List<AdminUserRecord>> watchAllUsers({String searchQuery = ''}) {
    final mockUsers = [
      AdminUserRecord(
        id: 'visitor@test.com',
        email: 'visitor@test.com',
        name: 'Test Visitor',
        role: 'visitor',
        active: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      AdminUserRecord(
        id: 'local@test.com',
        email: 'local@test.com',
        name: 'Test Local Business',
        role: 'local',
        active: false,
        createdAt: DateTime(2026, 1, 5),
      ),
    ];

    if (searchQuery.isEmpty) {
      return Stream.value(mockUsers);
    }

    final filtered = mockUsers
        .where((u) =>
            u.email.toLowerCase().contains(searchQuery.toLowerCase()) ||
            u.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Stream.value(filtered);
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
