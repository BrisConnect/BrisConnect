import 'package:brisconnect/screens/notification_health_screen.dart';
import 'package:brisconnect/services/notification_health_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationHealthService implements NotificationHealthService {
  final NotificationHealthResult _result;
  final List<NotificationHealthResult> _history;

  _FakeNotificationHealthService(this._result, this._history);

  @override
  Future<NotificationHealthResult> checkHealth() async => _result;

  @override
  Stream<List<NotificationHealthResult>> watchRecentChecks({int limit = 100}) {
    return Stream.value(_history);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('NotificationHealthScreen shows healthy status', (tester) async {
    final service = _FakeNotificationHealthService(
      const NotificationHealthResult(
        status: 'ok',
        firestoreReachable: true,
        fcmReachable: true,
        latencyMs: 80,
      ),
      [
        const NotificationHealthResult(
          status: 'ok',
          firestoreReachable: true,
          fcmReachable: true,
          latencyMs: 80,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationHealthScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Healthy'), findsOneWidget);
    expect(find.textContaining('Latency: 80 ms'), findsOneWidget);
    expect(find.textContaining('Availability'), findsOneWidget);
    expect(find.textContaining('100.00%'), findsOneWidget);
  });

  testWidgets('NotificationHealthScreen shows degraded status', (tester) async {
    final service = _FakeNotificationHealthService(
      NotificationHealthResult.unavailable('FCM unreachable'),
      [
        const NotificationHealthResult(
          status: 'unavailable',
          firestoreReachable: true,
          fcmReachable: false,
          latencyMs: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationHealthScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Degraded or unavailable'), findsOneWidget);
    expect(find.textContaining('FCM unreachable'), findsOneWidget);
    expect(find.textContaining('0.00%'), findsOneWidget);
  });
}
