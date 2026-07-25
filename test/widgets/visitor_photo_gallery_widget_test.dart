import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/visitor_photo_service.dart';
import 'package:brisconnect/widgets/visitor_photo_gallery_widget.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockImagePicker extends Mock implements ImagePicker {}

class _FakeMediaStorageDriver implements MediaStorageDriver {
  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async =>
      'https://fake.storage/$path';

  @override
  Future<void> delete(String path) async {}
}

Uint8List _oneByOnePng() {
  // 1x1 transparent PNG — valid for Flutter's image codec.
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
    0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0x06,
    0x77, 0x9C, 0x96, 0x7E, 0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}

XFile _fakeXFile(String name, Uint8List bytes) {
  return XFile.fromData(bytes, name: name, mimeType: 'image/jpeg');
}

VisitorPhotoService _createService({
  required FakeFirebaseFirestore firestore,
  required ImagePicker imagePicker,
  String visitorId = 'visitor_1',
}) {
  final auth = _MockFirebaseAuth();
  final user = _MockUser();
  when(() => user.uid).thenReturn(visitorId);
  when(() => user.email).thenReturn('visitor@example.com');
  when(() => auth.currentUser).thenReturn(user);

  return VisitorPhotoService(
    firestore: firestore,
    auth: auth,
    mediaService: FirebaseMediaService(driver: _FakeMediaStorageDriver()),
    imagePicker: imagePicker,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisitorPhotoGalleryWidget', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockImagePicker mockPicker;
    late VisitorPhotoService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockPicker = _MockImagePicker();
      service = _createService(
        firestore: fakeFirestore,
        imagePicker: mockPicker,
      );
      VisitorAuth.debugSetCurrentVisitorForTesting(const VisitorUser(
        name: 'Alice',
        email: 'visitor@example.com',
        password: '',
      ));
    });

    tearDown(() {
      VisitorAuth.debugSetCurrentVisitorForTesting(null);
    });

    testWidgets('shows empty state and upload button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorPhotoGalleryWidget(
              businessId: 'biz_1',
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Visitor Photos'), findsOneWidget);
      expect(find.text('Be the first to share a photo'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('displays approved photos in horizontal list', (tester) async {
      await fakeFirestore.collection('visitor_photos').add({
        'businessId': 'biz_1',
        'visitorId': 'visitor_1',
        'visitorName': 'Alice',
        'imageUrl': 'https://example.com/photo.jpg',
        'storagePath': 'p/photo.jpg',
        'mimeType': 'image/jpeg',
        'fileSize': 100,
        'status': 'approved',
        'caption': 'Yum',
        'createdAt': DateTime.now(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorPhotoGalleryWidget(
              businessId: 'biz_1',
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.text('Yum'), findsOneWidget);
      expect(find.text('Add Photo'), findsOneWidget);
    });

    testWidgets('upload flow picks image and creates pending photo',
        (tester) async {
      final bytes = _oneByOnePng();
      when(() => mockPicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1600,
            maxHeight: 1600,
          )).thenAnswer((_) async => _fakeXFile('dish.jpg', bytes));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorPhotoGalleryWidget(
              businessId: 'biz_1',
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Share a photo'), findsOneWidget);

      await tester.tap(find.text('Tap to choose a photo'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Great food',
      );
      await tester.tap(find.text('Upload Photo'));
      await tester.pumpAndSettle();

      final docs = await fakeFirestore
          .collection('visitor_photos')
          .where('businessId', isEqualTo: 'biz_1')
          .get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first.data()['caption'], 'Great food');
      expect(docs.docs.first.data()['status'], 'pending');
    });

    testWidgets('shows sign-in prompt when visitor is not logged in',
        (tester) async {
      VisitorAuth.debugSetCurrentVisitorForTesting(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorPhotoGalleryWidget(
              businessId: 'biz_1',
              service: service,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Please log in as a Visitor to upload photos.'),
          findsOneWidget);
    });
  });
}
