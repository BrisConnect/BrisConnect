import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/business_event.dart';

class BusinessEventService {
  BusinessEventService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Create a new business event
  Future<String?> createBusinessEvent({
    required String businessId,
    required String ownerId,
    required String ownerEmail,
    required String title,
    required String date,
    required String time,
    required String location,
    required String description,
  }) async {
    try {
      final event = BusinessEvent(
        businessId: businessId,
        ownerId: ownerId,
        ownerEmail: ownerEmail.trim().toLowerCase(),
        title: title.trim(),
        date: date.trim(),
        time: time.trim(),
        location: location.trim(),
        description: description.trim(),
        status: 'published',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('business_events')
          .add(event.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('[BusinessEventService] Error creating event: $e');
      return null;
    }
  }

  /// Update an existing business event
  Future<bool> updateBusinessEvent({
    required String eventId,
    required String businessId,
    required String ownerEmail,
    required String title,
    required String date,
    required String time,
    required String location,
    required String description,
    String? imageUrl,
    String? imageStoragePath,
    String? status,
  }) async {
    try {
      final eventRef =
          _firestore.collection('business_events').doc(eventId);

      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(eventRef);
        if (!snapshot.exists) {
          return false;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final storedBusinessId = data['businessId'] as String? ?? '';
        final storedEmail = ((data['ownerEmail'] as String?) ?? '')
            .trim()
            .toLowerCase();
        final normalizedRequester =
            ownerEmail.trim().toLowerCase();

        // Verify ownership and business
        if (storedBusinessId != businessId ||
            storedEmail != normalizedRequester) {
          return false;
        }

        transaction.update(eventRef, {
          'title': title.trim(),
          'date': date.trim(),
          'time': time.trim(),
          'location': location.trim(),
          'description': description.trim(),
          if (imageUrl != null) 'imageUrl': imageUrl.trim(),
          if (imageStoragePath != null)
            'imageStoragePath': imageStoragePath.trim(),
          if (status != null) 'status': status.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('[BusinessEventService] Error updating event: $e');
      return false;
    }
  }

  /// Delete/cancel a business event
  Future<bool> deleteBusinessEvent({
    required String eventId,
    required String businessId,
    required String ownerEmail,
    bool softDelete = true, // Mark as cancelled instead of deleting
  }) async {
    try {
      final eventRef =
          _firestore.collection('business_events').doc(eventId);

      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(eventRef);
        if (!snapshot.exists) {
          return false;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final storedBusinessId = data['businessId'] as String? ?? '';
        final storedEmail = ((data['ownerEmail'] as String?) ?? '')
            .trim()
            .toLowerCase();
        final normalizedRequester =
            ownerEmail.trim().toLowerCase();

        // Verify ownership and business
        if (storedBusinessId != businessId ||
            storedEmail != normalizedRequester) {
          return false;
        }

        if (softDelete) {
          // Mark as cancelled
          transaction.update(eventRef, {
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Hard delete
          transaction.delete(eventRef);

          // Delete image from storage if exists
          final storagePath =
              data['imageStoragePath'] as String? ?? '';
          if (storagePath.isNotEmpty) {
            try {
              await _storage.ref(storagePath).delete();
            } catch (e) {
              debugPrint(
                '[BusinessEventService] Error deleting image: $e',
              );
            }
          }
        }

        return true;
      });
    } catch (e) {
      debugPrint('[BusinessEventService] Error deleting event: $e');
      return false;
    }
  }

  /// Get all events for a specific business
  Future<List<BusinessEvent>> getBusinessEvents({
    required String businessId,
    bool publishedOnly = true,
  }) async {
    try {
      Query query =
          _firestore.collection('business_events')
              .where('businessId', isEqualTo: businessId);

      if (publishedOnly) {
        query =
            query.where('status', isEqualTo: 'published');
      }

      final snapshot = await query.get();
      final events = <BusinessEvent>[];

      for (final doc in snapshot.docs) {
        try {
          events.add(BusinessEvent.fromFirestore(doc));
        } catch (e) {
          debugPrint(
            '[BusinessEventService] Error parsing event ${doc.id}: $e',
          );
        }
      }

      // Sort by date (most recent first)
      events.sort((a, b) {
        try {
          final dateA = _parseDate(a.date);
          final dateB = _parseDate(b.date);
          return dateB.compareTo(dateA);
        } catch (_) {
          return 0;
        }
      });

      return events;
    } catch (e) {
      debugPrint('[BusinessEventService] Error fetching events: $e');
      return [];
    }
  }

  /// Watch events for a business in real-time
  Stream<List<BusinessEvent>> watchBusinessEvents({
    required String businessId,
    bool publishedOnly = true,
  }) {
    Query query =
        _firestore.collection('business_events')
            .where('businessId', isEqualTo: businessId);

    if (publishedOnly) {
      query = query.where('status', isEqualTo: 'published');
    }

    return query.snapshots().map((snapshot) {
      final events = <BusinessEvent>[];

      for (final doc in snapshot.docs) {
        try {
          events.add(BusinessEvent.fromFirestore(doc));
        } catch (e) {
          debugPrint(
            '[BusinessEventService] Error parsing event ${doc.id}: $e',
          );
        }
      }

      // Sort by date (most recent first)
      events.sort((a, b) {
        try {
          final dateA = _parseDate(a.date);
          final dateB = _parseDate(b.date);
          return dateB.compareTo(dateA);
        } catch (_) {
          return 0;
        }
      });

      return events;
    });
  }

  /// Upload event image to Firebase Storage
  Future<({String downloadUrl, String storagePath})?> uploadEventImage({
    required String businessId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'business_events/$businessId/$timestamp-$sanitizedName';

      final ref = _storage.ref(storagePath);
      await ref.putData(bytes);
      final downloadUrl = await ref.getDownloadURL();

      return (downloadUrl: downloadUrl, storagePath: storagePath);
    } catch (e) {
      debugPrint(
        '[BusinessEventService] Error uploading event image: $e',
      );
      return null;
    }
  }

  /// Parse date string in format dd/mm/yyyy
  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return DateTime.now();
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }
}
