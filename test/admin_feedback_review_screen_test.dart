import 'package:brisconnect/screens/admin_feedback_review_screen.dart';
import 'package:brisconnect/services/app_feedback_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock service that returns cached streams (avoids re-subscribe loops).
// ---------------------------------------------------------------------------
class TestAppFeedbackService extends AppFeedbackService {
  final Map<String, Stream<List<AppFeedbackItem>>> _cache = {};

  final List<AppFeedbackItem> pendingItems;
  final List<AppFeedbackItem> resolvedItems;
  final List<AppFeedbackItem> inProgressItems;
  final List<AppFeedbackItem> wontFixItems;

  String? lastUpdatedId;
  String? lastUpdatedStatus;

  TestAppFeedbackService({
    this.pendingItems = const [],
    this.resolvedItems = const [],
    this.inProgressItems = const [],
    this.wontFixItems = const [],
  }) : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<List<AppFeedbackItem>> watchFeedbackByStatus(String status) {
    return _cache.putIfAbsent(status, () {
      switch (status) {
        case 'pending_triage':
          return Stream.value(pendingItems);
        case 'in_progress':
          return Stream.value(inProgressItems);
        case 'resolved':
          return Stream.value(resolvedItems);
        case 'wont_fix':
          return Stream.value(wontFixItems);
        default:
          return Stream.value([]);
      }
    });
  }

  @override
  Future<void> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    bool? consideredForFix,
  }) async {
    lastUpdatedId = feedbackId;
    lastUpdatedStatus = status;
  }

  @override
  Future<void> replyToFeedback({
    required String feedbackId,
    required String reply,
  }) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
AppFeedbackItem _item({
  String id = 'fb-1',
  String subject = 'Test Bug',
  String details = 'Detail info about the bug',
  String severity = 'high',
  String status = 'pending_triage',
  String category = 'bug',
  String referenceId = 'FB-0001',
  String reporterEmail = 'user@test.com',
  String reporterRole = 'visitor',
}) {
  return AppFeedbackItem(
    id: id,
    reporterRole: reporterRole,
    reporterEmail: reporterEmail,
    reporterName: 'Test User',
    subject: subject,
    details: details,
    category: category,
    severity: severity,
    status: status,
    consideredForFix: true,
    maintenanceWindowDays: 14,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
    resolutionDueAt: DateTime(2026, 4, 15),
    referenceId: referenceId,
  );
}

Widget _buildScreen(TestAppFeedbackService service) {
  return MaterialApp(
    home: AdminFeedbackReviewScreen(
      feedbackService: service,
      enforceRoleGuard: false,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  group('AdminFeedbackReviewScreen', () {
    testWidgets('shows status and severity filter chips', (tester) async {
      final service = TestAppFeedbackService();
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      // Status chips
      expect(find.text('Pending Triage'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text("Won't Fix"), findsOneWidget);

      // Severity chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('displays feedback card with reference ID and details',
        (tester) async {
      final service = TestAppFeedbackService(
        pendingItems: [
          _item(
            subject: 'Map pin wrong',
            details: 'Pin shows incorrect location',
            severity: 'high',
            referenceId: 'FB-0042',
          ),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('FB-0042'), findsOneWidget);
      expect(find.text('Map pin wrong'), findsOneWidget);
      expect(find.text('Pin shows incorrect location'), findsOneWidget);
    });

    testWidgets('shows empty state when no feedback matches', (tester) async {
      final service = TestAppFeedbackService(pendingItems: []);
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No'),
        findsOneWidget,
      );
    });

    testWidgets('filters by severity', (tester) async {
      final service = TestAppFeedbackService(
        pendingItems: [
          _item(id: 'fb-1', subject: 'Critical Bug', severity: 'critical'),
          _item(id: 'fb-2', subject: 'Low Priority', severity: 'low'),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      // At least the first visible card present (All severity selected)
      expect(find.text('Critical Bug'), findsOneWidget);

      // Tap 'Critical' severity chip
      await tester.tap(find.text('Critical'));
      await tester.pumpAndSettle();

      expect(find.text('Critical Bug'), findsOneWidget);
      expect(find.text('Low Priority'), findsNothing);
    });

    testWidgets('switches status filter to show resolved items',
        (tester) async {
      final service = TestAppFeedbackService(
        pendingItems: [_item(subject: 'Pending Item')],
        resolvedItems: [
          _item(
            id: 'fb-r',
            subject: 'Resolved Item',
            status: 'resolved',
          ),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('Pending Item'), findsOneWidget);
      expect(find.text('Resolved Item'), findsNothing);

      // Tap 'Resolved' status chip
      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Resolved Item'), findsOneWidget);
      expect(find.text('Pending Item'), findsNothing);
    });

    testWidgets('shows meta chips with category, severity, due date',
        (tester) async {
      final service = TestAppFeedbackService(
        pendingItems: [
          _item(category: 'usability', severity: 'medium'),
        ],
      );
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      expect(find.text('Category: usability'), findsOneWidget);
      expect(find.text('Severity: medium'), findsOneWidget);
      expect(find.textContaining('Due:'), findsOneWidget);
    });

    testWidgets('tapping Mark In Progress calls updateFeedbackStatus',
        (tester) async {
      final service = TestAppFeedbackService(
        pendingItems: [_item(id: 'fb-action')],
      );
      await tester.pumpWidget(_buildScreen(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark In Progress'));
      await tester.pumpAndSettle();

      expect(service.lastUpdatedId, 'fb-action');
      expect(service.lastUpdatedStatus, 'in_progress');
    });
  });
}
