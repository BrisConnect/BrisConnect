import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppFeedbackItem {
  AppFeedbackItem({
    required this.id,
    required this.reporterRole,
    required this.reporterEmail,
    required this.reporterName,
    required this.subject,
    required this.details,
    required this.category,
    required this.severity,
    required this.status,
    required this.consideredForFix,
    required this.maintenanceWindowDays,
    required this.createdAt,
    required this.updatedAt,
    this.screenContext,
    this.appVersion,
    this.resolutionDueAt,
    this.adminReply,
    this.adminReplyAt,
    this.replyReadByReporter = true,
    this.imageUrl,
    this.imageStoragePath,
    this.referenceId = '',
  });

  final String id;
  final String reporterRole;
  final String reporterEmail;
  final String reporterName;
  final String subject;
  final String details;
  final String category;
  final String severity;
  final String status;
  final bool consideredForFix;
  final int maintenanceWindowDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? screenContext;
  final String? appVersion;
  final DateTime? resolutionDueAt;
  final String? adminReply;
  final DateTime? adminReplyAt;
  final bool replyReadByReporter;
  final String? imageUrl;
  final String? imageStoragePath;
  final String referenceId;

  factory AppFeedbackItem.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return AppFeedbackItem(
      id: docId,
      reporterRole: (data['reporterRole'] as String?) ?? 'unknown',
      reporterEmail: (data['reporterEmail'] as String?) ?? '',
      reporterName: (data['reporterName'] as String?) ?? '',
      subject: (data['subject'] as String?) ?? '',
      details: (data['details'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'other',
      severity: (data['severity'] as String?) ?? 'medium',
      status: (data['status'] as String?) ?? 'pending_triage',
      consideredForFix: (data['consideredForFix'] as bool?) ?? true,
      maintenanceWindowDays: (data['maintenanceWindowDays'] as int?) ?? 14,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      screenContext: data['screenContext'] as String?,
      appVersion: data['appVersion'] as String?,
      resolutionDueAt: (data['resolutionDueAt'] as Timestamp?)?.toDate(),
      adminReply: data['adminReply'] as String?,
      adminReplyAt: (data['adminReplyAt'] as Timestamp?)?.toDate(),
      replyReadByReporter: (data['replyReadByReporter'] as bool?) ?? true,
      imageUrl: data['imageUrl'] as String?,
      imageStoragePath: data['imageStoragePath'] as String?,
      referenceId: (data['referenceId'] as String?) ?? '',
    );
  }
}

class AppFeedbackService {
  AppFeedbackService({
    FirebaseFirestore? firestore,
    this.maintenanceWindowDays = 14,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final int maintenanceWindowDays;

  static const List<String> feedbackStatuses = [
    'pending_triage',
    'in_progress',
    'resolved',
    'wont_fix',
  ];

  Stream<List<AppFeedbackItem>> watchFeedbackByStatus(String status) {
    return _firestore
        .collection('app_feedback')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => AppFeedbackItem.fromFirestore(doc.id, doc.data()))
              .toList(growable: false);

          final sorted = [...items]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return sorted;
        });
  }

  Stream<int> pendingFeedbackCount() {
    return _firestore
        .collection('app_feedback')
        .where('status', isEqualTo: 'pending_triage')
        .snapshots()
        .map((snapshot) => snapshot.size)
        .distinct();
  }

  Future<void> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    bool? consideredForFix,
  }) async {
    await _firestore.collection('app_feedback').doc(feedbackId).update({
      'status': status,
      if (consideredForFix != null) 'consideredForFix': consideredForFix,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> replyToFeedback({
    required String feedbackId,
    required String reply,
  }) async {
    await _firestore.collection('app_feedback').doc(feedbackId).update({
      'adminReply': reply.trim(),
      'adminReplyAt': FieldValue.serverTimestamp(),
      'replyReadByReporter': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppFeedbackItem>> watchFeedbackByReporter(String email) {
    return _firestore
        .collection('app_feedback')
        .where('reporterEmail', isEqualTo: email.trim().toLowerCase())
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => AppFeedbackItem.fromFirestore(doc.id, doc.data()))
              .toList(growable: false);
          final sorted = [...items]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return sorted;
        });
  }

  Future<void> markReplyRead({required String feedbackId}) async {
    await _firestore.collection('app_feedback').doc(feedbackId).update({
      'replyReadByReporter': true,
    });
  }

  Future<void> submitFeedback({
    required String reporterRole,
    required String reporterEmail,
    required String reporterName,
    required String subject,
    required String details,
    required String category,
    required String severity,
    String? screenContext,
    String? appVersion,
    String? imageUrl,
    String? imageStoragePath,
  }) async {
    final now = DateTime.now();
    final normalizedRole = reporterRole.trim().toLowerCase();
    final normalizedEmail = reporterEmail.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Reporter email cannot be empty.');
    }

    if (subject.trim().isEmpty || details.trim().isEmpty) {
      throw ArgumentError('Subject and details are required.');
    }

    // Generate a human-readable reference ID using a Firestore counter.
    final counterRef = _firestore.collection('counters').doc('app_feedback');
    final nextNumber = await _firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      tx.set(counterRef, {'count': next}, SetOptions(merge: true));
      return next;
    });
    final referenceId = 'FB-${nextNumber.toString().padLeft(4, '0')}';

    await _firestore.collection('app_feedback').doc(referenceId.toLowerCase()).set({
      'referenceId': referenceId,
      'reporterRole': normalizedRole,
      'reporterEmail': normalizedEmail,
      'reporterName': reporterName.trim(),
      'subject': subject.trim(),
      'details': details.trim(),
      'category': category.trim().toLowerCase(),
      'severity': severity.trim().toLowerCase(),
      'screenContext': screenContext?.trim().isNotEmpty == true
          ? screenContext!.trim()
          : null,
      'appVersion': appVersion?.trim().isNotEmpty == true
          ? appVersion!.trim()
          : null,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'status': 'pending_triage',
      // Explicit lifecycle fields make sure each feedback item is tracked,
      // reviewed, and time-boxed for maintenance follow-up.
      'consideredForFix': true,
      'maintenanceWindowDays': maintenanceWindowDays,
      'resolutionDueAt': Timestamp.fromDate(
        now.add(Duration(days: maintenanceWindowDays)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '[AppFeedbackService] Feedback submitted by $normalizedEmail ($normalizedRole)',
    );
  }
}
