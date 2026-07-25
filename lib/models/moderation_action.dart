import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of content that can be moderated.
enum ModeratedContentType {
  review,
  event,
  photo,
  recommendation;

  String get firestoreValue {
    switch (this) {
      case ModeratedContentType.review:
        return 'review';
      case ModeratedContentType.event:
        return 'event';
      case ModeratedContentType.photo:
        return 'photo';
      case ModeratedContentType.recommendation:
        return 'recommendation';
    }
  }

  static ModeratedContentType fromString(String value) {
    switch (value) {
      case 'event':
        return ModeratedContentType.event;
      case 'photo':
        return ModeratedContentType.photo;
      case 'recommendation':
        return ModeratedContentType.recommendation;
      case 'review':
      default:
        return ModeratedContentType.review;
    }
  }
}

/// Actions an admin can take on reported content.
enum ModerationDecision {
  approve,
  delete,
  dismiss,
  flag,
  unflag,
  restore;

  String get firestoreValue {
    switch (this) {
      case ModerationDecision.approve:
        return 'approve';
      case ModerationDecision.delete:
        return 'delete';
      case ModerationDecision.dismiss:
        return 'dismiss';
      case ModerationDecision.flag:
        return 'flag';
      case ModerationDecision.unflag:
        return 'unflag';
      case ModerationDecision.restore:
        return 'restore';
    }
  }

  static ModerationDecision fromString(String value) {
    switch (value) {
      case 'delete':
        return ModerationDecision.delete;
      case 'dismiss':
        return ModerationDecision.dismiss;
      case 'flag':
        return ModerationDecision.flag;
      case 'unflag':
        return ModerationDecision.unflag;
      case 'restore':
        return ModerationDecision.restore;
      case 'approve':
      default:
        return ModerationDecision.approve;
    }
  }

  String get label {
    switch (this) {
      case ModerationDecision.approve:
        return 'Approved';
      case ModerationDecision.delete:
        return 'Deleted';
      case ModerationDecision.dismiss:
        return 'Dismissed';
      case ModerationDecision.flag:
        return 'Flagged';
      case ModerationDecision.unflag:
        return 'Unflagged';
      case ModerationDecision.restore:
        return 'Restored';
    }
  }
}

/// Immutable record of a moderation action written to the audit log.
class ModerationAction {
  final String id;
  final String adminEmail;
  final ModeratedContentType contentType;
  final String contentId;
  final String? contentOwnerId;
  final ModerationDecision decision;
  final String reason;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const ModerationAction({
    required this.id,
    required this.adminEmail,
    required this.contentType,
    required this.contentId,
    this.contentOwnerId,
    required this.decision,
    required this.reason,
    required this.createdAt,
    this.metadata,
  });

  factory ModerationAction.fromFirestore(String docId, Map<String, dynamic> data) {
    return ModerationAction(
      id: docId,
      adminEmail: (data['adminEmail'] as String? ?? '').trim().toLowerCase(),
      contentType: ModeratedContentType.fromString(data['contentType'] as String? ?? 'review'),
      contentId: (data['contentId'] as String? ?? '').trim(),
      contentOwnerId: data['contentOwnerId'] as String?,
      decision: ModerationDecision.fromString(data['decision'] as String? ?? 'approve'),
      reason: (data['reason'] as String? ?? '').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'adminEmail': adminEmail,
        'contentType': contentType.firestoreValue,
        'contentId': contentId,
        if (contentOwnerId != null) 'contentOwnerId': contentOwnerId,
        'decision': decision.firestoreValue,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        if (metadata != null) 'metadata': metadata,
      };

  ModerationAction copyWith({
    String? id,
    String? adminEmail,
    ModeratedContentType? contentType,
    String? contentId,
    String? contentOwnerId,
    ModerationDecision? decision,
    String? reason,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ModerationAction(
      id: id ?? this.id,
      adminEmail: adminEmail ?? this.adminEmail,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      contentOwnerId: contentOwnerId ?? this.contentOwnerId,
      decision: decision ?? this.decision,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
