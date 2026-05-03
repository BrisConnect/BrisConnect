import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmsNotificationService', () {
    test('queues local account registration and review sms', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await service.queueLocalAccountRegistrationReceivedSms(
        recipientPhone: '+61400111222',
        businessName: 'River Cafe',
      );
      await service.queueLocalAccountReviewSms(
        recipientPhone: '+61400111222',
        businessName: 'River Cafe',
        approved: true,
      );

      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 2);
    });

    test('queues visitor registration sms', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await service.queueVisitorRegistrationReceivedSms(
        recipientPhone: '0448 675 413',
        visitorName: 'Visitor Tester',
      );

      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 1);
      expect(queue.docs.first.data()['to'], '+61448675413');
      expect(queue.docs.first.data()['meta']['type'], 'visitor_registration_received_sms');
    });

    test('queues visitor saved event sms only once per event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await firestore.collection('visitor_users').doc('visitor@example.com').set({
        'phoneNumber': '+61400999888',
      });
      await firestore.collection('events').doc('event-1').set({
        'title': 'Riverfire',
        'date': '01/01/2027',
        'time': '7:00 PM',
      });

      final first = await service.queueVisitorSavedEventSms(
        visitorEmail: 'visitor@example.com',
        eventId: 'event-1',
      );
      final second = await service.queueVisitorSavedEventSms(
        visitorEmail: 'visitor@example.com',
        eventId: 'event-1',
      );

      expect(first, isTrue);
      expect(second, isFalse);

      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 1);
      expect(queue.docs.first.data()['meta']['type'], 'visitor_saved_event_sms');
    });

    test('queues admin broadcast SMS for locals and visitors with dedupe', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await firestore.collection('local_users').doc('l1').set({
        'phone': '+61400111000',
        'approvalStatus': 'approved',
      });
      await firestore.collection('local_users').doc('l2').set({
        'phone': '+61400222000',
        'approvalStatus': 'pending',
      });
      await firestore.collection('visitor_users').doc('v1').set({
        'phoneNumber': '+61400111000',
      });

      final queued = await service.queueAdminBroadcastSms(
        audience: 'both',
        message: 'Service update tonight at 10 PM.',
      );

      expect(queued, 2);

      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 2);
      expect(
        queue.docs.every((doc) => doc.data()['meta']['type'] == 'admin_broadcast_sms'),
        isTrue,
      );
    });

    test('queues admin broadcast SMS only for approved locals when selected', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await firestore.collection('local_users').doc('l1').set({
        'phone': '+61400111000',
        'approvalStatus': 'approved',
      });
      await firestore.collection('local_users').doc('l2').set({
        'phone': '+61400222000',
        'approvalStatus': 'pending',
      });

      final queued = await service.queueAdminBroadcastSms(
        audience: 'locals',
        message: 'Approved-local notice.',
        approvedLocalsOnly: true,
      );

      expect(queued, 1);
      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 1);
      expect(queue.docs.first.data()['to'], '+61400111000');
    });

    test('throws for invalid admin broadcast audience', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await expectLater(
        service.queueAdminBroadcastSms(
          audience: 'everyone',
          message: 'Hello',
        ),
        throwsArgumentError,
      );
    });

    test('normalizes local AU phone formats to E.164 for broadcast', () async {
      final firestore = FakeFirebaseFirestore();
      final service = SmsNotificationService(firestore: firestore);

      await firestore.collection('local_users').doc('l1').set({
        'phone': '0448 675 413',
        'approvalStatus': 'approved',
      });

      final queued = await service.queueAdminBroadcastSms(
        audience: 'locals',
        message: 'Formatting test.',
      );

      expect(queued, 1);
      final queue = await firestore.collection('sms_queue').get();
      expect(queue.docs.length, 1);
      expect(queue.docs.first.data()['to'], '+61448675413');
    });
  });
}
