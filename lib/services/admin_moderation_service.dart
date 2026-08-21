import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/moderation_action.dart';
import '../models/review.dart';
import '../models/visitor_photo.dart';
import 'moderation_audit_service.dart';
import 'moderation_notification_service.dart';
import 'photo_report_service.dart';
import 'report_event_service.dart';
import 'review_service.dart';
import 'visitor_photo_service.dart';

/// Unified admin moderation service for reviews, recommendations, events and
/// photos. Wraps content-specific services and ensures every action is audited.
class AdminModerationService {
  AdminModerationService({
    FirebaseFirestore? firestore,
    ReviewService? reviewService,
    ReportEventService? reportEventService,
    PhotoReportService? photoReportService,
    VisitorPhotoService? visitorPhotoService,
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
        _photoReportService = photoReportService ?? PhotoReportService(firestore: firestore),
        _visitorPhotoService = visitorPhotoService ?? VisitorPhotoService(firestore: firestore),
        _auditService = auditService ?? ModerationAuditService(firestore: firestore),
        _notificationService = notificationService ??
            ModerationNotificationService(firestore: firestore);

  /// Optional override for admin email, used in tests and headless environments.
  final String? currentAdminEmail;

  final ReviewService _reviewService;
  final ReportEventService _reportEventService;
  final PhotoReportService _photoReportService;
  final VisitorPhotoService _visitorPhotoService;
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

  /// Records an audit log entry for suspending a reported user's account.
  /// The suspension itself is performed by [AdminUserManagementService];
  /// this only ensures the action is auditable like every other moderation
  /// decision.
  Future<void> logUserSuspension({
    required String userEmail,
    required String adminEmail,
    required String reason,
    required ModeratedContentType relatedContentType,
    required String relatedContentId,
  }) {
    return _auditService.logAction(
      adminEmail: adminEmail,
      contentType: ModeratedContentType.userAccount,
      contentId: userEmail.trim().toLowerCase(),
      contentOwnerId: userEmail.trim().toLowerCase(),
      decision: ModerationDecision.suspend,
      reason: reason,
      metadata: {
        'relatedContentType': relatedContentType.firestoreValue,
        'relatedContentId': relatedContentId,
      },
    );
  }

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
      case ModerationDecision.suspend:
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

  /// Photo reports filtered by status, for the reported-photos moderation queue.
  Stream<List<PhotoReport>> watchPhotoReportsByStatus(String status) =>
      _photoReportService.watchReportsByStatus(status);

  /// Recently soft-deleted photos that can still be recovered.
  Stream<List<VisitorPhoto>> get deletedPhotosStream =>
      _visitorPhotoService.getDeletedPhotosStream();

  /// Moderate a reported photo: approve/dismiss the report, or soft-delete
  /// the photo (recoverable for 30 days) when it's confirmed inappropriate.
  Future<void> moderatePhotoReport({
    required String reportId,
    required ModerationDecision decision,
    required String adminEmail,
    required String reason,
  }) async {
    final report = await _photoReportService.getReportById(reportId);
    if (report == null) {
      throw Exception('Report not found');
    }

    final photo = await _visitorPhotoService.getPhoto(report.photoId);

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
      case ModerationDecision.suspend:
        status = 'dismissed';
        break;
    }

    await _photoReportService.updateReportStatus(reportId, status);

    await _auditService.logAction(
      adminEmail: adminEmail,
      contentType: ModeratedContentType.photo,
      contentId: report.photoId,
      contentOwnerId: photo?.visitorId,
      decision: decision,
      reason: reason,
      metadata: {
        'reportId': reportId,
        'reportReason': report.reason,
      },
    );

    if (decision == ModerationDecision.delete || decision == ModerationDecision.flag) {
      await _visitorPhotoService.softDeletePhoto(report.photoId, adminEmail: adminEmail);

      // Note: VisitorPhoto only stores the uploader's Firebase Auth UID
      // (visitorId), not their email, so we cannot reliably notify them via
      // the email-keyed notification system used elsewhere. Per the
      // acceptance criteria this notification is optional; the reporter is
      // still notified below.
    }

    // Notify the reporter of the resolution.
    try {
      await _notificationService.notifyReportResolved(
        userEmail: report.visitorEmail,
        userType: 'visitor',
        contentType: 'photo',
        contentId: report.photoId,
        decision: decision,
      );
    } catch (e) {
      debugPrint('[AdminModerationService] Could not notify reporter: $e');
    }
  }
}
