import 'package:brisconnect/services/report_event_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('ReportEventService', () {
    late FakeFirebaseFirestore firestore;
    late ReportEventService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ReportEventService(firestore: firestore);
    });

    test('submitReport writes report with severity', () async {
      final result = await service.submitReport(
        eventId: 'event-1',
        visitorEmail: 'Visitor@Example.com',
        reason: 'spam',
        comments: 'Too many ads',
        severity: 'high',
      );

      expect(result, isTrue);

      final doc = await firestore
          .collection('event_reports')
          .doc('event-1__visitor%40example.com')
          .get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['eventId'], 'event-1');
      expect(data['visitorEmail'], 'visitor@example.com');
      expect(data['reason'], 'spam');
      expect(data['severity'], 'high');
      expect(data['comments'], 'Too many ads');
      expect(data['status'], 'pending');
      expect((data['createdAt'] as Timestamp).seconds, isPositive);
    });

    test('invalid severity normalises to medium', () async {
      await service.submitReport(
        eventId: 'event-2',
        visitorEmail: 'v@example.com',
        reason: 'other',
        severity: 'unknown',
      );

      final doc = await firestore
          .collection('event_reports')
          .doc('event-2__v%40example.com')
          .get();
      expect(doc.data()!['severity'], 'medium');
    });

    test('duplicate report returns false', () async {
      await service.submitReport(
        eventId: 'event-3',
        visitorEmail: 'v@example.com',
        reason: 'spam',
      );

      final result = await service.submitReport(
        eventId: 'event-3',
        visitorEmail: 'v@example.com',
        reason: 'spam',
      );

      expect(result, isFalse);
    });

    test('getReasonLabel returns readable labels', () {
      expect(ReportEventService.getReasonLabel('spam'), 'Spam');
      expect(ReportEventService.getReasonLabel('unknown'), 'unknown');
    });

    test('getSeverityLabel returns readable labels', () {
      expect(ReportEventService.getSeverityLabel('critical'), 'Critical');
      expect(ReportEventService.getSeverityLabel('unknown'), 'unknown');
    });
  });
}
