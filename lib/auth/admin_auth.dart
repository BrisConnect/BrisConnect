import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

class AdminAuth {
  static bool _isAdminLoggedIn = false;
  static String? _lastErrorMessage;
  static String? _profileImageUrl;
  static String? _profileImageStoragePath;
  static final ValueNotifier<int> profileVersion = ValueNotifier<int>(0);

  static bool get isAdminLoggedIn => _isAdminLoggedIn;
  static String? get lastErrorMessage => _lastErrorMessage;
  static String? get currentAdminEmail =>
      fb_auth.FirebaseAuth.instance.currentUser?.email;
  static String? get profileImageUrl => _profileImageUrl;
  static String? get profileImageStoragePath => _profileImageStoragePath;

  static String _deriveUsername(String email) {
    return email.trim().toLowerCase().split('@').first;
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      _isAdminLoggedIn = false;
      _lastErrorMessage = 'Please enter a valid admin email address.';
      return false;
    }

    try {
      await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(normalized)
          .get();

      if (!adminDoc.exists) {
        await fb_auth.FirebaseAuth.instance.signOut();
        _isAdminLoggedIn = false;
        _lastErrorMessage =
            'Account is valid but not authorized as admin in Firestore.';
        return false;
      }

      final data = adminDoc.data() ?? const <String, dynamic>{};
      final role = (data['role'] as String?)?.toLowerCase() ?? '';
      final active = (data['active'] as bool?) ?? true;

      if (!active || (role.isNotEmpty && role != 'admin')) {
        await fb_auth.FirebaseAuth.instance.signOut();
        _isAdminLoggedIn = false;
        _lastErrorMessage = 'Admin account is disabled or role is invalid.';
        return false;
      }

      try {
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(normalized)
            .set({
          'role': 'admin',
          'active': true,
          'email': normalized,
          'username': _deriveUsername(normalized),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Non-critical: login can continue if role metadata update fails.
      }

      _profileImageUrl = (data['profileImageUrl'] as String?)?.trim();
      _profileImageStoragePath = (data['profileImageStoragePath'] as String?)?.trim();
      _isAdminLoggedIn = true;
      profileVersion.value++;
      return true;
    } on fb_auth.FirebaseAuthException catch (error) {
      _isAdminLoggedIn = false;
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _lastErrorMessage = 'Invalid admin credentials.';
          break;
        case 'invalid-email':
          _lastErrorMessage = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          _lastErrorMessage =
              'Email/password sign-in is not enabled in Firebase Authentication.';
          break;
        case 'network-request-failed':
          _lastErrorMessage =
              'Network error. Check your connection and try again.';
          break;
        default:
          _lastErrorMessage = 'Admin login failed (${error.code}).';
      }
      return false;
    } on FirebaseException catch (error) {
      _isAdminLoggedIn = false;
      if (error.code == 'permission-denied') {
        _lastErrorMessage =
            'Firestore denied access to admin profile. Check security rules.';
      } else {
        _lastErrorMessage = 'Could not verify admin profile (${error.code}).';
      }
      return false;
    } catch (_) {
      _isAdminLoggedIn = false;
      _lastErrorMessage = 'Admin login failed due to an unexpected error.';
      return false;
    }
  }

  static Future<void> logout() async {
    await fb_auth.FirebaseAuth.instance.signOut();
    _isAdminLoggedIn = false;
    _profileImageUrl = null;
    _profileImageStoragePath = null;
    profileVersion.value++;
  }

  static Future<bool> updateProfile({required String name}) async {
    final currentEmail =
        fb_auth.FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    final trimmedName = name.trim();
    if (!_isAdminLoggedIn || currentEmail == null || currentEmail.isEmpty) {
      return false;
    }
    if (trimmedName.isEmpty) {
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(currentEmail)
          .set({
        'name': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Restores an admin session from Firestore after an app restart.
  /// Called during startup when Firebase Auth still has a cached user.
  static Future<bool> restoreSession(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(normalizedEmail)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() ?? const <String, dynamic>{};
      final isActive = (data['active'] as bool?) ?? true;
      final role = (data['role'] as String?)?.toLowerCase() ?? 'admin';
      if (!isActive || role != 'admin') return false;
      _profileImageUrl = (data['profileImageUrl'] as String?)?.trim();
      _profileImageStoragePath = (data['profileImageStoragePath'] as String?)?.trim();
      _isAdminLoggedIn = true;
      profileVersion.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateProfileImage({
    String? imageUrl,
    String? storagePath,
  }) async {
    final currentEmail =
        fb_auth.FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (!_isAdminLoggedIn || currentEmail == null || currentEmail.isEmpty) {
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(currentEmail)
          .set({
        'profileImageUrl': imageUrl,
        'profileImageStoragePath': storagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _profileImageUrl = imageUrl;
      _profileImageStoragePath = storagePath;
      profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[AdminAuth] updateProfileImage failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
