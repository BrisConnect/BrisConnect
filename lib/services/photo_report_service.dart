import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A visitor's report against a [VisitorPhoto].
class PhotoReport {
  final String id;
  final String photoId;
  final String visitorEmail;
  final String reason; // e.g., 'inappropriate_content', 'spam', 'other'
  final String? comments;
  final String status; // 'pending', 'reviewing', 'resolved', 'dismissed'
  final String severity; // 'low', 'medium', 'high', 'critical'
  final DateTime createdAt;
  final DateTime? reviewedAt;

  PhotoReport({
    required this.id,
    required this.photoId,
    required this.visitorEmail,
    required this.reason,
    this.comments,
    required this.status,
    this.severity = 'medium',
    required this.createdAt,
    this.reviewedAt,
  });

  factory PhotoReport.fromFirestore(String docId, Map<String, dynamic> data) {
    return PhotoReport(
      id: docId,
      photoId: (data['photoId'] as String?) ?? '',
      visitorEmail: (data['visitorEmail'] as String?) ?? '',
      reason: (data['reason'] as String?) ?? 'other',
      comments: data['comments'] as String?,
      status: (data['status'] as String?) ?? 'pending',
      severity: (data['severity'] as String?) ?? 'medium',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'photoId': photoId,
        'visitorEmail': visitorEmail,
        'reason': reason,
        'comments': comments,
        'status': status,
        'severity': severity,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      };
}

/// Handles visitor reports against contributed photos and the admin
/// moderation queue that reviews them.
class PhotoReportService {
  PhotoReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('photo_reports');

  static const List<String> reportReasons = [
    'inappropriate_content',
    'spam',
    'harassment',
    'not_relevant',
    'other',
  ];

  static const List<String> reportSeverities = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  static String getReasonLabel(String reason) {
    final labels = {
      'inappropriate_content': 'Inappropriate Content',
      'spam': 'Spam',
      'harassment': 'Harassment',
      'not_relevant': 'Not Relevant',
      'other': 'Other',
    };
    return labels[reason] ?? reason;
  }

  static String getSeverityLabel(String severity) {
    final labels = {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'critical': 'Critical',
    };
    return labels[severity] ?? severity;
  }

  String _reportDocId(String photoId, String visitorEmailLower) {
    final safePhotoId = Uri.encodeComponent(photoId);
    final safeEmail = Uri.encodeComponent(visitorEmailLower);
    return '${safePhotoId}__$safeEmail';
  }

  /// Check if a visitor has already reported this photo, to avoid duplicates.
  Future<bool> hasVisitorReportedPhoto(String photoId, String visitorEmail) async {
    try {
      final doc = await _reportsCollection
          .doc(_reportDocId(photoId, visitorEmail.toLowerCase().trim()))
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('[PhotoReportService] Error checking report status: $e');
      return false;
    }
  }

  /// Submit a new photo report. Uses a deterministic doc ID so a visitor can
  /// only report the same photo once.
  Future<bool> submitReport({
    required String photoId,
    required String visitorEmail,
    required String reason,
    String? comments,
    String severity = 'medium',
  }) async {
    try {
      final visitorEmailLower = visitorEmail.toLowerCase().trim();
      final report = PhotoReport(
        id: '',
        photoId: photoId,
        visitorEmail: visitorEmailLower,
        reason: reason,
        comments: comments,
        status: 'pending',
        severity: reportSeverities.contains(severity) ? severity : 'medium',
        createdAt: DateTime.now(),
      );
      await _reportsCollection
          .doc(_reportDocId(photoId, visitorEmailLower))
          .set(report.toFirestore());
      return true;
    } catch (e) {
      debugPrint('[PhotoReportService] Error submitting report: $e');
      return false;
    }
  }

  Future<PhotoReport?> getReportById(String reportId) async {
    final doc = await _reportsCollection.doc(reportId).get();
    if (!doc.exists) return null;
    return PhotoReport.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    await _reportsCollection.doc(reportId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of photo reports filtered by [status], newest first.
  Stream<List<PhotoReport>> watchReportsByStatus(String status) {
    return _reportsCollection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotoReport.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}
