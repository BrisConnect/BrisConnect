import 'package:cloud_firestore/cloud_firestore.dart';

class LocalEmailNotificationService {
  LocalEmailNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> queueRegistrationReceivedEmail({
    required String recipientEmail,
    required String businessName,
  }) async {
    final slug = _slugify(businessName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('mail').doc(
      'local-reg-received-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': 'BrisConnect local account received',
        'html': '<p>Hello $businessName,</p>'
            '<p>Your local account registration has been received and is pending admin verification.</p>'
            '<p>You will receive another email once your account is approved or rejected.</p>',
      },
      'meta': {
        'type': 'local_account_registration_received',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueAccountReviewEmail({
    required String recipientEmail,
    required String businessName,
    required bool approved,
  }) async {
    final slug = _slugify(businessName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final verdict = approved ? 'approved' : 'rejected';
    await _firestore.collection('mail').doc(
      'local-review-$verdict-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': approved
            ? 'Your BrisConnect local account was approved'
            : 'Your BrisConnect local account was reviewed',
        'html': '<p>Hello $businessName,</p>'
            '<p>Your local account has been ${approved ? 'approved' : 'reviewed'}.</p>',
      },
      'meta': {
        'type': 'local_account_review',
        'approved': approved,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueEventReviewEmail({
    required String recipientEmail,
    required String eventTitle,
    required bool approved,
  }) async {
    final statusLabel = approved ? 'approved' : 'rejected';
    final slug = _slugify(eventTitle);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('mail').doc(
      'event-review-$statusLabel-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': 'Your BrisConnect event was $statusLabel',
        'html': '<p>Hello,</p>'
            '<p>Your submitted event <strong>${_escapeHtml(eventTitle)}</strong> '
            'has been <strong>$statusLabel</strong> by the BrisConnect admin team.</p>'
            '${approved ? '<p>It is now visible to all users in the app.</p>' : '<p>If you believe this was a mistake, please contact support.</p>'}',
      },
      'meta': {
        'type': 'local_event_review',
        'approved': approved,
        'eventTitle': eventTitle,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueEventSavedEmail({
    required String recipientEmail,
    required String businessName,
    required String eventTitle,
    required String eventDate,
    required String eventLocation,
  }) async {
    final slug = _slugify(eventTitle);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final schedule = [eventDate, eventLocation]
        .where((s) => s.isNotEmpty)
        .join(' — ');
    await _firestore.collection('mail').doc(
      'local-event-saved-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': 'BrisConnect: You saved "${_escapeHtml(eventTitle)}"',
        'html': '<p>Hello $businessName,</p>'
            '<p>You saved <strong>${_escapeHtml(eventTitle)}</strong> to your events.</p>'
            '${schedule.isNotEmpty ? '<p>Details: $schedule</p>' : ''}'
            '<p>Open BrisConnect to view your saved events.</p>',
      },
      'meta': {
        'type': 'local_event_saved',
        'eventTitle': eventTitle,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"['']+"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}