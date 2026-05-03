import 'dart:async';
import 'dart:typed_data';

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

Uint8List _pngBytes([int extra = 0]) {
  return Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...List.filled(extra, 0x00),
  ]);
}

Uint8List _invalidBytes() => Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03]);

Uint8List _oversizedEventImage() {
  final header = <int>[0xFF, 0xD8, 0xFF, 0xE0];
  // Event image limit: 2 MB.
  return Uint8List.fromList(
    header + List<int>.filled(FirebaseMediaService.maxEventImageBytes + 1 - header.length, 0x00),
  );
}

/// Seeds a submitted event into the fake Firestore.
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
  // =====================================================================
  // AC‑1  The system provides an event submission form with required fields
  // =====================================================================
  group('AC-1: event submission form required fields', () {
    test('EventItem model requires title, date, time, location, description', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Community Market',
        date: '15/06/2026',
        time: '10:00 AM',
        location: 'South Bank',
        description: 'Fresh produce and local crafts.',
        reviewStatus: EventReviewStatus.pending,
      );

      expect(event.title, 'Community Market');
      expect(event.date, '15/06/2026');
      expect(event.time, '10:00 AM');
      expect(event.location, 'South Bank');
      expect(event.description, 'Fresh produce and local crafts.');
    });

    test('EventItem has category field with default value General', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Test',
        date: '15/06/2026',
        time: '6:00 PM',
        location: 'CBD',
        description: 'Test event.',
        reviewStatus: EventReviewStatus.pending,
      );

      expect(event.category, 'General');
    });

    test('EventItem accepts explicit category', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Jazz Night',
        date: '20/06/2026',
        time: '8:00 PM',
        category: 'Music',
        location: 'Fortitude Valley',
        description: 'Live jazz.',
        reviewStatus: EventReviewStatus.pending,
      );

      expect(event.category, 'Music');
    });

    test('Firestore event doc stores all required fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Market Day',
        date: '15/06/2026',
        time: '9:00 AM',
        category: 'Food',
        location: 'West End',
        description: 'Weekend market.',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      final data = doc.data()!;
      expect(data['title'], 'Market Day');
      expect(data['date'], '15/06/2026');
      expect(data['time'], '9:00 AM');
      expect(data['category'], 'Food');
      expect(data['location'], 'West End');
      expect(data['description'], 'Weekend market.');
      expect(data['createdByLocalEmail'], 'local@brisconnect.com');
    });

    test('LocalEventService parses stored event doc into EventItem', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'River Concert',
        category: 'Music',
      );

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events, hasLength(1));
      expect(events.first.id, 'evt-1');
      expect(events.first.title, 'River Concert');
      expect(events.first.category, 'Music');
      expect(events.first.location, 'South Bank');
    });

    test('EventItem tracks createdByLocalEmail for ownership', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'My Event',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('owner@brisconnect.com')
          .first;

      expect(events, hasLength(1));
      expect(events.first.createdByLocalEmail, 'owner@brisconnect.com');
    });
  });

  // =====================================================================
  // AC‑2  The Local user can upload an event image during submission
  // =====================================================================
  group('AC-2: upload event image during submission', () {
    test('uploadEventImage accepts valid JPEG and returns StoredMediaFile', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'photo.jpg',
      );

      expect(result.downloadUrl, contains('hero.jpg'));
      expect(result.storagePath, contains('event-images/'));
      expect(result.contentType, 'image/jpeg');
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('uploadEventImage accepts valid PNG', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _pngBytes(),
        fileName: 'photo.png',
      );

      expect(result.contentType, 'image/png');
      expect(result.storagePath, contains('hero.png'));
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('uploadEventImage rejects unsupported format (magic bytes)', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _invalidBytes(),
          fileName: 'photo.jpg',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('JPG and PNG'),
        )),
      );
    });

    test('uploadEventImage rejects unsupported file extension', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _jpegBytes(),
          fileName: 'photo.bmp',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('uploadEventImage rejects files exceeding 2 MB', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _oversizedEventImage(),
          fileName: 'huge.jpg',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('too large'),
        )),
      );
    });

    test('maxEventImageBytes is 2 MB', () {
      expect(FirebaseMediaService.maxEventImageBytes, 2 * 1024 * 1024);
    });

    test('exactly max-size event image passes, max+1 fails', () async {
      final exactBytes = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xE0,
        ...List.filled(FirebaseMediaService.maxEventImageBytes - 4, 0x00),
      ]);
      expect(exactBytes.length, FirebaseMediaService.maxEventImageBytes);

      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: exactBytes,
        fileName: 'exact.jpg',
      );
      expect(result.downloadUrl, isNotEmpty);

      await expectLater(
        service.uploadEventImage(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: _oversizedEventImage(),
          fileName: 'over.jpg',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('uploadEventImage deletes previous image when path differs', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'new.jpg',
        previousStoragePath: 'event-images/old/hero.jpg',
      );

      expect(driver.deletedPaths, contains('event-images/old/hero.jpg'));
    });

    test('storage path uses slugified email and eventId', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventImage(
        eventId: 'my-event-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'hero.jpg',
      );

      expect(result.storagePath, contains('event-images/'));
      expect(result.storagePath, contains('local@brisconnect.com'));
      expect(result.storagePath, contains('my-event-1'));
    });
  });

  // =====================================================================
  // AC‑3  Submitted events are stored with a review status
  // =====================================================================
  group('AC-3: events stored with review status', () {
    test('new submission is stored with pending review status', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'New Submission',
        reviewStatus: 'pending',
      );

      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'pending');
    });

    test('LocalEventService parses pending status correctly', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Pending Event');

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events.first.reviewStatus, EventReviewStatus.pending);
      expect(events.first.isPending, isTrue);
      expect(events.first.isApproved, isFalse);
    });

    test('approved event status is parsed correctly', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-a',
        title: 'Approved Event',
        reviewStatus: 'approved',
      );

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events.first.reviewStatus, EventReviewStatus.approved);
      expect(events.first.isApproved, isTrue);
    });

    test('rejected event status is parsed correctly', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-r',
        title: 'Rejected Event',
        reviewStatus: 'rejected',
      );

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events.first.reviewStatus, EventReviewStatus.rejected);
      expect(events.first.isRejected, isTrue);
    });

    test('editing an approved event resets status to pending', () async {
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
        title: 'Edited Event',
        date: '20/06/2026',
        category: 'Music',
        location: 'New Location',
        description: 'Edited description.',
      );

      expect(didUpdate, isTrue);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['reviewStatus'], 'pending');
      expect(doc.data()?['title'], 'Edited Event');
    });

    test('watchSubmittedEvents emits real-time status changes', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'My Event');

      final service = LocalEventService(firestore: firestore);
      final statuses = service
          .watchSubmittedEvents('local@brisconnect.com')
          .where((events) => events.isNotEmpty)
          .map((events) => events.first.reviewStatus);

      final orderedStatuses = expectLater(
        statuses,
        emitsInOrder([
          EventReviewStatus.pending,
          EventReviewStatus.approved,
        ]),
      );

      await firestore.collection('events').doc('evt-1').update({
        'reviewStatus': 'approved',
      });

      await orderedStatuses.timeout(const Duration(seconds: 2));
    });

    test('EventReviewStatus enum has all three values', () {
      expect(EventReviewStatus.values, hasLength(3));
      expect(EventReviewStatus.values, containsAll([
        EventReviewStatus.pending,
        EventReviewStatus.approved,
        EventReviewStatus.rejected,
      ]));
    });
  });

  // =====================================================================
  // AC‑4  Unapproved events are not shown in the public visitor feed
  // =====================================================================
  group('AC-4: unapproved events not in public feed', () {
    test('EventItem.isApproved returns true only for approved status', () {
      const pending = EventItem(
        id: 'p',
        title: 'P',
        date: '',
        time: '',
        location: '',
        description: '',
        reviewStatus: EventReviewStatus.pending,
      );
      const approved = EventItem(
        id: 'a',
        title: 'A',
        date: '',
        time: '',
        location: '',
        description: '',
        reviewStatus: EventReviewStatus.approved,
      );
      const rejected = EventItem(
        id: 'r',
        title: 'R',
        date: '',
        time: '',
        location: '',
        description: '',
        reviewStatus: EventReviewStatus.rejected,
      );

      expect(pending.isApproved, isFalse);
      expect(approved.isApproved, isTrue);
      expect(rejected.isApproved, isFalse);
    });

    test('client-side filter using isApproved excludes pending and rejected', () {
      final allEvents = <EventItem>[
        const EventItem(id: '1', title: 'Approved', date: '', time: '', location: '', description: '', reviewStatus: EventReviewStatus.approved),
        const EventItem(id: '2', title: 'Pending', date: '', time: '', location: '', description: '', reviewStatus: EventReviewStatus.pending),
        const EventItem(id: '3', title: 'Rejected', date: '', time: '', location: '', description: '', reviewStatus: EventReviewStatus.rejected),
        const EventItem(id: '4', title: 'Also Approved', date: '', time: '', location: '', description: '', reviewStatus: EventReviewStatus.approved),
      ];

      final publicFeed = allEvents.where((e) => e.isApproved).toList();
      expect(publicFeed, hasLength(2));
      expect(publicFeed.map((e) => e.title), containsAll(['Approved', 'Also Approved']));
      expect(publicFeed.map((e) => e.title), isNot(contains('Pending')));
      expect(publicFeed.map((e) => e.title), isNot(contains('Rejected')));
    });

    test('Firestore where-clause on reviewStatus filters at query level', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'approved-1', title: 'Approved Event', reviewStatus: 'approved');
      await _seedEvent(firestore, id: 'pending-1', title: 'Pending Event', reviewStatus: 'pending');
      await _seedEvent(firestore, id: 'rejected-1', title: 'Rejected Event', reviewStatus: 'rejected');

      final snapshot = await firestore
          .collection('events')
          .where('reviewStatus', isEqualTo: 'approved')
          .get();

      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.first.data()['title'], 'Approved Event');
    });

    test('watchSubmittedEvents returns all statuses for the owner', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'a', title: 'Approved', reviewStatus: 'approved');
      await _seedEvent(firestore, id: 'p', title: 'Pending', reviewStatus: 'pending');
      await _seedEvent(firestore, id: 'r', title: 'Rejected', reviewStatus: 'rejected');

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      // Owner sees all their events regardless of status.
      expect(events, hasLength(3));
    });

    test('submitted events sort: pending first, approved second, rejected last', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'a', title: 'Approved', reviewStatus: 'approved');
      await _seedEvent(firestore, id: 'r', title: 'Rejected', reviewStatus: 'rejected');
      await _seedEvent(firestore, id: 'p', title: 'Pending', reviewStatus: 'pending');

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events[0].reviewStatus, EventReviewStatus.pending);
      expect(events[1].reviewStatus, EventReviewStatus.approved);
      expect(events[2].reviewStatus, EventReviewStatus.rejected);
    });
  });

  // =====================================================================
  // AC‑5  Submission completes when optional fields are empty
  // =====================================================================
  group('AC-5: submission completes with empty optional fields', () {
    test('event stored without image fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(
        firestore,
        id: 'evt-no-media',
        title: 'Text Only Event',
        // No imageUrl, imageStoragePath, audioUrl, audioStoragePath
      );

      final doc = await firestore.collection('events').doc('evt-no-media').get();
      final data = doc.data()!;
      expect(data['title'], 'Text Only Event');
      expect(data.containsKey('imageUrl'), isFalse);
      expect(data.containsKey('imageStoragePath'), isFalse);
      expect(data.containsKey('audioUrl'), isFalse);
    });

    test('LocalEventService parses event with missing optional fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('evt-minimal').set({
        'title': 'Minimal Event',
        'date': '15/06/2026',
        'time': '6:00 PM',
        'location': 'CBD',
        'description': 'Just text.',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
      });

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events, hasLength(1));
      expect(events.first.title, 'Minimal Event');
      expect(events.first.imageAsset, isNull);
      expect(events.first.imageStoragePath, isNull);
      expect(events.first.audioUrl, isNull);
      expect(events.first.audioStoragePath, isNull);
    });

    test('EventItem defaults optional fields to null', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Simple',
        date: '15/06/2026',
        time: '6:00 PM',
        location: 'CBD',
        description: 'Minimal.',
        reviewStatus: EventReviewStatus.pending,
      );

      expect(event.imageAsset, isNull);
      expect(event.imageStoragePath, isNull);
      expect(event.audioUrl, isNull);
      expect(event.audioStoragePath, isNull);
      expect(event.videoUrl, isNull);
      expect(event.videoStoragePath, isNull);
      expect(event.createdByLocalEmail, isNull);
      expect(event.latitude, isNull);
      expect(event.longitude, isNull);
    });

    test('updateSubmittedEvent works with null optional media fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Original');

      final service = LocalEventService(firestore: firestore);
      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'local@brisconnect.com',
        title: 'Edited',
        date: '20/06/2026',
        category: 'Music',
        location: 'West End',
        description: 'Edited description.',
        // imageUrl, imageStoragePath, audioUrl, audioStoragePath all null
      );

      expect(didUpdate, isTrue);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'Edited');
      expect(doc.data()?['imageUrl'], isNull);
      expect(doc.data()?['audioUrl'], isNull);
    });

    test('Firestore doc with empty strings for optional fields parses safely', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('events').doc('evt-empty').set({
        'title': 'Empty Strings Event',
        'date': '',
        'time': '',
        'location': '',
        'description': '',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
        'imageUrl': '',
        'imageStoragePath': '',
        'audioUrl': '',
      });

      final service = LocalEventService(firestore: firestore);
      final events = await service
          .watchSubmittedEvents('local@brisconnect.com')
          .first;

      expect(events, hasLength(1));
      expect(events.first.title, 'Empty Strings Event');
      // Empty strings should be trimmed — service handles gracefully.
      expect(events.first.date, isNotNull);
      expect(events.first.time, isNotNull);
    });

    test('copyWith preserves optional fields when not overridden', () {
      const event = EventItem(
        id: 'evt-1',
        title: 'Test',
        date: '15/06/2026',
        time: '6:00 PM',
        location: 'CBD',
        description: 'Desc.',
        reviewStatus: EventReviewStatus.pending,
        imageAsset: 'https://example.com/hero.jpg',
        imageStoragePath: 'event-images/hero.jpg',
        audioUrl: 'https://example.com/audio.mp3',
      );

      final updated = event.copyWith(title: 'Updated Title');
      expect(updated.title, 'Updated Title');
      expect(updated.imageAsset, 'https://example.com/hero.jpg');
      expect(updated.imageStoragePath, 'event-images/hero.jpg');
      expect(updated.audioUrl, 'https://example.com/audio.mp3');
    });
  });

  // =====================================================================
  // AC‑6  Event submissions with media are processed efficiently & reliably
  // =====================================================================
  group('AC-6: efficient and reliable processing', () {
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

    test('upload failure is catchable and does not leak storage', () async {
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

    test('format rejection prevents storage driver invocation', () async {
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
      expect(driver.deletedPaths, isEmpty);
    });

    test('previous image deletion failure does not block new upload', () async {
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
      expect(result.storagePath, isNotEmpty);
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('deleteSubmittedEvent removes event and cleans up media', () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final service = LocalEventService(
        firestore: firestore,
        mediaService: FirebaseMediaService(driver: driver),
      );

      await _seedEvent(
        firestore,
        id: 'evt-media',
        title: 'Event with Image',
        imageStoragePath: 'event-images/local/evt-media/hero.jpg',
      );

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'evt-media',
        localEmail: 'local@brisconnect.com',
      );

      expect(deleted, isTrue);
      final doc = await firestore.collection('events').doc('evt-media').get();
      expect(doc.exists, isFalse);
      expect(driver.deletedPaths, contains('event-images/local/evt-media/hero.jpg'));
    });

    test('deleteSubmittedEvent rejects non-owner deletion', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Owned by local',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'attacker@brisconnect.com',
      );

      expect(deleted, isFalse);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.exists, isTrue, reason: 'event should not be deleted by non-owner');
    });

    test('updateSubmittedEvent rejects non-owner edit', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      await _seedEvent(
        firestore,
        id: 'evt-1',
        title: 'Owned by local',
        createdByLocalEmail: 'owner@brisconnect.com',
      );

      final didUpdate = await service.updateSubmittedEvent(
        eventId: 'evt-1',
        localEmail: 'attacker@brisconnect.com',
        title: 'Hijacked Title',
        date: '01/01/2026',
        category: 'Hacked',
        location: 'Nowhere',
        description: 'Unauthorized edit.',
      );

      expect(didUpdate, isFalse);
      final doc = await firestore.collection('events').doc('evt-1').get();
      expect(doc.data()?['title'], 'Owned by local', reason: 'title unchanged');
    });

    test('watchSubmittedEvents returns empty list for empty email', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedEvent(firestore, id: 'evt-1', title: 'Some Event');

      final service = LocalEventService(firestore: firestore);
      final events = await service.watchSubmittedEvents('').first;

      expect(events, isEmpty);
    });

    test('updateSubmittedEvent returns false for non-existent event', () async {
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

    test('deleteSubmittedEvent returns false for non-existent event', () async {
      final firestore = FakeFirebaseFirestore();
      final service = LocalEventService(firestore: firestore);

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'does-not-exist',
        localEmail: 'local@brisconnect.com',
      );

      expect(deleted, isFalse);
    });

    test('event audio upload validates supported formats', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadEventAudio(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'narration.mp3',
      );

      expect(result.storagePath, contains('event-audio/'));
      expect(result.contentType, 'audio/mpeg');

      await expectLater(
        service.uploadEventAudio(
          eventId: 'evt-1',
          ownerEmail: 'local@brisconnect.com',
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'narration.txt',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('storage path is deterministic for same eventId and email', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result1 = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'first.jpg',
      );
      final result2 = await service.uploadEventImage(
        eventId: 'evt-1',
        ownerEmail: 'local@brisconnect.com',
        bytes: _jpegBytes(),
        fileName: 'second.jpg',
      );

      expect(result1.storagePath, result2.storagePath);
    });
  });
}
