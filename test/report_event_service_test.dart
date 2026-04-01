import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/report_event_service.dart';

void main() {
  group('ReportEventService', () {
    test('submits a report and stores it with deterministic id', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReportEventService(firestore: firestore);

      await firestore.collection('events').doc('event-123').set({
        'title': 'Music Night',
      });

      final submitted = await service.submitReport(
        eventId: 'event-123',
        visitorEmail: 'visitor@example.com',
        reason: 'false_information',
        comments: 'The date appears incorrect.',
      );

      expect(submitted, isTrue);

      final reportId = '${Uri.encodeComponent('event-123')}__${Uri.encodeComponent('visitor@example.com')}';
      final reportDoc =
          await firestore.collection('event_reports').doc(reportId).get();

      expect(reportDoc.exists, isTrue);
      expect(reportDoc.data()!['eventId'], 'event-123');
      expect(reportDoc.data()!['visitorEmail'], 'visitor@example.com');
      expect(reportDoc.data()!['reason'], 'false_information');
      expect(reportDoc.data()!['comments'], 'The date appears incorrect.');
      expect(reportDoc.data()!['status'], 'pending');
    });

    test('prevents duplicate report from same visitor for same event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReportEventService(firestore: firestore);

      await service.submitReport(
        eventId: 'event-xyz',
        visitorEmail: 'visitor@example.com',
        reason: 'spam',
      );

      Future<void> duplicate() async {
        await service.submitReport(
          eventId: 'event-xyz',
          visitorEmail: 'visitor@example.com',
          reason: 'spam',
        );
      }

      await expectLater(
        duplicate,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'You have already reported this event.',
          ),
        ),
      );

      final allReports = await firestore.collection('event_reports').get();
      expect(allReports.docs.length, 1);
    });

    test('flags event for admin review when report is submitted', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReportEventService(firestore: firestore);

      await firestore.collection('events').doc('event-flag').set({
        'title': 'River Walk',
        'reportCount': 0,
        'flaggedForAdminReview': false,
      });

      await service.submitReport(
        eventId: 'event-flag',
        visitorEmail: 'visitor@example.com',
        reason: 'inappropriate_content',
      );

      final eventDoc = await firestore.collection('events').doc('event-flag').get();
      final data = eventDoc.data()!;

      expect(data['flaggedForAdminReview'], isTrue);
      expect(data['reportCount'], 1);
      expect(data['lastReportedAt'], isNotNull);
    });
  });
}
