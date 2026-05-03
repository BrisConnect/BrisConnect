import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';

void main() {
  group('LocalEmailNotificationService', () {
    test('queues registration received email for local account', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueRegistrationReceivedEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Local Tester',
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');
      expect((data['meta'] as Map<String, dynamic>)['type'],
          'local_account_registration_received');

      final message = (data['message'] as Map<String, dynamic>);
      expect((message['subject'] as String).toLowerCase(),
          contains('account received'));
      expect((message['html'] as String).toLowerCase(),
          contains('pending admin verification'));
    });

    test('queues account review email for approved and rejected outcomes',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Local Tester',
        approved: true,
      );
      await service.queueAccountReviewEmail(
        recipientEmail: 'local@test.com',
        businessName: 'Local Tester',
        approved: false,
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(2));

      final approvedMail = snapshot.docs
          .map((doc) => doc.data())
          .firstWhere((data) =>
              ((data['meta'] as Map<String, dynamic>)['approved'] as bool?) ==
              true);
      final rejectedMail = snapshot.docs
          .map((doc) => doc.data())
          .firstWhere((data) =>
              ((data['meta'] as Map<String, dynamic>)['approved'] as bool?) ==
              false);

      expect((approvedMail['message'] as Map<String, dynamic>)['subject'],
          contains('approved'));
      expect((rejectedMail['message'] as Map<String, dynamic>)['subject'],
          contains('reviewed'));
    });

    test('queues event review email for approved event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Outdoor Market',
        approved: true,
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');
      expect((data['meta'] as Map<String, dynamic>)['type'],
          'local_event_review');
      expect(
          (data['meta'] as Map<String, dynamic>)['approved'], isTrue);

      final message = (data['message'] as Map<String, dynamic>);
      expect((message['subject'] as String), contains('approved'));
      expect((message['html'] as String), contains('Outdoor Market'));
      expect((message['html'] as String), contains('visible to all users'));
    });

    test('queues event review email for rejected event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: 'Blocked Party',
        approved: false,
      );

      final snapshot = await firestore.collection('mail').get();
      expect(snapshot.docs, hasLength(1));

      final data = snapshot.docs.first.data();
      expect(data['to'], 'local@test.com');
      expect(
          (data['meta'] as Map<String, dynamic>)['approved'], isFalse);

      final message = (data['message'] as Map<String, dynamic>);
      expect((message['subject'] as String), contains('rejected'));
      expect((message['html'] as String), contains('Blocked Party'));
      expect((message['html'] as String), contains('contact support'));
    });

    test('escapes HTML in event title for email body', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEmailNotificationService(firestore: firestore);

      await service.queueEventReviewEmail(
        recipientEmail: 'local@test.com',
        eventTitle: '<script>alert("xss")</script>',
        approved: true,
      );

      final snapshot = await firestore.collection('mail').get();
      final message =
          (snapshot.docs.first.data()['message'] as Map<String, dynamic>);
      final html = message['html'] as String;
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
    });
  });
}