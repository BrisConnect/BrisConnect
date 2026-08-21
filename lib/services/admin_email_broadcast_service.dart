import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/utils/email_formatter.dart';

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

    final recipients = <_Recipient>{};

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
        if (email != null) {
          recipients.add(_Recipient(
            email: email,
            name: (data['name'] as String?)?.trim(),
          ));
        }
      }
    }

    if (normalizedAudience == 'visitors' || normalizedAudience == 'both') {
      final visitorQuery = await _firestore.collection('visitor_users').get();
      for (final doc in visitorQuery.docs) {
        final data = doc.data();
        final email = _normalizeEmail(
          (data['email'] as String?) ?? '',
        );
        if (email != null) {
          recipients.add(_Recipient(
            email: email,
            name: (data['name'] as String?)?.trim(),
          ));
        }
      }
    }

    if (recipients.isEmpty) return 0;

    final baseHtml =
        EmailFormatter.escapeHtml(normalizedMessage).replaceAll('\n', '<br>');
    final baseSubject = EmailFormatter.escapeHtml(normalizedSubject);

    final batch = _firestore.batch();
    int seq = 0;
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final recipient in recipients) {
      seq++;
      final htmlBody = _personalize(baseHtml, recipient);
      final subject = _personalize(baseSubject, recipient);
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
      final ref = _firestore.collection('mail').doc(
            'broadcast-$normalizedAudience-$ts-$seq',
          );
      batch.set(ref, {
        'to': recipient.email,
        'message': {
          'subject': subject,
          'html': wrappedHtml,
        },
        'meta': {
          'type': 'admin_broadcast_email',
          'audience': normalizedAudience,
          'approvedLocalsOnly': approvedLocalsOnly,
        },
        'status': 'pending',
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
    if (normalizedSubject.isEmpty) {
      throw ArgumentError('Subject cannot be empty.');
    }
    if (normalizedMessage.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    final recipient = _Recipient(email: normalizedEmail, name: null);
    final htmlBody = _personalize(
      EmailFormatter.escapeHtml(normalizedMessage).replaceAll('\n', '<br>'),
      recipient,
    );
    final personalizedSubject =
        _personalize(EmailFormatter.escapeHtml(normalizedSubject), recipient);
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
        'subject': personalizedSubject,
        'html': wrappedHtml,
      },
      'meta': {
        'type': 'admin_direct_email',
        'targetEmail': normalizedEmail,
      },
      'status': 'pending',
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

  /// Replaces personalization placeholders with recipient data.
  /// Supported placeholders: {{name}}, {{email}}.
  static String _personalize(String input, _Recipient recipient) {
    final name = recipient.name?.isNotEmpty == true ? recipient.name! : 'there';
    return input
        .replaceAll('{{email}}', recipient.email)
        .replaceAll('{{name}}', EmailFormatter.escapeHtml(name));
  }
}

class _Recipient {
  final String email;
  final String? name;

  _Recipient({required this.email, this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Recipient &&
          runtimeType == other.runtimeType &&
          email == other.email;

  @override
  int get hashCode => email.hashCode;
}
