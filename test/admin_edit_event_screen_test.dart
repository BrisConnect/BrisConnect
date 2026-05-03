import 'dart:typed_data';

import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/screens/admin_edit_event_screen.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/event_category_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Mock service that records calls without hitting Firestore.
// ---------------------------------------------------------------------------
class TestAdminEventService extends AdminEventService {
  String? lastUpdatedId;
  String? lastTitle;
  String? lastDate;
  String? lastCategory;
  String? lastLocation;
  String? lastDescription;
  EventReviewStatus? lastReviewStatus;
  bool shouldThrow = false;

  TestAdminEventService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String date,
    String? category,
    EventReviewStatus? reviewStatus,
    required String location,
    required String description,
    String? imageUrl,
    String? imageStoragePath,
    String? videoUrl,
    String? videoStoragePath,
    String? audioUrl,
    String? audioStoragePath,
    String? aiNarration,
  }) async {
    if (shouldThrow) {
      throw Exception('Firestore write failed');
    }
    lastUpdatedId = eventId;
    lastTitle = title;
    lastDate = date;
    lastCategory = category;
    lastLocation = location;
    lastDescription = description;
    lastReviewStatus = reviewStatus;
  }

  @override
  Future<int> migrateLegacyLocalSubmissionIds() async => 0;
}

// ---------------------------------------------------------------------------
// Fake category service backed by FakeFirebaseFirestore.
// ---------------------------------------------------------------------------
class TestEventCategoryService extends EventCategoryService {
  TestEventCategoryService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<String>> fetchCategories() async {
    return List<String>.from(EventCategoryService.defaultCategories);
  }
}

// ---------------------------------------------------------------------------
// No-op media driver so FirebaseStorage.instance is never accessed.
// ---------------------------------------------------------------------------
class _FakeMediaDriver implements MediaStorageDriver {
  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async =>
      'https://fake/$path';

  @override
  Future<void> delete(String path) async {}
}

const _testEvent = EventItem(
  id: 'evt-edit-1',
  title: 'Riverfire 2026',
  date: '15/06/2026',
  time: '7:00 PM',
  category: 'Culture',
  location: 'South Bank Parklands',
  description: 'Annual fireworks display over the Brisbane River.',
  reviewStatus: EventReviewStatus.pending,
  createdByLocalEmail: 'local@test.com',
);

const _testEventWithImage = EventItem(
  id: 'evt-edit-1',
  title: 'Riverfire 2026',
  date: '15/06/2026',
  time: '7:00 PM',
  category: 'Culture',
  location: 'South Bank Parklands',
  description: 'Annual fireworks display over the Brisbane River.',
  reviewStatus: EventReviewStatus.pending,
  createdByLocalEmail: 'local@test.com',
  imageAsset: 'https://example.com/riverfire.jpg',
  imageStoragePath: 'event-images/local@test.com/evt-edit-1/hero.jpg',
);

Widget _buildApp(TestAdminEventService service, {EventItem? event}) {
  return MaterialApp(
    home: AdminEditEventScreen(
      event: event ?? _testEvent,
      eventService: service,
      enforceRoleGuard: false,
      categoryService: TestEventCategoryService(),
      mediaService: FirebaseMediaService(driver: _FakeMediaDriver()),
    ),
  );
}

void main() {
  group('AdminEditEventScreen', () {
    testWidgets('renders pre-filled form with existing event data',
        (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Title, location, description pre-filled
      expect(find.text('Riverfire 2026'), findsOneWidget);
      expect(find.text('South Bank Parklands'), findsOneWidget);
      expect(
        find.text('Annual fireworks display over the Brisbane River.'),
        findsOneWidget,
      );

      // Date pre-filled
      expect(find.text('15/06/2026'), findsOneWidget);

      // Category dropdown showing Culture
      expect(find.text('Culture'), findsOneWidget);

      // Form labels present
      expect(find.text('Event Title'), findsOneWidget);
      expect(find.text('Event Date'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('shows all 8 category options in dropdown', (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Tap the Category dropdown to open it
      await tester.tap(find.text('Culture'));
      await tester.pumpAndSettle();

      // All 8 categories visible in the dropdown overlay
      for (final cat in [
        'Culture',
        'Music',
        'Food',
        'Sports',
        'Community',
        'Education',
        'Family',
        'General',
      ]) {
        expect(find.text(cat), findsWidgets);
      }
    });

    testWidgets('shows validation error when title is cleared',
        (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Clear the title field (first TextFormField)
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '');
      await tester.pumpAndSettle();

      // Tap Save — scroll to ensure button is visible
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter event title'), findsOneWidget);
      expect(service.lastUpdatedId, isNull);
    });

    testWidgets('shows validation error when location is cleared',
        (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Location is the 2nd TextFormField (after title; date is InkWell)
      final locationField = find.byType(TextFormField).at(1);
      await tester.enterText(locationField, '');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter location'), findsOneWidget);
      expect(service.lastUpdatedId, isNull);
    });

    testWidgets('shows validation error when description is cleared',
        (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Description is the 3rd TextFormField (after title, location)
      final descField = find.byType(TextFormField).at(2);
      await tester.enterText(descField, '');
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Save Changes'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter description'), findsOneWidget);
      expect(service.lastUpdatedId, isNull);
    });

    testWidgets('shows upload button when event has no image', (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // No image on default test event → shows Upload
      expect(find.text('Upload Event Image'), findsOneWidget);
      expect(find.text('Remove Image'), findsNothing);
    });

    testWidgets('date picker shows pre-selected date and opens dialog',
        (tester) async {
      final service = TestAdminEventService();
      await tester.pumpWidget(_buildApp(service));
      await tester.pumpAndSettle();

      // Date is pre-filled from the event
      expect(find.text('15/06/2026'), findsOneWidget);

      // Tap the date field to open the picker
      await tester.tap(find.text('15/06/2026'));
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
