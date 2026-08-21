import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of push notifications a visitor can receive.
enum VisitorNotificationType {
  nearbyPromotion,
  savedBusinessUpdate,
  trendingBusiness,
  promotionExpiryReminder,
  newBusinessDiscovery,
  personalisedRecommendation,
  unknown,
}

/// A platform notification stored for a visitor in
/// `visitor_users/{email}/notifications`.
class VisitorNotificationRecord {
  final String id;
  final String userEmail;
  final String title;
  final String message;
  final VisitorNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedItemId;
  final String? relatedItemType;
  final String? actionRoute;

  const VisitorNotificationRecord({
    required this.id,
    required this.userEmail,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.relatedItemId,
    this.relatedItemType,
    this.actionRoute,
  });

  factory VisitorNotificationRecord.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return VisitorNotificationRecord(
      id: doc.id,
      userEmail: '${data['userEmail'] ?? ''}'.trim().toLowerCase(),
      title: '${data['title'] ?? 'Notification'}'.trim(),
      message: '${data['message'] ?? ''}'.trim(),
      type: _parseType(data['type']),
      createdAt: createdAt,
      isRead: data['isRead'] == true || data['read'] == true,
      relatedItemId: data['relatedItemId']?.toString(),
      relatedItemType: data['relatedItemType']?.toString(),
      actionRoute: data['actionRoute']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userEmail': userEmail,
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
      'actionRoute': actionRoute,
    };
  }

  VisitorNotificationRecord copyWith({
    bool? isRead,
  }) {
    return VisitorNotificationRecord(
      id: id,
      userEmail: userEmail,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedItemId: relatedItemId,
      relatedItemType: relatedItemType,
      actionRoute: actionRoute,
    );
  }

  static VisitorNotificationType _parseType(dynamic value) {
    final name = '${value ?? 'unknown'}';
    switch (name) {
      case 'nearby_promotion':
      case 'nearbyPromotion':
        return VisitorNotificationType.nearbyPromotion;
      case 'saved_business_update':
      case 'savedBusinessUpdate':
        return VisitorNotificationType.savedBusinessUpdate;
      case 'trending_business':
      case 'trendingBusiness':
        return VisitorNotificationType.trendingBusiness;
      case 'promotion_expiry_reminder':
      case 'promotionExpiryReminder':
        return VisitorNotificationType.promotionExpiryReminder;
      case 'new_business_discovery':
      case 'newBusinessDiscovery':
        return VisitorNotificationType.newBusinessDiscovery;
      case 'personalised_recommendation':
      case 'personalisedRecommendation':
        return VisitorNotificationType.personalisedRecommendation;
      default:
        return VisitorNotificationType.unknown;
    }
  }

  /// Human-readable label for the notification type.
  String get typeLabel {
    switch (type) {
      case VisitorNotificationType.nearbyPromotion:
        return 'Nearby promotion';
      case VisitorNotificationType.savedBusinessUpdate:
        return 'Saved business';
      case VisitorNotificationType.trendingBusiness:
        return 'Trending';
      case VisitorNotificationType.promotionExpiryReminder:
        return 'Expiring soon';
      case VisitorNotificationType.newBusinessDiscovery:
        return 'New discovery';
      case VisitorNotificationType.personalisedRecommendation:
        return 'For you';
      case VisitorNotificationType.unknown:
        return 'Notification';
    }
  }
}
