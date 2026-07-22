import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEmailBroadcastService {
  AdminEmailBroadcastService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> queueAdminBroadcastEmail({
    required String audience,
    required String subject,
    required String message,
    bool approvedLocalsOnly = false,
  }) async {
    final normalizedAudience = audience.trim().toLowerCase();
    final normalizedSubject = subject.trim();
    final normalizedMessage = message.trim();
    const validAudiences = {'locals', 'visitors', 'both'};
    if (!validAudiences.contains(normalizedAudience)) {
      throw ArgumentError('Audience must be one of: locals, visitors, both.');
    }
    if (normalizedSubject.isEmpty) {
      throw ArgumentError('Subject cannot be empty.');
    }
    if (normalizedMessage.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    final recipients = <String>{};

    if (normalizedAudience == 'locals' || normalizedAudience == 'both') {
      final localQuery = approvedLocalsOnly
          ? await _firestore
              .collection('local_users')
              .where('approvalStatus', isEqualTo: 'approved')
              .get()
          : await _firestore.collection('local_users').get();

      for (final doc in localQuery.docs) {
        final data = doc.data();
        final email = _normalizeEmail(
          (data['email'] as String?) ?? '',
        );
        if (email != null) recipients.add(email);
      }
    }

    if (normalizedAudience == 'visitors' || normalizedAudience == 'both') {
      final visitorQuery =
          await _firestore.collection('visitor_users').get();
      for (final doc in visitorQuery.docs) {
        final data = doc.data();
        final email = _normalizeEmail(
          (data['email'] as String?) ?? '',
        );
        if (email != null) recipients.add(email);
      }
    }

    if (recipients.isEmpty) return 0;

    final htmlBody = _escapeHtml(normalizedMessage)
        .replaceAll('\n', '<br>');

    final wrappedHtml = '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
          <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
        </div>
        <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
          <p>$htmlBody</p>
        </div>
        <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
      </div>
    ''';

    final batch = _firestore.batch();
    int seq = 0;
    for (final email in recipients) {
      seq++;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _firestore.collection('mail').doc(
        'broadcast-$normalizedAudience-$ts-$seq',
      );
      batch.set(ref, {
        'to': email,
        'message': {
          'subject': normalizedSubject,
          'html': wrappedHtml,
        },
        'meta': {
          'type': 'admin_broadcast_email',
          'audience': normalizedAudience,
          'approvedLocalsOnly': approvedLocalsOnly,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return recipients.length;
  }

  Future<int> queueSingleLocalEmail({
    required String email,
    required String subject,
    required String message,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) throw ArgumentError('Invalid email address.');
    final normalizedSubject = subject.trim();
    final normalizedMessage = message.trim();
    if (normalizedSubject.isEmpty) throw ArgumentError('Subject cannot be empty.');
    if (normalizedMessage.isEmpty) throw ArgumentError('Message cannot be empty.');

    final htmlBody = _escapeHtml(normalizedMessage).replaceAll('\n', '<br>');
    final wrappedHtml = '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
          <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
        </div>
        <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
          <p>$htmlBody</p>
        </div>
        <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
      </div>
    ''';

    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('mail').doc('direct-local-$ts').set({
      'to': normalizedEmail,
      'message': {
        'subject': normalizedSubject,
        'html': wrappedHtml,
      },
      'meta': {
        'type': 'admin_direct_email',
        'targetEmail': normalizedEmail,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return 1;
  }

  static String? _normalizeEmail(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    // Basic email format check
    if (!trimmed.contains('@') || !trimmed.contains('.')) return null;
    return trimmed;
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
