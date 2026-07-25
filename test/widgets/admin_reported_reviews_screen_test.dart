import 'package:brisconnect/models/moderation_action.dart';
import 'package:brisconnect/models/review.dart';
import 'package:brisconnect/screens/admin_reported_reviews_screen.dart';
import 'package:brisconnect/services/admin_moderation_service.dart';
import 'package:brisconnect/services/admin_user_management_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminModerationService extends Mock
    implements AdminModerationService {}

class _MockAdminUserManagementService extends Mock
    implements AdminUserManagementService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ModerationDecision.delete);
  });

  group('AdminReportedReviewsScreen', () {
    late _MockAdminModerationService service;
    late _MockAdminUserManagementService userManagementService;

    setUp(() {
      service = _MockAdminModerationService();
      userManagementService = _MockAdminUserManagementService();
      when(() => userManagementService.watchAllUsers()).thenAnswer(
        (_) => Stream.value([]),
      );
    });

    testWidgets('shows loading indicator while stream is waiting',
        (tester) async {
      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => const Stream<List<Review>>.empty(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no reported reviews', (tester) async {
      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reported recommendations'), findsOneWidget);
    });

    testWidgets('displays reported review cards', (tester) async {
      final reviews = [
        _fakeReview(id: 'review-1', comment: 'Great place!'),
        _fakeReview(id: 'review-2', comment: 'Rude staff', isReported: true, reportReason: 'Inappropriate'),
      ];

      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value(reviews),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Great place!'), findsOneWidget);
      expect(find.text('Rude staff'), findsOneWidget);
      expect(find.text('Report reason: Inappropriate'), findsOneWidget);
      expect(find.text('REPORTED'), findsOneWidget);
      expect(find.text('VISIBLE'), findsOneWidget);
    });

    testWidgets('shows delete and dismiss actions for reported review',
        (tester) async {
      final review = _fakeReview(id: 'review-1', isReported: true);

      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value([review]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    });

    testWidgets('shows restore action for deleted review', (tester) async {
      final review = _fakeReview(
        id: 'review-1',
        isReported: true,
        deletedAt: DateTime(2025, 1, 1),
      );

      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value([review]),
      );
      when(() => service.deletedReviewsStream).thenAnswer(
        (_) => Stream.value([review]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deleted'));
      await tester.pumpAndSettle();

      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('delete reason dialog is shown and confirm calls moderateReview',
        (tester) async {
      final review = _fakeReview(id: 'review-1', isReported: true);

      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value([review]),
      );
      when(() => service.currentAdminEmail).thenReturn('admin@example.com');
      when(
        () => service.moderateReview(
          reviewId: any(named: 'reviewId'),
          decision: any(named: 'decision'),
          adminEmail: any(named: 'adminEmail'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});

      // Ensure deleted stream is also stubbed so switching filters does not crash.
      when(() => service.deletedReviewsStream).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('moderation_reason_title')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Spam content');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();

      verify(
        () => service.moderateReview(
          reviewId: 'review-1',
          decision: ModerationDecision.delete,
          adminEmail: 'admin@example.com',
          reason: 'Spam content',
        ),
      ).called(1);
    });

    testWidgets('severity filter hides non-matching reviews', (tester) async {
      final reviews = [
        _fakeReview(id: 'r1', isReported: true, severity: 'critical'),
        _fakeReview(id: 'r2', isReported: true, severity: 'low'),
      ];

      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.value(reviews),
      );
      when(() => service.deletedReviewsStream).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test comment'), findsNWidgets(2));

      await tester.tap(find.text('All severities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Critical').last);
      await tester.pumpAndSettle();

      expect(find.text('Test comment'), findsOneWidget);
    });

    testWidgets('shows error message on stream error', (tester) async {
      when(() => service.reportedReviewsStream).thenAnswer(
        (_) => Stream.error('Network failure'),
      );
      when(() => service.deletedReviewsStream).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportedReviewsScreen(
            moderationService: service,
            userManagementService: userManagementService,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading recommendations'), findsOneWidget);
      expect(find.textContaining('Network failure'), findsOneWidget);
    });
  });
}

Review _fakeReview({
  required String id,
  String comment = 'Test comment',
  bool isReported = false,
  String? reportReason,
  String severity = 'medium',
  DateTime? deletedAt,
}) {
  return Review(
    id: id,
    businessId: 'business-1',
    visitorId: 'visitor-1',
    visitorName: 'Test Visitor',
    rating: 4,
    buzzRating: 3,
    comment: comment,
    createdAt: DateTime(2025, 1, 1),
    isReported: isReported,
    reportReason: reportReason,
    severity: severity,
    deletedAt: deletedAt,
  );
}
