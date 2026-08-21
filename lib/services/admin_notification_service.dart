import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/models/admin_notification_record.dart';

/// Reads and manages admin platform notifications stored in
/// `admin_notifications`.
class AdminNotificationService {
  AdminNotificationService({
    FirebaseFirestore? firestore,
    String? adminEmail,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _adminEmail = adminEmail?.trim().toLowerCase();

  final FirebaseFirestore _db;
  final String? _adminEmail;
  static const String _collection = 'admin_notifications';

  bool _belongsToAdmin(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (_adminEmail == null) return true;
    final email = doc.data()?['adminEmail']?.toString().trim().toLowerCase();
    return email == _adminEmail;
  }

  /// Stream of all admin notifications ordered newest first.
  Stream<List<AdminNotificationRecord>> watchNotifications({int? limit}) {
    Query<Map<String, dynamic>> query = _db
        .collection(_collection)
        .orderBy('createdAt', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .where(_belongsToAdmin)
        .map((doc) => AdminNotificationRecord.fromDoc(doc))
        .toList(growable: false));
  }

  /// Stream of unread admin notifications ordered newest first.
  /// Note: Filters client-side to avoid requiring composite indexes.
  Stream<List<AdminNotificationRecord>> watchUnreadNotifications() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => _belongsToAdmin(doc) && doc.data()['read'] != true)
            .map((doc) => AdminNotificationRecord.fromDoc(doc))
            .toList(growable: false));
  }

  /// Real-time count of unread notifications.
  /// Note: Filters client-side to avoid requiring composite indexes.
  Stream<int> watchUnreadCount() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => _belongsToAdmin(doc) && doc.data()['read'] != true)
            .length)
        .transform(StreamTransformer<int, int>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            debugPrint('[AdminNotificationService] unread count error: $error');
            sink.add(0);
          },
        ));
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection(_collection).doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdminNotificationService] markAsRead failed: $e');
    }
  }

  /// Mark all unread notifications as read up to the current time.
  Future<int> markAllAsRead() async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('read', isEqualTo: false)
          .get();

      final docs = snapshot.docs.where(_belongsToAdmin).toList();
      if (docs.isEmpty) return 0;

      final batch = _db.batch();
      for (final doc in docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return docs.length;
    } catch (e) {
      debugPrint('[AdminNotificationService] markAllAsRead failed: $e');
      return 0;
    }
  }

  /// Deletes a notification. Intended for admin-driven cleanup.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection(_collection).doc(notificationId).delete();
    } catch (e) {
      debugPrint('[AdminNotificationService] deleteNotification failed: $e');
    }
  }
}
