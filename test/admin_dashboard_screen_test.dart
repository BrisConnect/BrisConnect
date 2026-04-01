import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/screens/admin_dashboard_screen.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> seedData(FakeFirebaseFirestore firestore) async {
    await firestore.collection('events').doc('e1').set({
      'title': 'Pending Event',
      'reviewStatus': 'pending',
    });
    await firestore.collection('events').doc('e2').set({
      'title': 'Approved Event',
      'reviewStatus': 'approved',
    });

    await firestore.collection('local_users').doc('l1').set({
      'email': 'l1@test.com',
      'approvalStatus': 'pending',
    });
    await firestore.collection('local_users').doc('l2').set({
      'email': 'l2@test.com',
      'approvalStatus': 'approved',
    });

    await firestore.collection('visitor_users').doc('v1').set({
      'email': 'v1@test.com',
    });

    await firestore.collection('admins').doc('a1').set({
      'email': 'a1@test.com',
    });
  }

  Widget buildApp(AdminDashboardService service) {
    return MaterialApp(
      home: AdminDashboardScreen(
        dashboardService: service,
        enforceRoleGuard: false,
        eventsScreenBuilder: (_) => const Scaffold(
          body: Center(child: Text('Events Test Page')),
        ),
        usersScreenBuilder: (_) => const Scaffold(
          body: Center(child: Text('Users Test Page')),
        ),
      ),
    );
  }

  testWidgets('shows accurate live metric values from Firestore', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);

    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Total Events'), findsOneWidget);
    expect(find.text('Pending Events'), findsOneWidget);
    expect(find.text('Local Users'), findsOneWidget);
    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('Pending Local Approvals'), findsOneWidget);

    // e1 + e2
    expect(find.text('2'), findsWidgets);
    // users (2 local + 1 visitor + 1 admin)
    expect(find.text('4'), findsWidgets);
    // pending events -> 1
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('metric update appears when data changes', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);
    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await firestore.collection('events').doc('e3').set({
      'title': 'New Pending Event',
      'reviewStatus': 'pending',
    });

    await firestore.collection('visitor_users').doc('v2').set({
      'email': 'v2@test.com',
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // total events now 3, pending now 2
    expect(find.text('3'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    // users now 5
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('tapping metric card navigates to details page', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);
    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Pending Events'));
    await tester.pumpAndSettle();

    expect(find.text('Events Test Page'), findsOneWidget);
  });
}
