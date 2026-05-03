import 'package:cloud_firestore/cloud_firestore.dart';

class SmsNotificationService {
  SmsNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> queueAdminBroadcastSms({
    required String audience,
    required String message,
    bool approvedLocalsOnly = false,
  }) async {
    final normalizedAudience = audience.trim().toLowerCase();
    final normalizedMessage = message.trim();
    const validAudiences = {'locals', 'visitors', 'both'};
    if (!validAudiences.contains(normalizedAudience)) {
      throw ArgumentError('Audience must be one of: locals, visitors, both.');
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
        final phone = _normalizePhone(
          (data['phone'] as String?) ??
              (data['phoneNumber'] as String?) ??
              (data['mobile'] as String?) ??
              '',
        );
        if (phone != null) {
          recipients.add(phone);
        }
      }
    }

    if (normalizedAudience == 'visitors' || normalizedAudience == 'both') {
      final visitorQuery = await _firestore.collection('visitor_users').get();
      for (final doc in visitorQuery.docs) {
        final data = doc.data();
        final phone = _normalizePhone(
          (data['phoneNumber'] as String?) ??
              (data['phone'] as String?) ??
              (data['mobile'] as String?) ??
              '',
        );
        if (phone != null) {
          recipients.add(phone);
        }
      }
    }

    if (recipients.isEmpty) {
      return 0;
    }

    final batch = _firestore.batch();
    int seq = 0;
    for (final phone in recipients) {
      seq++;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _firestore.collection('sms_queue').doc(
        'broadcast-$normalizedAudience-$ts-$seq',
      );
      batch.set(ref, {
        'to': phone,
        'message': normalizedMessage,
        'meta': {
          'type': 'admin_broadcast_sms',
          'audience': normalizedAudience,
          'approvedLocalsOnly': approvedLocalsOnly,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return recipients.length;
  }

  Future<void> queueLocalAccountRegistrationReceivedSms({
    required String recipientPhone,
    required String businessName,
  }) async {
    final to = _normalizePhone(recipientPhone);
    if (to == null) {
      return;
    }

    final slug = _slugify(businessName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('sms_queue').doc(
      'local-reg-received-$slug-$ts',
    ).set({
      'to': to,
      'message':
          'Hi $businessName, your BrisConnect local account registration was received and is pending verification.',
      'meta': {
        'type': 'local_account_registration_received_sms',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueVisitorRegistrationReceivedSms({
    required String recipientPhone,
    required String visitorName,
  }) async {
    final to = _normalizePhone(recipientPhone);
    if (to == null) {
      return;
    }

    final slug = _slugify(visitorName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('sms_queue').doc(
      'visitor-reg-received-$slug-$ts',
    ).set({
      'to': to,
      'message':
          'Hi $visitorName, welcome to BrisConnect. Your visitor account has been created successfully.',
      'meta': {
        'type': 'visitor_registration_received_sms',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueLocalAccountReviewSms({
    required String recipientPhone,
    required String businessName,
    required bool approved,
  }) async {
    final to = _normalizePhone(recipientPhone);
    if (to == null) {
      return;
    }

    final slug = _slugify(businessName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final verdict = approved ? 'approved' : 'rejected';
    await _firestore.collection('sms_queue').doc(
      'local-review-$verdict-$slug-$ts',
    ).set({
      'to': to,
      'message': approved
          ? 'Hi $businessName, your BrisConnect local account is approved.'
          : 'Hi $businessName, your BrisConnect local account was reviewed and is not approved.',
      'meta': {
        'type': 'local_account_review_sms',
        'approved': approved,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> queueLocalEventReviewSms({
    required String recipientPhone,
    required String eventTitle,
    required String reviewStatus,
  }) async {
    final to = _normalizePhone(recipientPhone);
    if (to == null) {
      return;
    }

    final slug = _slugify(eventTitle);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('sms_queue').doc(
      'event-review-${reviewStatus.toLowerCase()}-$slug-$ts',
    ).set({
      'to': to,
      'message': 'Your event "$eventTitle" is now ${reviewStatus.toUpperCase()} on BrisConnect.',
      'meta': {
        'type': 'local_event_review_sms',
        'reviewStatus': reviewStatus,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> queueVisitorSavedEventSms({
    required String visitorEmail,
    required String eventId,
  }) async {
    final normalizedEmail = visitorEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty || eventId.trim().isEmpty) {
      return false;
    }

    final visitorDoc = await _firestore.collection('visitor_users').doc(normalizedEmail).get();
    final visitorData = visitorDoc.data() ?? const <String, dynamic>{};
    final to = _normalizePhone(
      (visitorData['phoneNumber'] as String?) ??
          (visitorData['phone'] as String?) ??
          (visitorData['mobile'] as String?) ??
          '',
    );
    if (to == null) {
      return false;
    }

    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    final eventData = eventDoc.data() ?? const <String, dynamic>{};
    final title = ((eventData['title'] as String?) ?? 'event').trim();
    final date = ((eventData['date'] as String?) ?? '').trim();
    final time = ((eventData['time'] as String?) ?? '').trim();
    final schedule = [date, time].where((part) => part.isNotEmpty).join(' ');

    final smsId = _smsDocId('visitor_saved_event_sms', '$normalizedEmail::$eventId');
    final existing = await _firestore.collection('sms_queue').doc(smsId).get();
    if (existing.exists) {
      return false;
    }

    await _firestore.collection('sms_queue').doc(smsId).set({
      'to': to,
      'message': schedule.isEmpty
          ? 'BrisConnect reminder: "$title" was saved to your events.'
          : 'BrisConnect reminder: "$title" was saved to your events. Schedule: $schedule',
      'meta': {
        'type': 'visitor_saved_event_sms',
        'visitorEmail': normalizedEmail,
        'eventId': eventId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<bool> queueLocalSavedEventSms({
    required String localEmail,
    required String eventId,
  }) async {
    final normalizedEmail = localEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty || eventId.trim().isEmpty) {
      return false;
    }

    final localDoc = await _firestore.collection('local_users').doc(normalizedEmail).get();
    final localData = localDoc.data() ?? const <String, dynamic>{};
    final to = _normalizePhone(
      (localData['phoneNumber'] as String?) ??
          (localData['phone'] as String?) ??
          (localData['mobile'] as String?) ??
          '',
    );
    if (to == null) {
      return false;
    }

    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    final eventData = eventDoc.data() ?? const <String, dynamic>{};
    final title = ((eventData['title'] as String?) ?? 'event').trim();
    final date = ((eventData['date'] as String?) ?? '').trim();
    final time = ((eventData['time'] as String?) ?? '').trim();
    final schedule = [date, time].where((part) => part.isNotEmpty).join(' ');

    final smsId = _smsDocId('local_saved_event_sms', '$normalizedEmail::$eventId');
    final existing = await _firestore.collection('sms_queue').doc(smsId).get();
    if (existing.exists) {
      return false;
    }

    await _firestore.collection('sms_queue').doc(smsId).set({
      'to': to,
      'message': schedule.isEmpty
          ? 'BrisConnect reminder: "$title" was saved to your events.'
          : 'BrisConnect reminder: "$title" was saved to your events. Schedule: $schedule',
      'meta': {
        'type': 'local_saved_event_sms',
        'localEmail': normalizedEmail,
        'eventId': eventId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  String? _normalizePhone(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }

    // Remove common formatting characters so we can standardize to E.164.
    var normalized = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.startsWith('00')) {
      normalized = '+${normalized.substring(2)}';
    } else if (normalized.startsWith('61')) {
      normalized = '+$normalized';
    } else if (normalized.startsWith('0')) {
      // BrisConnect targets AU users: convert local 0-prefixed numbers to +61.
      normalized = '+61${normalized.substring(1)}';
    }

    if (!normalized.startsWith('+')) {
      return null;
    }

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
      return null;
    }

    return normalized;
  }

  String _smsDocId(String type, String key) {
    final safeType = Uri.encodeComponent(type.toLowerCase());
    final safeKey = Uri.encodeComponent(key.toLowerCase());
    return '${safeType}__$safeKey';
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
