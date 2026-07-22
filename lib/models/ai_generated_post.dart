import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an AI-generated post.
enum AiPostStatus { draft, published }

/// Types of content the AI post assistant can generate.
enum AiPostType {
  promotion,
  menuItem,
  businessEvent,
  announcement,
  reviewHighlight;

  String get displayName {
    switch (this) {
      case AiPostType.promotion:
        return 'Promotion';
      case AiPostType.menuItem:
        return 'Menu Item';
      case AiPostType.businessEvent:
        return 'Business Event';
      case AiPostType.announcement:
        return 'Announcement';
      case AiPostType.reviewHighlight:
        return 'Review Highlight';
    }
  }

  static AiPostType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'promotion':
        return AiPostType.promotion;
      case 'menuitem':
      case 'menu_item':
      case 'menu item':
        return AiPostType.menuItem;
      case 'businessevent':
      case 'business_event':
      case 'business event':
        return AiPostType.businessEvent;
      case 'reviewhighlight':
      case 'review_highlight':
      case 'review highlight':
        return AiPostType.reviewHighlight;
      case 'announcement':
      default:
        return AiPostType.announcement;
    }
  }
}

/// An AI-generated marketing post saved as a draft or published by a business
/// owner.
class AiGeneratedPost {
  final String? id;
  final String businessId;
  final String ownerId;
  final AiPostType postType;
  final String title;
  final String description;
  final String? price;
  final String? discount;
  final DateTime? eventDate;
  final String? location;
  final String generatedContent;
  final AiPostStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiGeneratedPost({
    this.id,
    required this.businessId,
    required this.ownerId,
    required this.postType,
    required this.title,
    this.description = '',
    this.price,
    this.discount,
    this.eventDate,
    this.location,
    required this.generatedContent,
    this.status = AiPostStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'postType': postType.name,
      'title': title,
      'description': description,
      'price': price,
      'discount': discount,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
      'location': location,
      'generatedContent': generatedContent,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AiGeneratedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AiGeneratedPost(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      postType: AiPostType.fromString(data['postType'] as String? ?? ''),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] as String?,
      discount: data['discount'] as String?,
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      location: data['location'] as String?,
      generatedContent: data['generatedContent'] ?? '',
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static AiPostStatus _parseStatus(String? value) {
    return value == 'published' ? AiPostStatus.published : AiPostStatus.draft;
  }

  AiGeneratedPost copyWith({
    String? id,
    String? businessId,
    String? ownerId,
    AiPostType? postType,
    String? title,
    String? description,
    String? price,
    String? discount,
    DateTime? eventDate,
    String? location,
    String? generatedContent,
    AiPostStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiGeneratedPost(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      generatedContent: generatedContent ?? this.generatedContent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
