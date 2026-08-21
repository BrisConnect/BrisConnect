import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of engagement a visitor can perform on an activity feed post.
enum PostEngagementAction {
  like,
  save,
  buzzVote,
  comment,
  share,
}

/// A single visitor engagement (like, save, or buzz vote) on an activity
/// feed item.
///
/// Stored in Firestore under the `post_engagements` collection. The document
/// id should be deterministic (`{postType}:{postId}:{action}:{visitorId}`)
/// so the same visitor cannot create duplicate engagements for a post.
class PostEngagement {
  final String? id;
  final String postType;
  final String postId;
  final PostEngagementAction action;
  final String visitorId;
  final DateTime createdAt;

  const PostEngagement({
    this.id,
    required this.postType,
    required this.postId,
    required this.action,
    required this.visitorId,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'postType': postType,
      'postId': postId,
      'action': action.name,
      'visitorId': visitorId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PostEngagement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final createdAt = data['createdAt'];
    return PostEngagement(
      id: doc.id,
      postType: data['postType']?.toString() ?? '',
      postId: data['postId']?.toString() ?? '',
      action: _parseAction(data['action']),
      visitorId: data['visitorId']?.toString() ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  static String documentId({
    required String postType,
    required String postId,
    required PostEngagementAction action,
    required String visitorId,
  }) {
    return '${postType}_${postId}_${action.name}_$visitorId';
  }

  static PostEngagementAction _parseAction(dynamic value) {
    final name = value?.toString().toLowerCase() ?? '';
    return PostEngagementAction.values.firstWhere(
      (a) => a.name == name,
      orElse: () => PostEngagementAction.like,
    );
  }
}
