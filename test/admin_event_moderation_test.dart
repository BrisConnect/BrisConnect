import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/admin_event_service.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedEvent(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String title,
  String date = '15/06/2026',
  String time = '6:00 PM',
  String category = 'Community',
  String location = 'South Bank',
  String description = 'A community event.',
  String reviewStatus = 'pending',
  String createdByLocalEmail = 'local@brisconnect.com',
  String? imageUrl,
  String? imageStoragePath,
  String? audioUrl,
  String? audioStoragePath,
  String? videoUrl,
  String? videoStoragePath,
}) async {
  await firestore.collection('events').doc(id).set(<String, dynamic>{
    'title': title,
    'date': date,
    'time': time,
    'category': category,
    'location': location,
    'description': description,
    'reviewStatus': reviewStatus,
    'createdByLocalEmail': createdByLocalEmail,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (imageStoragePath != null) 'imageStoragePath': imageStoragePath,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (audioStoragePath != null) 'audioStoragePath': audioStoragePath,
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (videoStoragePath != null) 'videoStoragePath': videoStoragePath,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =====================================================================
  // AC-1  The system displays pending, approved, and rejected event states
  // =====================================================================
  group('AC-1: display pending, approved, and rejected event states', () {
    test('watchAllEvents returns events of all three statuses', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'p1', title: 'Pending Fest', reviewStatus: 'pending');
      await _seedEvent(firestore, id: 'a1', title: 'Approved Market', reviewStatus: 'approved');
      await _seedEvent(firestore, id: 'r1', title: 'Rejected Gig', reviewStatus: 'rejected');

      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      expect(events, hasLength(3));
      expect(events.any((e) => e.isPending), isTrue);
      expect(events.any((e) => e.isApproved), isTrue);
      expect(events.any((e) => e.isRejected), isTrue);
    });

    test('events are sorted pending → approved → rejected', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'a1', title: 'Alpha Approved', reviewStatus: 'approved');
      await _seedEvent(firestore, id: 'r1', title: 'Alpha Rejected', reviewStatus: 'rejected');
      await _seedEvent(firestore, id: 'p1', title: 'Alpha Pending', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      expect(events[0].reviewStatus, EventReviewStatus.pending);
      expect(events[1].reviewStatus, EventReviewStatus.approved);
      expect(events[2].reviewStatus, EventReviewStatus.rejected);
    });

    test('within same status, events are sorted alphabetically by title', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'p2', title: 'Zulu Pending', reviewStatus: 'pending');
      await _seedEvent(firestore, id: 'p1', title: 'Alpha Pending', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      expect(events[0].title, 'Alpha Pending');
      expect(events[1].title, 'Zulu Pending');
    });

    test('EventItem convenience getters match status', () {
      const pending = EventItem(
        id: 'p', title: 'P', date: '', time: '', location: '', description: '',
        reviewStatus: EventReviewStatus.pending,
      );
      const approved = EventItem(
        id: 'a', title: 'A', date: '', time: '', location: '', description: '',
        reviewStatus: EventReviewStatus.approved,
      );
      const rejected = EventItem(
        id: 'r', title: 'R', date: '', time: '', location: '', description: '',
        reviewStatus: EventReviewStatus.rejected,
      );

      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
      expect(rejected.isRejected, isTrue);
      expect(rejected.isApproved, isFalse);
    });

    test('_parseStatus handles flexible Firestore status values', () async {
      final firestore = FakeFirebaseFirestore();
      // status field stored as 'PENDING' (uppercase badge format)
      await firestore.collection('events').doc('up').set({
        'title': 'Uppercase',
        'date': '15/06/2026',
        'time': '6:00 PM',
        'location': 'CBD',
        'description': 'Test.',
        'badge': 'PENDING',
      });
      // status stored via 'status' field rather than 'reviewStatus'
      await firestore.collection('events').doc('alt').set({
        'title': 'Alt Field',
        'date': '15/06/2026',
        'time': '6:00 PM',
        'location': 'CBD',
        'description': 'Test.',
        'status': 'rejected',
      });

      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      final uppercase = events.firstWhere((e) => e.id == 'up');
      final alt = events.firstWhere((e) => e.id == 'alt');

      expect(uppercase.reviewStatus, EventReviewStatus.pending);
      expect(alt.reviewStatus, EventReviewStatus.rejected);
    });

    test('empty events collection returns empty list', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      expect(events, isEmpty);
    });

    test('malformed event docs are skipped without crashing', () async {
      final firestore = FakeFirebaseFirestore();
      // Valid event
      await _seedEvent(firestore, id: 'ok', title: 'Good Event');
      // Minimal doc that should still parse via defaults
      await firestore.collection('events').doc('minimal').set({
        'title': 'Bare Minimum',
      });

      final service = AdminEventService(firestore: firestore);
      final events = await service.watchAllEvents().first;

      // Both should parse; _eventFromDoc fills defaults for missing fields
      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.any((e) => e.id == 'ok'), isTrue);
    });
  });

  // =====================================================================
  // AC-2  The Admin can approve an event
  // =====================================================================
  group('AC-2: admin can approve an event', () {
    test('approving a pending event sets reviewStatus to approved', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Pending Fest', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Pending Fest',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'A community event.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'approved');
      expect(doc.data()?['status'], 'approved');
      expect(doc.data()?['isApproved'], isTrue);
    });

    test('approving a rejected event changes status to approved', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-r', title: 'Was Rejected', reviewStatus: 'rejected');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-r',
        title: 'Was Rejected',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Now approved.',
      );

      final doc = await firestore.collection('events').doc('evt-r').get();
      expect(doc.data()?['reviewStatus'], 'approved');
      expect(doc.data()?['isApproved'], isTrue);
    });

    test('approving an event sets the badge to APPROVED', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Badge Test', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Badge Test',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Check badge.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['badge'], 'APPROVED');
    });

    test('approved event is synced to discover_items collection', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Discoverable Event',
        reviewStatus: 'pending',
        imageUrl: 'https://example.com/hero.jpg',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Discoverable Event',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Public-facing event.',
        imageUrl: 'https://example.com/hero.jpg',
      );

      final discoverDoc =
          await firestore.collection('discover_items').doc('evt-1').get();
      expect(discoverDoc.exists, isTrue);
      expect(discoverDoc.data()?['title'], 'Discoverable Event');
      expect(discoverDoc.data()?['approvalStatus'], 'approved');
      expect(discoverDoc.data()?['section'], 'events');
      expect(discoverDoc.data()?['location'], 'South Bank');
      expect(discoverDoc.data()?['imageUrl'], 'https://example.com/hero.jpg');
    });

    test('discover_items doc includes all media fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-m',
        title: 'Media Event',
        reviewStatus: 'pending',
        imageUrl: 'https://img.com/hero.jpg',
        imageStoragePath: 'event-images/local/hero.jpg',
        audioUrl: 'https://audio.com/narration.mp3',
        audioStoragePath: 'event-audio/local/narration.mp3',
        videoUrl: 'https://video.com/clip.mp4',
        videoStoragePath: 'event-video/local/clip.mp4',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-m',
        title: 'Media Event',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'Valley',
        description: 'Has all media.',
        imageUrl: 'https://img.com/hero.jpg',
        imageStoragePath: 'event-images/local/hero.jpg',
        audioUrl: 'https://audio.com/narration.mp3',
        audioStoragePath: 'event-audio/local/narration.mp3',
        videoUrl: 'https://video.com/clip.mp4',
        videoStoragePath: 'event-video/local/clip.mp4',
      );

      final discover =
          await firestore.collection('discover_items').doc('evt-m').get();
      final data = discover.data()!;
      expect(data['imageUrl'], 'https://img.com/hero.jpg');
      expect(data['imageStoragePath'], 'event-images/local/hero.jpg');
      expect(data['audioUrl'], 'https://audio.com/narration.mp3');
      expect(data['audioStoragePath'], 'event-audio/local/narration.mp3');
      expect(data['videoUrl'], 'https://video.com/clip.mp4');
      expect(data['videoStoragePath'], 'event-video/local/clip.mp4');
    });
  });

  // =====================================================================
  // AC-3  The Admin can reject an event
  // =====================================================================
  group('AC-3: admin can reject an event', () {
    test('rejecting a pending event sets reviewStatus to rejected', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Pending Fest', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Pending Fest',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'South Bank',
        description: 'Rejected event.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'rejected');
      expect(doc.data()?['status'], 'rejected');
      expect(doc.data()?['isApproved'], isFalse);
    });

    test('rejecting sets the badge to REJECTED', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Badge Test', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Badge Test',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'CBD',
        description: 'Check badge.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['badge'], 'REJECTED');
    });

    test('rejecting an approved event reverts status', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-a', title: 'Was Approved', reviewStatus: 'approved');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-a',
        title: 'Was Approved',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'South Bank',
        description: 'Now rejected.',
      );

      final doc = await firestore.collection('events').doc('evt-a').get();
      expect(doc.data()?['reviewStatus'], 'rejected');
      expect(doc.data()?['isApproved'], isFalse);
    });

    test('rejected event is NOT synced to discover_items', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Rejected One', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Rejected One',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'CBD',
        description: 'Should not appear in discover.',
      );

      final discoverDoc =
          await firestore.collection('discover_items').doc('evt-1').get();
      expect(discoverDoc.exists, isFalse);
    });

    test('pending event update without reviewStatus does not sync to discover', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Still Pending', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Edited Still Pending',
        date: '20/06/2026',
        location: 'West End',
        description: 'Edited but not moderated.',
      );

      final discoverDoc =
          await firestore.collection('discover_items').doc('evt-1').get();
      expect(discoverDoc.exists, isFalse);
    });
  });

  // =====================================================================
  // AC-4  Event moderation updates are saved immediately
  // =====================================================================
  group('AC-4: moderation updates saved immediately', () {
    test('updatedAt field is set on moderation', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Event', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Event',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Approved.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['updatedAt'], isNotNull);
    });

    test('discover_items doc has updatedAt on approval', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Event', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Event',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Approved.',
      );

      final discover =
          await firestore.collection('discover_items').doc('evt-1').get();
      expect(discover.data()?['updatedAt'], isNotNull);
    });

    test('multiple sequential status changes are all persisted', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Flip-flop', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);

      // Approve
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Flip-flop',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Now approved.',
      );
      var doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'approved');

      // Reject
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Flip-flop',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'CBD',
        description: 'Now rejected.',
      );
      doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'rejected');

      // Approve again
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Flip-flop',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Approved again.',
      );
      doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'approved');
    });

    test('dateTime field is recomposed on moderation update', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Timed', time: '3:30 PM');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Timed',
        date: '25/07/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Timed event.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['dateTime'], contains('25/07/2026'));
      expect(doc.data()?['dateTime'], contains('3:30 PM'));
    });

    test('text fields are trimmed of whitespace before saving', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Untrimmed');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: '  Trimmed Title  ',
        date: '  20/06/2026  ',
        reviewStatus: EventReviewStatus.approved,
        location: '  Valley  ',
        description: '  Trimmed desc.  ',
        category: '  Music  ',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'Trimmed Title');
      expect(doc.data()?['date'], '20/06/2026');
      expect(doc.data()?['location'], 'Valley');
      expect(doc.data()?['description'], 'Trimmed desc.');
      expect(doc.data()?['category'], 'Music');
    });

    test('admin can update only title without changing review status', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Old Title', reviewStatus: 'approved');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'New Title',
        date: '15/06/2026',
        location: 'South Bank',
        description: 'A community event.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'New Title');
      // reviewStatus should remain unchanged when not explicitly set
      expect(doc.data()?['reviewStatus'], 'approved');
    });
  });

  // =====================================================================
  // AC-5  Public event listings reflect the latest approval status
  // =====================================================================
  group('AC-5: public listings reflect latest approval status', () {
    test('watchApprovedDiscoverItems only returns approved items', () async {
      final firestore = FakeFirebaseFirestore();

      // Seed discover_items with mixed statuses
      await firestore.collection('discover_items').doc('d1').set({
        'id': 'd1',
        'title': 'Approved Event',
        'approvalStatus': 'approved',
        'section': 'events',
      });
      await firestore.collection('discover_items').doc('d2').set({
        'id': 'd2',
        'title': 'Pending Event',
        'approvalStatus': 'pending',
        'section': 'events',
      });
      await firestore.collection('discover_items').doc('d3').set({
        'id': 'd3',
        'title': 'Rejected Event',
        'approvalStatus': 'rejected',
        'section': 'events',
      });

      final discoverService = DiscoverDataService(
        firestore: firestore,
        enableSeedDefaults: false,
      );
      final items = await discoverService.watchApprovedDiscoverItems().first;

      expect(items, hasLength(1));
      expect(items.first['title'], 'Approved Event');
    });

    test('approving an event makes it visible in discover stream', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'New Fest', reviewStatus: 'pending');

      final adminService = AdminEventService(firestore: firestore);
      final discoverService = DiscoverDataService(
        firestore: firestore,
        enableSeedDefaults: false,
      );

      // Before approval: discover_items is empty
      var items = await discoverService.watchApprovedDiscoverItems().first;
      expect(items, isEmpty);

      // Approve the event
      await adminService.updateEvent(
        eventId: 'evt-1',
        title: 'New Fest',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Public now.',
      );

      // After approval: event appears in discover_items
      items = await discoverService.watchApprovedDiscoverItems().first;
      expect(items, hasLength(1));
      expect(items.first['title'], 'New Fest');
      expect(items.first['approvalStatus'], 'approved');
    });

    test('re-approving an event updates its discover_items entry', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'V1 Title', reviewStatus: 'pending');

      final adminService = AdminEventService(firestore: firestore);
      final discoverService = DiscoverDataService(
        firestore: firestore,
        enableSeedDefaults: false,
      );

      // First approval
      await adminService.updateEvent(
        eventId: 'evt-1',
        title: 'V1 Title',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'South Bank',
        description: 'Version 1.',
      );

      var items = await discoverService.watchApprovedDiscoverItems().first;
      expect(items.first['title'], 'V1 Title');

      // Admin edits and re-approves
      await adminService.updateEvent(
        eventId: 'evt-1',
        title: 'V2 Title',
        date: '20/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'New Farm',
        description: 'Version 2.',
      );

      items = await discoverService.watchApprovedDiscoverItems().first;
      expect(items, hasLength(1));
      expect(items.first['title'], 'V2 Title');
      expect(items.first['location'], 'New Farm');
    });

    test('discover_items preserves createdByLocalEmail from event', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Sourced Event',
        reviewStatus: 'pending',
        createdByLocalEmail: 'author@brisconnect.com',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Sourced Event',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Author preserved.',
      );

      final discover =
          await firestore.collection('discover_items').doc('evt-1').get();
      expect(discover.data()?['createdByLocalEmail'], 'author@brisconnect.com');
    });

    test('watchAllEvents stream emits new list after moderation', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Moderated', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      final statuses = service
          .watchAllEvents()
          .where((events) => events.isNotEmpty)
          .map((events) => events.first.reviewStatus);

      final expected = expectLater(
        statuses,
        emitsInOrder([
          EventReviewStatus.pending,
          EventReviewStatus.approved,
        ]),
      );

      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Moderated',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Now approved.',
      );

      await expected.timeout(const Duration(seconds: 2));
    });
  });

  // =====================================================================
  // AC-6  Moderation actions are processed quickly and accurately
  //       without data inconsistency
  // =====================================================================
  group('AC-6: quick, accurate moderation without data inconsistency', () {
    test('updateEvent uses transaction (throws on missing event)', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AdminEventService(firestore: firestore);

      await expectLater(
        service.updateEvent(
          eventId: 'ghost',
          title: 'Gone',
          date: '15/06/2026',
          reviewStatus: EventReviewStatus.approved,
          location: 'Nowhere',
          description: 'Non-existent.',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer exists'),
        )),
      );
    });

    test('deleteEvent uses transaction (throws on missing event)', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AdminEventService(firestore: firestore);

      await expectLater(
        service.deleteEvent('ghost'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer exists'),
        )),
      );
    });

    test('deleteEvent removes the event document', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-del', title: 'Delete Me');

      final service = AdminEventService(firestore: firestore);
      await service.deleteEvent('evt-del');

      final doc = await firestore.collection('events').doc('evt-del').get();
      expect(doc.exists, isFalse);
    });

    test('all three status-related fields stay consistent after approval', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Consistent', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Consistent',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Check consistency.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      final data = doc.data()!;
      expect(data['reviewStatus'], 'approved');
      expect(data['status'], 'approved');
      expect(data['badge'], 'APPROVED');
      expect(data['isApproved'], isTrue);
    });

    test('all three status-related fields stay consistent after rejection', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Consistent', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Consistent',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.rejected,
        location: 'CBD',
        description: 'Check consistency.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      final data = doc.data()!;
      expect(data['reviewStatus'], 'rejected');
      expect(data['status'], 'rejected');
      expect(data['badge'], 'REJECTED');
      expect(data['isApproved'], isFalse);
    });

    test('event and discover_items stay consistent after approval', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Cross-check',
        reviewStatus: 'pending',
        location: 'West End',
        description: 'Ensure consistency.',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Cross-check',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'West End',
        description: 'Ensure consistency.',
      );

      final eventDoc = await firestore.collection('events').doc('evt-1').get();
      final discoverDoc =
          await firestore.collection('discover_items').doc('evt-1').get();

      expect(eventDoc.data()?['title'], discoverDoc.data()?['title']);
      expect(eventDoc.data()?['location'], discoverDoc.data()?['location']);
      expect(eventDoc.data()?['description'], discoverDoc.data()?['description']);
      expect(discoverDoc.data()?['approvalStatus'], 'approved');
    });

    test('rapid approve/reject cycle leaves correct final state', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Rapid', reviewStatus: 'pending');

      final service = AdminEventService(firestore: firestore);

      for (var i = 0; i < 5; i++) {
        await service.updateEvent(
          eventId: 'evt-1',
          title: 'Rapid',
          date: '15/06/2026',
          reviewStatus: EventReviewStatus.approved,
          location: 'CBD',
          description: 'Cycle.',
        );
        await service.updateEvent(
          eventId: 'evt-1',
          title: 'Rapid',
          date: '15/06/2026',
          reviewStatus: EventReviewStatus.rejected,
          location: 'CBD',
          description: 'Cycle.',
        );
      }

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'rejected');
      expect(doc.data()?['isApproved'], isFalse);
    });

    test('category is optional and preserved when null', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Cat Test',
        category: 'Music',
        reviewStatus: 'pending',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Cat Test',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Category unchanged.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['category'], 'Music');
    });

    test('createdByLocalEmail is not overwritten by moderation', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Authored',
        reviewStatus: 'pending',
        createdByLocalEmail: 'author@brisconnect.com',
      );

      final service = AdminEventService(firestore: firestore);
      await service.updateEvent(
        eventId: 'evt-1',
        title: 'Authored',
        date: '15/06/2026',
        reviewStatus: EventReviewStatus.approved,
        location: 'CBD',
        description: 'Owner unchanged.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['createdByLocalEmail'], 'author@brisconnect.com');
    });
  });
}
