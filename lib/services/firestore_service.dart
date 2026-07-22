import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Get all approved events with normalized fields for visitor UI.
  Stream<List<Map<String, dynamic>>> getEvents() {
    return _db.collection('events').snapshots().map((snapshot) {
      final events = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (!_isApproved(data)) {
            continue;
          }
          events.add(_normalizeEventData(doc.id, data));
        } catch (error) {
          // Skip malformed records so one bad document does not crash the list.
          debugPrint(
              '[FirestoreService] Skipping invalid event ${doc.id}: $error');
        }
      }

      return events;
    });
  }

  bool _isApproved(Map<String, dynamic> data) {
    final reviewStatus =
        (data['reviewStatus'] as String?)?.trim().toLowerCase();
    final approvalStatus =
        (data['approvalStatus'] as String?)?.trim().toLowerCase();
    final status = (data['status'] as String?)?.trim().toLowerCase();
    final isApproved = (data['isApproved'] as bool?) ?? false;

    return isApproved ||
        reviewStatus == 'approved' ||
        approvalStatus == 'approved' ||
        status == 'approved';
  }

  Map<String, dynamic> _normalizeEventData(
    String docId,
    Map<String, dynamic> data,
  ) {
    final rawDate = (data['date'] as String?)?.trim() ?? '';
    final rawTime = (data['time'] as String?)?.trim() ?? '';
    final rawDateTime = (data['dateTime'] as String?)?.trim() ?? '';

    String date = rawDate;
    String time = rawTime;

    if ((date.isEmpty || time.isEmpty) && rawDateTime.isNotEmpty) {
      final parsedIso = DateTime.tryParse(rawDateTime);
      if (parsedIso != null) {
        date = date.isEmpty
            ? '${parsedIso.year}-${parsedIso.month.toString().padLeft(2, '0')}-${parsedIso.day.toString().padLeft(2, '0')}'
            : date;
        time = time.isEmpty
            ? '${parsedIso.hour.toString().padLeft(2, '0')}:${parsedIso.minute.toString().padLeft(2, '0')}'
            : time;
      } else {
        final parts = rawDateTime
            .split(RegExp(r'\s*[•·]|ΓÇó|\|\s*'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
        if (date.isEmpty && parts.isNotEmpty) {
          date = parts.first;
        }
        if (time.isEmpty && parts.length > 1) {
          time = parts.sublist(1).join(' • ');
        }
      }
    }

    return {
      ...data,
      'id': (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id']
          : docId,
      'section': 'events',
      'title': ((data['title'] as String?) ?? 'Untitled Event').trim(),
      'date': date.isNotEmpty ? date : 'Date TBA',
      'time': time.isNotEmpty ? time : 'Time TBA',
      'location': ((data['location'] as String?) ?? 'Location TBA').trim(),
    };
  }
}
