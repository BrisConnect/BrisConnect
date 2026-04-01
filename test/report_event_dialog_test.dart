import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:brisconnect/widgets/report_event_dialog.dart';
import 'package:brisconnect/services/report_event_service.dart';

class _SuccessReportService extends ReportEventService {
  _SuccessReportService() : super(firestore: FakeFirebaseFirestore());

  bool called = false;
  String? eventId;
  String? visitorEmail;
  String? reason;
  String? comments;

  @override
  Future<bool> submitReport({
    required String eventId,
    required String visitorEmail,
    required String reason,
    String? comments,
  }) async {
    called = true;
    this.eventId = eventId;
    this.visitorEmail = visitorEmail;
    this.reason = reason;
    this.comments = comments;
    return true;
  }
}

class _DuplicateReportService extends ReportEventService {
  _DuplicateReportService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<bool> submitReport({
    required String eventId,
    required String visitorEmail,
    required String reason,
    String? comments,
  }) {
    throw StateError('You have already reported this event.');
  }
}

void main() {
  group('ReportEventDialog', () {
    testWidgets('submits selected reason and optional comments', (tester) async {
      final service = _SuccessReportService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  ReportEventDialog.show(
                    context: context,
                    eventId: 'event-123',
                    visitorEmail: 'visitor@example.com',
                    reportService: service,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Report Event'), findsOneWidget);
      expect(find.text('Reason for Report'), findsOneWidget);

      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'This event appears to be promotional spam.',
      );

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(service.called, isTrue);
      expect(service.eventId, 'event-123');
      expect(service.visitorEmail, 'visitor@example.com');
      expect(service.reason, 'spam');
      expect(service.comments, 'This event appears to be promotional spam.');
    });

    testWidgets('shows error when duplicate report is submitted', (tester) async {
      final service = _DuplicateReportService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  ReportEventDialog.show(
                    context: context,
                    eventId: 'event-123',
                    visitorEmail: 'visitor@example.com',
                    reportService: service,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.textContaining('You have already reported this event.'), findsOneWidget);
    });
  });
}
