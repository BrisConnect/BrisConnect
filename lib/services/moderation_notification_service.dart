import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Sends in-app moderation outcome notifications to content owners.
///
/// Notifications are stored in the `user_notifications` collection keyed by
/// the recipient email so they surface in the user's notification centre.
class ModerationNotificationService {
  ModerationNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('user_notifications');

  String _docId(String userEmail, String contentId, String decision) {
    final emailSlug = userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final contentSlug = contentId.trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '${emailSlug}_${contentSlug}_$decision';
  }

  /// Notify a user that their content was removed by a moderator.
  Future<void> notifyContentRemoved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    final normalized = userEmail.trim().toLowerCase();
    if (normalized.isEmpty) {
      debugPrint('[ModerationNotificationService] Cannot notify empty email');
      return;
    }

    final title = 'Your $contentType was removed';
    final message =
        'A moderator removed your $contentType because: $reason. If you believe this was a mistake, please contact support.';

    await _notificationsCollection.doc(_docId(normalized, contentId, 'removed')).set({
      'userEmail': normalized,
      'userType': userType,
      'type': 'moderation_removed',
      'title': title,
      'message': message,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notify a user that a report against their content was dismissed.
  Future<void> notifyReportDismissed({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
  }) async {
    final normalized = userEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;

    await _notificationsCollection.doc(_docId(normalized, contentId, 'dismissed')).set({
      'userEmail': normalized,
      'userType': userType,
      'type': 'moderation_dismissed',
      'title': 'Report dismissed',
      'message': 'A report against your $contentType was reviewed and dismissed.',
      'contentType': contentType,
      'contentId': contentId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Notify the original reporter that their report has been resolved.
  Future<void> notifyReportResolved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required dynamic decision,
  }) async {
    final normalized = userEmail.trim().toLowerCase();
    if (normalized.isEmpty) {
      debugPrint('[ModerationNotificationService] Cannot notify empty reporter email');
      return;
    }

    final decisionLabel = _decisionLabel(decision);
    final title = 'Report resolved';
    final message = decisionLabel == 'Dismissed'
        ? 'Your report about a $contentType was reviewed and dismissed.'
        : 'Your report about a $contentType was reviewed and action was taken.';

    await _notificationsCollection.doc(_docId(normalized, contentId, 'resolved')).set({
      'userEmail': normalized,
      'userType': userType,
      'type': 'report_resolved',
      'title': title,
      'message': message,
      'contentType': contentType,
      'contentId': contentId,
      'decision': decisionLabel,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _decisionLabel(dynamic decision) {
    if (decision == null) return 'Reviewed';
    // Accept ModerationDecision enum or raw string.
    final raw = decision.toString();
    if (raw.contains('dismiss')) return 'Dismissed';
    if (raw.contains('delete')) return 'Removed';
    if (raw.contains('flag')) return 'Flagged';
    if (raw.contains('unflag')) return 'Unflagged';
    if (raw.contains('restore')) return 'Restored';
    if (raw.contains('approve')) return 'Approved';
    return 'Reviewed';
  }
}
