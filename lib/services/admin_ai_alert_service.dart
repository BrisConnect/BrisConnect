import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/admin_ai_alert_record.dart';
import 'package:brisconnect/services/admin_dashboard_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/services/notification_health_service.dart';
import 'package:brisconnect/services/google_listing_monitoring_service.dart';

/// Service for generating AI-powered platform insights and alerts.
///
/// This service monitors real BrisConnect platform metrics and generates alerts
/// based on meaningful changes and anomalies. All data is sourced from existing
/// services; no data is fabricated.
///
/// Alert generation uses configurable thresholds to avoid alert fatigue and
/// deduplicates repeated alerts about the same underlying condition.
class AdminAiAlertService {
  final FirebaseFirestore _firestore;
  final AdminDashboardService _dashboardService;
  final ReportEventService _eventReportService;
  final NotificationHealthService _notificationHealthService;
  final GoogleListingMonitoringService _googleMonitoringService;

  static const String _alertsCollection = 'admin_ai_alerts';
  static const Duration _deduplicationWindow = Duration(hours: 6);
  
  // Threshold configs - adjust these to tune alert sensitivity
  static const int _reportVolumeThreshold = 15;        // 15+ reports in a time window
  static const int _businessRegistrationThreshold = 10; // 10+ businesses registered

  AdminAiAlertService({
    FirebaseFirestore? firestore,
    AdminDashboardService? dashboardService,
    ReportEventService? eventReportService,
    NotificationHealthService? notificationHealthService,
    GoogleListingMonitoringService? googleMonitoringService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _dashboardService = dashboardService ?? AdminDashboardService(),
        _eventReportService = eventReportService ?? ReportEventService(),
        _notificationHealthService = notificationHealthService ?? NotificationHealthService(),
        _googleMonitoringService = googleMonitoringService ?? GoogleListingMonitoringService();

  /// Stream of active (non-dismissed) AI alerts
  Stream<List<AdminAiAlertRecord>> watchActiveAlerts({int limit = 50}) {
    return _firestore
        .collection(_alertsCollection)
        .where('dismissed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminAiAlertRecord.fromDoc(doc))
            .toList());
  }

  /// Stream of unread AI alerts
  Stream<List<AdminAiAlertRecord>> watchUnreadAlerts({int limit = 50}) {
    return _firestore
        .collection(_alertsCollection)
        .where('read', isEqualTo: false)
        .where('dismissed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminAiAlertRecord.fromDoc(doc))
            .toList());
  }

  /// Stream of unread alert count
  Stream<int> watchUnreadAlertCount() {
    return _firestore
        .collection(_alertsCollection)
        .where('read', isEqualTo: false)
        .where('dismissed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark an alert as read
  Future<void> markAlertAsRead(String alertId) async {
    try {
      await _firestore
          .collection(_alertsCollection)
          .doc(alertId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdminAiAlertService] markAlertAsRead failed: $e');
    }
  }

  /// Dismiss an alert (remove from active list but keep in history)
  Future<void> dismissAlert(String alertId) async {
    try {
      await _firestore
          .collection(_alertsCollection)
          .doc(alertId)
          .update({
        'dismissed': true,
        'dismissedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdminAiAlertService] dismissAlert failed: $e');
    }
  }

  /// Delete an alert completely
  Future<void> deleteAlert(String alertId) async {
    try {
      await _firestore.collection(_alertsCollection).doc(alertId).delete();
    } catch (e) {
      debugPrint('[AdminAiAlertService] deleteAlert failed: $e');
    }
  }

  /// Check for notification health issues and generate critical alerts if needed
  Future<void> checkNotificationHealth() async {
    try {
      final health = await _notificationHealthService.checkHealth();
      
      // Check if FCM or Firestore are unreachable
      if (!health.firestoreReachable || !health.fcmReachable) {
        await _createAlert(
          severity: AiAlertSeverity.critical,
          title: 'Notification Service Unavailable',
          explanation: health.message ?? 'Platform notification services are experiencing issues. '
              'Business owners may not receive important updates.',
          alertReason: 'Firestore: ${health.firestoreReachable ? "OK" : "UNAVAILABLE"}, '
              'FCM: ${health.fcmReachable ? "OK" : "UNAVAILABLE"}',
          metrics: {
            'status': health.status,
            'latencyMs': health.latencyMs,
            'timestamp': DateTime.now().toIso8601String(),
          },
          actionRoute: '/admin/notifications',
          recommendations: [
            'Check Cloud Function logs for errors',
            'Verify Firebase configuration',
            'Ensure FCM and Firestore quotas are not exceeded',
          ],
          deduplicationKey: 'notification_health_critical',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkNotificationHealth failed: $e');
    }
  }

  /// Check for high report volumes
  Future<void> checkReportVolumes() async {
    try {
      final eventReports = await _eventReportService.watchPendingReports().first;
      final reportCount = eventReports.length;

      if (reportCount >= _reportVolumeThreshold) {
        final severity = reportCount >= 30 ? AiAlertSeverity.critical : AiAlertSeverity.attention;
        await _createAlert(
          severity: severity,
          title: severity == AiAlertSeverity.critical 
              ? 'High Report Volume - Urgent Review Needed'
              : 'Elevated Report Volume',
          explanation: 'Platform has $reportCount pending event reports. '
              'This may indicate problematic events or platform spam.',
          alertReason: '$reportCount reports are pending admin review. '
              'Recent spike suggests increased user reports.',
          metrics: {
            'pendingReports': reportCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
          actionRoute: '/admin/reports',
          relatedItemType: 'reports',
          recommendations: [
            'Review pending reports in the Reports dashboard',
            'Check for patterns in reported events',
            'Consider temporary action if abuse is detected',
          ],
          deduplicationKey: 'report_volume_$reportCount',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkReportVolumes failed: $e');
    }
  }

  /// Check for unusual business registration patterns
  Future<void> checkBusinessRegistrations() async {
    try {
      // This would ideally use daily registration data
      // For now, we check total pending businesses
      final pendingStream = _dashboardService.pendingLocalUsersCount();
      final pendingCount = await pendingStream.first;

      if (pendingCount >= _businessRegistrationThreshold) {
        await _createAlert(
          severity: AiAlertSeverity.attention,
          title: 'High Volume of Pending Business Approvals',
          explanation: 'There are $pendingCount pending business registrations awaiting review. '
              'Review and approve legitimate businesses to keep them engaged.',
          alertReason: '$pendingCount businesses are waiting for admin verification.',
          metrics: {
            'pendingBusinesses': pendingCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
          actionRoute: '/admin/users',
          relatedItemType: 'businesses',
          recommendations: [
            'Review pending business applications',
            'Prioritize high-engagement applicants',
            'Provide feedback to rejected applicants',
          ],
          deduplicationKey: 'pending_businesses_$pendingCount',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkBusinessRegistrations failed: $e');
    }
  }

  /// Check for positive engagement trends
  Future<void> checkPositiveTrends() async {
    try {
      final trendStream = _dashboardService.reviewsTrend();
      final trend = await trendStream.first;
      
      if (trend.current > trend.previous) {
        final increase = trend.current - trend.previous;
        if (increase >= 5) {
          await _createAlert(
            severity: AiAlertSeverity.positive,
            title: 'Increased Review Activity',
            explanation: 'Platform reviews have increased by $increase compared to the previous period. '
                'This indicates growing user engagement!',
            alertReason: 'Review count: ${trend.current} (was ${trend.previous})',
            metrics: {
              'currentReviews': trend.current,
              'previousReviews': trend.previous,
              'increase': increase,
              'timestamp': DateTime.now().toIso8601String(),
            },
            actionRoute: '/admin/analytics',
            recommendations: [
              'Monitor engagement trends',
              'Encourage more reviews from satisfied users',
              'Feature top-reviewed businesses',
            ],
            deduplicationKey: 'positive_review_trend_$increase',
          );
        }
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkPositiveTrends failed: $e');
    }
  }

  /// Check for critical changes in Google business listings
  Future<void> checkGoogleListingChanges() async {
    try {
      // Get unreviewed critical alerts first
      final criticalRecords = await _googleMonitoringService.getCriticalCount();
      
      if (criticalRecords > 0) {
        await _createAlert(
          severity: AiAlertSeverity.critical,
          title: 'Critical: Google Listing Changes Detected',
          explanation: '$criticalRecords business(es) have critical changes on Google. '
              'This may include permanent closures or significant business info changes.',
          alertReason: 'Google Places monitoring detected $criticalRecords critical changes requiring immediate review.',
          metrics: {
            'criticalChanges': criticalRecords,
            'timestamp': DateTime.now().toIso8601String(),
          },
          actionRoute: '/admin/google-listings',
          relatedItemType: 'google_listings',
          recommendations: [
            'Review critical business listings immediately',
            'Accept or reject Google changes',
            'Contact businesses if significant data differences detected',
          ],
          deduplicationKey: 'google_critical_changes_$criticalRecords',
        );
      }

      // Check for unreviewed mismatches
      final unreviewedCount = await _googleMonitoringService.getUnreviewedCount();
      
      if (unreviewedCount > 0 && unreviewedCount < 5) {
        // Only alert for small batches to avoid alert fatigue
        await _createAlert(
          severity: AiAlertSeverity.attention,
          title: 'Google Listing Changes Pending Review',
          explanation: '$unreviewedCount business(es) have differences between '
              'BrisConnect and Google listing data.',
          alertReason: '$unreviewedCount monitoring records are pending admin review.',
          metrics: {
            'unreviewedRecords': unreviewedCount,
            'timestamp': DateTime.now().toIso8601String(),
          },
          actionRoute: '/admin/google-listings',
          relatedItemType: 'google_listings',
          recommendations: [
            'Review pending Google listing comparisons',
            'Update outdated business information',
            'Verify address and contact changes',
          ],
          deduplicationKey: 'google_unreviewed_$unreviewedCount',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkGoogleListingChanges failed: $e');
    }
  }

  /// Internal helper to create an alert with deduplication
  Future<void> _createAlert({
    required AiAlertSeverity severity,
    required String title,
    required String explanation,
    required String alertReason,
    required Map<String, dynamic> metrics,
    required String? actionRoute,
    String? relatedItemType,
    List<String> recommendations = const [],
    required String deduplicationKey,
  }) async {
    try {
      // Check for recent duplicate alert
      final recentDuplicates = await _firestore
          .collection(_alertsCollection)
          .where('deduplicationKey', isEqualTo: deduplicationKey)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(_deduplicationWindow)))
          .get();

      if (recentDuplicates.docs.isNotEmpty) {
        // Update duplicate count instead of creating new alert
        final doc = recentDuplicates.docs.first;
        final currentCount = (doc['duplicateCount'] as int?) ?? 1;
        await doc.reference.update({
          'duplicateCount': currentCount + 1,
          'firstSeenAt': doc['firstSeenAt'] ?? FieldValue.serverTimestamp(),
        });
        debugPrint('[AdminAiAlertService] Deduplicated alert: $deduplicationKey');
        return;
      }

      // Create new alert
      final alert = AdminAiAlertRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        severity: severity,
        title: title,
        explanation: explanation,
        createdAt: DateTime.now(),
        alertReason: alertReason,
        metrics: metrics,
        actionRoute: actionRoute,
        relatedItemType: relatedItemType,
        recommendations: recommendations,
        duplicateCount: 1,
      );

      await _firestore
          .collection(_alertsCollection)
          .doc(alert.id)
          .set({
        ...alert.toMap(),
        'deduplicationKey': deduplicationKey,
      });

      debugPrint('[AdminAiAlertService] Created alert: ${alert.title}');
    } catch (e) {
      debugPrint('[AdminAiAlertService] _createAlert failed: $e');
    }
  }

  /// Check for critical pending approvals buildup
  Future<void> checkPendingApprovals() async {
    try {
      final pendingCount = await _dashboardService.pendingLocalUsersCount().first;
      
      if (pendingCount > 20) {
        // Critical: Too many pending approvals
        await _createAlert(
          severity: AiAlertSeverity.critical,
          title: 'High Pending Business Approvals',
          explanation: '$pendingCount businesses are awaiting approval. '
              'This backlog may impact new business growth.',
          alertReason: 'Pending approvals count ($pendingCount) exceeds critical threshold (20)',
          metrics: {'pendingApprovals': pendingCount},
          actionRoute: '/admin/businesses',
          relatedItemType: 'pending_approvals',
          recommendations: [
            'Review and approve pending businesses',
            'Set approval review schedule',
            'Contact business owners with status updates',
          ],
          deduplicationKey: 'pending_approvals_critical_$pendingCount',
        );
      } else if (pendingCount > 10) {
        // Attention: Moderate pending approvals
        await _createAlert(
          severity: AiAlertSeverity.attention,
          title: 'Pending Business Approvals Building Up',
          explanation: '$pendingCount businesses are awaiting approval.',
          alertReason: 'Pending approvals ($pendingCount) approaching capacity',
          metrics: {'pendingApprovals': pendingCount},
          actionRoute: '/admin/businesses',
          relatedItemType: 'pending_approvals',
          recommendations: [
            'Process pending business approvals',
            'Prioritize high-quality submissions',
          ],
          deduplicationKey: 'pending_approvals_attention_$pendingCount',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkPendingApprovals failed: $e');
    }
  }

  /// Check for critical pending reports buildup
  Future<void> checkPendingReports() async {
    try {
      final pendingCount = await _dashboardService.pendingReviewReportsCount().first;
      
      if (pendingCount > 30) {
        // Critical: Too many pending reports
        await _createAlert(
          severity: AiAlertSeverity.critical,
          title: 'Critical: High Volume of Pending Reports',
          explanation: '$pendingCount reports require admin action. '
              'Platform health may be impacted by unaddressed issues.',
          alertReason: 'Pending reports ($pendingCount) exceeds critical threshold',
          metrics: {'pendingReports': pendingCount},
          actionRoute: '/admin/reports',
          relatedItemType: 'pending_reports',
          recommendations: [
            'Review critical reports immediately',
            'Take action on high-priority cases',
            'Communicate decisions to reporters',
          ],
          deduplicationKey: 'pending_reports_critical_$pendingCount',
        );
      } else if (pendingCount > 15) {
        // Attention: Moderate pending reports
        await _createAlert(
          severity: AiAlertSeverity.attention,
          title: 'Reports Pending Review',
          explanation: '$pendingCount community reports are awaiting admin review.',
          alertReason: 'Pending reports backlog is growing',
          metrics: {'pendingReports': pendingCount},
          actionRoute: '/admin/reports',
          relatedItemType: 'pending_reports',
          recommendations: [
            'Process pending community reports',
            'Prioritize urgent issues',
          ],
          deduplicationKey: 'pending_reports_attention_$pendingCount',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkPendingReports failed: $e');
    }
  }

  /// Check monthly revenue trends
  Future<void> checkRevenueTrends() async {
    try {
      final currentRevenue = await _dashboardService.monthlyRevenueCents().first;
      
      // Compare with historical data to detect drops
      // For now, alert on zero revenue
      if (currentRevenue == 0) {
        await _createAlert(
          severity: AiAlertSeverity.attention,
          title: 'No Monthly Revenue Detected',
          explanation: 'Current month shows \$0 revenue. '
              'Check subscription processing and payment systems.',
          alertReason: 'Monthly revenue is \$0.00',
          metrics: {'monthlyRevenueCents': currentRevenue},
          actionRoute: '/admin/subscriptions',
          relatedItemType: 'revenue',
          recommendations: [
            'Verify payment processing is active',
            'Check subscription health',
            'Investigate customer payment issues',
          ],
          deduplicationKey: 'revenue_zero_this_month',
        );
      } else if (currentRevenue > 0) {
        // Insight alert for healthy revenue
        await _createAlert(
          severity: AiAlertSeverity.insight,
          title: 'Monthly Revenue Tracking',
          explanation: 'Current month revenue: \$${(currentRevenue / 100).toStringAsFixed(2)}. '
              'Keep monitoring subscription trends.',
          alertReason: 'Monthly revenue update',
          metrics: {'monthlyRevenueCents': currentRevenue},
          actionRoute: '/admin/subscriptions',
          relatedItemType: 'revenue',
          recommendations: [
            'Monitor subscription churn rate',
            'Identify high-value customers',
            'Plan retention strategies',
          ],
          deduplicationKey: 'revenue_monthly_update',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkRevenueTrends failed: $e');
    }
  }

  /// Check user and business growth metrics
  Future<void> checkGrowthMetrics() async {
    try {
      final totalUsers = await _dashboardService.totalUsersCount().first;
      final totalBusinesses = await _dashboardService.totalBusinessesCount().first;
      final totalEvents = await _dashboardService.totalEventsCount().first;
      
      // Alert on platform health
      if (totalUsers > 100) {
        await _createAlert(
          severity: AiAlertSeverity.insight,
          title: 'Platform Growth Update',
          explanation: 'Platform metrics: $totalUsers users, $totalBusinesses businesses, $totalEvents events. '
              'Growth tracking enabled.',
          alertReason: 'Platform metrics snapshot',
          metrics: {
            'totalUsers': totalUsers,
            'totalBusinesses': totalBusinesses,
            'totalEvents': totalEvents,
          },
          actionRoute: '/admin/dashboard',
          relatedItemType: 'platform_health',
          recommendations: [
            'Monitor user engagement trends',
            'Encourage business profile completion',
            'Plan feature releases based on usage',
          ],
          deduplicationKey: 'growth_metrics_daily',
        );
      }
    } catch (e) {
      debugPrint('[AdminAiAlertService] checkGrowthMetrics failed: $e');
    }
  }

  /// Run all alert checks (should be called periodically, e.g., on dashboard load)
  /// Note: Google listing checks run in background to avoid blocking dashboard load
  Future<void> runAllChecks() async {
    await Future.wait([
      checkNotificationHealth(),
      checkReportVolumes(),
      checkBusinessRegistrations(),
      checkPositiveTrends(),
      checkPendingApprovals(),
      checkPendingReports(),
      checkRevenueTrends(),
      checkGrowthMetrics(),
    ]);
    // Run Google listing checks in background (non-blocking)
    unawaited(checkGoogleListingChanges());
  }
}
