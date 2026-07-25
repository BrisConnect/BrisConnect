import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brisconnect/models/promotion_schedule.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this._data);

  final T _data;

  @override
  T get data => _data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BestTimeToPostService promotion helpers', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BestTimeToPostService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = BestTimeToPostService(firestore: fakeFirestore);
    });

    Future<DocumentReference> addPromotion({
      required String ownerId,
      required String status,
      required DateTime endAt,
    }) async {
      return fakeFirestore.collection('promotions').add({
        'businessId': 'b1',
        'ownerId': ownerId,
        'title': 'Test Promo',
        'description': '',
        'scheduledAt': Timestamp.fromDate(DateTime.now()),
        'endAt': Timestamp.fromDate(endAt),
        'status': status,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    test('getPromotion returns active promotion with parsed fields', () async {
      final endAt = DateTime.now().add(const Duration(days: 3));
      final doc = await addPromotion(
        ownerId: 'owner@test.com',
        status: 'active',
        endAt: endAt,
      );

      final promotion = await service.getPromotion(doc.id);
      expect(promotion, isNotNull);
      expect(promotion!.id, doc.id);
      expect(promotion.ownerId, 'owner@test.com');
      expect(promotion.status, PromotionStatus.active);
      expect(promotion.endAt!.day, endAt.day);
    });

    test('getPromotion returns null for non-existent id', () async {
      final result = await service.getPromotion('does-not-exist');
      expect(result, isNull);
    });

    test('extendPromotion calls Cloud Function with correct arguments', () async {
      final functions = MockFirebaseFunctions();
      final callable = MockHttpsCallable();
      when(() => functions.httpsCallable('extendPromotion')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _FakeHttpsCallableResult({'success': true, 'promotionId': 'promo-1', 'extensionDays': 7}),
      );

      final serviceWithMock = BestTimeToPostService(
        firestore: fakeFirestore,
        functions: functions,
      );

      final ok = await serviceWithMock.extendPromotion(promotionId: 'promo-1');

      expect(ok, isTrue);
      verify(() => functions.httpsCallable('extendPromotion')).called(1);
      verify(
        () => callable.call<Map<String, dynamic>>({
          'promotionId': 'promo-1',
          'extensionDays': 7,
        }),
      ).called(1);
    });

    test('extendPromotion returns false on Cloud Function failure', () async {
      final functions = MockFirebaseFunctions();
      final callable = MockHttpsCallable();
      when(() => functions.httpsCallable('extendPromotion')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Invalid promotion',
        ),
      );

      final serviceWithMock = BestTimeToPostService(
        firestore: fakeFirestore,
        functions: functions,
      );

      final ok = await serviceWithMock.extendPromotion(promotionId: 'bad-id');
      expect(ok, isFalse);
    });
  });
}
