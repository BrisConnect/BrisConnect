import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessReview {
  final String id;
  final String businessId;
  final String userId;
  final String? userName;
  final double rating; // 1-5 stars
  final double buzzRating; // 1-5 buzz score
  final String comment;
  final DateTime createdAt;
  final int? helpfulCount;

  BusinessReview({
    required this.id,
    required this.businessId,
    required this.userId,
    this.userName,
    required this.rating,
    this.buzzRating = 0.0,
    required this.comment,
    required this.createdAt,
    this.helpfulCount,
  });

  factory BusinessReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessReview(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      buzzRating: (data['buzzRating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      helpfulCount: data['helpfulCount'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'buzzRating': buzzRating,
      'comment': comment,
      'createdAt': createdAt,
      'helpfulCount': helpfulCount,
    };
  }
}
