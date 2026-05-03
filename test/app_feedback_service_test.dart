import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFeedbackService', () {
    test('stores feedback with maintenance tracking fields', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AppFeedbackService(
        firestore: firestore,
        maintenanceWindowDays: 10,
      );

      await service.submitFeedback(
        reporterRole: 'visitor',
        reporterEmail: 'visitor@example.com',
        reporterName: 'Visitor One',
        subject: 'Map pin is wrong',
        details: 'The map pin for one event points to the wrong street corner.',
        category: 'misleading_info',
        severity: 'high',
        screenContext: 'Visitor Portal > Event Detail',
        appVersion: '1.0.1',
      );

      final snapshot = await firestore.collection('app_feedback').get();
      expect(snapshot.docs.length, 1);

      final data = snapshot.docs.first.data();
      expect(data['reporterRole'], 'visitor');
      expect(data['reporterEmail'], 'visitor@example.com');
      expect(data['subject'], 'Map pin is wrong');
      expect(data['status'], 'pending_triage');
      expect(data['consideredForFix'], true);
      expect(data['maintenanceWindowDays'], 10);
      expect(data['resolutionDueAt'], isNotNull);
      expect(data['createdAt'], isNotNull);
    });

    test('throws when subject is empty', () async {
      final service = AppFeedbackService(firestore: FakeFirebaseFirestore());

      expect(
        () => service.submitFeedback(
          reporterRole: 'local',
          reporterEmail: 'local@example.com',
          reporterName: 'Local Business',
          subject: '  ',
          details: 'Detailed feedback here for testing.',
          category: 'bug',
          severity: 'medium',
        ),
        throwsArgumentError,
      );
    });
  });
}
