import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String businessId;
  final String visitorId;
  final String visitorName;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isReported;
  final String? reportReason;

  Review({
    required this.id,
    required this.businessId,
    required this.visitorId,
    required this.visitorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.isReported = false,
    this.reportReason,
  });

  // Convert Review to Firestore JSON
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'visitorId': visitorId,
      'visitorName': visitorName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isReported': isReported,
      'reportReason': reportReason,
    };
  }

  // Create Review from Firestore document
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      visitorId: data['visitorId'] ?? '',
      visitorName: data['visitorName'] ?? 'Anonymous',
      rating: data['rating'] ?? 5,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isReported: data['isReported'] ?? false,
      reportReason: data['reportReason'],
    );
  }

  // Copy with method for updates
  Review copyWith({
    String? id,
    String? businessId,
    String? visitorId,
    String? visitorName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isReported,
    String? reportReason,
  }) {
    return Review(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      visitorId: visitorId ?? this.visitorId,
      visitorName: visitorName ?? this.visitorName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isReported: isReported ?? this.isReported,
      reportReason: reportReason ?? this.reportReason,
    );
  }
}
