import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/moderation_audit_service.dart';
import 'package:brisconnect/services/moderation_notification_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Performance / SLA tests for the admin report-review workflow.
///
/// Acceptance criteria referenced:
/// - Admin report list loads within 3 seconds.
/// - Moderation status updates within 5 seconds.
/// - Notification delivery success rate >= 99%.

class _FastReportEventService implements ReportEventService {
  _FastReportEventService({this.delay = Duration.zero});

  final Duration delay;

  @override
  Future<EventReport?> getReportById(String id) async {
    await Future.delayed(delay);
    return EventReport(
      id: id,
      eventId: 'event-1',
      visitorEmail: 'reporter@example.com',
      reason: 'spam',
      status: 'pending',
      severity: 'high',
      createdAt: DateTime(2025, 1, 1),
    );
  }

  @override
  Future<void> updateReportStatus(String id, String status) async {
    await Future.delayed(delay);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FastAuditService implements ModerationAuditService {
  @override
  Future<String> logAction({
    required String adminEmail,
    required ModeratedContentType contentType,
    required String contentId,
    String? contentOwnerId,
    required ModerationDecision decision,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    return 'audit-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingNotificationService implements ModerationNotificationService {
  int resolvedCount = 0;
  int failureCount = 0;

  @override
  Future<void> notifyReportResolved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required dynamic decision,
  }) async {
    resolvedCount++;
  }

  @override
  Future<void> notifyContentRemoved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Moderation SLA', () {
    test('moderateEventReport completes within 5 seconds', () async {
      final service = AdminModerationService(
        reportEventService: _FastReportEventService(),
        auditService: _FastAuditService(),
        notificationService: _CountingNotificationService(),
      );

      final stopwatch = Stopwatch()..start();
      await service.moderateEventReport(
        reportId: 'report-1',
        decision: ModerationDecision.delete,
        adminEmail: 'admin@example.com',
        reason: 'Spam',
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('reporter notification delivery success rate is >= 99%', () async {
      final notificationService = _CountingNotificationService();
      final service = AdminModerationService(
        reportEventService: _FastReportEventService(),
        auditService: _FastAuditService(),
        notificationService: notificationService,
      );

      const totalReports = 100;
      for (var i = 0; i < totalReports; i++) {
        await service.moderateEventReport(
          reportId: 'report-$i',
          decision: ModerationDecision.dismiss,
          adminEmail: 'admin@example.com',
          reason: 'No violation',
        );
      }

      final totalAttempts =
          notificationService.resolvedCount + notificationService.failureCount;
      expect(totalAttempts, totalReports);

      final successRate = notificationService.resolvedCount / totalAttempts;
      expect(successRate, greaterThanOrEqualTo(0.99));
    });
  });
}
