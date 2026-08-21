import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/models/post_comment.dart';
import 'package:brisconnect/models/post_engagement.dart';
import 'package:brisconnect/services/firebase_media_service.dart';

/// Tracks visitor engagement (like, save, buzz vote, comment, share) on
/// community activity feed posts.
///
/// Engagements are stored best-effort; failures are logged but never block
/// the UI.
class PostEngagementService {
  static const String _engagementsCollection = 'post_engagements';
  static const String _commentsCollection = 'post_comments';
  static const int maxCommentMediaBytes = 20 * 1024 * 1024; // 20 MB

  final FirebaseFirestore _firestore;
  final FirebaseMediaService _mediaService;

  PostEngagementService({
    FirebaseFirestore? firestore,
    FirebaseMediaService? mediaService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _mediaService = mediaService ?? FirebaseMediaService();

  /// Current visitor id (Firebase Auth UID), or null when unauthenticated.
  String? get _currentVisitorId {
    final fbUser = FirebaseAuth.instance.currentUser;
    return fbUser?.uid;
  }

  /// Record a like, save, or buzz vote. Returns true on success.
  Future<bool> engage({
    required ActivityFeedItem item,
    required PostEngagementAction action,
  }) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) {
      debugPrint('[PostEngagementService] Cannot engage: no visitor id');
      return false;
    }

    final postType = _postTypeForItem(item);
    final postId = item.id;
    final docId = PostEngagement.documentId(
      postType: postType,
      postId: postId,
      action: action,
      visitorId: visitorId,
    );

    final engagement = PostEngagement(
      id: docId,
      postType: postType,
      postId: postId,
      action: action,
      visitorId: visitorId,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection(_engagementsCollection)
          .doc(docId)
          .set(engagement.toFirestore());
      return true;
    } catch (e) {
      debugPrint('[PostEngagementService] engage failed: $e');
      return false;
    }
  }

  /// Remove a previously recorded engagement. Returns true on success.
  Future<bool> disengage({
    required ActivityFeedItem item,
    required PostEngagementAction action,
  }) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) return false;

    final postType = _postTypeForItem(item);
    final postId = item.id;
    final docId = PostEngagement.documentId(
      postType: postType,
      postId: postId,
      action: action,
      visitorId: visitorId,
    );

    try {
      await _firestore.collection(_engagementsCollection).doc(docId).delete();
      return true;
    } catch (e) {
      debugPrint('[PostEngagementService] disengage failed: $e');
      return false;
    }
  }

  /// Toggle an engagement on/off for the current visitor.
  ///
  /// Returns the new active state, or null if the operation failed.
  Future<bool?> toggle({
    required ActivityFeedItem item,
    required PostEngagementAction action,
  }) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) return null;

    final postType = _postTypeForItem(item);
    final postId = item.id;
    final docId = PostEngagement.documentId(
      postType: postType,
      postId: postId,
      action: action,
      visitorId: visitorId,
    );

    final ref = _firestore.collection(_engagementsCollection).doc(docId);
    try {
      final doc = await ref.get();
      if (doc.exists) {
        await ref.delete();
        return false;
      } else {
        await ref.set(PostEngagement(
          id: docId,
          postType: postType,
          postId: postId,
          action: action,
          visitorId: visitorId,
          createdAt: DateTime.now(),
        ).toFirestore());
        return true;
      }
    } catch (e) {
      debugPrint('[PostEngagementService] toggle failed: $e');
      return null;
    }
  }

  /// Whether the current visitor has already performed [action] on [item].
  Future<bool> hasEngaged({
    required ActivityFeedItem item,
    required PostEngagementAction action,
  }) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) return false;

    final postType = _postTypeForItem(item);
    final postId = item.id;
    final docId = PostEngagement.documentId(
      postType: postType,
      postId: postId,
      action: action,
      visitorId: visitorId,
    );

    try {
      final doc =
          await _firestore.collection(_engagementsCollection).doc(docId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[PostEngagementService] hasEngaged failed: $e');
      return false;
    }
  }

  /// Stream of engagement counts for a post, grouped by action.
  ///
  /// Includes like/save/buzzVote/share from [post_engagements] and a live
  /// comment count from [post_comments] so the feed feels active and every
  /// button can show a dynamic count.
  Stream<Map<PostEngagementAction, int>> engagementCounts({
    required ActivityFeedItem item,
  }) {
    final postType = _postTypeForItem(item);
    final postId = item.id;

    final engagementsStream = _firestore
        .collection(_engagementsCollection)
        .where('postType', isEqualTo: postType)
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
      final counts = <PostEngagementAction, int>{};
      for (final action in PostEngagementAction.values) {
        counts[action] = 0;
      }
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final action = PostEngagementAction.values.firstWhere(
          (a) => a.name == (data['action'] as String? ?? ''),
          orElse: () => PostEngagementAction.like,
        );
        counts[action] = (counts[action] ?? 0) + 1;
      }
      return counts;
    });

    final commentsStream = _firestore
        .collection(_commentsCollection)
        .where('postType', isEqualTo: postType)
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    return _combineLatest2(
      engagementsStream,
      commentsStream,
      (Map<PostEngagementAction, int> engagementCounts, int commentCount) {
        return <PostEngagementAction, int>{
          ...engagementCounts,
          PostEngagementAction.comment: commentCount,
        };
      },
    );
  }

  /// Record a share engagement for a post. Returns true on success.
  Future<bool> recordShare({required ActivityFeedItem item}) async {
    return engage(item: item, action: PostEngagementAction.share);
  }

  /// Stream of engagement document ids for the current visitor on a set of
  /// posts. Useful for batch-highlighting buttons for visible posts.
  Stream<Set<String>> visitorEngagementIdsForPostIds(
    String postType,
    List<String> postIds,
  ) {
    final visitorId = _currentVisitorId;
    if (visitorId == null ||
        visitorId.isEmpty ||
        postIds.isEmpty ||
        postType.isEmpty) {
      return Stream.value(const <String>{});
    }

    // Firestore supports up to 10 values in whereIn. Chunk postIds.
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < postIds.length; i += chunkSize) {
      chunks.add(postIds.sublist(
        i,
        i + chunkSize > postIds.length ? postIds.length : i + chunkSize,
      ));
    }

    final streams = chunks.map((chunk) {
      return _firestore
          .collection(_engagementsCollection)
          .where('postType', isEqualTo: postType)
          .where('postId', whereIn: chunk)
          .where('visitorId', isEqualTo: visitorId)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
    }).toList();

    if (streams.isEmpty) return Stream.value(const <String>{});

    final controller = StreamController<Set<String>>.broadcast();
    final latest = List<Set<String>?>.filled(streams.length, null);
    var hasValue = List<bool>.filled(streams.length, false);
    var subscriptions = <StreamSubscription<Set<String>>>[];

    void emit() {
      if (hasValue.every((v) => v) && !controller.isClosed) {
        final combined = latest
            .whereType<Set<String>>()
            .fold<Set<String>>(<String>{}, (acc, set) => acc..addAll(set));
        controller.add(combined);
      }
    }

    for (var i = 0; i < streams.length; i++) {
      final sub = streams[i].listen(
        (set) {
          latest[i] = set;
          hasValue[i] = true;
          emit();
        },
        onError: controller.addError,
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Add a comment to a post, optionally with an attached photo or video.
  /// Returns true on success.
  Future<bool> addComment({
    required ActivityFeedItem item,
    required String text,
    Uint8List? mediaBytes,
    String? mediaFileName,
    String? mediaMimeType,
  }) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId.isEmpty) return false;

    final visitorName = VisitorAuth.currentVisitor?.name ?? 'Anonymous';
    final trimmed = text.trim();
    final hasMedia = mediaBytes != null && mediaBytes.isNotEmpty;
    if (trimmed.length > 500) return false;
    if (!hasMedia && trimmed.isEmpty) return false;
    if (hasMedia && mediaBytes.length > maxCommentMediaBytes) {
      debugPrint('[PostEngagementService] Comment media too large');
      return false;
    }

    String? mediaUrl;
    String? mediaType;
    if (hasMedia) {
      final mimeType = mediaMimeType ?? 'application/octet-stream';
      mediaType = mimeType.startsWith('video/') ? 'video' : 'image';
      final ext = _extensionForMimeType(mimeType, fileName: mediaFileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'post_comments_media/$visitorId/$timestamp.$ext';
      try {
        mediaUrl = await _mediaService.uploadBytes(
          path: path,
          bytes: mediaBytes,
          contentType: mimeType,
        );
      } catch (e) {
        debugPrint('[PostEngagementService] comment media upload failed: $e');
        return false;
      }
    }

    final comment = PostComment(
      postType: _postTypeForItem(item),
      postId: item.id,
      visitorId: visitorId,
      visitorName: visitorName,
      text: trimmed,
      createdAt: DateTime.now(),
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );

    try {
      await _firestore
          .collection(_commentsCollection)
          .add(comment.toFirestore());
      return true;
    } catch (e) {
      debugPrint('[PostEngagementService] addComment failed: $e');
      return false;
    }
  }

  /// Stream of comments for a post, newest first.
  Stream<List<PostComment>> commentsForPost({
    required ActivityFeedItem item,
    int limit = 50,
  }) {
    return _firestore
        .collection(_commentsCollection)
        .where('postType', isEqualTo: _postTypeForItem(item))
        .where('postId', isEqualTo: item.id)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(PostComment.fromFirestore)
            .toList(growable: false));
  }

  /// Delete a comment. Only the original author may delete their own
  /// comment (enforced both here and by Firestore security rules).
  Future<bool> deleteComment(PostComment comment) async {
    final visitorId = _currentVisitorId;
    if (visitorId == null || visitorId != comment.visitorId) return false;
    if (comment.id == null) return false;

    try {
      await _firestore
          .collection(_commentsCollection)
          .doc(comment.id)
          .delete();
      return true;
    } catch (e) {
      debugPrint('[PostEngagementService] deleteComment failed: $e');
      return false;
    }
  }

  String _postTypeForItem(ActivityFeedItem item) {
    switch (item.type) {
      case ActivityFeedType.review:
        return 'review';
      case ActivityFeedType.event:
        return 'event';
      case ActivityFeedType.business:
        return 'business';
      case ActivityFeedType.photo:
        return 'photo';
      case ActivityFeedType.all:
      case ActivityFeedType.trending:
      case ActivityFeedType.nearby:
      case ActivityFeedType.following:
      case ActivityFeedType.newest:
      case ActivityFeedType.popular:
        return 'post';
    }
  }

  String _extensionForMimeType(String mimeType, {String? fileName}) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/webm':
        return 'webm';
      case 'image/jpeg':
        return 'jpg';
    }
    final name = fileName?.trim() ?? '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return name.substring(dotIndex + 1).toLowerCase();
    }
    return 'bin';
  }

  /// Combines two streams into one, emitting whenever either input emits.
  Stream<R> _combineLatest2<T1, T2, R>(
    Stream<T1> stream1,
    Stream<T2> stream2,
    R Function(T1, T2) combiner,
  ) {
    T1? latest1;
    T2? latest2;
    var has1 = false;
    var has2 = false;

    final controller = StreamController<R>.broadcast();

    void emit() {
      if (has1 && has2 && !controller.isClosed) {
        controller.add(combiner(latest1 as T1, latest2 as T2));
      }
    }

    stream1.listen(
      (value) {
        latest1 = value;
        has1 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    stream2.listen(
      (value) {
        latest2 = value;
        has2 = true;
        emit();
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }
}
