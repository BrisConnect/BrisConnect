import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/admin_business_management_screen.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBusinessProfileService extends Mock
    implements BusinessProfileService {}

void main() {
  group('AdminBusinessManagementScreen', () {
    late _MockBusinessProfileService service;

    setUp(() {
      service = _MockBusinessProfileService();
    });

    testWidgets('shows loading indicator while stream is waiting',
        (tester) async {
      when(() => service.getAllBusinessesAdminStream()).thenAnswer(
        (_) => const Stream<List<Business>>.empty(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessManagementScreen(
            businessService: service,
            enforceRoleGuard: false,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no businesses', (tester) async {
      when(() => service.getAllBusinessesAdminStream()).thenAnswer(
        (_) => Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessManagementScreen(
            businessService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No all businesses'), findsOneWidget);
    });

    testWidgets('displays business cards with actions', (tester) async {
      final businesses = [
        _fakeBusiness(id: 'b1', businessName: 'Cafe One'),
        _fakeBusiness(
          id: 'b2',
          businessName: 'Cafe Two',
          isVerified: true,
          duplicateOf: 'b1',
        ),
      ];

      when(() => service.getAllBusinessesAdminStream()).thenAnswer(
        (_) => Stream.value(businesses),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessManagementScreen(
            businessService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cafe One'), findsOneWidget);
      expect(find.text('Cafe Two'), findsOneWidget);
      expect(find.text('Possible duplicate of b1'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verify'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Unverify'), findsOneWidget);
    });

    testWidgets('filter chips update displayed businesses', (tester) async {
      final pending = _fakeBusiness(id: 'b1', businessName: 'Pending Biz');
      final verified = _fakeBusiness(
        id: 'b2',
        businessName: 'Verified Biz',
        isVerified: true,
      );

      when(() => service.getAllBusinessesAdminStream()).thenAnswer(
        (_) => Stream.value([pending, verified]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminBusinessManagementScreen(
            businessService: service,
            enforceRoleGuard: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Pending Biz'), findsOneWidget);
      expect(find.text('Verified Biz'), findsNothing);
    });
  });
}

Business _fakeBusiness({
  required String id,
  String businessName = 'Fake Business',
  bool isVerified = false,
  bool isActive = true,
  String? duplicateOf,
}) {
  return Business(
    id: id,
    ownerId: 'owner@example.com',
    businessName: businessName,
    category: 'Restaurant',
    description: 'A fake business',
    address: '123 Main St',
    contactNumber: '555-0000',
    isVerified: isVerified,
    isActive: isActive,
    duplicateOf: duplicateOf,
  );
}
