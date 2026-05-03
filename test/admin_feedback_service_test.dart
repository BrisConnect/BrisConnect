import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin feedback lifecycle', () {
    test('can watch pending feedback and update status', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AppFeedbackService(firestore: firestore);

      await service.submitFeedback(
        reporterRole: 'visitor',
        reporterEmail: 'visitor@example.com',
        reporterName: 'Visitor One',
        subject: 'Broken detail page',
        details: 'Event detail page shows incorrect venue details and crashes.',
        category: 'bug',
        severity: 'high',
      );

      final initialPending = await service.watchFeedbackByStatus('pending_triage').first;
      expect(initialPending, isNotEmpty);
      final id = initialPending.first.id;

      await service.updateFeedbackStatus(
        feedbackId: id,
        status: 'in_progress',
      );

      final pendingAfterUpdate = await service.watchFeedbackByStatus('pending_triage').first;
      final inProgress = await service.watchFeedbackByStatus('in_progress').first;

      expect(pendingAfterUpdate, isEmpty);
      expect(inProgress.length, 1);
      expect(inProgress.first.status, 'in_progress');
    });
  });
}
