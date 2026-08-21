import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String businessId;
  final String visitorId;
  final String visitorName;
  final String? visitorPhotoUrl; // Reviewer profile photo
  final int rating; // 1-5 stars
  final int buzzRating; // 1-5 buzz score
  final String comment;
  final List<String> photos; // Uploaded review photos
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isReported;
  final String? reportReason;
  final String reportedBy;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final int helpfulCount;
  final bool isFlagged;
  final bool visible;
  final String? reply;
  final DateTime? replyAt;
  final String? replyBy;

  Review({
    required this.id,
    required this.businessId,
    required this.visitorId,
    required this.visitorName,
    this.visitorPhotoUrl,
    required this.rating,
    this.buzzRating = 0,
    required this.comment,
    this.photos = const [],
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isReported = false,
    this.reportReason,
    this.reportedBy = '',
    this.severity = 'medium',
    this.helpfulCount = 0,
    this.isFlagged = false,
    this.visible = true,
    this.reply,
    this.replyAt,
    this.replyBy,
  });

  bool get isDeleted => deletedAt != null;

  // Convert Review to Firestore JSON
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'visitorId': visitorId,
      'visitorName': visitorName,
      if (visitorPhotoUrl != null) 'visitorPhotoUrl': visitorPhotoUrl,
      'rating': rating,
      'buzzRating': buzzRating,
      'comment': comment,
      if (photos.isNotEmpty) 'photos': photos,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'isReported': isReported,
      'reportReason': reportReason,
      'reportedBy': reportedBy,
      'severity': severity,
      'helpfulCount': helpfulCount,
      'isFlagged': isFlagged,
      'visible': visible,
      if (reply != null && reply!.isNotEmpty) 'reply': reply,
      if (replyAt != null) 'replyAt': replyAt,
      if (replyBy != null && replyBy!.isNotEmpty) 'replyBy': replyBy,
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
      visitorPhotoUrl: data['visitorPhotoUrl']?.toString(),
      rating: data['rating'] ?? 5,
      buzzRating: data['buzzRating'] ?? 0,
      comment: data['comment'] ?? '',
      photos: data['photos'] is List
          ? (data['photos'] as List).whereType<String>().toList()
          : [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      isReported: data['isReported'] ?? false,
      reportReason: data['reportReason'],
      reportedBy: data['reportedBy'] ?? '',
      severity: data['severity'] ?? 'medium',
      helpfulCount: data['helpfulCount'] ?? 0,
      isFlagged: data['isFlagged'] ?? false,
      visible: data['visible'] ?? !(data['isReported'] == true || data['isFlagged'] == true || data['deletedAt'] != null),
      reply: data['reply']?.toString(),
      replyAt: (data['replyAt'] as Timestamp?)?.toDate(),
      replyBy: data['replyBy']?.toString(),
    );
  }

  // Copy with method for updates
  Review copyWith({
    String? id,
    String? businessId,
    String? visitorId,
    String? visitorName,
    String? visitorPhotoUrl,
    int? rating,
    int? buzzRating,
    String? comment,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isReported,
    String? reportReason,
    String? reportedBy,
    String? severity,
    int? helpfulCount,
    bool? isFlagged,
    bool? visible,
    String? reply,
    DateTime? replyAt,
    String? replyBy,
  }) {
    return Review(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      visitorId: visitorId ?? this.visitorId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhotoUrl: visitorPhotoUrl ?? this.visitorPhotoUrl,
      rating: rating ?? this.rating,
      buzzRating: buzzRating ?? this.buzzRating,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isReported: isReported ?? this.isReported,
      reportReason: reportReason ?? this.reportReason,
      reportedBy: reportedBy ?? this.reportedBy,
      severity: severity ?? this.severity,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isFlagged: isFlagged ?? this.isFlagged,
      visible: visible ?? this.visible,
      reply: reply ?? this.reply,
      replyAt: replyAt ?? this.replyAt,
      replyBy: replyBy ?? this.replyBy,
    );
  }
}
