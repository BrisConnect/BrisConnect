import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminMessageType {
  reportNotice,
  contentRequest,
  general;

  String get label {
    switch (this) {
      case AdminMessageType.reportNotice:
        return 'Report Notice';
      case AdminMessageType.contentRequest:
        return 'Content Request';
      case AdminMessageType.general:
        return 'General';
    }
  }

  String get firestoreValue {
    switch (this) {
      case AdminMessageType.reportNotice:
        return 'report_notice';
      case AdminMessageType.contentRequest:
        return 'content_request';
      case AdminMessageType.general:
        return 'general';
    }
  }

  static AdminMessageType fromString(String value) {
    switch (value) {
      case 'report_notice':
        return AdminMessageType.reportNotice;
      case 'content_request':
        return AdminMessageType.contentRequest;
      default:
        return AdminMessageType.general;
    }
  }
}

class AdminMessage {
  final String id;
  final String to;
  final String subject;
  final String message;
  final AdminMessageType type;
  final String? eventId;
  final String? eventTitle;
  final bool isRead;
  final String sentBy;
  final DateTime createdAt;

  const AdminMessage({
    required this.id,
    required this.to,
    required this.subject,
    required this.message,
    required this.type,
    this.eventId,
    this.eventTitle,
    this.isRead = false,
    required this.sentBy,
    required this.createdAt,
  });

  factory AdminMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();
    return AdminMessage(
      id: doc.id,
      to: (data['to'] as String? ?? '').trim(),
      subject: (data['subject'] as String? ?? '').trim(),
      message: (data['message'] as String? ?? '').trim(),
      type: AdminMessageType.fromString(data['type'] as String? ?? ''),
      eventId: data['eventId'] as String?,
      eventTitle: data['eventTitle'] as String?,
      isRead: data['isRead'] == true,
      sentBy: (data['sentBy'] as String? ?? '').trim(),
      createdAt: createdAt,
    );
  }
}

class AdminMessageService {
  AdminMessageService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Send an admin message to a local user.
  Future<void> sendMessage({
    required String toEmail,
    required String subject,
    required String message,
    required AdminMessageType type,
    required String sentBy,
    String? eventId,
    String? eventTitle,
  }) async {
    final normalized = toEmail.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Recipient email cannot be empty.');
    }
    if (subject.trim().isEmpty) {
      throw ArgumentError('Subject cannot be empty.');
    }
    if (message.trim().isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('admin_messages').doc('msg-$normalized-$ts').set({
      'to': normalized,
      'subject': subject.trim(),
      'message': message.trim(),
      'type': type.firestoreValue,
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      if (eventTitle != null && eventTitle.isNotEmpty) 'eventTitle': eventTitle,
      'isRead': false,
      'sentBy': sentBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of admin messages for a local user, newest first.
  Stream<List<AdminMessage>> watchMessagesForLocal(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return const Stream.empty();
    return _firestore
        .collection('admin_messages')
        .where('to', isEqualTo: normalized)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdminMessage.fromDoc).toList());
  }

  /// Count of unread messages for a local user.
  Stream<int> watchUnreadCount(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return const Stream.empty();
    return _firestore
        .collection('admin_messages')
        .where('to', isEqualTo: normalized)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Mark a message as read.
  Future<void> markAsRead(String messageId) async {
    await _firestore
        .collection('admin_messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  /// Fetch all local users (email + name) for the admin message picker.
  Future<List<Map<String, String>>> fetchLocalUsers() async {
    final snap = await _firestore
        .collection('local_users')
        .orderBy('name')
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'email': (data['email'] as String? ?? doc.id).trim().toLowerCase(),
        'name': (data['name'] as String? ?? doc.id).trim(),
        'approvalStatus': (data['approvalStatus'] as String? ?? 'pending').trim(),
      };
    }).toList();
  }
}
