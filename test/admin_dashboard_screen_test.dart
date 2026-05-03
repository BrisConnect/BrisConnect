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
      'interestedCount': 50,
    });

    await firestore.collection('local_users').doc('l1').set({
      'email': 'l1@test.com',
      'name': 'Local One',
      'suburb': 'South Bank',
      'approvalStatus': 'pending',
      'createdAt': '2026-04-01',
    });
    await firestore.collection('local_users').doc('l2').set({
      'email': 'l2@test.com',
      'name': 'Local Two',
      'suburb': 'CBD',
      'approvalStatus': 'approved',
      'createdAt': '2026-04-02',
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

  testWidgets('shows stat cards with live values', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);

    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Stats carousel labels
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);

    // Users total = 2 local + 1 visitor + 1 admin = 4
    expect(find.text('4'), findsWidgets);
    // Events total = 2
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('stat values update when data changes', (tester) async {
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

    // total events now 3
    expect(find.text('3'), findsWidgets);
    // users now 5
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('shows hero section with Admin Dashboard title', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);
    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('BrisConnect'), findsOneWidget);
  });

  testWidgets('shows quick action chips', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedData(firestore);
    final service = AdminDashboardService(firestore: firestore);

    await tester.pumpWidget(buildApp(service));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.text('Quick Actions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('SMS Broadcast'), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
  });
}
