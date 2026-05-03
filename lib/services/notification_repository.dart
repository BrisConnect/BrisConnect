import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:brisconnect/models/notification_record.dart';

class NotificationRepository {
  static const _collection = 'user_notifications';

  NotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _notificationId({
    required String userEmail,
    required String eventTitle,
    required String eventDateTime,
  }) {
    final emailPart = _slugify(userEmail);
    final titlePart = _slugify(eventTitle);
    final datePart = _slugify(eventDateTime);
    return [emailPart, titlePart, datePart]
        .where((part) => part.isNotEmpty)
        .join('_');
  }

  Future<int> migrateNotificationIdsForUser(String userEmail) async {
    try {
      final normalized = userEmail.trim().toLowerCase();
      if (normalized.isEmpty) {
        return 0;
      }

      final snapshot = await _db
          .collection(_collection)
          .where('userEmail', isEqualTo: normalized)
          .get();

      var migratedCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final targetId = _notificationId(
          userEmail: '${data['userEmail'] ?? normalized}',
          eventTitle: '${data['eventTitle'] ?? 'event'}',
          eventDateTime: '${data['eventDateTime'] ?? 'date'}',
        );

        if (targetId.isEmpty || doc.id == targetId) {
          continue;
        }

        final batch = _db.batch();
        batch.set(
          _db.collection(_collection).doc(targetId),
          data,
          SetOptions(merge: true),
        );
        batch.delete(doc.reference);
        await batch.commit();
        migratedCount++;
      }

      if (migratedCount > 0) {
        debugPrint(
          '[NotificationRepository] migrated $migratedCount notification IDs for $normalized',
        );
      }
      return migratedCount;
    } catch (e) {
      debugPrint(
          '[NotificationRepository] migrateNotificationIdsForUser failed: $e');
      return 0;
    }
  }

  /// Writes a notification record to Firestore.
  /// Uses a deterministic document ID so repeats update the same record.
  Future<bool> saveNotification({
    required String userEmail,
    required String userType,
    required String eventId,
    required String eventTitle,
    required String eventDateTime,
    required String eventLocation,
    String scheduleType = 'unknown',
  }) async {
    try {
      final normalized = userEmail.trim().toLowerCase();

      if (normalized.isEmpty) {
        debugPrint(
            '[NotificationRepository] saveNotification skipped: empty userEmail');
        return false;
      }

      await migrateNotificationIdsForUser(normalized);

      final documentId = _notificationId(
        userEmail: normalized,
        eventTitle: eventTitle,
        eventDateTime: eventDateTime,
      );

      await _db.collection(_collection).doc(documentId).set({
        'eventId': eventId.trim(),
        'userEmail': normalized,
        'userType': userType,
        'eventTitle': eventTitle.trim(),
        'eventDateTime': eventDateTime.trim(),
        'eventLocation': eventLocation.trim(),
        'scheduleType': scheduleType,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      }, SetOptions(merge: true));

      debugPrint(
        '[NotificationRepository] saved notification for $normalized ($documentId)',
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationRepository] saveNotification failed: $e');
      return false;
    }
  }

  /// Returns a real-time stream of notifications for the given user email.
  Stream<List<NotificationRecord>> watchNotificationsForUser(String userEmail) {
    final normalized = userEmail.trim().toLowerCase();
    return _db
        .collection(_collection)
        .where('userEmail', isEqualTo: normalized)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => NotificationRecord.fromDoc(doc))
          .toList(growable: false);
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    });
  }

  /// Toggles the isRead field on a notification document.
  Future<void> setReadStatus(String notificationId,
      {required bool isRead}) async {
    try {
      await _db
          .collection(_collection)
          .doc(notificationId)
          .update({'isRead': isRead});
    } catch (e) {
      debugPrint('[NotificationRepository] setReadStatus failed: $e');
    }
  }

  Future<void> deleteNotificationForEvent({
    required String userEmail,
    required String eventTitle,
    required String eventDateTime,
  }) async {
    try {
      final normalized = userEmail.trim().toLowerCase();
      if (normalized.isEmpty) return;
      final documentId = _notificationId(
        userEmail: normalized,
        eventTitle: eventTitle,
        eventDateTime: eventDateTime,
      );
      if (documentId.isEmpty) return;
      await _db.collection(_collection).doc(documentId).delete();
    } catch (e) {
      debugPrint(
          '[NotificationRepository] deleteNotificationForEvent failed: $e');
    }
  }
}
