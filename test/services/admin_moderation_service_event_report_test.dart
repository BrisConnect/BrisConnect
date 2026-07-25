import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/moderation_audit_service.dart';
import 'package:brisconnect/services/moderation_notification_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAuditService implements ModerationAuditService {
  final List<_LogCall> calls = [];

  @override
  Future<void> logAction({
    required String adminEmail,
    required dynamic contentType,
    required String contentId,
    required String contentOwnerId,
    required dynamic decision,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    calls.add(_LogCall(
      adminEmail: adminEmail,
      contentId: contentId,
      decision: decision,
      reason: reason,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotificationService implements ModerationNotificationService {
  final List<_NotifyCall> contentRemovedCalls = [];
  final List<_NotifyResolvedCall> resolvedCalls = [];

  @override
  Future<void> notifyContentRemoved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    contentRemovedCalls.add(_NotifyCall(
      userEmail: userEmail,
      userType: userType,
      contentType: contentType,
      contentId: contentId,
      reason: reason,
    ));
  }

  @override
  Future<void> notifyReportResolved({
    required String userEmail,
    required String userType,
    required String contentType,
    required String contentId,
    required dynamic decision,
  }) async {
    resolvedCalls.add(_NotifyResolvedCall(
      userEmail: userEmail,
      userType: userType,
      contentType: contentType,
      contentId: contentId,
      decision: decision,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReportEventService implements ReportEventService {
  final EventReport report;
  final List<_UpdateCall> updates = [];

  _FakeReportEventService(this.report);

  @override
  Future<EventReport?> getReportById(String id) async => report;

  @override
  Future<void> updateReportStatus(String id, String status) async {
    updates.add(_UpdateCall(id: id, status: status));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AdminModerationService.moderateEventReport', () {
    late AdminModerationService service;
    late _MockAuditService auditService;
    late _MockNotificationService notificationService;
    late _FakeReportEventService reportService;

    setUp(() {
      auditService = _MockAuditService();
      notificationService = _MockNotificationService();
      reportService = _FakeReportEventService(
        EventReport(
          id: 'report-1',
          eventId: 'event-1',
          visitorEmail: 'reporter@example.com',
          reason: 'spam',
          status: 'pending',
          severity: 'high',
          createdAt: DateTime(2025, 1, 1),
        ),
      );
      service = AdminModerationService(
        reportEventService: reportService,
        auditService: auditService,
        notificationService: notificationService,
      );
    });

    test('delete decision updates report to resolved and notifies reporter',
        () async {
      await service.moderateEventReport(
        reportId: 'report-1',
        decision: ModerationDecision.delete,
        adminEmail: 'admin@example.com',
        reason: 'Confirmed spam',
      );

      expect(reportService.updates.single.status, 'resolved');
      expect(auditService.calls.single.reason, 'Confirmed spam');
      expect(notificationService.resolvedCalls.single.userEmail,
          'reporter@example.com');
      expect(notificationService.resolvedCalls.single.decision,
          ModerationDecision.delete);
    });

    test('dismiss decision updates report to dismissed and notifies reporter',
        () async {
      await service.moderateEventReport(
        reportId: 'report-1',
        decision: ModerationDecision.dismiss,
        adminEmail: 'admin@example.com',
        reason: 'No violation',
      );

      expect(reportService.updates.single.status, 'dismissed');
      expect(notificationService.resolvedCalls.single.decision,
          ModerationDecision.dismiss);
    });

    test('throws when report is not found', () async {
      final emptyService = AdminModerationService(
        reportEventService: _FakeReportEventService(
          // id mismatch simulates missing document
          EventReport(
            id: 'other',
            eventId: 'event-x',
            visitorEmail: 'other@example.com',
            reason: 'other',
            status: 'pending',
            createdAt: DateTime.now(),
          ),
        ),
        auditService: auditService,
        notificationService: notificationService,
      );

      expect(
        () => emptyService.moderateEventReport(
          reportId: 'missing',
          decision: ModerationDecision.delete,
          adminEmail: 'admin@example.com',
          reason: 'Spam',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('flag decision is treated as resolved', () async {
      await service.moderateEventReport(
        reportId: 'report-1',
        decision: ModerationDecision.flag,
        adminEmail: 'admin@example.com',
        reason: 'Warning issued',
      );

      expect(reportService.updates.single.status, 'resolved');
    });
  });
}

class _LogCall {
  _LogCall({
    required this.adminEmail,
    required this.contentId,
    required this.decision,
    required this.reason,
  });

  final String adminEmail;
  final String contentId;
  final dynamic decision;
  final String reason;
}

class _NotifyCall {
  _NotifyCall({
    required this.userEmail,
    required this.userType,
    required this.contentType,
    required this.contentId,
    required this.reason,
  });

  final String userEmail;
  final String userType;
  final String contentType;
  final String contentId;
  final String reason;
}

class _NotifyResolvedCall {
  _NotifyResolvedCall({
    required this.userEmail,
    required this.userType,
    required this.contentType,
    required this.contentId,
    required this.decision,
  });

  final String userEmail;
  final String userType;
  final String contentType;
  final String contentId;
  final dynamic decision;
}

class _UpdateCall {
  _UpdateCall({required this.id, required this.status});

  final String id;
  final String status;
}
