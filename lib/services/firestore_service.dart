import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all approved events
  Stream<List<Map<String, dynamic>>> getEvents() {
    return _db
        .collection('events')
        .snapshots()
        .map((snapshot) {
          debugPrint("🔥 Documents found: ${snapshot.docs.length}");
          final events = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              events.add({
                ...data,
                'id': (data['id'] as String?)?.trim().isNotEmpty == true
                    ? data['id']
                    : doc.id,
              });
            } catch (error) {
              // Skip malformed records so one bad document does not crash the list.
              debugPrint('[FirestoreService] Skipping invalid event ${doc.id}: $error');
            }
          }
          return events;
        });
  }
}
