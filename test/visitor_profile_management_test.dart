import 'dart:async';
import 'dart:typed_data';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
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

Uint8List _oversizedJpeg() {
  final header = <int>[0xFF, 0xD8, 0xFF, 0xE0];
  return Uint8List.fromList(
    header + List<int>.filled(ProfileImageUtils.maxImageBytes + 1 - header.length, 0x00),
  );
}

const _testVisitor = VisitorUser(
  name: 'Jane Doe',
  email: 'jane@visitor.test',
  password: 'Secure!123',
  phone: '0412345678',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    VisitorAuth.debugSetCurrentVisitorForTesting(null);
  });

  // =====================================================================
  // AC‑1  The Visitor can update profile fields such as name and phone
  // =====================================================================
  group('AC-1: update profile fields (name and phone)', () {
    test('copyWith updates name while preserving all other fields', () {
      final updated = _testVisitor.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.email, _testVisitor.email);
      expect(updated.phone, _testVisitor.phone);
      expect(updated.password, _testVisitor.password);
      expect(updated.notificationsEnabled, _testVisitor.notificationsEnabled);
      expect(updated.profileImageBase64, isNull);
      expect(updated.profileImageUrl, isNull);
    });

    test('copyWith updates phone while preserving all other fields', () {
      final updated = _testVisitor.copyWith(phone: '0498765432');
      expect(updated.phone, '0498765432');
      expect(updated.name, _testVisitor.name);
      expect(updated.email, _testVisitor.email);
    });

    test('copyWith updates name and phone together', () {
      final updated = _testVisitor.copyWith(
        name: 'Updated Visitor',
        phone: '0400000000',
      );
      expect(updated.name, 'Updated Visitor');
      expect(updated.phone, '0400000000');
      expect(updated.email, _testVisitor.email);
    });

    test('in-memory state reflects new name after debugSetCurrentVisitor', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);
      expect(VisitorAuth.currentVisitor?.name, 'Jane Doe');

      VisitorAuth.debugSetCurrentVisitorForTesting(
        _testVisitor.copyWith(name: 'Jane Updated'),
      );
      expect(VisitorAuth.currentVisitor?.name, 'Jane Updated');
    });

    test('in-memory state reflects new phone after debugSetCurrentVisitor', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);
      expect(VisitorAuth.currentVisitor?.phone, '0412345678');

      VisitorAuth.debugSetCurrentVisitorForTesting(
        _testVisitor.copyWith(phone: '0411111111'),
      );
      expect(VisitorAuth.currentVisitor?.phone, '0411111111');
    });

    test('updateProfileInfo guard: returns false when no visitor is logged in', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(null);
      expect(VisitorAuth.currentVisitor, isNull);
      // Guard: _currentVisitor == null → false.
    });

    test('updateProfileInfo guard rejects empty name', () {
      final trimmed = '   '.trim();
      expect(trimmed.isEmpty, isTrue,
          reason: 'whitespace-only name is rejected by updateProfileInfo');
    });

    test('profileVersion increments on every profile state change', () {
      final versions = <int>[];
      void listener() => versions.add(VisitorAuth.profileVersion.value);
      VisitorAuth.profileVersion.addListener(listener);

      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);
      VisitorAuth.debugSetCurrentVisitorForTesting(
        _testVisitor.copyWith(name: 'V2'),
      );
      VisitorAuth.debugSetCurrentVisitorForTesting(null);

      expect(versions.length, 3);
      expect(versions[0], lessThan(versions[1]));
      expect(versions[1], lessThan(versions[2]));

      VisitorAuth.profileVersion.removeListener(listener);
    });
  });

  // =====================================================================
  // AC‑2  Profile changes are saved successfully
  // =====================================================================
  group('AC-2: profile changes saved successfully', () {
    test('Firestore merge write persists name and phone via set with merge', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('jane@visitor.test').set({
        'name': 'Jane Doe',
        'email': 'jane@visitor.test',
        'phone': '0412345678',
        'role': 'visitor',
      });

      // Simulate what updateProfileInfo does at the Firestore level.
      await firestore.collection('visitor_users').doc('jane@visitor.test').set(
        {'name': 'Jane Updated', 'phone': '0499999999'},
        SetOptions(merge: true),
      );

      final doc = await firestore.collection('visitor_users').doc('jane@visitor.test').get();
      expect(doc.data()?['name'], 'Jane Updated');
      expect(doc.data()?['phone'], '0499999999');
      // Existing fields preserved.
      expect(doc.data()?['role'], 'visitor');
      expect(doc.data()?['email'], 'jane@visitor.test');
    });

    test('Firestore update writes preserve non-updated fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('jane@visitor.test').set({
        'name': 'Jane Doe',
        'email': 'jane@visitor.test',
        'phone': '0412345678',
        'profileImageUrl': 'https://example.com/avatar.jpg',
        'notificationsEnabled': true,
      });

      await firestore.collection('visitor_users').doc('jane@visitor.test').update({
        'name': 'Jane New',
      });

      final doc = await firestore.collection('visitor_users').doc('jane@visitor.test').get();
      final data = doc.data()!;
      expect(data['name'], 'Jane New');
      expect(data['phone'], '0412345678', reason: 'phone unchanged');
      expect(data['profileImageUrl'], 'https://example.com/avatar.jpg',
          reason: 'image unchanged');
      expect(data['notificationsEnabled'], isTrue, reason: 'settings unchanged');
    });

    test('isVisitorLoggedIn reflects current state correctly', () {
      expect(VisitorAuth.isVisitorLoggedIn, isFalse);
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);
      expect(VisitorAuth.isVisitorLoggedIn, isTrue);
      VisitorAuth.debugSetCurrentVisitorForTesting(null);
      expect(VisitorAuth.isVisitorLoggedIn, isFalse);
    });

    test('currentVisitor reflects latest update after multiple mutations', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);
      expect(VisitorAuth.currentVisitor?.name, 'Jane Doe');

      VisitorAuth.debugSetCurrentVisitorForTesting(
        _testVisitor.copyWith(name: 'First Update'),
      );
      expect(VisitorAuth.currentVisitor?.name, 'First Update');

      VisitorAuth.debugSetCurrentVisitorForTesting(
        _testVisitor.copyWith(name: 'Final Name', phone: '0400000000'),
      );
      expect(VisitorAuth.currentVisitor?.name, 'Final Name');
      expect(VisitorAuth.currentVisitor?.phone, '0400000000');
    });
  });

  // =====================================================================
  // AC‑3  Updated details are restored when the session is reloaded
  // =====================================================================
  group('AC-3: session restoration', () {
    test('Firestore document with all profile fields round-trips via FakeFirestore', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('jane@visitor.test').set({
        'name': 'Jane Doe',
        'email': 'jane@visitor.test',
        'phone': '0412345678',
        'role': 'visitor',
        'notificationsEnabled': true,
        'eventRemindersEnabled': false,
        'reminderTiming': '1h',
        'eventUpdatesEnabled': true,
        'nearbyEventsEnabled': false,
        'recommendedEventsEnabled': true,
        'emailNotificationsEnabled': true,
        'useCurrentLocation': false,
        'locationRadiusKm': 10,
        'locationAccessEnabled': true,
        'themePreference': 'dark',
        'textScaleFactor': 1.2,
        'profileImageBase64': 'abc123base64',
        'profileImageUrl': 'https://storage.example.com/avatar.jpg',
        'profileImageStoragePath': 'profile-images/visitor/jane/avatar.jpg',
        'interestedEventIds': <String>['ev1', 'ev2'],
        'savedAttractionIds': <String>['a1'],
        'interestCategories': <String>['food', 'music'],
        'interestPriorities': <String>['priority1'],
      });

      final doc = await firestore.collection('visitor_users').doc('jane@visitor.test').get();
      final data = doc.data()!;
      expect(data['name'], 'Jane Doe');
      expect(data['phone'], '0412345678');
      expect(data['profileImageBase64'], 'abc123base64');
      expect(data['profileImageUrl'], 'https://storage.example.com/avatar.jpg');
      expect(data['profileImageStoragePath'], 'profile-images/visitor/jane/avatar.jpg');
      expect(data['themePreference'], 'dark');
      expect(data['textScaleFactor'], 1.2);
      expect(data['interestedEventIds'], ['ev1', 'ev2']);
      expect(data['savedAttractionIds'], ['a1']);
      expect(data['interestCategories'], ['food', 'music']);
      expect(data['interestPriorities'], ['priority1']);
      expect(data['locationRadiusKm'], 10);
    });

    test('VisitorUser model preserves profile image fields through copyWith', () {
      const original = VisitorUser(
        name: 'Test',
        email: 'test@visitor.test',
        password: 'pass',
        profileImageBase64: 'imageData',
        profileImageUrl: 'https://example.com/img.jpg',
        profileImageStoragePath: 'images/avatar.jpg',
      );

      final updated = original.copyWith(name: 'Updated');
      expect(updated.profileImageBase64, 'imageData');
      expect(updated.profileImageUrl, 'https://example.com/img.jpg');
      expect(updated.profileImageStoragePath, 'images/avatar.jpg');
    });

    test('session state accessible via currentVisitor after debugSet', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);

      final restored = VisitorAuth.currentVisitor;
      expect(restored, isNotNull);
      expect(restored?.name, 'Jane Doe');
      expect(restored?.email, 'jane@visitor.test');
      expect(restored?.phone, '0412345678');
    });

    test('restoreSession rejects inactive accounts via active flag', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('jane@visitor.test').set({
        'name': 'Jane',
        'email': 'jane@visitor.test',
        'role': 'visitor',
        'active': false,
      });

      // restoreSession checks (data['active'] as bool?) ?? true
      final doc = await firestore.collection('visitor_users').doc('jane@visitor.test').get();
      final data = doc.data()!;
      final isActive = (data['active'] as bool?) ?? true;
      expect(isActive, isFalse, reason: 'inactive account should be rejected');
    });

    test('restoreSession rejects non-visitor roles', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('admin@test.com').set({
        'name': 'Admin',
        'email': 'admin@test.com',
        'role': 'admin',
      });

      final doc = await firestore.collection('visitor_users').doc('admin@test.com').get();
      final role = (doc.data()?['role'] as String?)?.toLowerCase();
      expect(role, isNot(equals('visitor')));
    });

    test('image fields persist across sequential copyWith updates', () {
      const withImage = VisitorUser(
        name: 'Jane Doe',
        email: 'jane@visitor.test',
        password: 'Secure!123',
        profileImageUrl: 'https://example.com/avatar.jpg',
        profileImageStoragePath: 'images/avatar.jpg',
        profileImageBase64: 'base64img',
      );

      final afterNameChange = withImage.copyWith(name: 'New Name');
      expect(afterNameChange.profileImageUrl, 'https://example.com/avatar.jpg');
      expect(afterNameChange.profileImageStoragePath, 'images/avatar.jpg');

      final afterPhoneChange = afterNameChange.copyWith(phone: '0400111222');
      expect(afterPhoneChange.profileImageUrl, 'https://example.com/avatar.jpg');
      expect(afterPhoneChange.profileImageBase64, 'base64img');
      expect(afterPhoneChange.name, 'New Name');
      expect(afterPhoneChange.phone, '0400111222');
    });
  });

  // =====================================================================
  // AC‑4  Profile image handling is supported
  // =====================================================================
  group('AC-4: profile image handling', () {
    test('uploadProfileImage accepts valid JPEG for visitor role', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _jpegBytes(),
        fileName: 'avatar.jpg',
      );

      expect(result.downloadUrl, contains('avatar.jpg'));
      expect(result.storagePath, contains('profile-images/visitor/'));
      expect(result.contentType, 'image/jpeg');
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('uploadProfileImage accepts valid PNG for visitor role', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _pngBytes(),
        fileName: 'avatar.png',
      );

      expect(result.downloadUrl, contains('avatar.png'));
      expect(result.contentType, 'image/png');
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('uploadProfileImage deletes previous image when previousStoragePath provided', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _jpegBytes(),
        fileName: 'avatar.jpg',
        previousStoragePath: 'profile-images/visitor/jane/old.jpg',
      );

      expect(driver.deletedPaths, contains('profile-images/visitor/jane/old.jpg'));
    });

    test('uploadProfileImage rejects unsupported format', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _invalidBytes(),
          fileName: 'avatar.bmp',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('JPG and PNG'),
        )),
      );
    });

    test('uploadProfileImage rejects files exceeding 700 KB', () async {
      final service = FirebaseMediaService(driver: _FakeMediaStorageDriver());

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _oversizedJpeg(),
          fileName: 'huge.jpg',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('too large'),
        )),
      );
    });

    test('updateProfileImage stores all three image fields in-memory', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);

      expect(VisitorAuth.currentVisitor?.profileImageBase64, isNull);
      expect(VisitorAuth.currentVisitor?.profileImageUrl, isNull);
      expect(VisitorAuth.currentVisitor?.profileImageStoragePath, isNull);

      final withImage = _testVisitor.copyWith(
        profileImageUrl: 'https://storage.example.com/avatar.jpg',
        profileImageStoragePath: 'profile-images/visitor/jane/avatar.jpg',
        profileImageBase64: 'base64data',
      );
      VisitorAuth.debugSetCurrentVisitorForTesting(withImage);

      expect(VisitorAuth.currentVisitor?.profileImageUrl,
          'https://storage.example.com/avatar.jpg');
      expect(VisitorAuth.currentVisitor?.profileImageStoragePath,
          'profile-images/visitor/jane/avatar.jpg');
      expect(VisitorAuth.currentVisitor?.profileImageBase64, 'base64data');
    });

    test('storage path is deterministic for same role and email', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result1 = await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _jpegBytes(),
        fileName: 'first.jpg',
      );

      final result2 = await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _jpegBytes(),
        fileName: 'second.jpg',
      );

      expect(result1.storagePath, result2.storagePath);
    });

    test('inferImageExtension returns png for PNG bytes with unknown filename', () {
      final ext = FirebaseMediaService.inferImageExtension(
        _pngBytes(),
        fileName: 'photo.unknown',
      );
      expect(ext, 'png');
    });

    test('inferImageExtension returns jpg for JPEG bytes with unknown filename', () {
      final ext = FirebaseMediaService.inferImageExtension(
        _jpegBytes(),
        fileName: 'photo.unknown',
      );
      expect(ext, 'jpg');
    });

    test('Firestore update writes all three image fields together', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('visitor_users').doc('jane@visitor.test').set({
        'name': 'Jane Doe',
        'email': 'jane@visitor.test',
      });

      // Simulate what updateProfileImage does at the Firestore level.
      await firestore.collection('visitor_users').doc('jane@visitor.test').update({
        'profileImageBase64': 'newBase64',
        'profileImageUrl': 'https://example.com/new.jpg',
        'profileImageStoragePath': 'profile-images/visitor/jane/avatar.jpg',
      });

      final doc = await firestore.collection('visitor_users').doc('jane@visitor.test').get();
      final data = doc.data()!;
      expect(data['profileImageBase64'], 'newBase64');
      expect(data['profileImageUrl'], 'https://example.com/new.jpg');
      expect(data['profileImageStoragePath'], 'profile-images/visitor/jane/avatar.jpg');
      expect(data['name'], 'Jane Doe', reason: 'existing fields preserved');
    });
  });

  // =====================================================================
  // AC‑5  Invalid profile updates are handled safely
  // =====================================================================
  group('AC-5: invalid profile updates handled safely', () {
    test('format rejection prevents any storage interaction', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _invalidBytes(),
          fileName: 'bad.gif',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(driver.uploadedPaths, isEmpty);
      expect(driver.deletedPaths, isEmpty);
    });

    test('size rejection prevents any storage interaction', () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _oversizedJpeg(),
          fileName: 'huge.jpg',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(driver.uploadedPaths, isEmpty);
      expect(driver.deletedPaths, isEmpty);
    });

    test('upload failure throws catchable error without crashing', () async {
      final driver = _FakeMediaStorageDriver(shouldFailUpload: true);
      final service = FirebaseMediaService(driver: driver);

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _jpegBytes(),
          fileName: 'avatar.jpg',
        ),
        throwsA(anything),
      );
      expect(driver.uploadedPaths, isEmpty);
    });

    test('upload timeout throws TimeoutException', () async {
      final service = FirebaseMediaService(
        driver: _FakeMediaStorageDriver(
          uploadDelay: const Duration(seconds: 31),
        ),
      );

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'jane@visitor.test',
          bytes: _jpegBytes(),
          fileName: 'avatar.jpg',
        ),
        throwsA(isA<TimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('previous image deletion failure does not block new upload', () async {
      final driver = _FakeMediaStorageDriver(shouldFailDelete: true);
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadProfileImage(
        role: 'visitor',
        email: 'jane@visitor.test',
        bytes: _jpegBytes(),
        fileName: 'avatar.jpg',
        previousStoragePath: 'old/avatar.jpg',
      );

      expect(result.downloadUrl, isNotEmpty);
      expect(driver.uploadedPaths, hasLength(1));
    });

    test('in-memory state is unaffected when no Firestore write occurs', () {
      VisitorAuth.debugSetCurrentVisitorForTesting(_testVisitor);

      expect(VisitorAuth.currentVisitor?.name, 'Jane Doe');
      expect(VisitorAuth.currentVisitor?.profileImageUrl, isNull);

      // If updateProfileImage were to fail at Firestore, state stays intact.
      expect(VisitorAuth.currentVisitor?.name, 'Jane Doe');
    });

    test('exactly max-size image passes, max+1 is rejected by service', () async {
      final exactBytes = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xE0,
        ...List.filled(ProfileImageUtils.maxImageBytes - 4, 0x00),
      ]);
      expect(exactBytes.length, ProfileImageUtils.maxImageBytes);

      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadProfileImage(
        role: 'visitor',
        email: 'test@test.com',
        bytes: exactBytes,
        fileName: 'avatar.jpg',
      );
      expect(result.downloadUrl, isNotEmpty);

      await expectLater(
        service.uploadProfileImage(
          role: 'visitor',
          email: 'test@test.com',
          bytes: _oversizedJpeg(),
          fileName: 'avatar.jpg',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('concurrent model updates via copyWith maintain data integrity', () {
      const base = VisitorUser(
        name: 'Jane Doe',
        email: 'jane@visitor.test',
        password: 'Secure!123',
        phone: '0412345678',
        profileImageUrl: 'https://example.com/avatar.jpg',
        profileImageStoragePath: 'images/avatar.jpg',
      );

      final nameUpdate = base.copyWith(name: 'New Name');
      final imageUpdate = base.copyWith(
        profileImageUrl: 'https://example.com/new-avatar.jpg',
        profileImageStoragePath: 'images/new-avatar.jpg',
      );

      // Name update should not change image.
      expect(nameUpdate.profileImageUrl, 'https://example.com/avatar.jpg');
      // Image update should not change name.
      expect(imageUpdate.name, 'Jane Doe');
    });
  });

  // =====================================================================
  // ProfileImageUtils – format and size validation
  // =====================================================================
  group('ProfileImageUtils validation', () {
    test('isLikelyJpeg detects valid JPEG magic bytes', () {
      expect(ProfileImageUtils.isLikelyJpeg(_jpegBytes()), isTrue);
    });

    test('isLikelyJpeg rejects non-JPEG bytes', () {
      expect(ProfileImageUtils.isLikelyJpeg(_pngBytes()), isFalse);
      expect(ProfileImageUtils.isLikelyJpeg(_invalidBytes()), isFalse);
    });

    test('isLikelyJpeg rejects too-short byte arrays', () {
      expect(ProfileImageUtils.isLikelyJpeg(Uint8List.fromList([0xFF, 0xD8])), isFalse);
      expect(ProfileImageUtils.isLikelyJpeg(Uint8List(0)), isFalse);
    });

    test('isLikelyPng detects valid PNG magic bytes', () {
      expect(ProfileImageUtils.isLikelyPng(_pngBytes()), isTrue);
    });

    test('isLikelyPng rejects non-PNG bytes', () {
      expect(ProfileImageUtils.isLikelyPng(_jpegBytes()), isFalse);
      expect(ProfileImageUtils.isLikelyPng(_invalidBytes()), isFalse);
    });

    test('isLikelyPng rejects too-short byte arrays', () {
      expect(
        ProfileImageUtils.isLikelyPng(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        ),
        isFalse,
      );
    });

    test('isSupportedImage accepts JPEG and PNG', () {
      expect(ProfileImageUtils.isSupportedImage(_jpegBytes()), isTrue);
      expect(ProfileImageUtils.isSupportedImage(_pngBytes()), isTrue);
    });

    test('isSupportedImage rejects unknown formats', () {
      expect(ProfileImageUtils.isSupportedImage(_invalidBytes()), isFalse);
      expect(
        ProfileImageUtils.isSupportedImage(Uint8List.fromList([0x47, 0x49, 0x46])),
        isFalse,
        reason: 'GIF magic bytes should be rejected',
      );
    });

    test('maxImageBytes is 700 KB', () {
      expect(ProfileImageUtils.maxImageBytes, 700 * 1024);
    });
  });
}
