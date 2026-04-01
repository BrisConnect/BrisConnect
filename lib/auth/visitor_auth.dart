import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class VisitorUser {
  final String name;
  final String email;
  final String password;
  final List<String> interestedEventIds;
  final bool notificationsEnabled;
  final String? profileImageBase64;

  const VisitorUser({
    required this.name,
    required this.email,
    required this.password,
    this.interestedEventIds = const [],
    this.notificationsEnabled = true,
    this.profileImageBase64,
  });

  VisitorUser copyWith({
    String? name,
    String? email,
    String? password,
    List<String>? interestedEventIds,
    bool? notificationsEnabled,
    String? profileImageBase64,
  }) {
    return VisitorUser(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      interestedEventIds: interestedEventIds ?? this.interestedEventIds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
    );
  }
}

class VisitorAuth {
  static final List<VisitorUser> _users = [];
  static VisitorUser? _currentVisitor;
  static final ValueNotifier<int> _interestedEventsVersion = ValueNotifier<int>(0);
  static final ValueNotifier<int> _profileVersion = ValueNotifier<int>(0);
  static String? _lastErrorMessage;

  static VisitorUser? get currentVisitor => _currentVisitor;
  static bool get isVisitorLoggedIn => _currentVisitor != null;
  static ValueListenable<int> get interestedEventsVersion => _interestedEventsVersion;
  static ValueListenable<int> get profileVersion => _profileVersion;
  static String? get lastErrorMessage => _lastErrorMessage;

  static String _passwordHash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String _deriveUsername(String email) {
    return email.trim().toLowerCase().split('@').first;
  }

  static Future<String?> _resolveLoginEmail(String identifier) async {
    final normalized = identifier.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('@')) {
      return normalized;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('visitor_users')
          .get();

      String? matchedEmail;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = ((data['email'] as String?) ?? doc.id).trim().toLowerCase();
        final username = ((data['username'] as String?) ?? _deriveUsername(email))
            .trim()
            .toLowerCase();

        if (username != normalized) {
          continue;
        }

        if (matchedEmail != null && matchedEmail != email) {
          _lastErrorMessage =
              'This username matches multiple accounts. Please log in with your email address.';
          return null;
        }
        matchedEmail = email;
      }

      return matchedEmail;
    } catch (_) {
      return normalized;
    }
  }

  static bool emailExists(String email) {
    final normalized = email.trim().toLowerCase();
    return _users.any((user) => user.email.toLowerCase() == normalized);
  }

  static Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    final normalizedEmail = email.trim().toLowerCase();

    if (emailExists(normalizedEmail)) {
      _lastErrorMessage = 'This email is already registered.';
      return false;
    }

    try {
      await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(normalizedEmail)
          .set({
        'name': name.trim(),
        'email': normalizedEmail,
        'username': _deriveUsername(normalizedEmail),
        'role': 'visitor',
        'interestedEventIds': const <String>[],
        'notificationsEnabled': true,
        'profileImageBase64': null,
        'passwordHash': _passwordHash(password),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await fb_auth.FirebaseAuth.instance.signOut();
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[VisitorAuth] Firebase Auth register failed: ${error.code}');
      switch (error.code) {
        case 'email-already-in-use':
          _lastErrorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          _lastErrorMessage = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          _lastErrorMessage = 'Password is too weak. Use at least 8 characters with upper, lower, and number.';
          break;
        case 'network-request-failed':
          _lastErrorMessage = 'No internet connection. Please try again.';
          break;
        default:
          _lastErrorMessage = 'Could not create visitor account (${error.code}).';
      }
      return false;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _lastErrorMessage = 'Could not save visitor profile due to Firestore permissions.';
      } else if (error.code == 'unavailable') {
        _lastErrorMessage = 'No internet connection. Please try again.';
      } else {
        _lastErrorMessage = 'Could not save visitor profile (${error.code}).';
      }
      return false;
    } catch (error) {
      debugPrint('[VisitorAuth] Failed to write visitor account: $error');
      _lastErrorMessage = 'Could not create visitor account. Please try again.';
      return false;
    }

    if (!emailExists(normalizedEmail)) {
      _users.add(
        VisitorUser(
          name: name.trim(),
          email: normalizedEmail,
          password: password,
        ),
      );
    }

    return true;
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    _lastErrorMessage = null;
    final normalizedEmail = await _resolveLoginEmail(email);
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      _lastErrorMessage ??= 'Invalid email or username.';
      return false;
    }

    try {
      await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final doc = await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(normalizedEmail)
          .get();

      final data = doc.data() ?? const <String, dynamic>{};
      final role = (data['role'] as String?)?.toLowerCase();
      if (role != null && role.isNotEmpty && role != 'visitor') {
        await fb_auth.FirebaseAuth.instance.signOut();
        _lastErrorMessage = 'Access denied: this account is not a Visitor account.';
        return false;
      }

      final isActive = (data['active'] as bool?) ?? true;
      if (!isActive) {
        await fb_auth.FirebaseAuth.instance.signOut();
        _lastErrorMessage = 'This account has been deactivated. Contact support for assistance.';
        return false;
      }

      try {
        await FirebaseFirestore.instance
            .collection('visitor_users')
            .doc(normalizedEmail)
            .set({
          'role': 'visitor',
          'email': normalizedEmail,
          'username': _deriveUsername(normalizedEmail),
          'passwordHash': _passwordHash(password),
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Non-critical: login can continue if role metadata update fails.
      }

      final user = VisitorUser(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : normalizedEmail.split('@').first,
        email: normalizedEmail,
        password: password,
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        profileImageBase64: (data['profileImageBase64'] as String?)?.trim().isNotEmpty == true
          ? (data['profileImageBase64'] as String)
          : null,
      );

      final userIndex = _users.indexWhere(
        (item) => item.email.toLowerCase() == normalizedEmail,
      );
      if (userIndex >= 0) {
        _users[userIndex] = user;
      } else {
        _users.add(user);
      }

      _currentVisitor = user;
      _interestedEventsVersion.value++;
      _profileVersion.value++;
      return true;
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[VisitorAuth] Firebase Auth login failed: ${error.code}');
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _lastErrorMessage = 'Invalid email or password.';
          break;
        case 'invalid-email':
          _lastErrorMessage = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          _lastErrorMessage = 'No internet connection. Please try again.';
          break;
        default:
          _lastErrorMessage = 'Visitor login failed (${error.code}).';
      }
      return false;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _lastErrorMessage =
            'Visitor profile is not accessible. Check Firestore rules.';
      } else if (error.code == 'unavailable') {
        _lastErrorMessage = 'No internet connection. Please try again.';
      } else {
        _lastErrorMessage = 'Could not load visitor profile (${error.code}).';
      }
      return false;
    } catch (_) {
      _lastErrorMessage = 'Visitor login failed due to an unexpected error.';
      return false;
    }
  }

  static Future<void> logout() async {
    await fb_auth.FirebaseAuth.instance.signOut();
    _currentVisitor = null;
    _interestedEventsVersion.value++;
    _profileVersion.value++;
  }

  @visibleForTesting
  static void debugSetCurrentVisitorForTesting(VisitorUser? user) {
    _currentVisitor = user;
    if (user != null) {
      final idx = _users.indexWhere(
        (u) => u.email.toLowerCase() == user.email.toLowerCase(),
      );
      if (idx >= 0) {
        _users[idx] = user;
      } else {
        _users.add(user);
      }
    }
    _interestedEventsVersion.value++;
    _profileVersion.value++;
  }

  static Set<String> getInterestedEventIds() {
    return Set<String>.from(_currentVisitor?.interestedEventIds ?? const []);
  }

  static bool isInterestedInEvent(String eventId) {
    return _currentVisitor?.interestedEventIds.contains(eventId) ?? false;
  }

  static bool toggleInterestedEvent(String eventId) {
    final current = _currentVisitor;
    if (current == null) {
      return false;
    }

    final updatedIds = List<String>.from(current.interestedEventIds);
    if (updatedIds.contains(eventId)) {
      updatedIds.remove(eventId);
    } else {
      updatedIds.add(eventId);
    }

    final updatedUser = current.copyWith(interestedEventIds: updatedIds);
    final userIndex = _users.indexWhere(
      (user) => user.email.toLowerCase() == current.email.toLowerCase(),
    );
    if (userIndex != -1) {
      _users[userIndex] = updatedUser;
    }
    _currentVisitor = updatedUser;
    _interestedEventsVersion.value++;
    _profileVersion.value++;

    FirebaseFirestore.instance
        .collection('visitor_users')
        .doc(current.email)
        .set(
      {'interestedEventIds': updatedIds},
      SetOptions(merge: true),
    ).catchError((e) {
      debugPrint('[VisitorAuth] Failed to persist interested events: $e');
    });

    return true;
  }

  /// Updates the visitor's display name in Firestore and in-memory.
  static Future<bool> updateName(String newName) async {
    final current = _currentVisitor;
    if (current == null) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(current.email)
          .update({'name': trimmed});
      final updated = current.copyWith(name: trimmed);
      _currentVisitor = updated;
      final idx = _users.indexWhere((u) => u.email == current.email);
      if (idx != -1) _users[idx] = updated;
      _interestedEventsVersion.value++;
      _profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[VisitorAuth] updateName failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Restores a visitor session from Firestore after an app restart.
  /// Called during startup when Firebase Auth still has a cached user.
  static Future<bool> restoreSession(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final doc = await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(normalizedEmail)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() ?? const <String, dynamic>{};
      final role = (data['role'] as String?)?.toLowerCase();
      if (role != null && role.isNotEmpty && role != 'visitor') return false;
      final isActive = (data['active'] as bool?) ?? true;
      if (!isActive) return false;
      final user = VisitorUser(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : normalizedEmail.split('@').first,
        email: normalizedEmail,
        password: '',
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        profileImageBase64: (data['profileImageBase64'] as String?)?.trim().isNotEmpty == true
          ? (data['profileImageBase64'] as String)
          : null,
      );
      _currentVisitor = user;
      _interestedEventsVersion.value++;
      _profileVersion.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool areNotificationsEnabled() {
    return _currentVisitor?.notificationsEnabled ?? true;
  }

  static Future<bool> setNotificationsEnabled(bool enabled) async {
    final current = _currentVisitor;
    if (current == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(current.email)
          .update({'notificationsEnabled': enabled});
      
      final updated = current.copyWith(notificationsEnabled: enabled);
      _currentVisitor = updated;
      final idx = _users.indexWhere((u) => u.email == current.email);
      if (idx != -1) _users[idx] = updated;
      _interestedEventsVersion.value++;
      _profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[VisitorAuth] setNotificationsEnabled failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateProfileImage(String base64Image) async {
    final current = _currentVisitor;
    if (current == null) return false;
    final trimmed = base64Image.trim();
    if (trimmed.isEmpty) return false;

    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(current.email)
          .update({'profileImageBase64': trimmed});

      final updated = current.copyWith(profileImageBase64: trimmed);
      _currentVisitor = updated;
      final idx = _users.indexWhere((u) => u.email == current.email);
      if (idx != -1) _users[idx] = updated;
      _profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[VisitorAuth] updateProfileImage failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
