import 'dart:async';

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

class _SlowReportService extends ReportEventService {
  _SlowReportService() : super(firestore: FakeFirebaseFirestore());

  bool called = false;
  final completer = Completer<bool>();

  @override
  Future<bool> submitReport({
    required String eventId,
    required String visitorEmail,
    required String reason,
    String? comments,
  }) async {
    called = true;
    return completer.future;
  }
}

Widget _buildHost(ReportEventService service) {
  return MaterialApp(
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
  );
}

void main() {
  group('ReportEventDialog', () {
    testWidgets('renders dialog with all 5 selectable reasons',
        (tester) async {
      final service = _SuccessReportService();
      await tester.pumpWidget(_buildHost(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Report Event'), findsOneWidget);
      expect(find.text('Reason for Report'), findsOneWidget);
      expect(find.text('Additional Details (Optional)'), findsOneWidget);

      // All 5 reason labels visible as radio options
      for (final label in [
        'Inappropriate Content',
        'False Information',
        'Spam',
        'Harassment',
        'Other',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // Submit and Cancel buttons present
      expect(find.text('Submit Report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel button dismisses dialog without submitting',
        (tester) async {
      final service = _SuccessReportService();
      await tester.pumpWidget(_buildHost(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Report Event'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog gone
      expect(find.text('Report Event'), findsNothing);
      // Service not called
      expect(service.called, isFalse);
    });

    testWidgets('shows loading spinner while submitting', (tester) async {
      final service = _SlowReportService();
      await tester.pumpWidget(_buildHost(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Report'));
      await tester.pump(); // start async
      await tester.pump(const Duration(milliseconds: 50));

      // Spinner visible, "Submit Report" text replaced
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Report'), findsNothing);
      expect(service.called, isTrue);

      // Complete the future so the test can dispose cleanly.
      service.completer.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('submits without comments when field is left empty',
        (tester) async {
      final service = _SuccessReportService();
      await tester.pumpWidget(_buildHost(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Don't enter any comments — just submit with default reason
      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(service.called, isTrue);
      expect(service.reason, 'inappropriate_content'); // default first
      expect(service.comments, isNull);
    });

    testWidgets('submits selected reason and optional comments', (tester) async {
      final service = _SuccessReportService();
      await tester.pumpWidget(_buildHost(service));

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
      await tester.pumpWidget(_buildHost(service));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.textContaining('You have already reported this event.'), findsOneWidget);
    });

    testWidgets('allows changing reason via radio buttons', (tester) async {
      final service = _SuccessReportService();
      await tester.pumpWidget(_buildHost(service));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Default is first reason (Inappropriate Content). Select Harassment.
      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(service.called, isTrue);
      expect(service.reason, 'harassment');
    });
  });
}
