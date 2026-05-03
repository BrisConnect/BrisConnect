import 'dart:async';
import 'dart:typed_data';

import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/models/event_item.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeMediaStorageDriver implements MediaStorageDriver {
  _FakeMediaStorageDriver({
    this.uploadDelay = Duration.zero,
    this.shouldFailUpload = false,
    this.shouldFailDelete = false,
  });

  final Duration uploadDelay;
  final bool shouldFailUpload;
  final bool shouldFailDelete;
  final List<String> uploadedPaths = <String>[];
  final List<String> deletedPaths = <String>[];

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (uploadDelay > Duration.zero) {
      await Future<void>.delayed(uploadDelay);
    }
    if (shouldFailUpload) {
      throw Exception('Simulated upload failure');
    }
    uploadedPaths.add(path);
    return 'https://example.com/$path';
  }

  @override
  Future<void> delete(String path) async {
    if (shouldFailDelete) {
      throw Exception('Simulated delete failure');
    }
    deletedPaths.add(path);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _jpegBytes([int extra = 0]) {
  return Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(extra, 0x00)]);
}

Uint8List _invalidBytes() => Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03]);

Future<void> _seedEvent(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String title,
  String date = '15/06/2026',
  String time = '6:00 PM',
  String category = 'Community',
  String location = 'South Bank',
  String description = 'A community event.',
  String reviewStatus = 'approved',
  String createdByLocalEmail = 'local@brisconnect.com',
  String? imageUrl,
  String? imageStoragePath,
  String? audioUrl,
  String? audioStoragePath,
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
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    LocalAuth.debugSetCurrentLocalForTesting(null);
  });

  // =====================================================================
  // AC‑1  The system provides an Edit Event screen for Local users
  // =====================================================================
  group('AC-1: edit event screen for Local users', () {
    test('EventItem carries all fields needed by the edit screen', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Market Day',
        date: '15/06/2026',
        time: '9:00 AM',
        category: 'Food',
        location: 'West End',
        description: 'Weekend market.',
        reviewStatus: EventReviewStatus.approved,
        createdByLocalEmail: 'local@brisconnect.com',
        imageAsset: 'https://example.com/hero.jpg',
        imageStoragePath: 'event-images/local/evt-1/hero.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        audioStoragePath: 'event-audio/local/evt-1/audio.mp3',
      );

      expect(event.id, 'evt-1');
      expect(event.title, 'Market Day');
      expect(event.date, '15/06/2026');
      expect(event.time, '9:00 AM');
      expect(event.category, 'Food');
      expect(event.location, 'West End');
      expect(event.description, 'Weekend market.');
      expect(event.createdByLocalEmail, 'local@brisconnect.com');
      expect(event.imageAsset, 'https://example.com/hero.jpg');
      expect(event.imageStoragePath, 'event-images/local/evt-1/hero.jpg');
      expect(event.audioUrl, isNotNull);
      expect(event.audioStoragePath, isNotNull);
    });

    test('updateSubmittedEvent accepts all editable fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Original');

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Edited Title',
        date: '20/06/2026',
        category: 'Music',
        location: 'Fortitude Valley',
        description: 'Edited description.',
        imageUrl: 'https://example.com/new.jpg',
        imageStoragePath: 'event-images/local/evt-1/hero.jpg',
        audioUrl: 'https://example.com/narration.mp3',
        audioStoragePath: 'event-audio/local/evt-1/audio.mp3',
        aiNarration: 'AI-generated narration text.',
      );

      expect(didUpdate, isTrue);

      final doc = await firestore.collection('events').doc('evt-1').get();
      final data = doc.data()!;
      expect(data['title'], 'Edited Title');
      expect(data['date'], '20/06/2026');
      expect(data['category'], 'Music');
      expect(data['location'], 'Fortitude Valley');
      expect(data['description'], 'Edited description.');
      expect(data['imageUrl'], 'https://example.com/new.jpg');
      expect(data['imageStoragePath'], 'event-images/local/evt-1/hero.jpg');
      expect(data['audioUrl'], 'https://example.com/narration.mp3');
      expect(data['audioStoragePath'], 'event-audio/local/evt-1/audio.mp3');
      expect(data['aiNarration'], 'AI-generated narration text.');
    });

    test('EventItem.copyWith allows field-by-field updates', () {
      const original = EventItem(
        id: 'evt-1',
        title: 'Original',
        date: '15/06/2026',
        time: '6:00 PM',
        category: 'Community',
        location: 'South Bank',
        description: 'Original desc.',
        reviewStatus: EventReviewStatus.approved,
      );

      final edited = original.copyWith(
        title: 'Edited',
        location: 'New Farm',
        description: 'Updated desc.',
      );

      expect(edited.title, 'Edited');
      expect(edited.location, 'New Farm');
      expect(edited.description, 'Updated desc.');
      // Unchanged fields preserved.
      expect(edited.date, '15/06/2026');
      expect(edited.time, '6:00 PM');
      expect(edited.category, 'Community');
      expect(edited.id, 'evt-1');
    });

    test('Firestore event doc preserves time field during edit', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Timed Event',
        time: '3:30 PM',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Edited Timed Event',
        date: '20/06/2026',
        category: 'Music',
        location: 'West End',
        description: 'Updated.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['time'], '3:30 PM', reason: 'time preserved from original');
    });
  });

  // =====================================================================
  // AC‑2  A Local user can only edit events created by their own account
  // =====================================================================
  group('AC-2: ownership restriction on edit', () {
    test('owner can edit their own event', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'My Event',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'owner@brisconnect.com',
        title: 'My Edited Event',
        date: '20/06/2026',
        category: 'Music',
        location: 'CBD',
        description: 'Updated by owner.',
      );

      expect(didUpdate, isTrue);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'My Edited Event');
    });

    test('non-owner is rejected from editing', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Original',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'attacker@brisconnect.com',
        title: 'Hijacked',
        date: '01/01/2026',
        category: 'Hacked',
        location: 'Nowhere',
        description: 'Unauthorized.',
      );

      expect(didUpdate, isFalse);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'Original', reason: 'title must not change');
    });

    test('ownership check is case-insensitive', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'My Event',
        createdByLocalEmail: 'Owner@BrisConnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'owner@brisconnect.com',
        title: 'Edited',
        date: '20/06/2026',
        category: 'Music',
        location: 'CBD',
        description: 'Edit.',
      );

      expect(didUpdate, isTrue);
    });

    test('non-owner cannot delete another user\'s event', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Protected',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      final deleted = await service.deleteSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'attacker@brisconnect.com',
      );

      expect(deleted, isFalse);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.exists, isTrue);
    });

    test('event with empty createdByLocalEmail rejects all edits', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('orphan').set({
        'title': 'Orphan Event',
        'date': '15/06/2026',
        'time': '6:00 PM',
        'location': 'CBD',
        'description': 'No owner.',
        'reviewStatus': 'approved',
        'createdByLocalEmail': '',
      });

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'orphan',
        localEmail: 'anyone@brisconnect.com',
        title: 'Hijacked',
        date: '01/01/2026',
        category: 'None',
        location: 'Nowhere',
        description: 'Should fail.',
      );

      expect(didUpdate, isFalse);
    });

    test('edit returns false for non-existent event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'does-not-exist',
        localEmail: 'local@brisconnect.com',
        title: 'Ghost',
        date: '01/01/2026',
        category: 'None',
        location: 'Nowhere',
        description: 'Non-existent.',
      );

      expect(didUpdate, isFalse);
    });
  });

  // =====================================================================
  // AC‑3  The user can update event details and replace the event image
  // =====================================================================
  group('AC-3: update details and replace event image', () {
    test('uploadEventImage replaces old image via previousStoragePath', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'new-hero.jpg',
        previousStoragePath: 'event-images/local/evt-1/old-hero.jpg',
      );

      expect(result.downloadUrl, isNotEmpty);
      expect(result.storagePath, isNotEmpty);
      expect(driver.uploadedPaths, hasLength(1));
      expect(driver.deletedPaths, contains('event-images/local/evt-1/old-hero.jpg'));
    });

    test('upload without previousStoragePath does not delete anything', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'hero.jpg',
      );

      expect(driver.uploadedPaths, hasLength(1));
      expect(driver.deletedPaths, isEmpty);
    });

    test('update writes new image URL and storage path to Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Event With Image',
        imageUrl: 'https://old.com/hero.jpg',
        imageStoragePath: 'event-images/old/hero.jpg',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Event With New Image',
        date: '15/06/2026',
        category: 'Community',
        location: 'South Bank',
        description: 'Updated with new image.',
        imageUrl: 'https://new.com/hero.jpg',
        imageStoragePath: 'event-images/new/hero.jpg',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['imageUrl'], 'https://new.com/hero.jpg');
      expect(doc.data()?['imageStoragePath'], 'event-images/new/hero.jpg');
    });

    test('image can be removed by passing null', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Has Image',
        imageUrl: 'https://example.com/hero.jpg',
        imageStoragePath: 'event-images/local/hero.jpg',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'No Image',
        date: '15/06/2026',
        category: 'Community',
        location: 'South Bank',
        description: 'Image removed.',
        imageUrl: null,
        imageStoragePath: null,
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['imageUrl'], isNull);
      expect(doc.data()?['imageStoragePath'], isNull);
    });

    test('audio can be replaced alongside image', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Full Media',
        imageUrl: 'https://old.com/hero.jpg',
        audioUrl: 'https://old.com/audio.mp3',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Updated Media',
        date: '15/06/2026',
        category: 'Music',
        location: 'Valley',
        description: 'Both media replaced.',
        imageUrl: 'https://new.com/hero.jpg',
        imageStoragePath: 'event-images/new/hero.jpg',
        audioUrl: 'https://new.com/audio.mp3',
        audioStoragePath: 'event-audio/new/audio.mp3',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['imageUrl'], 'https://new.com/hero.jpg');
      expect(doc.data()?['audioUrl'], 'https://new.com/audio.mp3');
    });

    test('uploadEventImage rejects invalid format', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _invalidBytes(),
          fileName: 'bad.gif',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(driver.uploadedPaths, isEmpty);
    });

    test('uploadEventImage rejects oversized files (>2 MB)', () async {
      final oversized = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xE0,
        ...List.filled(FirebaseMediaService.maxEventImageBytes + 1 - 4, 0x00),
      ]);
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: oversized,
          fileName: 'huge.jpg',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('too large'),
        )),
      );
    });
  });

  // =====================================================================
  // AC‑4  Updated event information is saved successfully
  // =====================================================================
  group('AC-4: updated information saved successfully', () {
    test('editing an approved event resets reviewStatus to pending', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Approved Event',
        reviewStatus: 'approved',
      );

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Edited Approved Event',
        date: '20/06/2026',
        category: 'Culture',
        location: 'New Farm',
        description: 'Re-submitted for review.',
      );

      expect(didUpdate, isTrue);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'pending');
    });

    test('editing a rejected event resets reviewStatus to pending', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-r',
        title: 'Rejected Event',
        reviewStatus: 'rejected',
      );

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-r',
        localEmail: 'local@brisconnect.com',
        title: 'Corrected Event',
        date: '20/06/2026',
        category: 'Community',
        location: 'CBD',
        description: 'Fixed and re-submitted.',
      );

      expect(didUpdate, isTrue);
      final doc = await firestore.collection('events').doc('evt-r').get();
      expect(doc.data()?['reviewStatus'], 'pending');
    });

    test('all editable fields are persisted to Firestore after update', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Before');

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'After Title',
        date: '25/06/2026',
        category: 'Arts',
        location: 'GOMA',
        description: 'After description.',
        imageUrl: 'https://new.com/hero.jpg',
        imageStoragePath: 'event-images/new/hero.jpg',
        audioUrl: 'https://new.com/audio.mp3',
        audioStoragePath: 'event-audio/new/audio.mp3',
        aiNarration: 'New narration.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      final data = doc.data()!;
      expect(data['title'], 'After Title');
      expect(data['date'], '25/06/2026');
      expect(data['category'], 'Arts');
      expect(data['location'], 'GOMA');
      expect(data['description'], 'After description.');
      expect(data['imageUrl'], 'https://new.com/hero.jpg');
      expect(data['imageStoragePath'], 'event-images/new/hero.jpg');
      expect(data['audioUrl'], 'https://new.com/audio.mp3');
      expect(data['audioStoragePath'], 'event-audio/new/audio.mp3');
      expect(data['aiNarration'], 'New narration.');
      expect(data['reviewStatus'], 'pending');
    });

    test('non-updated fields are preserved after edit', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Original',
        time: '7:00 PM',
        createdByLocalEmail: 'local@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Edited',
        date: '20/06/2026',
        category: 'Music',
        location: 'Valley',
        description: 'Updated.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['createdByLocalEmail'], 'local@brisconnect.com',
          reason: 'owner unchanged');
      expect(doc.data()?['time'], '7:00 PM', reason: 'time preserved');
    });

    test('watchSubmittedEvents reflects edits in real-time', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'V1');

      final service = LocalEventService(firestore: firestore);
      final titles = service
          .watchSubmittedEvents('local@brisconnect.com')
          .where((events) => events.isNotEmpty)
          .map((events) => events.first.title);

      final expected = expectLater(
        titles,
        emitsInOrder(['V1', 'V2']),
      );

      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'V2',
        date: '15/06/2026',
        category: 'Community',
        location: 'South Bank',
        description: 'Version 2.',
      );

      await expected.timeout(const Duration(seconds: 2));
    });

    test('dateTime field is recomposed from new date and existing time', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Timed',
        date: '15/06/2026',
        time: '3:30 PM',
      );

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Retimed',
        date: '25/07/2026',
        category: 'Music',
        location: 'CBD',
        description: 'Date changed.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['dateTime'], '25/07/2026 • 3:30 PM');
    });
  });

  // =====================================================================
  // AC‑5  The system prevents unauthenticated users from editing events
  // =====================================================================
  group('AC-5: unauthenticated users prevented from editing', () {
    test('LocalAuth.currentLocal is null when no one is logged in', () {
      LocalAuth.debugSetCurrentLocalForTesting(null);
      expect(LocalAuth.currentLocal, isNull);
      expect(LocalAuth.isLocalLoggedIn, isFalse);
    });

    test('auth guard: null email prevents edit flow from proceeding', () {
      LocalAuth.debugSetCurrentLocalForTesting(null);
      final email = LocalAuth.currentLocal?.email;
      expect(email, isNull, reason: 'no email means edit guard blocks');
    });

    test('logged-in Local has non-null email for edit flow', () {
      LocalAuth.debugSetCurrentLocalForTesting(const LocalUser(
        name: 'Test Local',
        email: 'test@local.com',
        password: 'Secure!123',
        phone: '0400000000',
        suburb: 'CBD',
        approvalStatus: AccountApprovalStatus.approved,
      ));

      expect(LocalAuth.currentLocal?.email, 'test@local.com');
    });

    test('service-level ownership check blocks even valid emails', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Protected',
        createdByLocalEmail: 'real-owner@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);

      // Another valid logged-in Local tries to edit.
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'other-local@brisconnect.com',
        title: 'Stolen',
        date: '01/01/2026',
        category: 'None',
        location: 'Nowhere',
        description: 'Should fail.',
      );

      expect(didUpdate, isFalse);
    });

    test('empty email string is treated as unauthenticated', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Event');

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: '',
        title: 'Empty Email',
        date: '01/01/2026',
        category: 'None',
        location: 'Nowhere',
        description: 'Should fail.',
      );

      expect(didUpdate, isFalse);
    });

    test('whitespace-only email is treated as unauthenticated', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Event');

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: '   ',
        title: 'Whitespace',
        date: '01/01/2026',
        category: 'None',
        location: 'Nowhere',
        description: 'Should fail.',
      );

      expect(didUpdate, isFalse);
    });

    test('pending-approval Local still has email but may be blocked at screen level', () {
      LocalAuth.debugSetCurrentLocalForTesting(const LocalUser(
        name: 'Pending User',
        email: 'pending@local.com',
        password: 'Secure!123',
        phone: '0400000000',
        suburb: 'CBD',
        approvalStatus: AccountApprovalStatus.pending,
      ));

      expect(LocalAuth.currentLocal?.email, 'pending@local.com');
      expect(
        LocalAuth.isApprovalAuthorized(
          LocalAuth.currentLocal!.approvalStatus,
        ),
        isFalse,
        reason: 'pending users are not authorized',
      );
    });
  });

  // =====================================================================
  // AC‑6  Secure, efficient, and restricted to authorized users
  // =====================================================================
  group('AC-6: secure, efficient, and restricted editing', () {
    test('upload timeout is 30 seconds', () {
      expect(FirebaseMediaService.operationTimeout, const Duration(seconds: 30));
    });

    test('image upload times out after 30 seconds', () async {
      final service = FirebaseMediaService(
        driver: _FakeMediaStorageDriver(
          uploadDelay: const Duration(seconds: 31),
        ),
      );

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _jpegBytes(),
          fileName: 'hero.jpg',
        ),
        throwsA(isA<TimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('image upload failure is catchable and does not corrupt state', () async {
      final driver = _FakeMediaStorageDriver(shouldFailUpload: true);
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _jpegBytes(),
          fileName: 'hero.jpg',
        ),
        throwsA(anything),
      );

      expect(driver.uploadedPaths, isEmpty);
    });

    test('previous image delete failure does not block new upload', () async {
      final driver = _FakeMediaStorageDriver(shouldFailDelete: true);
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'hero.jpg',
        previousStoragePath: 'event-images/old/hero.jpg',
      );

      expect(result.downloadUrl, isNotEmpty);
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('format rejection prevents driver invocation', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _invalidBytes(),
          fileName: 'bad.bmp',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(driver.uploadedPaths, isEmpty);
      expect(driver.deletedPaths, isEmpty);
    });

    test('deleteSubmittedEvent removes doc and cleans up stored image', () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final service = LocalEventService(
        firestore: firestore,
        mediaService: FirebaseMediaService(driver: driver),
      );

      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'With Image',
        imageStoragePath: 'event-images/local/evt-1/hero.jpg',
      );

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
      );

      expect(deleted, isTrue);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.exists, isFalse);
      expect(driver.deletedPaths, contains('event-images/local/evt-1/hero.jpg'));
    });

    test('deleteSubmittedEvent rejects non-owner', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Protected',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'attacker@brisconnect.com',
      );

      expect(deleted, isFalse);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.exists, isTrue);
    });

    test('storage path is deterministic for same eventId and email', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final r1 = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'first.jpg',
      );
      final r2 = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'second.jpg',
      );

      expect(r1.storagePath, r2.storagePath,
          reason: 'same event always overwrites to same path');
    });

    test('deleteSubmittedEvent returns false for non-existent event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'ghost',
        localEmail: 'local@brisconnect.com',
      );

      expect(deleted, isFalse);
    });

    test('updateSubmittedEvent trims whitespace from text fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Original');

      final service = LocalEventService(firestore: firestore);
      await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: '  Trimmed Title  ',
        date: '  20/06/2026  ',
        category: '  Music  ',
        location: '  Valley  ',
        description: '  Trimmed description.  ',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'Trimmed Title');
      expect(doc.data()?['date'], '20/06/2026');
      expect(doc.data()?['category'], 'Music');
      expect(doc.data()?['location'], 'Valley');
      expect(doc.data()?['description'], 'Trimmed description.');
    });
  });
}
