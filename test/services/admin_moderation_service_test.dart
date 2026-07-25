import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/moderation_audit_service.dart';
import 'package:brisconnect/services/moderation_notification_service.dart';
import 'package:brisconnect/services/report_event_service.dart';
import 'package:brisconnect/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockModerationAuditService implements ModerationAuditService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockModerationNotificationService implements ModerationNotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockReportEventService implements ReportEventService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AdminModerationService', () {
    late AdminModerationService service;
    late _SpyReviewService reviewService;

    setUp(() {
      reviewService = _SpyReviewService();
      service = AdminModerationService(
        reviewService: reviewService,
        reportEventService: _MockReportEventService(),
        auditService: _MockModerationAuditService(),
        notificationService: _MockModerationNotificationService(),
      );
    });

    test('moderateReview delegates to review service', () async {
      await service.moderateReview(
        reviewId: 'review-1',
        decision: ModerationDecision.delete,
        adminEmail: 'admin@example.com',
        reason: 'Inappropriate language',
      );

      expect(reviewService.calls.length, 1);
      final call = reviewService.calls.first;
      expect(call.reviewId, 'review-1');
      expect(call.decision, ModerationDecision.delete);
      expect(call.adminEmail, 'admin@example.com');
      expect(call.reason, 'Inappropriate language');
    });

    test('moderateReview handles dismiss decision', () async {
      await service.moderateReview(
        reviewId: 'review-2',
        decision: ModerationDecision.dismiss,
        adminEmail: 'admin@example.com',
        reason: 'Report not valid',
      );

      expect(reviewService.calls.length, 1);
      expect(reviewService.calls.first.decision, ModerationDecision.dismiss);
    });
  });

  group('ModerationDecision', () {
    test('parses and serializes all values', () {
      for (final decision in ModerationDecision.values) {
        expect(
          ModerationDecision.fromString(decision.firestoreValue),
          decision,
        );
      }
    });

    test('unknown string defaults to approve', () {
      expect(
        ModerationDecision.fromString('unknown'),
        ModerationDecision.approve,
      );
    });
  });

  group('ModeratedContentType', () {
    test('parses and serializes all values', () {
      for (final type in ModeratedContentType.values) {
        expect(
          ModeratedContentType.fromString(type.firestoreValue),
          type,
        );
      }
    });
  });
}

class _SpyReviewService implements ReviewService {
  final List<_ModerateReviewCall> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> moderateReview({
    required String reviewId,
    required ModerationDecision decision,
    required String adminEmail,
    required String reason,
  }) async {
    calls.add(_ModerateReviewCall(
      reviewId: reviewId,
      decision: decision,
      adminEmail: adminEmail,
      reason: reason,
    ));
  }
}

class _ModerateReviewCall {
  _ModerateReviewCall({
    required this.reviewId,
    required this.decision,
    required this.adminEmail,
    required this.reason,
  });

  final String reviewId;
  final ModerationDecision decision;
  final String adminEmail;
  final String reason;
}
