import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Test utility service to create dummy data for development.
/// All methods are no-ops in release builds to prevent test data from
/// reaching production Firestore.
class TestDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a dummy approved local event that shows on the map.
  /// Only works in debug/profile mode.
  static Future<void> createDummyLocalEvent() async {
    if (kReleaseMode) {
      debugPrint('[TestDataService] Skipped — release mode');
      return;
    }

    final dummyEventId = 'dummy-coffee-pop-up-south-bank';
    final eventsRef = _firestore.collection('events').doc(dummyEventId);

    await eventsRef.set({
      'id': dummyEventId,
      'title': 'Coffee Pop-Up Market',
      'date': 'Check schedule',
      'time': '8:00 AM - 12:00 PM',
      'dateTime': 'Check schedule • 8:00 AM - 12:00 PM',
      'category': 'Food & Beverage',
      'location': 'South Bank Parklands, Brisbane QLD 4101',
      'description':
          'Local specialty coffee roasters and artisan pastries at the South Bank Parklands.',
      'reviewStatus': 'approved',
      'createdByLocalEmail': 'test@brisconnect.local',
      'imageUrl': null,
      'imageStoragePath': null,
      'latitude': -27.4810,
      'longitude': 153.0234,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'test_data',
    });

    debugPrint('[TestDataService] Dummy event created: $dummyEventId');
  }

  /// Deletes the dummy event. Only works in debug/profile mode.
  static Future<void> deleteDummyLocalEvent() async {
    if (kReleaseMode) return;
    await _firestore.collection('events').doc('dummy-coffee-pop-up-south-bank').delete();
    debugPrint('[TestDataService] Dummy event deleted');
  }
}
