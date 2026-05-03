import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/services/report_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildScreen({TestReportEventService? service}) {
    return MaterialApp(
      home: AdminReportedEventsScreen(
        reportService: service ?? TestReportEventService(),
        enforceRoleGuard: false,
      ),
    );
  }

  group('AdminReportedEventsScreen (STORY-38)', () {
    testWidgets('Renders AppBar and status filter chips', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Reported Events'), findsOneWidget);
      expect(find.text('Filter Reports by Status'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Pending'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Reviewing'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Resolved'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Dismissed'), findsOneWidget);
    });

    testWidgets('Displays pending reports from stream', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('event-001'), findsOneWidget);
      expect(find.textContaining('reporter@test.com'), findsOneWidget);
      expect(find.text('Reason: Inappropriate Content'), findsOneWidget);
    });

    testWidgets('Shows reporter details, reason, and comments', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('reporter@test.com'), findsOneWidget);
      expect(find.text('Reason: Inappropriate Content'), findsOneWidget);
      expect(find.text('This event has offensive content.'), findsOneWidget);
    });

    testWidgets('Shows Dismiss and Review buttons for pending reports',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('Filters reports by status when chip tapped', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Initially shows pending report
      expect(find.textContaining('event-001'), findsOneWidget);

      // Tap Resolved filter
      await tester.tap(find.widgetWithText(FilterChip, 'Resolved'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Resolved report visible
      expect(find.textContaining('event-002'), findsOneWidget);
      expect(find.text('Mark Resolved'), findsOneWidget);
    });

    testWidgets('Shows empty state when no reports match filter',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Tap Dismissed filter — no reports exist with this status
      await tester.tap(find.widgetWithText(FilterChip, 'Dismissed'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No dismissed reports'), findsOneWidget);
    });

    testWidgets('Status chip shows color-coded badge on report card',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });
  });
}

class TestReportEventService extends ReportEventService {
  TestReportEventService() : super(firestore: FakeFirebaseFirestore());

  final _pendingReports = [
    EventReport(
      id: 'report-001',
      eventId: 'event-001',
      visitorEmail: 'reporter@test.com',
      reason: 'inappropriate_content',
      comments: 'This event has offensive content.',
      status: 'pending',
      createdAt: DateTime(2026, 4, 1),
    ),
  ];

  final _resolvedReports = [
    EventReport(
      id: 'report-002',
      eventId: 'event-002',
      visitorEmail: 'user2@test.com',
      reason: 'false_information',
      comments: 'Date was wrong.',
      status: 'resolved',
      createdAt: DateTime(2026, 3, 20),
      reviewedAt: DateTime(2026, 3, 21),
    ),
  ];

  final Map<String, Stream<List<EventReport>>> _streamCache = {};

  @override
  Stream<List<EventReport>> watchReportsByStatus(String status) {
    return _streamCache.putIfAbsent(status, () {
      switch (status) {
        case 'pending':
          return Stream.value(_pendingReports);
        case 'resolved':
          return Stream.value(_resolvedReports);
        default:
          return Stream.value([]);
      }
    });
  }

  @override
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    debugPrint('[TestService] updateReportStatus $reportId → $newStatus');
  }
}
