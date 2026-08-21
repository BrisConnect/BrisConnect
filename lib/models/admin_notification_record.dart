import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Types of platform-level notifications sent to admins.
enum AdminNotificationType {
  newBusiness,
  verificationRequest,
  reportedContent,
  paymentFailed,
  newSubscription,
  canceledSubscription,
  promotionApproval,
  eventApproval,
  unknown,
}

/// A notification sent to admin users about platform events such as new
/// business registrations, reported content, or subscription changes.
class AdminNotificationRecord {
  final String id;
  final String title;
  final String message;
  final AdminNotificationType type;
  final DateTime createdAt;
  final bool read;
  final String? relatedItemId;
  final String? relatedItemType;
  final String? actionRoute;
  final Map<String, dynamic> metadata;

  const AdminNotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.relatedItemId,
    this.relatedItemType,
    this.actionRoute,
    this.metadata = const {},
  });

  factory AdminNotificationRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return AdminNotificationRecord(
      id: doc.id,
      title: '${data['title'] ?? 'Notification'}'.trim(),
      message: '${data['message'] ?? ''}'.trim(),
      type: _parseType(data['type']),
      createdAt: createdAt,
      read: data['read'] == true,
      relatedItemId: data['relatedItemId']?.toString(),
      relatedItemType: data['relatedItemType']?.toString(),
      actionRoute: data['actionRoute']?.toString(),
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
      'read': read,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
      'actionRoute': actionRoute,
      'metadata': metadata,
    };
  }

  AdminNotificationRecord copyWith({
    bool? read,
  }) {
    return AdminNotificationRecord(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      read: read ?? this.read,
      relatedItemId: relatedItemId,
      relatedItemType: relatedItemType,
      actionRoute: actionRoute,
      metadata: metadata,
    );
  }

  static AdminNotificationType _parseType(dynamic value) {
    final name = '${value ?? 'unknown'}';
    switch (name) {
      case 'new_business':
      case 'newBusiness':
        return AdminNotificationType.newBusiness;
      case 'verification_request':
      case 'verificationRequest':
        return AdminNotificationType.verificationRequest;
      case 'reported_content':
      case 'reportedContent':
        return AdminNotificationType.reportedContent;
      case 'payment_failed':
      case 'paymentFailed':
        return AdminNotificationType.paymentFailed;
      case 'new_subscription':
      case 'newSubscription':
        return AdminNotificationType.newSubscription;
      case 'canceled_subscription':
      case 'canceledSubscription':
        return AdminNotificationType.canceledSubscription;
      case 'promotion_approval':
      case 'promotionApproval':
        return AdminNotificationType.promotionApproval;
      case 'event_approval':
      case 'eventApproval':
        return AdminNotificationType.eventApproval;
      default:
        return AdminNotificationType.unknown;
    }
  }
}

extension AdminNotificationTypeName on AdminNotificationType {
  String get name {
    switch (this) {
      case AdminNotificationType.newBusiness:
        return 'new_business';
      case AdminNotificationType.verificationRequest:
        return 'verification_request';
      case AdminNotificationType.reportedContent:
        return 'reported_content';
      case AdminNotificationType.paymentFailed:
        return 'payment_failed';
      case AdminNotificationType.newSubscription:
        return 'new_subscription';
      case AdminNotificationType.canceledSubscription:
        return 'canceled_subscription';
      case AdminNotificationType.promotionApproval:
        return 'promotion_approval';
      case AdminNotificationType.eventApproval:
        return 'event_approval';
      case AdminNotificationType.unknown:
        return 'unknown';
    }
  }

  String get displayLabel {
    switch (this) {
      case AdminNotificationType.newBusiness:
        return 'New business';
      case AdminNotificationType.verificationRequest:
        return 'Verification request';
      case AdminNotificationType.reportedContent:
        return 'Reported content';
      case AdminNotificationType.paymentFailed:
        return 'Payment issue';
      case AdminNotificationType.newSubscription:
        return 'New subscription';
      case AdminNotificationType.canceledSubscription:
        return 'Canceled subscription';
      case AdminNotificationType.promotionApproval:
        return 'Promotion approval';
      case AdminNotificationType.eventApproval:
        return 'Event approval';
      case AdminNotificationType.unknown:
        return 'Notification';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminNotificationType.newBusiness:
        return Icons.storefront_outlined;
      case AdminNotificationType.verificationRequest:
        return Icons.verified_outlined;
      case AdminNotificationType.reportedContent:
        return Icons.report_outlined;
      case AdminNotificationType.paymentFailed:
        return Icons.payment_outlined;
      case AdminNotificationType.newSubscription:
        return Icons.card_membership_outlined;
      case AdminNotificationType.canceledSubscription:
        return Icons.cancel_outlined;
      case AdminNotificationType.promotionApproval:
        return Icons.campaign_outlined;
      case AdminNotificationType.eventApproval:
        return Icons.event_outlined;
      case AdminNotificationType.unknown:
        return Icons.notifications_outlined;
    }
  }
}
