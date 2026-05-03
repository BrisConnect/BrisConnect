import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:brisconnect/screens/admin_event_review_screen.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/models/event_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildScreen({TestAdminEventService? service}) {
    return MaterialApp(
      home: AdminEventReviewScreen(
        eventService: service ?? TestAdminEventService(),
        enforceRoleGuard: false,
      ),
    );
  }

  group('AdminEventReviewScreen', () {
    testWidgets('Renders AppBar, search summary, and event list',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Manage Events'), findsOneWidget);

      // Summary section
      expect(find.text('Admin Event Control'), findsOneWidget);
      expect(find.textContaining('Total: 3'), findsOneWidget);
      expect(find.textContaining('Pending: 1'), findsOneWidget);
      expect(find.textContaining('Approved: 1'), findsOneWidget);
      expect(find.textContaining('Rejected: 1'), findsOneWidget);
    });

    testWidgets('Displays event cards from stream', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Pending event sorts first and is visible
      expect(find.text('Pending Festival'), findsOneWidget);
      // Event details visible on card
      expect(find.textContaining('South Bank'), findsOneWidget);
    });

    testWidgets('Shows approve and reject buttons for pending events',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Pending event has Approve and Reject action buttons
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('Shows edit and delete buttons for all events',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Every event card has Edit and Delete buttons
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Delete'), findsWidgets);
    });

    testWidgets('Delete button triggers confirmation dialog', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap the first Delete button
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Cancel dismisses delete dialog without deleting',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Open delete dialog
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, events still visible
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Pending Festival'), findsOneWidget);
    });

    testWidgets('Shows empty state when no events exist', (tester) async {
      final emptyService = TestAdminEventService(events: []);
      await tester.pumpWidget(buildScreen(service: emptyService));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No events found in Firebase.'), findsOneWidget);
      expect(find.textContaining('Total: 0'), findsOneWidget);
    });
  });
}

class TestAdminEventService extends AdminEventService {
  TestAdminEventService({List<EventItem>? events})
      : _events = events ??
            [
              const EventItem(
                id: 'evt-1',
                title: 'Pending Festival',
                date: '15 Apr 2026',
                time: '10:00 AM',
                location: 'South Bank',
                description: 'A pending event for review.',
                reviewStatus: EventReviewStatus.pending,
                createdByLocalEmail: 'local@test.com',
              ),
              const EventItem(
                id: 'evt-2',
                title: 'Approved Market',
                date: '20 Apr 2026',
                time: '9:00 AM',
                location: 'West End',
                description: 'An approved market event.',
                reviewStatus: EventReviewStatus.approved,
              ),
              const EventItem(
                id: 'evt-3',
                title: 'Rejected Concert',
                date: '25 Apr 2026',
                time: '7:00 PM',
                location: 'Fortitude Valley',
                description: 'A rejected concert.',
                reviewStatus: EventReviewStatus.rejected,
              ),
            ],
        super(firestore: FakeFirebaseFirestore());

  final List<EventItem> _events;

  // Cache so StreamBuilder sees the same object on rebuild.
  Stream<List<EventItem>>? _cachedStream;

  @override
  Stream<List<EventItem>> watchAllEvents() {
    return _cachedStream ??= Stream.value(_events);
  }

  @override
  Future<int> migrateLegacyLocalSubmissionIds() async => 0;

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
    debugPrint('[TestService] updateEvent $eventId status=$reviewStatus');
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    debugPrint('[TestService] deleteEvent $eventId');
  }
}