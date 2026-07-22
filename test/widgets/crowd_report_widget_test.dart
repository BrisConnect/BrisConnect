import 'package:brisconnect/services/crowd_report_service.dart';
import 'package:brisconnect/widgets/crowd_report_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCrowdReportService extends CrowdReportService {
  _FakeCrowdReportService({
    required this.canSubmit,
  }) : super();

  final bool canSubmit;
  final List<Map<String, dynamic>> submittedReports = [];

  @override
  Future<bool> canSubmitReport(String eventId) async => canSubmit;

  @override
  Future<void> submitReport(String eventId, CrowdLevel level) async {
    submittedReports.add({'eventId': eventId, 'level': level.label});
  }

  @override
  Stream<CrowdStatus?> watchCrowdStatus(String eventId) async* {
    yield null;
  }
}

void main() {
  group('CrowdReportWidget', () {
    testWidgets('displays Low, Moderate, High options', (tester) async {
      final service = _FakeCrowdReportService(canSubmit: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CrowdReportWidget(
            eventId: 'event_1',
            crowdReportService: service,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('selecting a level enables submit button', (tester) async {
      final service = _FakeCrowdReportService(canSubmit: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CrowdReportWidget(
            eventId: 'event_1',
            crowdReportService: service,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      expect(tester.widget<ElevatedButton>(submitButton).enabled, false);

      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(submitButton).enabled, true);
    });

    testWidgets('submitting records report and shows thanks feedback',
        (tester) async {
      final service = _FakeCrowdReportService(canSubmit: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CrowdReportWidget(
            eventId: 'event_1',
            crowdReportService: service,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Moderate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Report'));
      await tester.pumpAndSettle();

      expect(service.submittedReports.length, 1);
      expect(service.submittedReports.first['level'], 'Moderate');
      expect(find.text('Thanks! Your report was submitted.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Submit Report'), findsNothing);
    });

    testWidgets('cooldown state hides report buttons', (tester) async {
      final service = _FakeCrowdReportService(canSubmit: false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CrowdReportWidget(
            eventId: 'event_1',
            crowdReportService: service,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('You can report again in 30 minutes.'), findsOneWidget);
      expect(find.text('Submit Report'), findsNothing);
    });
  });
}
