import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of push notifications sent to business owners.
enum OwnerNotificationType {
  verificationApproved,
  verificationRejected,
  verificationNeedsInfo,
  newReview,
  buzzMilestone,
  promotionApproved,
  promotionRejected,
  promotionPublished,
  promotionExpiring,
  promotionPerformance,
  profileEngagement,
  subscriptionSuccess,
  subscriptionRenewal,
  subscriptionRenewalSuccess,
  subscriptionPaymentFailed,
  subscriptionCancelled,
  adminMessage,
  reportedContent,
  unknown,
}

/// A notification stored for a business owner in
/// `local_users/{email}/notifications`.
class OwnerNotificationRecord {
  final String id;
  final String userId;
  final String? businessId;
  final String title;
  final String message;
  final OwnerNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedItemId;
  final String? relatedItemType;
  final String? actionRoute;
  final String? rawType;
  final String? postType;

  const OwnerNotificationRecord({
    required this.id,
    required this.userId,
    this.businessId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.relatedItemId,
    this.relatedItemType,
    this.actionRoute,
    this.rawType,
    this.postType,
  });

  factory OwnerNotificationRecord.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return OwnerNotificationRecord(
      id: doc.id,
      userId: '${data['userId'] ?? data['ownerId'] ?? ''}'.trim().toLowerCase(),
      businessId: data['businessId']?.toString(),
      title: '${data['title'] ?? 'Notification'}'.trim(),
      message: '${data['message'] ?? ''}'.trim(),
      type: _parseType(data['type']),
      createdAt: createdAt,
      isRead: data['isRead'] == true || data['read'] == true,
      relatedItemId: data['relatedItemId']?.toString(),
      relatedItemType: data['relatedItemType']?.toString(),
      actionRoute: data['actionRoute']?.toString(),
      rawType: data['type']?.toString(),
      postType: (data['data'] as Map?)?['postType']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessId': businessId,
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

  OwnerNotificationRecord copyWith({bool? isRead}) {
    return OwnerNotificationRecord(
      id: id,
      userId: userId,
      businessId: businessId,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedItemId: relatedItemId,
      relatedItemType: relatedItemType,
      actionRoute: actionRoute,
      rawType: rawType,
      postType: postType,
    );
  }

  static OwnerNotificationType _parseType(dynamic value) {
    final name = '${value ?? 'unknown'}';
    switch (name) {
      case 'verification_approved':
      case 'verificationApproved':
        return OwnerNotificationType.verificationApproved;
      case 'verification_rejected':
      case 'verificationRejected':
        return OwnerNotificationType.verificationRejected;
      case 'verification_needs_info':
      case 'verificationNeedsInfo':
        return OwnerNotificationType.verificationNeedsInfo;
      case 'new_review':
      case 'newReview':
        return OwnerNotificationType.newReview;
      case 'buzz_milestone':
      case 'buzzMilestone':
        return OwnerNotificationType.buzzMilestone;
      case 'promotion_approved':
      case 'promotionApproved':
        return OwnerNotificationType.promotionApproved;
      case 'promotion_rejected':
      case 'promotionRejected':
        return OwnerNotificationType.promotionRejected;
      case 'promotion_published':
      case 'promotionPublished':
        return OwnerNotificationType.promotionPublished;
      case 'promotion_expiring':
      case 'promotionExpiring':
        return OwnerNotificationType.promotionExpiring;
      case 'promotion_performance':
      case 'promotionPerformance':
        return OwnerNotificationType.promotionPerformance;
      case 'profile_engagement':
      case 'profileEngagement':
        return OwnerNotificationType.profileEngagement;
      case 'subscription_success':
      case 'subscriptionSuccess':
        return OwnerNotificationType.subscriptionSuccess;
      case 'subscription_renewal':
      case 'subscriptionRenewal':
        return OwnerNotificationType.subscriptionRenewal;
      case 'subscription_renewal_success':
      case 'subscriptionRenewalSuccess':
        return OwnerNotificationType.subscriptionRenewalSuccess;
      case 'subscription_payment_failed':
      case 'subscriptionPaymentFailed':
        return OwnerNotificationType.subscriptionPaymentFailed;
      case 'subscription_cancelled':
      case 'subscriptionCancelled':
        return OwnerNotificationType.subscriptionCancelled;
      case 'admin_message':
      case 'adminMessage':
        return OwnerNotificationType.adminMessage;
      case 'reported_content':
      case 'reportedContent':
        return OwnerNotificationType.reportedContent;
      default:
        return OwnerNotificationType.unknown;
    }
  }

  String get typeLabel {
    switch (type) {
      case OwnerNotificationType.verificationApproved:
        return 'Verified';
      case OwnerNotificationType.verificationRejected:
        return 'Verification';
      case OwnerNotificationType.verificationNeedsInfo:
        return 'Action required';
      case OwnerNotificationType.newReview:
        return 'Review';
      case OwnerNotificationType.buzzMilestone:
        return 'Buzz milestone';
      case OwnerNotificationType.promotionApproved:
        return 'Promotion approved';
      case OwnerNotificationType.promotionRejected:
        return 'Promotion';
      case OwnerNotificationType.promotionPublished:
        return 'Promotion live';
      case OwnerNotificationType.promotionExpiring:
        return 'Expiring soon';
      case OwnerNotificationType.promotionPerformance:
        return 'Promotion';
      case OwnerNotificationType.profileEngagement:
        return 'Engagement';
      case OwnerNotificationType.subscriptionSuccess:
      case OwnerNotificationType.subscriptionRenewal:
      case OwnerNotificationType.subscriptionRenewalSuccess:
      case OwnerNotificationType.subscriptionPaymentFailed:
      case OwnerNotificationType.subscriptionCancelled:
        return 'Subscription';
      case OwnerNotificationType.adminMessage:
        return 'Admin';
      case OwnerNotificationType.reportedContent:
        return 'Reported';
      case OwnerNotificationType.unknown:
        return 'Notification';
    }
  }
}
