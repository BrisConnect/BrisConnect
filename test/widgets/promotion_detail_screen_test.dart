import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brisconnect/models/promotion_schedule.dart';
import 'package:brisconnect/screens/promotion_detail_screen.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';

class MockBestTimeToPostService extends Mock implements BestTimeToPostService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromotionDetailScreen', () {
    late MockBestTimeToPostService service;

    setUp(() {
      service = MockBestTimeToPostService();
    });

    testWidgets('shows loading then promotion details', (tester) async {
      final promotion = PromotionSchedule(
        id: 'promo-1',
        businessId: 'b1',
        ownerId: 'owner@test.com',
        title: 'Summer Special',
        description: '20% off',
        scheduledAt: DateTime(2026, 7, 20, 9, 0),
        endAt: DateTime(2026, 7, 27, 9, 0),
        status: PromotionStatus.active,
        createdAt: DateTime(2026, 7, 15),
      );

      when(() => service.getPromotion('promo-1'))
          .thenAnswer((_) async => promotion);

      await tester.pumpWidget(
        MaterialApp(
          home: PromotionDetailScreen(
            promotionId: 'promo-1',
            service: service,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Summer Special'), findsOneWidget);
      expect(find.text('20% off'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('Extend offer by 7 days'), findsOneWidget);
    });

    testWidgets('extend button calls service and shows success', (tester) async {
      final promotion = PromotionSchedule(
        id: 'promo-1',
        businessId: 'b1',
        ownerId: 'owner@test.com',
        title: 'Summer Special',
        description: '',
        scheduledAt: DateTime(2026, 7, 20),
        endAt: DateTime(2026, 7, 27),
        status: PromotionStatus.active,
        createdAt: DateTime(2026, 7, 15),
      );

      when(() => service.getPromotion('promo-1'))
          .thenAnswer((_) async => promotion);
      when(() => service.extendPromotion(promotionId: 'promo-1'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          home: PromotionDetailScreen(
            promotionId: 'promo-1',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Extend offer by 7 days'));
      await tester.pumpAndSettle();

      verify(() => service.extendPromotion(promotionId: 'promo-1')).called(1);
      expect(find.text('Offer extended by 7 days.'), findsOneWidget);
    });

    testWidgets('shows not found message for missing promotion', (tester) async {
      when(() => service.getPromotion('missing'))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: PromotionDetailScreen(
            promotionId: 'missing',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Promotion not found or no longer available.'), findsOneWidget);
    });
  });
}
