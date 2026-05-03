import 'dart:typed_data';

import 'package:brisconnect/services/admin_attraction_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/utils/narration_builder.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake media driver (matches established project pattern)
// ---------------------------------------------------------------------------
class _FakeMediaStorageDriver implements MediaStorageDriver {
  final List<String> uploadedPaths = <String>[];
  final List<String> deletedPaths = <String>[];
  bool shouldFailDelete = false;

  @override
  Future<void> delete(String path) async {
    if (shouldFailDelete) {
      throw Exception('Delete failed');
    }
    deletedPaths.add(path);
  }

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadedPaths.add(path);
    return 'https://example.com/$path';
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seed a single attraction document with sensible defaults.
Future<void> _seedAttraction(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  String description = 'A great place to visit.',
  String location = 'Brisbane CBD',
  double latitude = -27.4698,
  double longitude = 153.0251,
  String approvalStatus = 'approved',
  String? category,
  String? imageUrl,
  String? imageStoragePath,
  String? audioUrl,
  String? audioStoragePath,
  String? webLink,
  List<String>? accessibilityDetails,
}) async {
  await firestore.collection('attractions').doc(id).set({
    'name': name,
    'description': description,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'approvalStatus': approvalStatus,
    if (category != null) 'category': category,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (imageStoragePath != null) 'imageStoragePath': imageStoragePath,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (audioStoragePath != null) 'audioStoragePath': audioStoragePath,
    if (webLink != null) 'webLink': webLink,
    if (accessibilityDetails != null)
      'accessibilityDetails': accessibilityDetails,
  });
}

AdminAttractionService _createService(
  FakeFirebaseFirestore firestore, {
  FirebaseMediaService? mediaService,
}) {
  return AdminAttractionService(
    firestore: firestore,
    mediaService: mediaService,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // =========================================================================
  // AC-1 : Admin can add a new attraction
  // =========================================================================
  group('AC-1: Add a new attraction', () {
    test('addAttraction creates a document in the attractions collection',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'City Botanic Gardens',
        description: 'Lush riverside gardens',
        location: 'Alice St, Brisbane',
        latitude: -27.4729,
        longitude: 153.0297,
      );

      final snapshot = await firestore.collection('attractions').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['name'], 'City Botanic Gardens');
    });

    test('addAttraction auto-generates a slug ID from the name', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'South Bank Parklands',
        description: 'River-front park',
        location: 'South Brisbane',
        latitude: -27.4804,
        longitude: 153.0229,
      );

      final doc =
          await firestore.collection('attractions').doc('south-bank-parklands').get();
      expect(doc.exists, isTrue);
    });

    test('addAttraction sets all three approval status fields and isApproved',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'GOMA',
        description: 'Gallery of Modern Art',
        location: 'Stanley Place',
        latitude: -27.4719,
        longitude: 153.0174,
      );

      final data =
          (await firestore.collection('attractions').doc('goma').get()).data()!;
      expect(data['approvalStatus'], 'approved');
      expect(data['status'], 'approved');
      expect(data['reviewStatus'], 'approved');
      expect(data['isApproved'], true);
    });

    test('addAttraction persists all core fields', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'Lone Pine Koala Sanctuary',
        description: 'World-famous wildlife sanctuary',
        location: 'Fig Tree Pocket',
        latitude: -27.5340,
        longitude: 152.9690,
        category: 'Nature',
        webLink: 'https://lonepinekoalasanctuary.com',
      );

      final docs = await firestore.collection('attractions').get();
      final data = docs.docs.first.data();
      expect(data['name'], 'Lone Pine Koala Sanctuary');
      expect(data['title'], 'Lone Pine Koala Sanctuary');
      expect(data['description'], 'World-famous wildlife sanctuary');
      expect(data['location'], 'Fig Tree Pocket');
      expect(data['latitude'], -27.5340);
      expect(data['longitude'], 152.9690);
      expect(data['category'], 'Nature');
      expect(data['webLink'], 'https://lonepinekoalasanctuary.com');
    });

    test('addAttraction generates and persists aiNarration', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'Story Bridge',
        description: 'Heritage-listed cantilever bridge',
        location: 'Kangaroo Point',
        latitude: -27.4630,
        longitude: 153.0340,
        category: 'Landmarks',
      );

      final data =
          (await firestore.collection('attractions').doc('story-bridge').get())
              .data()!;
      final expected = buildAttractionNarration(
        name: 'Story Bridge',
        category: 'Landmarks',
        description: 'Heritage-listed cantilever bridge',
        location: 'Kangaroo Point',
      );
      expect(data['aiNarration'], expected);
      expect(data['aiNarration'], contains('Story Bridge'));
    });

    test('addAttraction trims whitespace from string fields', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: '  Roma Street Parkland  ',
        description: '  Subtropical garden  ',
        location: '  Roma Street  ',
        latitude: -27.4620,
        longitude: 153.0170,
        category: '  Nature  ',
      );

      final docs = await firestore.collection('attractions').get();
      final data = docs.docs.first.data();
      expect(data['name'], 'Roma Street Parkland');
      expect(data['description'], 'Subtropical garden');
      expect(data['location'], 'Roma Street');
      expect(data['category'], 'Nature');
    });

    test('addAttraction persists accessibility details list', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'Wheel of Brisbane',
        description: 'Observation wheel at South Bank',
        location: 'South Bank Parklands',
        latitude: -27.4760,
        longitude: 153.0220,
        accessibilityDetails: ['Wheelchair ramp', 'Audio descriptions'],
      );

      final docs = await firestore.collection('attractions').get();
      final data = docs.docs.first.data();
      expect(data['accessibilityDetails'],
          containsAll(['Wheelchair ramp', 'Audio descriptions']));
    });

    test('addAttraction handles slug generation for special characters',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: "Queen's Wharf & Casino",
        description: 'Integrated resort',
        location: 'Brisbane CBD',
        latitude: -27.4718,
        longitude: 153.0210,
      );

      // Apostrophes stripped, special chars become dashes
      final snapshot = await firestore.collection('attractions').get();
      expect(snapshot.docs.length, 1);
      final id = snapshot.docs.first.id;
      expect(id, isNot(contains("'")));
      expect(id, isNot(contains('&')));
    });
  });

  // =========================================================================
  // AC-2 : Admin can edit an existing attraction
  // =========================================================================
  group('AC-2: Edit an existing attraction', () {
    test('updateAttraction updates name and description', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a1', name: 'Old Name');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a1',
        name: 'New Name',
        description: 'Updated description',
        location: 'Brisbane CBD',
        latitude: -27.4698,
        longitude: 153.0251,
      );

      final data =
          (await firestore.collection('attractions').doc('a1').get()).data()!;
      expect(data['name'], 'New Name');
      expect(data['title'], 'New Name');
      expect(data['description'], 'Updated description');
    });

    test('updateAttraction updates location and coordinates', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a2', name: 'City Hall');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a2',
        name: 'City Hall',
        description: 'Historic civic building',
        location: 'King George Square',
        latitude: -27.4688,
        longitude: 153.0235,
      );

      final data =
          (await firestore.collection('attractions').doc('a2').get()).data()!;
      expect(data['location'], 'King George Square');
      expect(data['latitude'], -27.4688);
      expect(data['longitude'], 153.0235);
    });

    test('updateAttraction updates category', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a3', name: 'GOMA');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a3',
        name: 'GOMA',
        description: 'Gallery of Modern Art',
        location: 'Stanley Place',
        latitude: -27.4719,
        longitude: 153.0174,
        category: 'Arts & Culture',
      );

      final data =
          (await firestore.collection('attractions').doc('a3').get()).data()!;
      expect(data['category'], 'Arts & Culture');
    });

    test('updateAttraction regenerates aiNarration with new values', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a4', name: 'Old Bridge');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a4',
        name: 'Story Bridge',
        description: 'Heritage cantilever bridge',
        location: 'Kangaroo Point',
        latitude: -27.4630,
        longitude: 153.0340,
        category: 'Landmarks',
        webLink: 'https://storybridge.com.au',
      );

      final data =
          (await firestore.collection('attractions').doc('a4').get()).data()!;
      final expected = buildAttractionNarration(
        name: 'Story Bridge',
        category: 'Landmarks',
        description: 'Heritage cantilever bridge',
        location: 'Kangaroo Point',
        webLink: 'https://storybridge.com.au',
      );
      expect(data['aiNarration'], expected);
    });

    test('updateAttraction preserves approval status as approved', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a5', name: 'Mt Coot-tha');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a5',
        name: 'Mt Coot-tha Lookout',
        description: 'Panoramic city views',
        location: 'Mt Coot-tha',
        latitude: -27.4776,
        longitude: 152.9578,
      );

      final data =
          (await firestore.collection('attractions').doc('a5').get()).data()!;
      expect(data['approvalStatus'], 'approved');
      expect(data['status'], 'approved');
      expect(data['reviewStatus'], 'approved');
      expect(data['isApproved'], true);
    });

    test('updateAttraction throws StateError when doc does not exist',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      expect(
        () => service.updateAttraction(
          attractionId: 'nonexistent',
          name: 'Ghost',
          description: 'Does not exist',
          location: 'Nowhere',
          latitude: 0,
          longitude: 0,
        ),
        throwsStateError,
      );
    });

    test('updateAttraction updates media-related fields', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a6', name: 'South Bank');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a6',
        name: 'South Bank',
        description: 'Updated',
        location: 'South Brisbane',
        latitude: -27.4804,
        longitude: 153.0229,
        imageUrl: 'https://example.com/image.jpg',
        imageStoragePath: 'attractions/south-bank/hero.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        audioStoragePath: 'attraction-media/south-bank/audio-guide.mp3',
      );

      final data =
          (await firestore.collection('attractions').doc('a6').get()).data()!;
      expect(data['imageUrl'], 'https://example.com/image.jpg');
      expect(data['imageStoragePath'], 'attractions/south-bank/hero.jpg');
      expect(data['audioUrl'], 'https://example.com/audio.mp3');
      expect(data['audioStoragePath'],
          'attraction-media/south-bank/audio-guide.mp3');
    });

    test('updateAttraction updates accessibility details', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a7', name: 'Museum');
      final service = _createService(firestore);

      await service.updateAttraction(
        attractionId: 'a7',
        name: 'Queensland Museum',
        description: 'Natural history and cultural museum',
        location: 'South Brisbane',
        latitude: -27.4713,
        longitude: 153.0170,
        accessibilityDetails: ['Wheelchair accessible', 'Braille guides'],
      );

      final data =
          (await firestore.collection('attractions').doc('a7').get()).data()!;
      expect(data['accessibilityDetails'],
          containsAll(['Wheelchair accessible', 'Braille guides']));
    });
  });

  // =========================================================================
  // AC-3 : Admin can delete an attraction
  // =========================================================================
  group('AC-3: Delete an attraction', () {
    test('deleteAttraction removes document from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'del-1', name: 'To Delete');
      final service = _createService(firestore);

      await service.deleteAttraction('del-1');

      final doc =
          await firestore.collection('attractions').doc('del-1').get();
      expect(doc.exists, isFalse);
    });

    test('deleteAttraction cleans up image storage path via media service',
        () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final media = FirebaseMediaService(driver: driver);

      await _seedAttraction(
        firestore,
        id: 'del-2',
        name: 'With Image',
        imageStoragePath: 'attractions/with-image/hero.jpg',
      );

      final service = _createService(firestore, mediaService: media);
      await service.deleteAttraction('del-2');

      expect(driver.deletedPaths, contains('attractions/with-image/hero.jpg'));
    });

    test('deleteAttraction cleans up audio storage path via media service',
        () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final media = FirebaseMediaService(driver: driver);

      await _seedAttraction(
        firestore,
        id: 'del-3',
        name: 'With Audio',
        audioStoragePath: 'attraction-media/with-audio/audio-guide.mp3',
      );

      final service = _createService(firestore, mediaService: media);
      await service.deleteAttraction('del-3');

      expect(driver.deletedPaths,
          contains('attraction-media/with-audio/audio-guide.mp3'));
    });

    test('deleteAttraction cleans up both image and audio storage paths',
        () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final media = FirebaseMediaService(driver: driver);

      await _seedAttraction(
        firestore,
        id: 'del-4',
        name: 'Full Media',
        imageStoragePath: 'attractions/full-media/hero.jpg',
        audioStoragePath: 'attraction-media/full-media/audio-guide.mp3',
      );

      final service = _createService(firestore, mediaService: media);
      await service.deleteAttraction('del-4');

      expect(driver.deletedPaths.length, 2);
      expect(
          driver.deletedPaths, contains('attractions/full-media/hero.jpg'));
      expect(driver.deletedPaths,
          contains('attraction-media/full-media/audio-guide.mp3'));
    });

    test('deleteAttraction without media paths does not call deleteMedia',
        () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final media = FirebaseMediaService(driver: driver);

      await _seedAttraction(firestore, id: 'del-5', name: 'No Media');

      final service = _createService(firestore, mediaService: media);
      await service.deleteAttraction('del-5');

      expect(driver.deletedPaths, isEmpty);
    });

    test('deleteAttraction throws StateError for nonexistent document',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      expect(
        () => service.deleteAttraction('nonexistent'),
        throwsStateError,
      );
    });
  });

  // =========================================================================
  // AC-4 : Attraction records support media-related fields
  // =========================================================================
  group('AC-4: Media-related fields (image & audio metadata)', () {
    test('addAttraction persists imageUrl and imageStoragePath', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'City Hall',
        description: 'Heritage building',
        location: 'King George Square',
        latitude: -27.4688,
        longitude: 153.0235,
        imageUrl: 'https://example.com/city-hall.jpg',
        imageStoragePath: 'attractions/city-hall/hero.jpg',
      );

      final data = (await firestore.collection('attractions').get())
          .docs
          .first
          .data();
      expect(data['imageUrl'], 'https://example.com/city-hall.jpg');
      expect(data['imageStoragePath'], 'attractions/city-hall/hero.jpg');
    });

    test('addAttraction persists audioUrl and audioStoragePath', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      await service.addAttraction(
        name: 'Story Bridge',
        description: 'Heritage bridge with audio tour',
        location: 'Kangaroo Point',
        latitude: -27.4630,
        longitude: 153.0340,
        audioUrl: 'https://example.com/story-bridge.mp3',
        audioStoragePath: 'attraction-media/story-bridge/audio-guide.mp3',
      );

      final data = (await firestore.collection('attractions').get())
          .docs
          .first
          .data();
      expect(data['audioUrl'], 'https://example.com/story-bridge.mp3');
      expect(data['audioStoragePath'],
          'attraction-media/story-bridge/audio-guide.mp3');
    });

    test('fromDoc parses imageUrl and imageStoragePath from Firestore doc',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(
        firestore,
        id: 'media-1',
        name: 'Media Attraction',
        imageUrl: 'https://example.com/hero.jpg',
        imageStoragePath: 'attractions/media-1/hero.jpg',
      );

      final doc =
          await firestore.collection('attractions').doc('media-1').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.imageUrl, 'https://example.com/hero.jpg');
      expect(item.imageStoragePath, 'attractions/media-1/hero.jpg');
    });

    test('fromDoc parses audioUrl and audioStoragePath from Firestore doc',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(
        firestore,
        id: 'media-2',
        name: 'Audio Attraction',
        audioUrl: 'https://example.com/guide.mp3',
        audioStoragePath: 'attraction-media/media-2/audio-guide.mp3',
      );

      final doc =
          await firestore.collection('attractions').doc('media-2').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.audioUrl, 'https://example.com/guide.mp3');
      expect(item.audioStoragePath, 'attraction-media/media-2/audio-guide.mp3');
    });

    test('fromDoc returns null for missing media fields gracefully', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'media-3', name: 'No Media');

      final doc =
          await firestore.collection('attractions').doc('media-3').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.imageUrl, isNull);
      expect(item.imageStoragePath, isNull);
      expect(item.audioUrl, isNull);
      expect(item.audioStoragePath, isNull);
    });

    test('updateAttraction can clear media fields by setting null', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(
        firestore,
        id: 'media-4',
        name: 'Had Media',
        imageUrl: 'https://example.com/old.jpg',
        audioUrl: 'https://example.com/old.mp3',
      );

      final service = _createService(firestore);
      await service.updateAttraction(
        attractionId: 'media-4',
        name: 'Had Media',
        description: 'Updated without media',
        location: 'Brisbane',
        latitude: -27.47,
        longitude: 153.02,
        imageUrl: null,
        audioUrl: null,
      );

      final data =
          (await firestore.collection('attractions').doc('media-4').get())
              .data()!;
      expect(data['imageUrl'], isNull);
      expect(data['audioUrl'], isNull);
    });

    test('FirebaseMediaService validates supported audio file extensions',
        () {
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.mp3'), isTrue);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.wav'), isTrue);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.m4a'), isTrue);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.aac'), isTrue);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.ogg'), isTrue);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.exe'), isFalse);
      expect(FirebaseMediaService.isSupportedAudioFileName('guide.pdf'), isFalse);
    });

    test('FirebaseMediaService rejects unsupported audio extension', () {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      expect(
        () => service.uploadAttractionAudio(
          attractionId: 'test',
          bytes: Uint8List(100),
          fileName: 'guide.exe',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('FirebaseMediaService rejects oversized audio file', () {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      expect(
        () => service.uploadAttractionAudio(
          attractionId: 'test',
          bytes: Uint8List(9 * 1024 * 1024), // 9 MB > 8 MB limit
          fileName: 'guide.mp3',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('FirebaseMediaService uploads attraction audio successfully',
        () async {
      final driver = _FakeMediaStorageDriver();
      final service = FirebaseMediaService(driver: driver);

      final result = await service.uploadAttractionAudio(
        attractionId: 'story-bridge',
        bytes: Uint8List(1024),
        fileName: 'narration.mp3',
      );

      expect(result.downloadUrl, contains('attraction-media'));
      expect(result.storagePath,
          'attraction-media/story-bridge/audio-guide.mp3');
      expect(result.contentType, 'audio/mpeg');
      expect(driver.uploadedPaths, hasLength(1));
    });
  });

  // =========================================================================
  // AC-5 : Admin can view attraction items in a management list
  // =========================================================================
  group('AC-5: View attractions in management list', () {
    test('watchAllAttractions returns an empty list for no documents',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      final items = await service.watchAllAttractions().first;
      expect(items, isEmpty);
    });

    test('watchAllAttractions returns all seeded attractions', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a1', name: 'Alpha');
      await _seedAttraction(firestore, id: 'a2', name: 'Beta');
      await _seedAttraction(firestore, id: 'a3', name: 'Gamma');

      final service = _createService(firestore);
      final items = await service.watchAllAttractions().first;
      expect(items.length, 3);
    });

    test('watchAllAttractions sorts results alphabetically by name', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'c', name: 'Zephyr');
      await _seedAttraction(firestore, id: 'a', name: 'Alpha');
      await _seedAttraction(firestore, id: 'b', name: 'Mango');

      final service = _createService(firestore);
      final items = await service.watchAllAttractions().first;
      expect(items.map((i) => i.name).toList(),
          ['Alpha', 'Mango', 'Zephyr']);
    });

    test('watchAllAttractions skips docs with empty name', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'valid', name: 'Valid');
      await firestore.collection('attractions').doc('invalid').set({
        'name': '',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final service = _createService(firestore);
      final items = await service.watchAllAttractions().first;
      expect(items.length, 1);
      expect(items.first.name, 'Valid');
    });

    test('watchAllAttractions skips docs without latitude/longitude',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'valid', name: 'Valid');
      await firestore.collection('attractions').doc('nolat').set({
        'name': 'No Location',
        'description': 'Missing coords',
      });

      final service = _createService(firestore);
      final items = await service.watchAllAttractions().first;
      expect(items.length, 1);
      expect(items.first.name, 'Valid');
    });

    test('watchAllAttractions maps all fields correctly', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(
        firestore,
        id: 'full',
        name: 'Full Record',
        description: 'All fields populated',
        location: 'Brisbane',
        latitude: -27.47,
        longitude: 153.02,
        category: 'Cultural',
        imageUrl: 'https://example.com/img.jpg',
        imageStoragePath: 'attractions/full/hero.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        audioStoragePath: 'attraction-media/full/audio-guide.mp3',
        webLink: 'https://example.com',
        accessibilityDetails: ['Ramp', 'Audio guide'],
        approvalStatus: 'approved',
      );

      final service = _createService(firestore);
      final items = await service.watchAllAttractions().first;
      expect(items.length, 1);
      final item = items.first;
      expect(item.id, 'full');
      expect(item.name, 'Full Record');
      expect(item.description, 'All fields populated');
      expect(item.location, 'Brisbane');
      expect(item.latitude, -27.47);
      expect(item.longitude, 153.02);
      expect(item.category, 'Cultural');
      expect(item.imageUrl, 'https://example.com/img.jpg');
      expect(item.audioUrl, 'https://example.com/audio.mp3');
      expect(item.webLink, 'https://example.com');
      expect(item.accessibilityDetails, containsAll(['Ramp', 'Audio guide']));
      expect(item.isApproved, isTrue);
    });

    test('watchAllAttractions emits updated list when new doc is added',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedAttraction(firestore, id: 'a1', name: 'First');

      final service = _createService(firestore);

      final first = await service.watchAllAttractions().first;
      expect(first.length, 1);

      await _seedAttraction(firestore, id: 'a2', name: 'Second');

      final second = await service.watchAllAttractions().first;
      expect(second.length, 2);
    });
  });

  // =========================================================================
  // AC-6 : Operations are efficient and maintain data accuracy
  // =========================================================================
  group('AC-6: Efficient operations and data accuracy', () {
    test('fromDoc handles field aliases: title instead of name', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-1').set({
        'title': 'Alias Title',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-1').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.name, 'Alias Title');
    });

    test('fromDoc handles field aliases: lat/lng instead of latitude/longitude',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-2').set({
        'name': 'Lat Lng Alias',
        'lat': -27.47,
        'lng': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-2').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.latitude, -27.47);
      expect(item.longitude, 153.02);
    });

    test('fromDoc handles field aliases: locationLat/locationLng', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-3').set({
        'name': 'Location Alias',
        'locationLat': -27.47,
        'locationLng': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-3').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.latitude, -27.47);
      expect(item.longitude, 153.02);
    });

    test('fromDoc handles address and suburb as location aliases', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-4').set({
        'name': 'Address Alias',
        'address': '100 Queen Street',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-4').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.location, '100 Queen Street');
    });

    test('fromDoc parses approvalStatus from status alias', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-5').set({
        'name': 'Status Alias',
        'status': 'approved',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-5').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.isApproved, isTrue);
    });

    test('fromDoc parses approvalStatus from reviewStatus alias', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('alias-6').set({
        'name': 'ReviewStatus Alias',
        'reviewStatus': 'pending',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('alias-6').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.isApproved, isFalse);
      expect(item.approvalStatus, 'pending');
    });

    test('fromDoc parses latitude/longitude from string values', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('str-coord').set({
        'name': 'String Coords',
        'latitude': '-27.47',
        'longitude': '153.02',
      });

      final doc =
          await firestore.collection('attractions').doc('str-coord').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.latitude, -27.47);
      expect(item.longitude, 153.02);
    });

    test('fromDoc returns null for unparseable latitude', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('bad-lat').set({
        'name': 'Bad Latitude',
        'latitude': 'not-a-number',
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('bad-lat').get();
      expect(AdminAttractionItem.fromDoc(doc), isNull);
    });

    test('fromDoc parses accessibilityDetails from string to list', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('acc-str').set({
        'name': 'Single Accessibility',
        'latitude': -27.47,
        'longitude': 153.02,
        'accessibilityDetails': 'Wheelchair ramp',
      });

      final doc =
          await firestore.collection('attractions').doc('acc-str').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.accessibilityDetails, ['Wheelchair ramp']);
    });

    test('fromDoc parses accessibilityDetails from list', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('acc-list').set({
        'name': 'Multi Accessibility',
        'latitude': -27.47,
        'longitude': 153.02,
        'accessibilityDetails': ['Ramp', 'Audio', 'Braille'],
      });

      final doc =
          await firestore.collection('attractions').doc('acc-list').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.accessibilityDetails, ['Ramp', 'Audio', 'Braille']);
    });

    test('fromDoc provides default description when missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('no-desc').set({
        'name': 'Minimal',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('no-desc').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.description, 'No description available.');
    });

    test('fromDoc provides default location when missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attractions').doc('no-loc').set({
        'name': 'No Location Field',
        'latitude': -27.47,
        'longitude': 153.02,
      });

      final doc =
          await firestore.collection('attractions').doc('no-loc').get();
      final item = AdminAttractionItem.fromDoc(doc);
      expect(item, isNotNull);
      expect(item!.location, 'Location not provided');
    });

    test('isApproved returns true only for approved status', () {
      final approved = AdminAttractionItem(
        id: 'a', name: 'A', description: 'd', location: 'l',
        latitude: 0, longitude: 0, approvalStatus: 'approved',
      );
      final pending = AdminAttractionItem(
        id: 'b', name: 'B', description: 'd', location: 'l',
        latitude: 0, longitude: 0, approvalStatus: 'pending',
      );
      final noStatus = AdminAttractionItem(
        id: 'c', name: 'C', description: 'd', location: 'l',
        latitude: 0, longitude: 0,
      );

      expect(approved.isApproved, isTrue);
      expect(pending.isApproved, isFalse);
      expect(noStatus.isApproved, isFalse);
    });

    test('isApproved is case-insensitive', () {
      final item = AdminAttractionItem(
        id: 'a', name: 'A', description: 'd', location: 'l',
        latitude: 0, longitude: 0, approvalStatus: 'Approved',
      );
      expect(item.isApproved, isTrue);
    });

    test('add then update then delete — full lifecycle', () async {
      final firestore = FakeFirebaseFirestore();
      final driver = _FakeMediaStorageDriver();
      final media = FirebaseMediaService(driver: driver);
      final service = _createService(firestore, mediaService: media);

      // Add
      await service.addAttraction(
        name: 'Lifecycle Test',
        description: 'Created',
        location: 'Brisbane',
        latitude: -27.47,
        longitude: 153.02,
        imageStoragePath: 'attractions/lifecycle-test/hero.jpg',
      );

      final slug = 'lifecycle-test';
      var doc = await firestore.collection('attractions').doc(slug).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['description'], 'Created');

      // Update
      await service.updateAttraction(
        attractionId: slug,
        name: 'Lifecycle Test',
        description: 'Updated',
        location: 'Brisbane CBD',
        latitude: -27.468,
        longitude: 153.025,
        imageStoragePath: 'attractions/lifecycle-test/hero.jpg',
      );

      doc = await firestore.collection('attractions').doc(slug).get();
      expect(doc.data()!['description'], 'Updated');
      expect(doc.data()!['location'], 'Brisbane CBD');

      // Delete
      await service.deleteAttraction(slug);
      doc = await firestore.collection('attractions').doc(slug).get();
      expect(doc.exists, isFalse);
      expect(driver.deletedPaths,
          contains('attractions/lifecycle-test/hero.jpg'));
    });

    test('watchAllAttractions stream reacts to add, update, delete cycle',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore);

      // Initially empty
      var items = await service.watchAllAttractions().first;
      expect(items, isEmpty);

      // Add two
      await _seedAttraction(firestore, id: 'r1', name: 'R1');
      await _seedAttraction(firestore, id: 'r2', name: 'R2');
      items = await service.watchAllAttractions().first;
      expect(items.length, 2);

      // Delete one
      await firestore.collection('attractions').doc('r1').delete();
      items = await service.watchAllAttractions().first;
      expect(items.length, 1);
      expect(items.first.id, 'r2');
    });
  });
}
