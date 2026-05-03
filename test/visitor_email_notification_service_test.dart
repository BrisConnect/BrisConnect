import 'package:brisconnect/services/visitor_email_notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VisitorEmailNotificationService', () {
    test('queues registration received email for visitor account', () async {
      final firestore = FakeFirebaseFirestore();
      final service = VisitorEmailNotificationService(firestore: firestore);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'visitor@test.com',
        visitorName: 'Visitor Tester',
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'visitor@test.com');
      expect((data['meta'] as Map<String, dynamic>)['type'], 'visitor_registration_received');

      final message = (data['message'] as Map<String, dynamic>);
      expect((message['subject'] as String).toLowerCase(), contains('welcome'));
      expect((message['html'] as String).toLowerCase(), contains('visitor account has been created successfully'));
    });
  });
}