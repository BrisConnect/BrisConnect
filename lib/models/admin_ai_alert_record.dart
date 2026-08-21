import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Severity levels for AI-generated platform insights.
enum AiAlertSeverity {
  insight,    // Blue - Informational
  positive,   // Green - Good news
  attention,  // Orange - Needs review
  critical,   // Red - Urgent
}

/// Actions that an admin can take on an AI alert.
enum AiAlertAction {
  viewAnalytics,
  viewReports,
  viewBusiness,
  viewInsights,
  markAsRead,
  dismiss,
}

/// An AI-generated alert based on real BrisConnect platform data.
/// 
/// AI alerts use real metrics from:
/// - AdminDashboardService (user/business/engagement trends)
/// - ReportEventService & PhotoReportService (report volumes)
/// - NotificationHealthService (notification delivery health)
/// - Subscription & revenue metrics from dashboard
///
/// AI does NOT perform destructive actions. All actions navigate to existing
/// admin screens where an admin makes the final decision.
class AdminAiAlertRecord {
  final String id;
  final AiAlertSeverity severity;
  final String title;
  final String explanation;
  final DateTime createdAt;
  final bool read;
  final bool dismissed;
  
  /// The route to navigate to when an action is clicked (e.g., '/admin/reports')
  final String? actionRoute;
  
  /// ID of related item (e.g., business ID, report ID)
  final String? relatedItemId;
  
  /// Type of related item (e.g., 'business', 'report', 'event')
  final String? relatedItemType;
  
  /// Reason alert was generated - used for "View Details"
  final String? alertReason;
  
  /// Metrics that triggered this alert
  final Map<String, dynamic> metrics;
  
  /// Recommended actions
  final List<String> recommendations;
  
  /// Timestamp when alert was first seen as duplicate
  final DateTime? firstSeenAt;
  
  /// Count of times this alert has been generated (for deduplication)
  final int duplicateCount;

  const AdminAiAlertRecord({
    required this.id,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.createdAt,
    this.read = false,
    this.dismissed = false,
    this.actionRoute,
    this.relatedItemId,
    this.relatedItemType,
    this.alertReason,
    this.metrics = const {},
    this.recommendations = const [],
    this.firstSeenAt,
    this.duplicateCount = 1,
  });

  /// Parse from Firestore document
  factory AdminAiAlertRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final firstSeenAtRaw = data['firstSeenAt'];
    
    final DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.now();
    }
    
    final DateTime? firstSeenAt;
    if (firstSeenAtRaw is Timestamp) {
      firstSeenAt = firstSeenAtRaw.toDate();
    } else {
      firstSeenAt = null;
    }

    return AdminAiAlertRecord(
      id: doc.id,
      severity: _parseSeverity(data['severity']),
      title: '${data['title'] ?? 'AI Alert'}'.trim(),
      explanation: '${data['explanation'] ?? ''}'.trim(),
      createdAt: createdAt,
      read: data['read'] == true,
      dismissed: data['dismissed'] == true,
      actionRoute: data['actionRoute']?.toString(),
      relatedItemId: data['relatedItemId']?.toString(),
      relatedItemType: data['relatedItemType']?.toString(),
      alertReason: data['alertReason']?.toString(),
      metrics: data['metrics'] is Map 
          ? Map<String, dynamic>.from(data['metrics'] as Map)
          : const {},
      recommendations: data['recommendations'] is List
          ? List<String>.from((data['recommendations'] as List).map((r) => r.toString()))
          : const [],
      firstSeenAt: firstSeenAt,
      duplicateCount: (data['duplicateCount'] as int?) ?? 1,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'severity': severity.name,
      'title': title,
      'explanation': explanation,
      'createdAt': FieldValue.serverTimestamp(),
      'read': read,
      'dismissed': dismissed,
      'actionRoute': actionRoute,
      'relatedItemId': relatedItemId,
      'relatedItemType': relatedItemType,
      'alertReason': alertReason,
      'metrics': metrics,
      'recommendations': recommendations,
      'firstSeenAt': firstSeenAt != null ? Timestamp.fromDate(firstSeenAt!) : null,
      'duplicateCount': duplicateCount,
    };
  }

  AdminAiAlertRecord copyWith({
    bool? read,
    bool? dismissed,
    int? duplicateCount,
    DateTime? firstSeenAt,
  }) {
    return AdminAiAlertRecord(
      id: id,
      severity: severity,
      title: title,
      explanation: explanation,
      createdAt: createdAt,
      read: read ?? this.read,
      dismissed: dismissed ?? this.dismissed,
      actionRoute: actionRoute,
      relatedItemId: relatedItemId,
      relatedItemType: relatedItemType,
      alertReason: alertReason,
      metrics: metrics,
      recommendations: recommendations,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      duplicateCount: duplicateCount ?? this.duplicateCount,
    );
  }

  static AiAlertSeverity _parseSeverity(dynamic value) {
    final name = '${value ?? 'insight'}'.toLowerCase();
    switch (name) {
      case 'insight':
        return AiAlertSeverity.insight;
      case 'positive':
        return AiAlertSeverity.positive;
      case 'attention':
        return AiAlertSeverity.attention;
      case 'critical':
        return AiAlertSeverity.critical;
      default:
        return AiAlertSeverity.insight;
    }
  }
}

/// Display colors for each severity level
extension AiAlertSeverityColor on AiAlertSeverity {
  Color get color {
    switch (this) {
      case AiAlertSeverity.insight:
        return const Color(0xFF2FA8FF); // Blue
      case AiAlertSeverity.positive:
        return const Color(0xFF10B981); // Green
      case AiAlertSeverity.attention:
        return const Color(0xFFFF7A29); // Orange
      case AiAlertSeverity.critical:
        return const Color(0xFFFF5D5D); // Red
    }
  }

  String get label {
    switch (this) {
      case AiAlertSeverity.insight:
        return 'Insight';
      case AiAlertSeverity.positive:
        return 'Positive';
      case AiAlertSeverity.attention:
        return 'Attention';
      case AiAlertSeverity.critical:
        return 'Critical';
    }
  }

  IconData get icon {
    switch (this) {
      case AiAlertSeverity.insight:
        return Icons.lightbulb_outlined;
      case AiAlertSeverity.positive:
        return Icons.trending_up_rounded;
      case AiAlertSeverity.attention:
        return Icons.warning_rounded;
      case AiAlertSeverity.critical:
        return Icons.error_rounded;
    }
  }
}
