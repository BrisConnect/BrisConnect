import 'package:cloud_firestore/cloud_firestore.dart';

/// A visitor comment on an activity feed post.
///
/// Stored in Firestore under the `post_comments` collection, keyed by the
/// source post type and post id so comments can be loaded per post.
class PostComment {
  final String? id;
  final String postType;
  final String postId;
  final String visitorId;
  final String visitorName;
  final String text;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? mediaType; // 'image' or 'video'

  const PostComment({
    this.id,
    required this.postType,
    required this.postId,
    required this.visitorId,
    required this.visitorName,
    required this.text,
    required this.createdAt,
    this.mediaUrl,
    this.mediaType,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'postType': postType,
      'postId': postId,
      'visitorId': visitorId,
      'visitorName': visitorName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (mediaUrl != null && mediaUrl!.isNotEmpty) 'mediaUrl': mediaUrl,
      if (mediaType != null && mediaType!.isNotEmpty) 'mediaType': mediaType,
    };
  }

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    final createdAt = data['createdAt'];
    return PostComment(
      id: doc.id,
      postType: data['postType']?.toString() ?? '',
      postId: data['postId']?.toString() ?? '',
      visitorId: data['visitorId']?.toString() ?? '',
      visitorName: data['visitorName']?.toString() ?? 'Anonymous',
      text: data['text']?.toString() ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      mediaUrl: (data['mediaUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : data['mediaUrl'] as String?,
      mediaType: (data['mediaType'] as String?)?.trim().isEmpty ?? true
          ? null
          : data['mediaType'] as String?,
    );
  }
}

