import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/local_email_notification_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';

enum AccountApprovalStatus { pending, approved, rejected }

class LocalUser {
  final String name;
  final String email;
  final String password;
  final String phone;
  final String suburb;
  final List<String> interestedEventIds;
  final List<String> interestCategories;
  final bool notificationsEnabled;
  final bool eventRemindersEnabled;
  final String reminderTiming;
  final bool eventUpdatesEnabled;
  final bool nearbyEventsEnabled;
  final bool recommendedEventsEnabled;
  final bool useCurrentLocation;
  final int locationRadiusKm;
  final bool locationAccessEnabled;
  final String themePreference;
  final double textScaleFactor;
  final String? profileImageBase64;
  final String? profileImageUrl;
  final String? profileImageStoragePath;
  final String accountType = 'local';
  final AccountApprovalStatus approvalStatus;

  const LocalUser({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.suburb,
    this.interestedEventIds = const [],
    this.interestCategories = const [],
    this.notificationsEnabled = true,
    this.eventRemindersEnabled = true,
    this.reminderTiming = '24h',
    this.eventUpdatesEnabled = true,
    this.nearbyEventsEnabled = true,
    this.recommendedEventsEnabled = true,
    this.useCurrentLocation = true,
    this.locationRadiusKm = 20,
    this.locationAccessEnabled = true,
    this.themePreference = 'system',
    this.textScaleFactor = 1.0,
    this.profileImageBase64,
    this.profileImageUrl,
    this.profileImageStoragePath,
    this.approvalStatus = AccountApprovalStatus.pending,
  });

  LocalUser copyWith({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? suburb,
    List<String>? interestedEventIds,
    List<String>? interestCategories,
    bool? notificationsEnabled,
    bool? eventRemindersEnabled,
    String? reminderTiming,
    bool? eventUpdatesEnabled,
    bool? nearbyEventsEnabled,
    bool? recommendedEventsEnabled,
    bool? useCurrentLocation,
    int? locationRadiusKm,
    bool? locationAccessEnabled,
    String? themePreference,
    double? textScaleFactor,
    String? profileImageBase64,
    String? profileImageUrl,
    String? profileImageStoragePath,
    AccountApprovalStatus? approvalStatus,
  }) {
    return LocalUser(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      suburb: suburb ?? this.suburb,
      interestedEventIds: interestedEventIds ?? this.interestedEventIds,
        interestCategories: interestCategories ?? this.interestCategories,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        eventRemindersEnabled:
          eventRemindersEnabled ?? this.eventRemindersEnabled,
        reminderTiming: reminderTiming ?? this.reminderTiming,
        eventUpdatesEnabled: eventUpdatesEnabled ?? this.eventUpdatesEnabled,
        nearbyEventsEnabled: nearbyEventsEnabled ?? this.nearbyEventsEnabled,
        recommendedEventsEnabled:
          recommendedEventsEnabled ?? this.recommendedEventsEnabled,
        useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
        locationRadiusKm: locationRadiusKm ?? this.locationRadiusKm,
        locationAccessEnabled:
          locationAccessEnabled ?? this.locationAccessEnabled,
        themePreference: themePreference ?? this.themePreference,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        profileImageStoragePath:
          profileImageStoragePath ?? this.profileImageStoragePath,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}

class LocalAuth {
  static final List<LocalUser> _users = [];

  static LocalUser? _currentLocal;
  static String? _lastErrorMessage;
  static bool _useFirestoreAuthFallback = false;
  static final ValueNotifier<int> _profileVersion = ValueNotifier<int>(0);

  static LocalUser? get currentLocal => _currentLocal;
  static bool get isLocalLoggedIn => _currentLocal != null;
  static String? get lastErrorMessage => _lastErrorMessage;
  static ValueListenable<int> get profileVersion => _profileVersion;

  @visibleForTesting
  static bool isApprovalAuthorized(AccountApprovalStatus status) {
    return status == AccountApprovalStatus.approved;
  }

  @visibleForTesting
  static String approvalDeniedMessage(AccountApprovalStatus status) {
    switch (status) {
      case AccountApprovalStatus.pending:
        return 'Your Local account is pending admin approval. You cannot access Local features yet.';
      case AccountApprovalStatus.rejected:
        return 'Your Local account was rejected by admin. Contact support for assistance.';
      case AccountApprovalStatus.approved:
        return '';
    }
  }

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
        final callable = FirebaseFunctions.instanceFor(region: AppConfig.firebaseFunctionsRegion)
          .httpsCallable('resolveUsername');
      final result = await callable.call<Map<String, dynamic>>({
        'username': normalized,
        'userType': 'local',
      });
      final data = result.data;
      if (data['error'] == 'duplicate') {
        _lastErrorMessage =
            'This username matches multiple accounts. Please log in with your email address.';
        return null;
      }
      return data['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  static bool emailExists(String email) {
    final normalized = email.trim().toLowerCase();
    return _users.any((u) => u.email.toLowerCase() == normalized);
  }

  static AccountApprovalStatus _approvalFromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return AccountApprovalStatus.approved;
      case 'rejected':
        return AccountApprovalStatus.rejected;
      default:
        return AccountApprovalStatus.pending;
    }
  }

  static Map<String, Object?> _buildLocalProfile({
    required String name,
    required String email,
    required String phone,
    required String suburb,
    required String passwordHash,
    required bool authFallback,
  }) {
    return {
      'name': name.trim(),
      'email': email,
      'username': _deriveUsername(email),
      'role': 'local',
      'phone': phone.trim(),
      'suburb': suburb.trim(),
      'accountType': 'local',
      'approvalStatus': 'pending',
      'notificationsEnabled': true,
      'eventRemindersEnabled': true,
      'reminderTiming': '24h',
      'eventUpdatesEnabled': true,
      'nearbyEventsEnabled': true,
      'recommendedEventsEnabled': true,
      'useCurrentLocation': true,
      'locationRadiusKm': 20,
      'locationAccessEnabled': true,
      'themePreference': 'system',
      'textScaleFactor': 1.0,
      'profileImageBase64': null,
      'profileImageUrl': null,
      'profileImageStoragePath': null,
      'interestCategories': const <String>[],
      'interestedEventIds': const <String>[],
      'passwordHash': passwordHash,
      'passwordUpdatedAt': FieldValue.serverTimestamp(),
      'authFallback': authFallback,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String suburb,
  }) async {
    _lastErrorMessage = 'Unable to create account. Please try again.';
    final normalizedEmail = email.trim().toLowerCase();

    if (emailExists(normalizedEmail)) {
      _lastErrorMessage = 'This email is already registered as a Local account.';
      return false;
    }

    try {
      await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(normalizedEmail)
          .set(
            _buildLocalProfile(
              name: name,
              email: normalizedEmail,
              phone: phone,
              suburb: suburb,
              passwordHash: _passwordHash(password),
              authFallback: false,
            ),
            SetOptions(merge: true),
          );
      await fb_auth.FirebaseAuth.instance.signOut();
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[LocalAuth] Firebase Auth register failed: code=${error.code}, message=${error.message}');
      switch (error.code) {
        case 'email-already-in-use':
          try {
            // Recovery path: account may already exist in Auth while Firestore profile is missing.
            await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
              email: normalizedEmail,
              password: password,
            );

            await FirebaseFirestore.instance
                .collection('local_users')
                .doc(normalizedEmail)
                .set(
                  _buildLocalProfile(
                    name: name,
                    email: normalizedEmail,
                    phone: phone,
                    suburb: suburb,
                    passwordHash: _passwordHash(password),
                    authFallback: false,
                  ),
                  SetOptions(merge: true),
                );

            await fb_auth.FirebaseAuth.instance.signOut();
            _lastErrorMessage = null;
            break;
          } on fb_auth.FirebaseAuthException catch (_) {
            _lastErrorMessage =
                'This email is already used by another account. Try logging in or use a different email.';
            return false;
          } on FirebaseException catch (firestoreError) {
            if (firestoreError.code == 'permission-denied') {
              _lastErrorMessage =
                  'Account exists, but Firestore blocked saving Local profile (permission denied).';
            } else {
              _lastErrorMessage =
                  'Account exists, but profile update failed (${firestoreError.code}).';
            }
            return false;
          }
        case 'invalid-email':
          _lastErrorMessage = 'Please enter a valid email address.';
          return false;
        case 'weak-password':
          _lastErrorMessage = 'Password is too weak. Use at least 6 characters.';
          return false;
        case 'network-request-failed':
          _lastErrorMessage = 'Network error. Check your connection and try again.';
          return false;
        case 'operation-not-allowed':
          _lastErrorMessage =
              'Local registration is unavailable because Firebase email/password sign-up is disabled.';
          return false;
        default:
          final rawMessage = (error.message ?? '').trim();
          if (error.code == 'unknown') {
            _lastErrorMessage =
                'Local registration could not verify the new account with Firebase Auth.';
            return false;
          } else {
            if (rawMessage.isNotEmpty) {
              _lastErrorMessage = 'Unable to create account (${error.code}): $rawMessage';
            } else {
              _lastErrorMessage = 'Unable to create account (${error.code}).';
            }
            return false;
          }
      }
    } on FirebaseException catch (error) {
      debugPrint('[LocalAuth] Firestore write failed: code=${error.code}, message=${error.message}');
      if (error.code == 'permission-denied') {
        _lastErrorMessage =
            'Account created in Firebase Auth, but Firestore blocked saving profile (permission denied).';
      } else {
        final rawMessage = (error.message ?? '').trim();
        if (rawMessage.isNotEmpty) {
          _lastErrorMessage = 'Could not save account profile (${error.code}): $rawMessage';
        } else {
          _lastErrorMessage = 'Could not save account profile (${error.code}).';
        }
      }
      return false;
    } catch (error) {
      debugPrint('[LocalAuth] Failed to write local account: $error');
      _lastErrorMessage = 'Could not save account. Please try again.';
      return false;
    }

    _useFirestoreAuthFallback = false;

    final localUser = LocalUser(
      name: name.trim(),
      email: normalizedEmail,
      password: password,
      phone: phone.trim(),
      suburb: suburb.trim(),
      notificationsEnabled: true,
      approvalStatus: AccountApprovalStatus.pending,
    );
    final existingIndex = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (existingIndex >= 0) {
      _users[existingIndex] = localUser;
    } else {
      _users.add(localUser);
    }

        LocalEmailNotificationService()
            .queueRegistrationReceivedEmail(
              recipientEmail: normalizedEmail,
              businessName: name.trim(),
            )
            .catchError((_) {
          // Registration should still succeed if queuing email fails.
        });

        SmsNotificationService()
            .queueLocalAccountRegistrationReceivedSms(
              recipientPhone: phone.trim(),
              businessName: name.trim(),
            )
            .catchError((_) {
          // Registration should still succeed if queuing SMS fails.
        });

    return true;
  }

  static Future<bool> login({required String email, required String password}) async {
    _lastErrorMessage = null;
    final normalizedEmail = await _resolveLoginEmail(email);
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      _lastErrorMessage ??= 'Invalid email or username.';
      return false;
    }

    try {
      if (!_useFirestoreAuthFallback) {
        await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      }
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[LocalAuth] Firebase Auth login failed: ${error.code}');
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
        case 'keychain-error':
          _lastErrorMessage = 'Keychain access failed. Retrying with secure fallback.';
          break;
        default:
          _lastErrorMessage = 'Login failed (${error.code}).';
      }
      _useFirestoreAuthFallback =
          error.code == 'operation-not-allowed' ||
          error.code == 'keychain-error';
      if (!_useFirestoreAuthFallback) {
        return false;
      }
    } catch (_) {
      _lastErrorMessage = 'Login failed due to an unexpected error.';
      return false;
    }

    // On unsigned macOS builds Firebase Auth may fail with keychain-error.
    // Firestore rules are relaxed for local development so we can validate
    // credentials and load the profile without a signed-in Firebase user.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('local_users')
          .doc(normalizedEmail)
          .get();

      final data = doc.data();
      if (data == null) {
        _lastErrorMessage = 'No Local profile found for this account.';
        return false;
      }

      final role = (data['role'] as String?)?.toLowerCase();
      final accountType = (data['accountType'] as String?)?.toLowerCase();
      if ((role != null && role.isNotEmpty && role != 'local') ||
          (accountType != null && accountType.isNotEmpty && accountType != 'local')) {
        await fb_auth.FirebaseAuth.instance.signOut();
        _lastErrorMessage = 'Access denied: this account is not a Local account.';
        return false;
      }

      final isActive = (data['active'] as bool?) ?? true;
      if (!isActive) {
        await fb_auth.FirebaseAuth.instance.signOut();
        _lastErrorMessage = 'This account has been deactivated. Contact support for assistance.';
        return false;
      }

          final approvalStatus = _approvalFromString(
            (data['approvalStatus'] as String?) ?? 'pending',
          );
          if (!isApprovalAuthorized(approvalStatus)) {
            await fb_auth.FirebaseAuth.instance.signOut();
            _lastErrorMessage = approvalDeniedMessage(approvalStatus);
            return false;
          }

      final storedPasswordHash = (data['passwordHash'] as String?) ?? '';
      final storedLegacyPassword = (data['password'] as String?) ?? '';
      final matchesHashedPassword =
          storedPasswordHash.isNotEmpty && storedPasswordHash == _passwordHash(password);
      final matchesLegacyPassword =
          storedLegacyPassword.isNotEmpty && storedLegacyPassword == password;
      if (_useFirestoreAuthFallback && !matchesHashedPassword && !matchesLegacyPassword) {
        _lastErrorMessage = 'Invalid email or password.';
        return false;
      }

      try {
        await FirebaseFirestore.instance
            .collection('local_users')
            .doc(normalizedEmail)
            .set({
          'role': 'local',
          'accountType': 'local',
          'email': normalizedEmail,
          'username': _deriveUsername(normalizedEmail),
          'passwordHash': _passwordHash(password),
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Non-critical: login can continue if role metadata update fails.
      }

      final user = LocalUser(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : normalizedEmail.split('@').first,
        email: normalizedEmail,
        password: password,
        phone: (data['phone'] as String?) ?? '',
        suburb: (data['suburb'] as String?) ?? '',
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        interestCategories: ((data['interestCategories'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        eventRemindersEnabled:
            (data['eventRemindersEnabled'] as bool?) ?? true,
        reminderTiming: (data['reminderTiming'] as String?) ?? '24h',
        eventUpdatesEnabled: (data['eventUpdatesEnabled'] as bool?) ?? true,
        nearbyEventsEnabled: (data['nearbyEventsEnabled'] as bool?) ?? true,
        recommendedEventsEnabled:
            (data['recommendedEventsEnabled'] as bool?) ?? true,
        useCurrentLocation: (data['useCurrentLocation'] as bool?) ?? true,
        locationRadiusKm: (data['locationRadiusKm'] as num?)?.toInt() ?? 20,
        locationAccessEnabled:
            (data['locationAccessEnabled'] as bool?) ?? true,
        themePreference: (data['themePreference'] as String?) ?? 'system',
        textScaleFactor:
            (data['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
        profileImageBase64: (data['profileImageBase64'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageBase64'] as String)
            : null,
        profileImageUrl: (data['profileImageUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageUrl'] as String)
            : null,
        profileImageStoragePath: (data['profileImageStoragePath'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageStoragePath'] as String)
            : null,
        approvalStatus: _approvalFromString(
          (data['approvalStatus'] as String?) ?? 'pending',
        ),
      );

      final userIndex = _users.indexWhere(
        (u) => u.email.toLowerCase() == normalizedEmail,
      );
      if (userIndex >= 0) {
        _users[userIndex] = user;
      } else {
        _users.add(user);
      }

      _currentLocal = user;
      _lastErrorMessage = null;
      _profileVersion.value++;
      AppDisplaySettingsController.applyFromPersisted(
        locationAccessEnabled: user.locationAccessEnabled,
        themePreference: user.themePreference,
        textScaleFactor: user.textScaleFactor,
      );
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _lastErrorMessage = 'Firestore denied access to your Local profile.';
      } else if (error.code == 'unavailable') {
        _lastErrorMessage = 'No internet connection. Please try again.';
      } else {
        _lastErrorMessage = 'Could not load Local profile (${error.code}).';
      }
      return false;
    } catch (_) {
      _lastErrorMessage = 'Could not load Local profile. Please try again.';
      return false;
    }
  }

  static Future<bool> sendPasswordReset({required String emailOrUsername}) async {
    debugPrint('[LocalAuth] sendPasswordReset called with: $emailOrUsername');
    _lastErrorMessage = null;

    final normalized = emailOrUsername.trim().toLowerCase();
    debugPrint('[LocalAuth] normalized email: $normalized');
    if (normalized.isEmpty) {
      _lastErrorMessage = 'Please enter your email address.';
      debugPrint('[LocalAuth] email is empty');
      return false;
    }

    if (!normalized.contains('@')) {
      _lastErrorMessage = 'Please enter your email address (not your username) to reset your password.';
      debugPrint('[LocalAuth] email does not contain @');
      return false;
    }

    try {
      debugPrint('[LocalAuth] calling Firebase sendPasswordResetEmail for: $normalized');
      await fb_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalized,
      );
      debugPrint('[LocalAuth] password reset email sent successfully');
      return true;
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[LocalAuth] Firebase error: code=${error.code}, message=${error.message}');
      switch (error.code) {
        case 'invalid-email':
          _lastErrorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          _lastErrorMessage = 'Too many reset attempts. Please try again later.';
          break;
        case 'network-request-failed':
          _lastErrorMessage = 'No internet connection. Please try again.';
          break;
        default:
          _lastErrorMessage = 'Could not send reset email. Please try again.';
      }
      debugPrint('[LocalAuth] error message set to: $_lastErrorMessage');
      return false;
    } catch (e) {
      debugPrint('[LocalAuth] Unexpected error: $e');
      _lastErrorMessage = 'Could not send reset email. Please try again.';
      return false;
    }
  }

  static Future<void> logout() async {
    await fb_auth.FirebaseAuth.instance.signOut();
    _currentLocal = null;
    _profileVersion.value++;
  }

  @visibleForTesting
  static void debugSetCurrentLocalForTesting(LocalUser? user) {
    _currentLocal = user;
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
    _profileVersion.value++;
  }

  /// Updates name, phone and suburb for the currently logged-in Local user.
  static Future<bool> updateProfile({
    required String name,
    String? phone,
    String? suburb,
  }) async {
    final current = _currentLocal;
    if (current == null) return false;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;
    try {
      final updates = <String, dynamic>{
        'name': trimmedName,
        if (phone != null) 'phone': phone.trim(),
        if (suburb != null) 'suburb': suburb.trim(),
      };
      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(current.email)
          .update(updates);
      final updated = current.copyWith(
        name: trimmedName,
        phone: phone?.trim() ?? current.phone,
        suburb: suburb?.trim() ?? current.suburb,
      );
      _currentLocal = updated;
      final idx = _users.indexWhere(
        (u) => u.email.toLowerCase() == current.email.toLowerCase(),
      );
      if (idx != -1) _users[idx] = updated;
      _profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[LocalAuth] updateProfile failed: ${e.code}');
      _lastErrorMessage = 'Could not update profile (${e.code}).';
      return false;
    } catch (_) {
      _lastErrorMessage = 'Could not update profile.';
      return false;
    }
  }

  static LocalUser _localUserFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final docEmail = doc.id.trim().toLowerCase();
    final storedEmail = (data['email'] as String?)?.trim().toLowerCase();
    final email = storedEmail?.isNotEmpty == true ? storedEmail! : docEmail;

    return LocalUser(
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : email.split('@').first,
      email: email,
      password: (data['password'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      suburb: (data['suburb'] as String?) ?? '',
      interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
        interestCategories: ((data['interestCategories'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        eventRemindersEnabled:
          (data['eventRemindersEnabled'] as bool?) ?? true,
        reminderTiming: (data['reminderTiming'] as String?) ?? '24h',
        eventUpdatesEnabled: (data['eventUpdatesEnabled'] as bool?) ?? true,
        nearbyEventsEnabled: (data['nearbyEventsEnabled'] as bool?) ?? true,
        recommendedEventsEnabled:
          (data['recommendedEventsEnabled'] as bool?) ?? true,
        useCurrentLocation: (data['useCurrentLocation'] as bool?) ?? true,
        locationRadiusKm: (data['locationRadiusKm'] as num?)?.toInt() ?? 20,
        locationAccessEnabled: (data['locationAccessEnabled'] as bool?) ?? true,
        themePreference: (data['themePreference'] as String?) ?? 'system',
        textScaleFactor:
          (data['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
      profileImageBase64: (data['profileImageBase64'] as String?)?.trim().isNotEmpty == true
          ? (data['profileImageBase64'] as String)
          : null,
        profileImageUrl: (data['profileImageUrl'] as String?)?.trim().isNotEmpty == true
          ? (data['profileImageUrl'] as String)
          : null,
        profileImageStoragePath:
          (data['profileImageStoragePath'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageStoragePath'] as String)
            : null,
      approvalStatus: _approvalFromString(
        (data['approvalStatus'] as String?) ?? 'pending',
      ),
    );
  }

  static Stream<List<LocalUser>> pendingAccountsStream() {
    return FirebaseFirestore.instance
        .collection('local_users')
        .where('approvalStatus', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_localUserFromFirestore)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        );
  }

  static Stream<List<LocalUser>> reviewedAccountsStream() {
    return FirebaseFirestore.instance
        .collection('local_users')
        .where('approvalStatus', whereIn: const ['approved', 'rejected'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_localUserFromFirestore)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        );
  }

  // Account approval methods
  static List<LocalUser> getPendingAccounts() {
    return _users.where((u) => u.approvalStatus == AccountApprovalStatus.pending).toList();
  }

  static List<LocalUser> getApprovedAccounts() {
    return _users.where((u) => u.approvalStatus == AccountApprovalStatus.approved).toList();
  }

  static List<LocalUser> getReviewedAccounts() {
    return _users
        .where((u) => u.approvalStatus == AccountApprovalStatus.approved || u.approvalStatus == AccountApprovalStatus.rejected)
        .toList();
  }

  static Future<bool> approveAccount(LocalUser user) async {
    _lastErrorMessage = null;
    final normalizedEmail = user.email.trim().toLowerCase();

    try {
      await FirebaseFirestore.instance.collection('local_users').doc(normalizedEmail).set({
        'approvalStatus': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': fb_auth.FirebaseAuth.instance.currentUser?.email?.toLowerCase(),
      }, SetOptions(merge: true));

      final index = _users.indexWhere((u) => u.email.toLowerCase() == normalizedEmail);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(approvalStatus: AccountApprovalStatus.approved);
        if (_currentLocal?.email.toLowerCase() == normalizedEmail) {
          _currentLocal = _users[index];
        }
      }
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _lastErrorMessage = 'Approval denied by Firestore rules. Sign in as an active admin.';
      } else {
        _lastErrorMessage = 'Could not approve account (${error.code}).';
      }
      return false;
    } catch (_) {
      _lastErrorMessage = 'Could not approve account due to an unexpected error.';
      return false;
    }
  }

  static Future<bool> rejectAccount(LocalUser user) async {
    _lastErrorMessage = null;
    final normalizedEmail = user.email.trim().toLowerCase();

    try {
      await FirebaseFirestore.instance.collection('local_users').doc(normalizedEmail).set({
        'approvalStatus': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': fb_auth.FirebaseAuth.instance.currentUser?.email?.toLowerCase(),
      }, SetOptions(merge: true));

      final index = _users.indexWhere((u) => u.email.toLowerCase() == normalizedEmail);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(approvalStatus: AccountApprovalStatus.rejected);
        if (_currentLocal?.email.toLowerCase() == normalizedEmail) {
          _currentLocal = null;
        }
      }
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _lastErrorMessage = 'Rejection denied by Firestore rules. Sign in as an active admin.';
      } else {
        _lastErrorMessage = 'Could not reject account (${error.code}).';
      }
      return false;
    } catch (_) {
      _lastErrorMessage = 'Could not reject account due to an unexpected error.';
      return false;
    }
  }

  /// Restores a local user session from Firestore after an app restart.
  /// Called during startup when Firebase Auth still has a cached user.
  static Future<bool> restoreSession(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final doc = await FirebaseFirestore.instance
          .collection('local_users')
          .doc(normalizedEmail)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() ?? const <String, dynamic>{};
      final role = (data['role'] as String?)?.toLowerCase();
      final accountType = (data['accountType'] as String?)?.toLowerCase();
      if ((role != null && role.isNotEmpty && role != 'local') ||
          (accountType != null && accountType.isNotEmpty && accountType != 'local')) {
        return false;
      }
      final approvalStatus = _approvalFromString(
        (data['approvalStatus'] as String?) ?? 'pending',
      );
      if (!isApprovalAuthorized(approvalStatus)) {
        return false;
      }
      final user = LocalUser(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : normalizedEmail.split('@').first,
        email: normalizedEmail,
        password: (data['password'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        suburb: (data['suburb'] as String?) ?? '',
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        interestCategories: ((data['interestCategories'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        eventRemindersEnabled:
          (data['eventRemindersEnabled'] as bool?) ?? true,
        reminderTiming: (data['reminderTiming'] as String?) ?? '24h',
        eventUpdatesEnabled: (data['eventUpdatesEnabled'] as bool?) ?? true,
        nearbyEventsEnabled: (data['nearbyEventsEnabled'] as bool?) ?? true,
        recommendedEventsEnabled:
          (data['recommendedEventsEnabled'] as bool?) ?? true,
        useCurrentLocation: (data['useCurrentLocation'] as bool?) ?? true,
        locationRadiusKm: (data['locationRadiusKm'] as num?)?.toInt() ?? 20,
        locationAccessEnabled: (data['locationAccessEnabled'] as bool?) ?? true,
        themePreference: (data['themePreference'] as String?) ?? 'system',
        textScaleFactor:
          (data['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
        profileImageBase64: (data['profileImageBase64'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageBase64'] as String)
            : null,
        profileImageUrl: (data['profileImageUrl'] as String?)?.trim().isNotEmpty == true
          ? (data['profileImageUrl'] as String)
          : null,
        profileImageStoragePath:
          (data['profileImageStoragePath'] as String?)?.trim().isNotEmpty == true
            ? (data['profileImageStoragePath'] as String)
            : null,
        approvalStatus: approvalStatus,
      );
      final idx = _users.indexWhere((u) => u.email.toLowerCase() == normalizedEmail);
      if (idx >= 0) {
        _users[idx] = user;
      } else {
        _users.add(user);
      }
      _currentLocal = user;
      _profileVersion.value++;
      AppDisplaySettingsController.applyFromPersisted(
        locationAccessEnabled: user.locationAccessEnabled,
        themePreference: user.themePreference,
        textScaleFactor: user.textScaleFactor,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Set<String> getInterestedEventIds() {
    return (_currentLocal?.interestedEventIds ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool isInterestedInEvent(String eventId) {
    final normalized = eventId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _currentLocal?.interestedEventIds
            .map((id) => id.trim())
            .contains(normalized) ??
        false;
  }

  static bool toggleInterestedEvent(String eventId) {
    final current = _currentLocal;
    if (current == null) {
      return false;
    }

    final normalized = eventId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final updatedIds = current.interestedEventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: true);
    if (updatedIds.contains(normalized)) {
      updatedIds.remove(normalized);
    } else {
      updatedIds.add(normalized);
    }

    final updatedUser = current.copyWith(interestedEventIds: updatedIds);
    final userIndex = _users.indexWhere(
      (user) => user.email.toLowerCase() == current.email.toLowerCase(),
    );
    if (userIndex != -1) {
      _users[userIndex] = updatedUser;
    }
    _currentLocal = updatedUser;
    _profileVersion.value++;

    final currentNormalized = current.interestedEventIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
    final wasAdded =
      updatedIds.contains(normalized) && !currentNormalized.contains(normalized);

    FirebaseFirestore.instance
        .collection('local_users')
        .doc(current.email)
        .set(
      {'interestedEventIds': updatedIds},
      SetOptions(merge: true),
    ).catchError((e) {
      debugPrint('[LocalAuth] Failed to persist interested events: $e');
    });

    if (wasAdded) {
      SmsNotificationService()
          .queueLocalSavedEventSms(
            localEmail: current.email,
            eventId: normalized,
          )
          .catchError((e) {
        debugPrint('[LocalAuth] Failed to queue saved-event SMS: $e');
        return false;
      });

      _queueLocalEventSavedEmail(current.email, current.name, normalized);

      // Best-effort increment of the event's saved count for owner analytics.
      FirebaseFirestore.instance
          .collection('business_events')
          .doc(normalized)
          .get()
          .then((doc) async {
        if (!doc.exists) return;
        final businessId = (doc.data()?['businessId'] as String?)?.trim();
        if (businessId != null && businessId.isNotEmpty) {
          final visitorId = fb_auth.FirebaseAuth.instance.currentUser?.uid;
          await BusinessDashboardService().recordSave(
            businessId,
            visitorId: visitorId,
          );
        }
      }).catchError((e) {
        debugPrint('[LocalAuth] Failed to record save metric: $e');
      });
    }

    return true;
  }

  static void _queueLocalEventSavedEmail(String email, String name, String eventId) {
    FirebaseFirestore.instance.collection('events').doc(eventId).get().then((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      final title = ((data['title'] as String?) ?? '').trim();
      final date = ((data['date'] as String?) ?? '').trim();
      final location = ((data['location'] as String?) ?? '').trim();
      if (title.isEmpty) return;
      LocalEmailNotificationService()
          .queueEventSavedEmail(
            recipientEmail: email,
            businessName: name,
            eventTitle: title,
            eventDate: date,
            eventLocation: location,
          )
          .catchError((e) {
        debugPrint('[LocalAuth] Failed to queue saved-event email: $e');
      });
    }).catchError((e) {
      debugPrint('[LocalAuth] Failed to fetch event for email: $e');
    });
  }

  static bool areNotificationsEnabled() {
    return _currentLocal?.notificationsEnabled ?? true;
  }

  static Future<bool> setNotificationsEnabled(bool enabled) async {
    final current = _currentLocal;
    if (current == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(current.email)
          .update({'notificationsEnabled': enabled});

      final updated = current.copyWith(notificationsEnabled: enabled);
      _currentLocal = updated;
      final idx = _users.indexWhere((u) => u.email == current.email);
      if (idx != -1) _users[idx] = updated;
      _profileVersion.value++;
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[LocalAuth] setNotificationsEnabled failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool areEventRemindersEnabled() {
    return _currentLocal?.eventRemindersEnabled ?? true;
  }

  static String getReminderTiming() {
    return _currentLocal?.reminderTiming ?? '24h';
  }

  static bool isLocationAccessEnabled() {
    return _currentLocal?.locationAccessEnabled ?? true;
  }

  static String getThemePreference() {
    return _currentLocal?.themePreference ?? 'system';
  }

  static double getTextScaleFactor() {
    return _currentLocal?.textScaleFactor ?? 1.0;
  }

  static Future<List<String>> getInterestCategories() async {
    return List<String>.from(_currentLocal?.interestCategories ?? const []);
  }

  static Future<bool> setInterestCategories(List<String> categories) async {
    return _mergeCurrentLocal(
      firestoreData: {'interestCategories': categories},
      updatedUser: (current) => current.copyWith(interestCategories: categories),
    );
  }

  static Future<bool> setLocationSettings({
    bool? useCurrentLocation,
    int? locationRadiusKm,
  }) async {
    return _mergeCurrentLocal(
      firestoreData: {
        if (useCurrentLocation != null)
          'useCurrentLocation': useCurrentLocation,
        if (locationRadiusKm != null) 'locationRadiusKm': locationRadiusKm,
      },
      updatedUser: (current) => current.copyWith(
        useCurrentLocation: useCurrentLocation,
        locationRadiusKm: locationRadiusKm,
      ),
    );
  }

  static Future<bool> setGeneralAppSettings({
    bool? locationAccessEnabled,
    String? themePreference,
    double? textScaleFactor,
  }) async {
    return _mergeCurrentLocal(
      firestoreData: {
        if (locationAccessEnabled != null)
          'locationAccessEnabled': locationAccessEnabled,
        if (themePreference != null) 'themePreference': themePreference,
        if (textScaleFactor != null) 'textScaleFactor': textScaleFactor,
      },
      updatedUser: (current) => current.copyWith(
        locationAccessEnabled: locationAccessEnabled,
        themePreference: themePreference,
        textScaleFactor: textScaleFactor,
      ),
    );
  }

  static Future<bool> setNotificationSettings({
    bool? notificationsEnabled,
    bool? eventRemindersEnabled,
    String? reminderTiming,
    bool? eventUpdatesEnabled,
    bool? nearbyEventsEnabled,
    bool? recommendedEventsEnabled,
  }) async {
    return _mergeCurrentLocal(
      firestoreData: {
        if (notificationsEnabled != null)
          'notificationsEnabled': notificationsEnabled,
        if (eventRemindersEnabled != null)
          'eventRemindersEnabled': eventRemindersEnabled,
        if (reminderTiming != null) 'reminderTiming': reminderTiming,
        if (eventUpdatesEnabled != null)
          'eventUpdatesEnabled': eventUpdatesEnabled,
        if (nearbyEventsEnabled != null)
          'nearbyEventsEnabled': nearbyEventsEnabled,
        if (recommendedEventsEnabled != null)
          'recommendedEventsEnabled': recommendedEventsEnabled,
      },
      updatedUser: (current) => current.copyWith(
        notificationsEnabled: notificationsEnabled,
        eventRemindersEnabled: eventRemindersEnabled,
        reminderTiming: reminderTiming,
        eventUpdatesEnabled: eventUpdatesEnabled,
        nearbyEventsEnabled: nearbyEventsEnabled,
        recommendedEventsEnabled: recommendedEventsEnabled,
      ),
    );
  }

  static Future<bool> updateProfileImage({
    String? base64Image,
    String? imageUrl,
    String? storagePath,
  }) async {
    final current = _currentLocal;
    if (current == null) return false;
    final resolvedBase64 = base64Image;

    try {
      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(current.email)
          .update({
        'profileImageBase64': resolvedBase64,
        'profileImageUrl': imageUrl,
        'profileImageStoragePath': storagePath,
      });

      final updated = current.copyWith(
        profileImageBase64: resolvedBase64,
        profileImageUrl: imageUrl,
        profileImageStoragePath: storagePath,
      );
      _replaceCurrentLocal(updated);
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[LocalAuth] updateProfileImage failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _mergeCurrentLocal({
    required Map<String, Object?> firestoreData,
    required LocalUser Function(LocalUser current) updatedUser,
  }) async {
    final current = _currentLocal;
    if (current == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('local_users')
          .doc(current.email)
          .set(firestoreData, SetOptions(merge: true));
      _replaceCurrentLocal(updatedUser(current));
      return true;
    } on FirebaseException catch (error) {
      debugPrint('[LocalAuth] Failed to persist local settings: ${error.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static void _replaceCurrentLocal(LocalUser updated) {
    _currentLocal = updated;
    final idx = _users.indexWhere((u) => u.email == updated.email);
    if (idx != -1) {
      _users[idx] = updated;
    } else {
      _users.add(updated);
    }
    _profileVersion.value++;
  }
}
