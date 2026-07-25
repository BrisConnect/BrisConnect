import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReportEventService extends Mock implements ReportEventService {}

class _MockAdminUserManagementService extends Mock
    implements AdminUserManagementService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ModerationDecision.delete);
  });

  group('AdminReportedEventsScreen', () {
    late _MockReportEventService reportService;
    late _MockAdminUserManagementService userManagementService;

    setUp(() {
      reportService = _MockReportEventService();
      userManagementService = _MockAdminUserManagementService();
    });

    testWidgets('displays reports and applies severity filter',
        (tester) async {
      final reports = [
        _fakeReport(id: 'r1', eventId: 'e1', severity: 'high'),
        _fakeReport(id: 'r2', eventId: 'e2', severity: 'low'),
      ];

      when(() => reportService.watchReportsByStatus('pending')).thenAnswer(
        (_) => Stream.value(reports),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedEventsScreen(
            reportService: reportService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Event ID: e1'), findsOneWidget);
      expect(find.text('Event ID: e2'), findsOneWidget);

      await tester.tap(find.text('All severities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();

      expect(find.text('Event ID: e1'), findsOneWidget);
      expect(find.text('Event ID: e2'), findsNothing);
    });

    testWidgets('delete action calls moderateEventReport', (tester) async {
      final report = _fakeReport(id: 'r1', eventId: 'e1');

      when(() => reportService.watchReportsByStatus('pending')).thenAnswer(
        (_) => Stream.value([report]),
      );
      when(() => reportService.getReportById('r1')).thenAnswer(
        (_) async => report,
      );
      when(() => reportService.updateReportStatus(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedEventsScreen(
            reportService: reportService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove Event'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Confirmed spam');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();

      verify(() => reportService.updateReportStatus('r1', 'resolved'))
          .called(1);
    });

    testWidgets('shows empty state when no reports match filters',
        (tester) async {
      when(() => reportService.watchReportsByStatus('pending')).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedEventsScreen(
            reportService: reportService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pending reports'), findsOneWidget);
    });
  });
}

EventReport _fakeReport({
  required String id,
  required String eventId,
  String severity = 'medium',
}) {
  return EventReport(
    id: id,
    eventId: eventId,
    visitorEmail: 'visitor@example.com',
    reason: 'spam',
    status: 'pending',
    severity: severity,
    createdAt: DateTime(2025, 1, 1),
  );
}
