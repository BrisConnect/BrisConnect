import 'dart:async';

import 'package:brisconnect/services/notification_health_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

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
      final firestore = _MockFirebaseFirestore();
      final collection = _MockCollectionReference();
      final ordered = _MockQuery();
      final limited = _MockQuery();
      final snapshot = _MockQuerySnapshot();
      final doc1 = _MockQueryDocumentSnapshot();
      final doc2 = _MockQueryDocumentSnapshot();

      when(() => firestore.collection('notification_health_checks')).thenReturn(collection);
      when(() => collection.orderBy('checkedAt', descending: true)).thenReturn(ordered);
      when(() => ordered.limit(100)).thenReturn(limited);
      when(() => limited.snapshots()).thenAnswer((_) => Stream.value(snapshot));
      when(() => snapshot.docs).thenReturn([doc1, doc2]);
      when(doc1.data).thenReturn({
        'status': 'ok',
        'firestoreReachable': true,
        'fcmReachable': true,
        'latencyMs': 50,
      });
      when(doc2.data).thenReturn({
        'status': 'degraded',
        'firestoreReachable': true,
        'fcmReachable': false,
        'latencyMs': 200,
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
