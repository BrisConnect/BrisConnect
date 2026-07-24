import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/fcm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FcmService.resetInstance();
  });

  group('FcmService navigatorKey', () {
    test('exposes a valid GlobalKey<NavigatorState>', () {
      expect(navigatorKey, isA<GlobalKey<NavigatorState>>());
      expect(navigatorKey.currentState, isNull);
    });
  });

  group('FcmService instance', () {
    test('singleton instance is accessible', () {
      expect(FcmService.instance, same(FcmService.instance));
    });

    test('token is null before initialization', () {
      expect(FcmService.instance.token, isNull);
    });
  });
}
