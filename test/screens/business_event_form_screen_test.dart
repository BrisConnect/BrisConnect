import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/business_event.dart';
import 'package:brisconnect/screens/business_event_form_screen.dart';
import 'package:brisconnect/services/business_event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockBusinessEventService extends Mock implements BusinessEventService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessEventFormScreen', () {
    final business = Business(
      id: 'biz_1',
      ownerId: 'owner_1',
      businessName: 'Test Café',
      category: 'Restaurant',
      description: 'A test café',
      address: '123 Brisbane St',
      contactNumber: '0400000000',
    );

    setUp(() {
      LocalAuth.debugSetCurrentLocalForTesting(LocalUser(
        name: 'Test Café',
        email: 'owner@example.com',
        password: '',
        phone: '',
        suburb: '',
      ));
    });

    tearDown(() {
      LocalAuth.debugSetCurrentLocalForTesting(null);
    });

    testWidgets('create mode shows required fields and validates input',
        (tester) async {
      final mockService = _MockBusinessEventService();

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 2000)),
            child: BusinessEventFormScreen(
              business: business,
              eventService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Event'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(3));

      // Enter only title and verify validation requires location.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Event Title'),
        'Wine Night',
      );

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Event'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Event'));
      await tester.pumpAndSettle();

      expect(find.text('Location is required'), findsOneWidget);
      verifyNoMoreInteractions(mockService);
    });

    testWidgets('shows validation error when all required fields are empty',
        (tester) async {
      final mockService = _MockBusinessEventService();

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 2000)),
            child: BusinessEventFormScreen(
              business: business,
              eventService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Remove default date/time by clearing them through the service-level
      // expectation. The form defaults date/time so the SnackBar is not shown.
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Create Event'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Event'));
      await tester.pumpAndSettle();

      expect(find.text('Event title is required'), findsOneWidget);
      expect(find.text('Location is required'), findsOneWidget);
      verifyNoMoreInteractions(mockService);
    });

    testWidgets('edit mode pre-fills event data and updates event',
        (tester) async {
      final mockService = _MockBusinessEventService();
      final event = BusinessEvent(
        id: 'event_1',
        businessId: 'biz_1',
        ownerId: 'owner_1',
        ownerEmail: 'owner@example.com',
        title: 'Existing Event',
        date: '25/07/2026',
        time: '18:30',
        location: 'Cellar Door',
        description: 'Existing description',
        status: 'published',
      );
      when(() => mockService.updateBusinessEvent(
            eventId: 'event_1',
            businessId: 'biz_1',
            ownerEmail: 'owner@example.com',
            title: 'Updated Event',
            date: '25/07/2026',
            time: '18:30',
            location: 'Cellar Door',
            description: 'Existing description',
          )).thenAnswer((_) async => true);

      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 2000)),
            child: BusinessEventFormScreen(
              business: business,
              event: event,
              eventService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Existing Event'), findsOneWidget);
      expect(find.text('Cellar Door'), findsOneWidget);
      expect(find.text('Existing description'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Event Title'),
        'Updated Event',
      );

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Update Event'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Event'));
      await tester.pumpAndSettle();

      verify(() => mockService.updateBusinessEvent(
            eventId: 'event_1',
            businessId: 'biz_1',
            ownerEmail: 'owner@example.com',
            title: 'Updated Event',
            date: '25/07/2026',
            time: '18:30',
            location: 'Cellar Door',
            description: 'Existing description',
          )).called(1);
    });
  });
}
