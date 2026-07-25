import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/moderation_action.dart';

/// Writes and queries immutable moderation audit logs.
///
/// Each moderation decision creates a new audit record so the history of
/// every action is preserved and cannot be altered by clients.
class ModerationAuditService {
  ModerationAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _auditCollection =>
      _firestore.collection('moderation_audit_log');

  /// Record a moderation action in the audit log.
  Future<String> logAction({
    required String adminEmail,
    required ModeratedContentType contentType,
    required String contentId,
    String? contentOwnerId,
    required ModerationDecision decision,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    final normalizedAdmin = adminEmail.trim().toLowerCase();
    if (normalizedAdmin.isEmpty) {
      throw ArgumentError('adminEmail cannot be empty');
    }
    if (contentId.trim().isEmpty) {
      throw ArgumentError('contentId cannot be empty');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('reason cannot be empty');
    }

    final docRef = _auditCollection.doc();
    final action = ModerationAction(
      id: docRef.id,
      adminEmail: normalizedAdmin,
      contentType: contentType,
      contentId: contentId.trim(),
      contentOwnerId: contentOwnerId?.trim(),
      decision: decision,
      reason: reason.trim(),
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    try {
      await docRef.set(action.toFirestore());
      debugPrint('[ModerationAuditService] Logged ${decision.label} for $contentType $contentId');
      return docRef.id;
    } catch (e) {
      debugPrint('[ModerationAuditService] Failed to log moderation action: $e');
      rethrow;
    }
  }

  /// Stream audit log entries for a specific content item.
  Stream<List<ModerationAction>> watchActionsForContent(
    ModeratedContentType contentType,
    String contentId,
  ) {
    return _auditCollection
        .where('contentType', isEqualTo: contentType.firestoreValue)
        .where('contentId', isEqualTo: contentId.trim())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ModerationAction.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Stream all audit log entries with optional decision filter.
  Stream<List<ModerationAction>> watchActions({
    ModerationDecision? decision,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _auditCollection
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (decision != null) {
      query = query.where('decision', isEqualTo: decision.firestoreValue);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ModerationAction.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }
}
