import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/services/moderation_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('ModerationNotificationService', () {
    late FakeFirebaseFirestore firestore;
    late ModerationNotificationService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ModerationNotificationService(firestore: firestore);
    });

    test('notifyContentRemoved writes notification document', () async {
      await service.notifyContentRemoved(
        userEmail: 'Owner@Example.com',
        userType: 'local',
        contentType: 'event',
        contentId: 'event-1',
        reason: 'Inappropriate content',
      );

      final snapshot = await firestore
          .collection('user_notifications')
          .doc('owner-example-com_event-1_removed')
          .get();

      expect(snapshot.exists, isTrue);
      final data = snapshot.data()!;
      expect(data['userEmail'], 'owner@example.com');
      expect(data['userType'], 'local');
      expect(data['type'], 'moderation_removed');
      expect(data['contentType'], 'event');
      expect(data['contentId'], 'event-1');
      expect(data['isRead'], isFalse);
      expect((data['createdAt'] as Timestamp).seconds, isPositive);
    });

    test('notifyReportResolved writes resolved notification', () async {
      await service.notifyReportResolved(
        userEmail: 'Reporter@Example.com',
        userType: 'visitor',
        contentType: 'recommendation',
        contentId: 'review-1',
        decision: ModerationDecision.delete,
      );

      final snapshot = await firestore
          .collection('user_notifications')
          .doc('reporter-example-com_review-1_resolved')
          .get();

      expect(snapshot.exists, isTrue);
      final data = snapshot.data()!;
      expect(data['type'], 'report_resolved');
      expect(data['decision'], 'Removed');
      expect(data['message'], contains('action was taken'));
    });

    test('notifyReportResolved with dismiss decision writes correct message',
        () async {
      await service.notifyReportResolved(
        userEmail: 'reporter@example.com',
        userType: 'visitor',
        contentType: 'event',
        contentId: 'event-2',
        decision: ModerationDecision.dismiss,
      );

      final snapshot = await firestore
          .collection('user_notifications')
          .doc('reporter-example-com_event-2_resolved')
          .get();

      expect(snapshot.data()!['decision'], 'Dismissed');
      expect(snapshot.data()!['message'], contains('dismissed'));
    });

    test('skips notification when user email is empty', () async {
      await service.notifyReportResolved(
        userEmail: '   ',
        userType: 'visitor',
        contentType: 'event',
        contentId: 'event-3',
        decision: ModerationDecision.delete,
      );

      final docs = await firestore.collection('user_notifications').get();
      expect(docs.docs, isEmpty);
    });
  });
}
