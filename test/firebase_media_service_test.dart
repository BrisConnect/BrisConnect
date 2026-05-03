import 'dart:async';
import 'dart:typed_data';

import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/local_event_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMediaStorageDriver implements MediaStorageDriver {
  _FakeMediaStorageDriver({this.uploadDelay = Duration.zero});

  final Duration uploadDelay;
  final List<String> uploadedPaths = <String>[];
  final List<String> deletedPaths = <String>[];

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (uploadDelay > Duration.zero) {
      await Future<void>.delayed(uploadDelay);
    }
    uploadedPaths.add(path);
    return 'https://example.com/$path';
  }
}

void main() {
  group('FirebaseMediaService', () {
    test('uploads a supported profile image and returns Firebase metadata',
        () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadProfileImage(
        role: 'visitor',
        email: 'person@example.com',
        bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]),
        fileName: 'avatar.jpg',
      );

      expect(result.downloadUrl,
          contains('profile-images/visitor/person-example.com/avatar.jpg'));
      expect(result.storagePath,
          'profile-images/visitor/person-example.com/avatar.jpg');
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('rejects unsupported audio types', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadAttractionAudio(
          attractionId: 'museum',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'audio.txt',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('times out long-running uploads after thirty seconds', () async {
      final service = FirebaseMediaService(
        driver: _FakeMediaStorageDriver(
          uploadDelay: const Duration(seconds: 31),
        ),
      );

      await expectLater(
        service.uploadAttractionAudio(
          attractionId: 'museum',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'guide.mp3',
        ),
        throwsA(isA<TimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('LocalEventService media cleanup', () {
    test('deleteSubmittedEvent removes stored event media for the owner',
        () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final service = LocalEventService(
        firestore: firestore,
        mediaService: FirebaseMediaService(driver: driver),
      );

      await firestore.collection('events').doc('event-1').set({
        'title': 'Community Concert',
        'date': '12/08/2026',
        'time': '6:00 PM',
        'location': 'South Bank',
        'description': 'Music night',
        'reviewStatus': 'pending',
        'createdByLocalEmail': 'local@brisconnect.com',
        'imageStoragePath':
            'event-images/local-brisconnect.com/event-1/hero.jpg',
      });

      final deleted = await service.deleteSubmittedEvent(
        eventId: 'event-1',
        localEmail: 'local@brisconnect.com',
      );

      expect(deleted, isTrue);
      expect(driver.deletedPaths,
          contains('event-images/local-brisconnect.com/event-1/hero.jpg'));
    });
  });
}
