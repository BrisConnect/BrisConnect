import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _FakeMediaStorageDriver implements MediaStorageDriver {
  final Map<String, Uint8List> uploads = {};

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads[path] = bytes;
    return 'https://fake.storage/$path';
  }

  @override
  Future<void> delete(String path) async {
    uploads.remove(path);
  }
}

Uint8List _jpgBytes() {
  // Minimal valid JPEG header.
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
    0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
  ]);
}

Uint8List _pngBytes() {
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  ]);
}

Uint8List _webpBytes() {
  return Uint8List.fromList([
    0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00,
    0x57, 0x45, 0x42, 0x50, 0x00, 0x00, 0x00, 0x00,
  ]);
}

VisitorPhotoService _createService({
  required FakeFirebaseFirestore firestore,
  required _FakeMediaStorageDriver driver,
  String visitorId = 'visitor_1',
  String email = 'visitor@example.com',
}) {
  final auth = _MockFirebaseAuth();
  final user = _MockUser();
  when(() => user.uid).thenReturn(visitorId);
  when(() => user.email).thenReturn(email);
  when(() => auth.currentUser).thenReturn(user);

  return VisitorPhotoService(
    firestore: firestore,
    auth: auth,
    mediaService: FirebaseMediaService(driver: driver),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisitorPhotoService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _FakeMediaStorageDriver fakeDriver;
    late VisitorPhotoService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeDriver = _FakeMediaStorageDriver();
      service = _createService(
        firestore: fakeFirestore,
        driver: fakeDriver,
      );
    });

    group('uploadPhoto', () {
      test('stores business photo with pending status', () async {
        final bytes = _jpgBytes();
        final photo = await service.uploadPhoto(
          bytes: bytes,
          fileName: 'dish.jpg',
          mimeType: 'image/jpeg',
          businessId: 'biz_1',
          caption: 'Great pasta',
          visitorName: 'Alice',
        );

        expect(photo.businessId, 'biz_1');
        expect(photo.eventId, isNull);
        expect(photo.visitorId, 'visitor_1');
        expect(photo.visitorName, 'Alice');
        expect(photo.caption, 'Great pasta');
        expect(photo.status, 'pending');
        expect(photo.mimeType, 'image/jpeg');
        expect(photo.imageUrl, startsWith('https://fake.storage/'));
        expect(photo.storagePath, contains('visitor_photos'));
        expect(fakeDriver.uploads.containsKey(photo.storagePath), true);

        final doc = await fakeFirestore
            .collection('visitor_photos')
            .doc(photo.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()!['status'], 'pending');
      });

      test('stores event photo with pending status', () async {
        final bytes = _pngBytes();
        final photo = await service.uploadPhoto(
          bytes: bytes,
          fileName: 'event.png',
          mimeType: 'image/png',
          eventId: 'evt_1',
          visitorName: 'Bob',
        );

        expect(photo.eventId, 'evt_1');
        expect(photo.businessId, isNull);
        expect(photo.visitorId, 'visitor_1');
        expect(photo.mimeType, 'image/png');
      });

      test('rejects upload when not signed in', () async {
        final unsignedService = VisitorPhotoService(
          firestore: fakeFirestore,
          mediaService: FirebaseMediaService(driver: fakeDriver),
          auth: _MockFirebaseAuth(),
        );

        expect(
          () => unsignedService.uploadPhoto(
            bytes: _jpgBytes(),
            fileName: 'x.jpg',
            mimeType: 'image/jpeg',
            businessId: 'biz_1',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('signed in as a Visitor'),
          )),
        );
      });

      test('rejects unsupported formats', () async {
        expect(
          () => service.uploadPhoto(
            bytes: Uint8List.fromList([0x00, 0x01, 0x02]),
            fileName: 'doc.gif',
            mimeType: 'image/gif',
            businessId: 'biz_1',
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('rejects oversized images', () async {
        final huge = Uint8List(6 * 1024 * 1024);
        huge[0] = 0xFF;
        huge[1] = 0xD8;
        huge[2] = 0xFF;
        expect(
          () => service.uploadPhoto(
            bytes: huge,
            fileName: 'huge.jpg',
            mimeType: 'image/jpeg',
            businessId: 'biz_1',
          ),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('5 MB'),
          )),
        );
      });

      test('rejects both or missing targets', () async {
        expect(
          () => service.uploadPhoto(
            bytes: _jpgBytes(),
            fileName: 'x.jpg',
            mimeType: 'image/jpeg',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('businessId or an eventId'),
          )),
        );

        expect(
          () => service.uploadPhoto(
            bytes: _jpgBytes(),
            fileName: 'x.jpg',
            mimeType: 'image/jpeg',
            businessId: 'biz_1',
            eventId: 'evt_1',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('businessId or an eventId'),
          )),
        );
      });

      test('rejects captions that are too long', () async {
        expect(
          () => service.uploadPhoto(
            bytes: _jpgBytes(),
            fileName: 'x.jpg',
            mimeType: 'image/jpeg',
            businessId: 'biz_1',
            caption: 'a' * 201,
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Caption must be'),
          )),
        );
      });
    });

    group('getApprovedPhotosForBusiness', () {
      test('streams only approved business photos sorted newest first',
          () async {
        await fakeFirestore.collection('visitor_photos').add({
          'businessId': 'biz_1',
          'visitorId': 'visitor_1',
          'visitorName': 'Alice',
          'imageUrl': 'https://example.com/1.jpg',
          'storagePath': 'p/1.jpg',
          'mimeType': 'image/jpeg',
          'fileSize': 100,
          'status': 'approved',
          'createdAt': DateTime(2026, 1, 1),
        });
        await fakeFirestore.collection('visitor_photos').add({
          'businessId': 'biz_1',
          'visitorId': 'visitor_2',
          'visitorName': 'Bob',
          'imageUrl': 'https://example.com/2.jpg',
          'storagePath': 'p/2.jpg',
          'mimeType': 'image/jpeg',
          'fileSize': 100,
          'status': 'pending',
          'createdAt': DateTime(2026, 1, 2),
        });
        await fakeFirestore.collection('visitor_photos').add({
          'businessId': 'biz_2',
          'visitorId': 'visitor_1',
          'visitorName': 'Alice',
          'imageUrl': 'https://example.com/3.jpg',
          'storagePath': 'p/3.jpg',
          'mimeType': 'image/jpeg',
          'fileSize': 100,
          'status': 'approved',
          'createdAt': DateTime(2026, 1, 3),
        });

        final photos = await service.getApprovedPhotosForBusiness('biz_1').first;
        expect(photos.length, 1);
        expect(photos.first.visitorName, 'Alice');
      });
    });

    group('deletePhoto', () {
      test('author can delete their own photo', () async {
        final photo = await service.uploadPhoto(
          bytes: _jpgBytes(),
          fileName: 'x.jpg',
          mimeType: 'image/jpeg',
          businessId: 'biz_1',
        );
        expect(fakeDriver.uploads.containsKey(photo.storagePath), true);

        await service.deletePhoto(photo.id);
        final doc = await fakeFirestore
            .collection('visitor_photos')
            .doc(photo.id)
            .get();
        expect(doc.exists, false);
        expect(fakeDriver.uploads.containsKey(photo.storagePath), false);
      });

      test('non-author cannot delete another visitor photo', () async {
        final photo = await service.uploadPhoto(
          bytes: _jpgBytes(),
          fileName: 'x.jpg',
          mimeType: 'image/jpeg',
          businessId: 'biz_1',
        );

        final otherService = _createService(
          firestore: fakeFirestore,
          driver: fakeDriver,
          visitorId: 'visitor_2',
        );

        expect(
          () => otherService.deletePhoto(photo.id),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('only delete your own'),
          )),
        );
      });
    });

    group('WebP support', () {
      test('accepts WebP images', () async {
        final bytes = _webpBytes();
        final photo = await service.uploadPhoto(
          bytes: bytes,
          fileName: 'dish.webp',
          mimeType: 'image/webp',
          businessId: 'biz_1',
        );
        expect(photo.mimeType, 'image/webp');
        expect(photo.storagePath, endsWith('.webp'));
      });
    });
  });
}
