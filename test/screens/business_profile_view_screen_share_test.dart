import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/screens/business_profile_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBusinessProfileService implements BusinessProfileService {
  _FakeBusinessProfileService();

  @override
  Stream<Business?> getBusinessProfileStream(String businessId) {
    return Stream.value(
      Business(
        id: 'biz_123',
        ownerId: 'owner@example.com',
        businessName: 'Test Cafe',
        category: 'Cafe',
        description: 'A nice cafe',
        address: '123 Main St',
        contactNumber: '555-1234',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> incrementViewCount(String businessId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BusinessProfileViewScreen share', () {
    testWidgets('shows share button in app bar and body',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessProfileViewScreen(
            businessId: 'biz_123',
            isOwnProfile: false,
            businessProfileService: _FakeBusinessProfileService(),
          ),
        ),
      );

      // Wait for stream to emit
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.share_rounded), findsNWidgets(2));
      expect(find.text('Share This Business'), findsOneWidget);
    });
  });
}
