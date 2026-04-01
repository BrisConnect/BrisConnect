import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AdminUserRecord {
  final String id;
  final String email;
  final String name;
  final String role; // 'visitor', 'local', 'admin'
  final bool active;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AdminUserRecord({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AdminUserRecord.fromVisitorDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    return AdminUserRecord(
      id: docId,
      email: docId,
      name: ((data['name'] as String?) ?? 'Unnamed User').trim(),
      role: 'visitor',
      active: (data['active'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AdminUserRecord.fromLocalDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    return AdminUserRecord(
      id: docId,
      email: docId,
      name: ((data['businessName'] as String?) ??
              (data['name'] as String?) ??
              'Unnamed User')
          .trim(),
      role: 'local',
      active: (data['active'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AdminUserRecord.fromAdminDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    return AdminUserRecord(
      id: docId,
      email: docId,
      name: ((data['username'] as String?) ?? 'Admin User').trim(),
      role: 'admin',
      active: (data['active'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminUserManagementService {
  AdminUserManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Stream of all users (visitors + locals + admins), optionally filtered by search.
  Stream<List<AdminUserRecord>> watchAllUsers({String searchQuery = ''}) {
    return Stream.multi((controller) async {
      // Listen to all three user collections
      final visitorsListener = _firestore
          .collection('visitor_users')
          .snapshots()
          .listen((_) => _emitCombinedUsers(controller, searchQuery));

      final localsListener = _firestore
          .collection('local_users')
          .snapshots()
          .listen((_) => _emitCombinedUsers(controller, searchQuery));

      final adminsListener = _firestore
          .collection('admins')
          .snapshots()
          .listen((_) => _emitCombinedUsers(controller, searchQuery));

      // Emit initial data
      _emitCombinedUsers(controller, searchQuery);

      // Cleanup when stream is cancelled
      controller.onCancel = () {
        visitorsListener.cancel();
        localsListener.cancel();
        adminsListener.cancel();
      };
    });
  }

  /// Helper to emit combined users to the stream controller
  Future<void> _emitCombinedUsers(
    StreamSink<List<AdminUserRecord>> controller,
    String searchQuery,
  ) async {
    try {
      final visitors = await _fetchVisitors();
      final locals = await _fetchLocals();
      final admins = await _fetchAdmins();

      var allUsers = [...visitors, ...locals, ...admins];
      allUsers.sort((a, b) => a.name.compareTo(b.name));

      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        allUsers = allUsers
            .where((user) =>
                user.email.toLowerCase().contains(lowerQuery) ||
                user.name.toLowerCase().contains(lowerQuery))
            .toList();
      }

      try {
        controller.add(allUsers);
      } catch (e) {
        // Stream may have been closed
        debugPrint('[AdminUserManagementService] Stream closed: $e');
      }
    } catch (error) {
      debugPrint('[AdminUserManagementService] Error emitting users: $error');
      try {
        controller.addError(error);
      } catch (e) {
        // Stream may have been closed
        debugPrint('[AdminUserManagementService] Stream closed: $e');
      }
    }
  }

  /// Fetch all visitor users from Firestore.
  Future<List<AdminUserRecord>> _fetchVisitors() async {
    try {
      final snapshot = await _firestore.collection('visitor_users').get();
      return snapshot.docs
          .map((doc) => AdminUserRecord.fromVisitorDoc(doc.id, doc.data()))
          .toList();
    } catch (error) {
      debugPrint('[AdminUserManagementService] Error fetching visitors: $error');
      return [];
    }
  }

  /// Fetch all local users from Firestore.
  Future<List<AdminUserRecord>> _fetchLocals() async {
    try {
      final snapshot = await _firestore.collection('local_users').get();
      return snapshot.docs
          .map((doc) => AdminUserRecord.fromLocalDoc(doc.id, doc.data()))
          .toList();
    } catch (error) {
      debugPrint('[AdminUserManagementService] Error fetching locals: $error');
      return [];
    }
  }

  /// Fetch all admin users from Firestore.
  Future<List<AdminUserRecord>> _fetchAdmins() async {
    try {
      final snapshot = await _firestore.collection('admins').get();
      return snapshot.docs
          .map((doc) => AdminUserRecord.fromAdminDoc(doc.id, doc.data()))
          .toList();
    } catch (error) {
      debugPrint('[AdminUserManagementService] Error fetching admins: $error');
      return [];
    }
  }

  /// Deactivate a user account (set active = false).
  /// Completes within 2 seconds via Firestore transaction.
  Future<void> deactivateUser(String email, String role) async {
    final collection = _collectionForRole(role);
    if (collection.isEmpty) {
      throw StateError('Invalid user role: $role');
    }

    final docRef = _firestore.collection(collection).doc(email);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('User no longer exists.');
      }

      transaction.update(docRef, {
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    });

    debugPrint('[AdminUserManagementService] Deactivated user: $email ($role)');
  }

  /// Reactivate a user account (set active = true).
  Future<void> reactivateUser(String email, String role) async {
    final collection = _collectionForRole(role);
    if (collection.isEmpty) {
      throw StateError('Invalid user role: $role');
    }

    final docRef = _firestore.collection(collection).doc(email);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('User no longer exists.');
      }

      transaction.update(docRef, {
        'active': true,
      });
    });

    debugPrint('[AdminUserManagementService] Reactivated user: $email ($role)');
  }

  /// Map role to Firestore collection name.
  String _collectionForRole(String role) {
    switch (role.toLowerCase()) {
      case 'visitor':
        return 'visitor_users';
      case 'local':
        return 'local_users';
      case 'admin':
        return 'admins';
      default:
        return '';
    }
  }
}
