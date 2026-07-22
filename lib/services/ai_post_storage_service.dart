import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/models/ai_generated_post.dart';

/// Stores and retrieves AI-generated posts for business owners.
class AiPostStorageService {
  final FirebaseFirestore _firestore;

  AiPostStorageService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'ai_generated_posts';

  /// Saves an AI-generated post as a draft.
  Future<String> saveDraft(AiGeneratedPost post) async {
    return _save(post.copyWith(status: AiPostStatus.draft));
  }

  /// Publishes an AI-generated post.
  Future<String> publish(AiGeneratedPost post) async {
    return _save(post.copyWith(status: AiPostStatus.published));
  }

  Future<String> _save(AiGeneratedPost post) async {
    final now = DateTime.now();
    final data = post
        .copyWith(
          updatedAt: now,
          createdAt: post.createdAt,
        )
        .toFirestore();

    try {
      if (post.id != null && post.id!.isNotEmpty) {
        await _firestore.collection(_collection).doc(post.id).update(data);
        return post.id!;
      } else {
        final docRef = await _firestore.collection(_collection).add(data);
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to save AI post: $e');
    }
  }

  /// Retrieves a single AI-generated post by ID.
  Future<AiGeneratedPost?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (!doc.exists) return null;
      return AiGeneratedPost.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch AI post: $e');
    }
  }

  /// Stream of AI-generated posts for a business owner.
  Stream<List<AiGeneratedPost>> getPostsForOwner(String ownerId) {
    return _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AiGeneratedPost.fromFirestore(doc)).toList());
  }

  /// Deletes an AI-generated post.
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete AI post: $e');
    }
  }
}
