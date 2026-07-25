import 'package:brisconnect/models/activity_feed_item.dart';
import 'package:brisconnect/screens/admin_community_feed_screen.dart';
import 'package:brisconnect/services/activity_feed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActivityFeedService extends Mock implements ActivityFeedService {}

void main() {
  group('AdminCommunityFeedScreen', () {
    late _MockActivityFeedService service;

    setUp(() {
      service = _MockActivityFeedService();
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.all,
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) => Stream.value([
          _fakeItem(id: '1', type: ActivityFeedType.review, title: 'Review 1'),
          _fakeItem(id: '2', type: ActivityFeedType.event, title: 'Event 1'),
        ]),
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.review,
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) => Stream.value([
          _fakeItem(id: '1', type: ActivityFeedType.review, title: 'Review 1'),
        ]),
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.event,
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) => Stream.value([
          _fakeItem(id: '2', type: ActivityFeedType.event, title: 'Event 1'),
        ]),
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.business,
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) => Stream.value([]),
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.photo,
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) => Stream.value([]),
      );
    });

    testWidgets('displays feed items and filter chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);
      expect(find.text('Event 1'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets('filtering by content type updates the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);
      expect(find.text('Event 1'), findsOneWidget);

      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();

      expect(find.text('Review 1'), findsOneWidget);
      expect(find.text('Event 1'), findsNothing);
    });

    testWidgets('pin action calls service.pinItem', (tester) async {
      final item = _fakeItem(
        id: '1',
        type: ActivityFeedType.review,
        title: 'Review 1',
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.all,
            limit: any(named: 'limit'),
          )).thenAnswer((_) => Stream.value([item]));
      when(() => service.pinItem(item)).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Pin'));
      await tester.pumpAndSettle();

      verify(() => service.pinItem(item)).called(1);
    });

    testWidgets('highlight action calls service.highlightItem', (tester) async {
      final item = _fakeItem(
        id: '1',
        type: ActivityFeedType.review,
        title: 'Review 1',
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.all,
            limit: any(named: 'limit'),
          )).thenAnswer((_) => Stream.value([item]));
      when(() => service.highlightItem(item)).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Highlight'));
      await tester.pumpAndSettle();

      verify(() => service.highlightItem(item)).called(1);
    });

    testWidgets('remove action confirms and calls service.removeItem',
        (tester) async {
      final item = _fakeItem(
        id: '1',
        type: ActivityFeedType.review,
        title: 'Spam review',
      );
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.all,
            limit: any(named: 'limit'),
          )).thenAnswer((_) => Stream.value([item]));
      when(() => service.removeItem(item)).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from feed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => service.removeItem(item)).called(1);
    });

    testWidgets('shows empty state when feed is empty', (tester) async {
      when(() => service.activityFeedStreamByType(
            ActivityFeedType.all,
            limit: any(named: 'limit'),
          )).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCommunityFeedScreen(
            activityFeedService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No activity'), findsOneWidget);
    });
  });
}

ActivityFeedItem _fakeItem({
  required String id,
  required ActivityFeedType type,
  required String title,
  bool isPinned = false,
  bool isHighlighted = false,
}) {
  return ActivityFeedItem(
    id: id,
    type: type,
    title: title,
    subtitle: 'Subtitle',
    body: 'Body',
    imageUrl: '',
    createdAt: DateTime(2026, 1, 1),
    isPinned: isPinned,
    isHighlighted: isHighlighted,
    targetId: id,
  );
}
