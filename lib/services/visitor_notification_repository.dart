import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/models/visitor_notification_record.dart';

/// Reads and manages visitor push notifications stored under
/// `visitor_users/{email}/notifications`.
class VisitorNotificationRepository {
  VisitorNotificationRepository({
    FirebaseFirestore? firestore,
    required this.userEmail,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String userEmail;

  String get _normalizedEmail => userEmail.trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> get _collection => _db
      .collection('visitor_users')
      .doc(_normalizedEmail)
      .collection('notifications');

  /// Stream of all visitor notifications ordered newest first.
  Stream<List<VisitorNotificationRecord>> watchNotifications({int? limit}) {
    Query<Map<String, dynamic>> query =
        _collection.orderBy('createdAt', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(VisitorNotificationRecord.fromDoc)
        .toList(growable: false));
  }

  /// Stream of unread visitor notifications ordered newest first.
  Stream<List<VisitorNotificationRecord>> watchUnreadNotifications() {
    return _collection
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(VisitorNotificationRecord.fromDoc)
            .toList(growable: false));
  }

  /// Real-time count of unread notifications.
  Stream<int> watchUnreadCount() {
    return _collection
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .transform(StreamTransformer<int, int>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            debugPrint(
                '[VisitorNotificationRepository] unread count error: $error');
            sink.add(0);
          },
        ));
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[VisitorNotificationRepository] markAsRead failed: $e');
    }
  }

  /// Mark all unread notifications as read up to the current time.
  Future<int> markAllAsRead() async {
    try {
      final snapshot = await _collection.where('isRead', isEqualTo: false).get();
      if (snapshot.docs.isEmpty) return 0;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('[VisitorNotificationRepository] markAllAsRead failed: $e');
      return 0;
    }
  }

  /// Deletes a notification.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _collection.doc(notificationId).delete();
    } catch (e) {
      debugPrint('[VisitorNotificationRepository] deleteNotification failed: $e');
    }
  }
}
