import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/utils/email_formatter.dart';

class VisitorEmailNotificationService {
  VisitorEmailNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> queueRegistrationReceivedEmail({
    required String recipientEmail,
    required String visitorName,
  }) async {
    final slug = EmailFormatter.slugify(visitorName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore
        .collection('mail')
        .doc(
          'visitor-reg-received-$slug-$ts',
        )
        .set({
      'to': recipientEmail,
      'message': {
        'subject': 'Welcome to BrisConnect+',
        'html': EmailFormatter.wrapEmail('<p>Hello $visitorName,</p>'
            '<p>Your BrisConnect+ visitor account has been created successfully.</p>'
            '<p>You can now sign in and explore events, attractions, and notifications.</p>'),
      },
      'meta': {
        'type': 'visitor_registration_received',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueEventSavedEmail({
    required String recipientEmail,
    required String visitorName,
    required String eventTitle,
    required String eventDate,
    required String eventLocation,
  }) async {
    final slug = EmailFormatter.slugify(eventTitle);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final schedule =
        [eventDate, eventLocation].where((s) => s.isNotEmpty).join(' — ');
    await _firestore
        .collection('mail')
        .doc(
          'visitor-event-saved-$slug-$ts',
        )
        .set({
      'to': recipientEmail,
      'message': {
        'subject':
            'BrisConnect+: You saved "${EmailFormatter.escapeHtml(eventTitle)}"',
        'html': EmailFormatter.wrapEmail('<p>Hello $visitorName,</p>'
            '<p>You saved <strong>${EmailFormatter.escapeHtml(eventTitle)}</strong> to your events.</p>'
            '${schedule.isNotEmpty ? '<p>Details: $schedule</p>' : ''}'
            '<p>Open BrisConnect+ to view your saved events.</p>'),
      },
      'meta': {
        'type': 'visitor_event_saved',
        'eventTitle': eventTitle,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
