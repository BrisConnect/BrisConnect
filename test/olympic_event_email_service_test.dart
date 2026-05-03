import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/olympic_event_email_service.dart';

void main() {
  group('OlympicEventEmailService', () {
    test('queues email with date time and venue details for upcoming event',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = OlympicEventEmailService(firestore: firestore);

      await firestore.collection('events').doc('event-1').set({
        'title': 'Brisbane Olympic Fan Festival',
        'description': 'A Brisbane 2032 celebration in South Bank',
        'date': '02/08/2032',
        'time': '6:30 PM',
        'location': 'South Bank',
        'reviewStatus': 'approved',
      });

      await service.queueUpcomingOlympicEventEmail(
        recipientEmail: 'visitor@example.com',
      );

      final mail = await firestore.collection('mail').get();
      expect(mail.docs, hasLength(1));

      final message =
          (mail.docs.first.data()['message'] as Map<String, dynamic>?) ?? {};
      final html = (message['html'] as String?) ?? '';
      expect(html, contains('Brisbane Olympic Fan Festival'));
      expect(html, contains('02/08/2032'));
      expect(html, contains('6:30 PM'));
      expect(html, contains('South Bank'));
    });

    test('queues for all opted-in visitors and avoids duplicates', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OlympicEventEmailService(firestore: firestore);

      await firestore.collection('events').doc('event-1').set({
        'title': 'Olympic Stadium Preview',
        'description': 'Brisbane Olympic activation event',
        'date': '2032-09-10',
        'time': '2:00 PM',
        'location': 'Brisbane City',
        'reviewStatus': 'approved',
      });

      await firestore.collection('visitor_users').doc('opted-in-1@test.com').set({
        'email': 'opted-in-1@test.com',
        'emailNotificationsEnabled': true,
      });
      await firestore.collection('visitor_users').doc('opted-out@test.com').set({
        'email': 'opted-out@test.com',
        'emailNotificationsEnabled': false,
      });
      await firestore.collection('visitor_users').doc('opted-in-2@test.com').set({
        'email': 'opted-in-2@test.com',
        'emailNotificationsEnabled': true,
      });

      final firstQueued = await service.queueUpcomingOlympicEventEmailsForOptedInVisitors();
      final firstMail = await firestore.collection('mail').get();

      expect(firstQueued, 2);
      expect(firstMail.docs, hasLength(2));

      final secondQueued = await service.queueUpcomingOlympicEventEmailsForOptedInVisitors();
      final secondMail = await firestore.collection('mail').get();

      expect(secondQueued, 0);
      expect(secondMail.docs, hasLength(2));
    });

    test('filters out non-Brisbane, non-Olympic, and past events', () async {
      final firestore = FakeFirebaseFirestore();
      final service = OlympicEventEmailService(firestore: firestore);

      await firestore.collection('events').doc('past-event').set({
        'title': 'Olympic Legacy Walk',
        'description': 'Brisbane Olympic history',
        'date': '01/01/2020',
        'time': '9:00 AM',
        'location': 'Brisbane City',
        'reviewStatus': 'approved',
      });
      await firestore.collection('events').doc('wrong-city').set({
        'title': 'Olympic Media Day',
        'description': 'Olympic prep event',
        'date': '02/01/2032',
        'time': '10:00 AM',
        'location': 'Sydney Olympic Park',
        'reviewStatus': 'approved',
      });
      await firestore.collection('events').doc('valid-event').set({
        'title': 'Games Volunteer Welcome',
        'description': 'Brisbane 2032 community welcome',
        'date': '03/01/2032',
        'time': '11:00 AM',
        'location': 'Kangaroo Point',
        'reviewStatus': 'approved',
      });

      await service.queueUpcomingOlympicEventEmail(
        recipientEmail: 'visitor@example.com',
      );

      final mail = await firestore.collection('mail').get();
      expect(mail.docs, hasLength(1));
      final message =
          (mail.docs.first.data()['message'] as Map<String, dynamic>?) ?? {};
      final html = (message['html'] as String?) ?? '';

      expect(html, contains('Games Volunteer Welcome'));
      expect(html, isNot(contains('Olympic Legacy Walk')));
      expect(html, isNot(contains('Olympic Media Day')));
    });
  });
}