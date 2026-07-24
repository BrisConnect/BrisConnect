import 'package:brisconnect/auth/local_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalUser notification preferences', () {
    const user = LocalUser(
      name: 'Test Owner',
      email: 'owner@test.com',
      password: 'pass',
      phone: '0000000000',
      suburb: 'Brisbane',
    );

    test('defaults all business notification preferences to true', () {
      expect(user.notifyTrendingPromotion, isTrue);
      expect(user.notifyOfferExpiry, isTrue);
      expect(user.notifyNewReview, isTrue);
      expect(user.notifyBusinessUpdates, isTrue);
    });

    test('copyWith updates only the requested preference', () {
      final updated = user.copyWith(notifyNewReview: false);

      expect(updated.notifyNewReview, isFalse);
      expect(updated.notifyTrendingPromotion, isTrue);
      expect(updated.notifyOfferExpiry, isTrue);
      expect(updated.notifyBusinessUpdates, isTrue);
    });
  });
}
