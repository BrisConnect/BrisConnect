import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/moderation_action.dart';
import '../models/review.dart';
import 'moderation_audit_service.dart';
import 'moderation_notification_service.dart';
import 'report_event_service.dart';
import 'review_service.dart';

/// Unified admin moderation service for reviews, recommendations, events and
/// photos. Wraps content-specific services and ensures every action is audited.
class AdminModerationService {
  AdminModerationService({
    FirebaseFirestore? firestore,
    ReviewService? reviewService,
    ReportEventService? reportEventService,
    ModerationAuditService? auditService,
    ModerationNotificationService? notificationService,
    this.currentAdminEmail,
  })  : _reviewService = reviewService ??
            ReviewService(
              firestore: firestore,
              auditService: auditService,
              notificationService: notificationService,
            ),
        _reportEventService = reportEventService ?? ReportEventService(firestore: firestore),
        _auditService = auditService ?? ModerationAuditService(firestore: firestore),
        _notificationService = notificationService ??
            ModerationNotificationService(firestore: firestore);

  /// Optional override for admin email, used in tests and headless environments.
  final String? currentAdminEmail;

  final ReviewService _reviewService;
  final ReportEventService _reportEventService;
  final ModerationAuditService _auditService;
  final ModerationNotificationService _notificationService;

  /// Reported reviews / recommendations visible to the admin dashboard.
  Stream<List<Review>> get reportedReviewsStream =>
      _reviewService.getReportedReviewsStream();

  /// Recently soft-deleted recommendations that can be recovered.
  Stream<List<Review>> get deletedReviewsStream =>
      _reviewService.getDeletedReviewsStream();

  Future<List<Review>> getReportedReviews() => _reviewService.getReportedReviews();

  Future<Review?> getReview(String reviewId) => _reviewService.getReview(reviewId);

  /// Moderate a review/recommendation.
  Future<void> moderateReview({
    required String reviewId,
    required ModerationDecision decision,
    required String adminEmail,
    required String reason,
  }) async {
    await _reviewService.moderateReview(
      reviewId: reviewId,
      decision: decision,
      adminEmail: adminEmail,
      reason: reason,
    );
  }

  /// Moderate an event report by updating the report status and, when the
  /// report is resolved, optionally deleting/cancelling the event itself.
  Future<void> moderateEventReport({
    required String reportId,
    required ModerationDecision decision,
    required String adminEmail,
    required String reason,
  }) async {
    final report = await _reportEventService.getReportById(reportId);
    if (report == null) {
      throw Exception('Report not found');
    }

    String status;
    switch (decision) {
      case ModerationDecision.approve:
      case ModerationDecision.dismiss:
        status = 'dismissed';
        break;
      case ModerationDecision.delete:
      case ModerationDecision.flag:
        status = 'resolved';
        break;
      case ModerationDecision.restore:
      case ModerationDecision.unflag:
        status = 'dismissed';
        break;
    }

    await _reportEventService.updateReportStatus(reportId, status);

    await _auditService.logAction(
      adminEmail: adminEmail,
      contentType: ModeratedContentType.event,
      contentId: report.eventId,
      contentOwnerId: report.visitorEmail,
      decision: decision,
      reason: reason,
      metadata: {
        'reportId': reportId,
        'reportReason': report.reason,
      },
    );

    if (decision == ModerationDecision.delete || decision == ModerationDecision.flag) {
      // Best-effort notification to the event creator if known.
      try {
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(report.eventId)
            .get();
        final ownerEmail = eventDoc.data()?['createdByLocalEmail'] as String?;
        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          await _notificationService.notifyContentRemoved(
            userEmail: ownerEmail,
            userType: 'local',
            contentType: 'event',
            contentId: report.eventId,
            reason: reason,
          );
        }
      } catch (e) {
        debugPrint('[AdminModerationService] Could not notify event owner: $e');
      }
    }

    // Notify the reporter of the resolution.
    try {
      await _notificationService.notifyReportResolved(
        userEmail: report.visitorEmail,
        userType: 'visitor',
        contentType: 'event',
        contentId: report.eventId,
        decision: decision,
      );
    } catch (e) {
      debugPrint('[AdminModerationService] Could not notify reporter: $e');
    }
  }

  /// Stream audit actions for a specific content item.
  Stream<List<ModerationAction>> watchAuditActions(
    ModeratedContentType contentType,
    String contentId,
  ) =>
      _auditService.watchActionsForContent(contentType, contentId);

  /// Stream recent audit actions with optional decision filter.
  Stream<List<ModerationAction>> watchRecentAuditActions({
    ModerationDecision? decision,
    int limit = 100,
  }) =>
      _auditService.watchActions(decision: decision, limit: limit);
}
