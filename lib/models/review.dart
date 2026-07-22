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
  final DateTime? deletedAt;
  final bool isReported;
  final String? reportReason;
  final int helpfulCount;
  final bool isFlagged;
  final bool visible;

  Review({
    required this.id,
    required this.businessId,
    required this.visitorId,
    required this.visitorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isReported = false,
    this.reportReason,
    this.helpfulCount = 0,
    this.isFlagged = false,
    this.visible = true,
  });

  bool get isDeleted => deletedAt != null;

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
      'deletedAt': deletedAt,
      'isReported': isReported,
      'reportReason': reportReason,
      'helpfulCount': helpfulCount,
      'isFlagged': isFlagged,
      'visible': visible,
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
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      isReported: data['isReported'] ?? false,
      reportReason: data['reportReason'],
      helpfulCount: data['helpfulCount'] ?? 0,
      isFlagged: data['isFlagged'] ?? false,
      visible: data['visible'] ?? !(data['isReported'] == true || data['isFlagged'] == true || data['deletedAt'] != null),
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
    DateTime? deletedAt,
    bool? isReported,
    String? reportReason,
    int? helpfulCount,
    bool? isFlagged,
    bool? visible,
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
      deletedAt: deletedAt ?? this.deletedAt,
      isReported: isReported ?? this.isReported,
      reportReason: reportReason ?? this.reportReason,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isFlagged: isFlagged ?? this.isFlagged,
      visible: visible ?? this.visible,
    );
  }
}
