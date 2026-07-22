import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorEmailNotificationService {
  VisitorEmailNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> queueRegistrationReceivedEmail({
    required String recipientEmail,
    required String visitorName,
  }) async {
    final slug = _slugify(visitorName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('mail').doc(
      'visitor-reg-received-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': 'Welcome to BrisConnect+',
        'html': _wrapEmail('<p>Hello $visitorName,</p>'
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
    final slug = _slugify(eventTitle);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final schedule = [eventDate, eventLocation]
        .where((s) => s.isNotEmpty)
        .join(' — ');
    await _firestore.collection('mail').doc(
      'visitor-event-saved-$slug-$ts',
    ).set({
      'to': recipientEmail,
      'message': {
        'subject': 'BrisConnect+: You saved "${_escapeHtml(eventTitle)}"',
        'html': _wrapEmail('<p>Hello $visitorName,</p>'
            '<p>You saved <strong>${_escapeHtml(eventTitle)}</strong> to your events.</p>'
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

  static String _emailHeader() {
    return '''
      <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
        <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
      </div>
      <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
    ''';
  }

  static String _emailFooter() {
    return '''
      </div>
      <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
    ''';
  }

  static String _wrapEmail(String body) {
    return '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        ${_emailHeader()}
        $body
        ${_emailFooter()}
      </div>
    ''';
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