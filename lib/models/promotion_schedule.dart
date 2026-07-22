import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a scheduled promotion.
enum PromotionStatus { draft, scheduled, active, expired, cancelled }

/// A promotion scheduled by a business owner.
class PromotionSchedule {
  final String? id;
  final String businessId;
  final String ownerId;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final DateTime? endAt;
  final PromotionStatus status;
  final DateTime createdAt;

  const PromotionSchedule({
    this.id,
    required this.businessId,
    required this.ownerId,
    required this.title,
    this.description = '',
    required this.scheduledAt,
    this.endAt,
    this.status = PromotionStatus.draft,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PromotionSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotionSchedule(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  static PromotionStatus _parseStatus(String? value) {
    switch (value) {
      case 'scheduled':
        return PromotionStatus.scheduled;
      case 'active':
        return PromotionStatus.active;
      case 'expired':
        return PromotionStatus.expired;
      case 'cancelled':
        return PromotionStatus.cancelled;
      case 'draft':
      default:
        return PromotionStatus.draft;
    }
  }

  PromotionSchedule copyWith({
    String? id,
    String? businessId,
    String? ownerId,
    String? title,
    String? description,
    DateTime? scheduledAt,
    DateTime? endAt,
    PromotionStatus? status,
    DateTime? createdAt,
  }) {
    return PromotionSchedule(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
