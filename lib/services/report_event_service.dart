import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EventReport {
  final String id;
  final String eventId;
  final String visitorEmail;
  final String reason; // e.g., 'inappropriate_content', 'false_information', 'spam', 'other'
  final String? comments;
  final String status; // 'pending', 'reviewing', 'resolved', 'dismissed'
  final DateTime createdAt;
  final DateTime? reviewedAt;

  EventReport({
    required this.id,
    required this.eventId,
    required this.visitorEmail,
    required this.reason,
    this.comments,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });

  factory EventReport.fromFirestore(String docId, Map<String, dynamic> data) {
    return EventReport(
      id: docId,
      eventId: (data['eventId'] as String?) ?? '',
      visitorEmail: (data['visitorEmail'] as String?) ?? '',
      reason: (data['reason'] as String?) ?? 'other',
      comments: (data['comments'] as String?),
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'eventId': eventId,
        'visitorEmail': visitorEmail,
        'reason': reason,
        'comments': comments,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      };
}

class ReportEventService {
  ReportEventService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _reportDocId(String eventId, String visitorEmailLower) {
    final safeEventId = Uri.encodeComponent(eventId);
    final safeEmail = Uri.encodeComponent(visitorEmailLower);
    return '${safeEventId}__$safeEmail';
  }

  static const List<String> reportReasons = [
    'inappropriate_content',
    'false_information',
    'spam',
    'harassment',
    'other',
  ];

  static String getReasonLabel(String reason) {
    final labels = {
      'inappropriate_content': 'Inappropriate Content',
      'false_information': 'False Information',
      'spam': 'Spam',
      'harassment': 'Harassment',
      'other': 'Other',
    };
    return labels[reason] ?? reason;
  }

  /// Check if a visitor has already reported this event
  Future<bool> hasVisitorReportedEvent(String eventId, String visitorEmail) async {
    try {
      final query = await _firestore
          .collection('event_reports')
          .where('eventId', isEqualTo: eventId)
          .where('visitorEmail', isEqualTo: visitorEmail.toLowerCase())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (error) {
      debugPrint('[ReportEventService] Error checking report status: $error');
      return false;
    }
  }

  /// Submit a new event report
  Future<bool> submitReport({
    required String eventId,
    required String visitorEmail,
    required String reason,
    String? comments,
  }) async {
    try {
      final visitorEmailLower = visitorEmail.toLowerCase().trim();
      final reportDocId = _reportDocId(eventId, visitorEmailLower);
      final reportRef = _firestore.collection('event_reports').doc(reportDocId);
      final eventRef = _firestore.collection('events').doc(eventId);

      // Create report
      final report = EventReport(
        id: reportDocId,
        eventId: eventId,
        visitorEmail: visitorEmailLower,
        reason: reason,
        comments: comments?.trim().isEmpty ?? true ? null : comments?.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reportRef);
        final eventSnap = await transaction.get(eventRef);

        if (existing.exists) {
          throw StateError('You have already reported this event.');
        }

        transaction.set(reportRef, report.toFirestore());

        // Flag event for moderation if it exists in the events collection.
        if (eventSnap.exists) {
          final currentCount = (eventSnap.data()?['reportCount'] as int?) ?? 0;
          transaction.update(eventRef, {
            'flaggedForAdminReview': true,
            'reportCount': currentCount + 1,
            'lastReportedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint(
          '[ReportEventService] Report submitted for event $eventId by $visitorEmail');
      return true;
    } catch (error) {
      debugPrint('[ReportEventService] Error submitting report: $error');
      rethrow;
    }
  }

  /// Get all reports for an event
  Future<List<EventReport>> getEventReports(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('event_reports')
          .where('eventId', isEqualTo: eventId)
          .get();

      return snapshot.docs
          .map((doc) => EventReport.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (error) {
      debugPrint('[ReportEventService] Error fetching event reports: $error');
      return [];
    }
  }

  /// Stream of all pending reports (for admin)
  Stream<List<EventReport>> watchPendingReports() {
    return _firestore
        .collection('event_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => EventReport.fromFirestore(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  /// Stream of all reports by status (for admin dashboard)
  Stream<List<EventReport>> watchReportsByStatus(String status) {
    return _firestore
        .collection('event_reports')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => EventReport.fromFirestore(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  /// Update report status (admin only)
  Future<void> updateReportStatus(
    String reportId,
    String newStatus,
  ) async {
    try {
      await _firestore.collection('event_reports').doc(reportId).update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[ReportEventService] Updated report $reportId to $newStatus');
    } catch (error) {
      debugPrint('[ReportEventService] Error updating report: $error');
      rethrow;
    }
  }

  /// Get count of pending reports for a specific event
  Future<int> getPendingReportCount(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('event_reports')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (error) {
      debugPrint('[ReportEventService] Error getting pending report count: $error');
      return 0;
    }
  }

  /// Get count of all pending reports (for admin dashboard)
  Future<int> getTotalPendingReports() async {
    try {
      final snapshot = await _firestore
          .collection('event_reports')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (error) {
      debugPrint('[ReportEventService] Error getting total pending reports: $error');
      return 0;
    }
  }
}
