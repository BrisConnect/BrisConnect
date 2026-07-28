import 'package:brisconnect/services/notification_health_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  group('NotificationHealthService', () {
    test('checkHealth returns healthy result when callable succeeds', () async {
      final functions = _MockFirebaseFunctions();
      final callable = _MockHttpsCallable();
      final result = _MockHttpsCallableResult<Map<String, dynamic>>();

      when(() => functions.httpsCallable('notificationHealth')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>()).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'status': 'ok',
        'firestoreReachable': true,
        'fcmReachable': true,
        'latencyMs': 120,
        'checkedAt': DateTime(2025, 1, 1, 12, 0),
      });

      final service = NotificationHealthService(functions: functions);
      final health = await service.checkHealth();

      expect(health.status, 'ok');
      expect(health.firestoreReachable, true);
      expect(health.fcmReachable, true);
      expect(health.latencyMs, 120);
      expect(health.isHealthy, true);
    });

    test('checkHealth returns unavailable on callable exception', () async {
      final functions = _MockFirebaseFunctions();
      final callable = _MockHttpsCallable();

      when(() => functions.httpsCallable('notificationHealth')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>()).thenThrow(
        FirebaseFunctionsException(code: 'internal', message: 'Simulated failure'),
      );

      final service = NotificationHealthService(functions: functions);
      final health = await service.checkHealth();

      expect(health.status, 'unavailable');
      expect(health.isHealthy, false);
    });

    test('watchRecentChecks emits parsed results', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('notification_health_checks').add({
        'status': 'ok',
        'firestoreReachable': true,
        'fcmReachable': true,
        'latencyMs': 50,
        'checkedAt': Timestamp.fromDate(DateTime(2025, 1, 1, 12, 0)),
      });
      await firestore.collection('notification_health_checks').add({
        'status': 'degraded',
        'firestoreReachable': true,
        'fcmReachable': false,
        'latencyMs': 200,
        'checkedAt': Timestamp.fromDate(DateTime(2025, 1, 1, 11, 0)),
      });

      final service = NotificationHealthService(firestore: firestore);
      final results = await service.watchRecentChecks(limit: 100).first;

      expect(results.length, 2);
      expect(results.first.status, 'ok');
      expect(results.last.fcmReachable, false);
    });

    test('calculateAvailability returns correct percentage', () {
      final checks = [
        const NotificationHealthResult(
          status: 'ok',
          firestoreReachable: true,
          fcmReachable: true,
          latencyMs: 50,
        ),
        const NotificationHealthResult(
          status: 'ok',
          firestoreReachable: true,
          fcmReachable: true,
          latencyMs: 60,
        ),
        const NotificationHealthResult(
          status: 'unavailable',
          firestoreReachable: false,
          fcmReachable: false,
          latencyMs: 0,
        ),
      ];

      final availability = NotificationHealthService.calculateAvailability(checks);
      expect(availability, closeTo(66.67, 0.01));
    });

    test('calculateAvailability returns null for empty list', () {
      expect(NotificationHealthService.calculateAvailability([]), isNull);
    });
  });
}
