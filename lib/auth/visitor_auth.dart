import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/services/visitor_email_notification_service.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';

class VisitorUser {
  final String name;
  final String email;
  final String password;
  final String phone;
  final List<String> interestedEventIds;
  final List<String> savedAttractionIds;
  final List<String> interestCategories;
  final List<String> interestPriorities;
  final bool notificationsEnabled;
  final bool eventRemindersEnabled;
  final String reminderTiming;
  final bool eventUpdatesEnabled;
  final bool nearbyEventsEnabled;
  final bool recommendedEventsEnabled;
  final bool emailNotificationsEnabled;
  final bool useCurrentLocation;
  final int locationRadiusKm;
  final bool locationAccessEnabled;
  final String themePreference;
  final double textScaleFactor;
  final String? profileImageBase64;
  final String? profileImageUrl;
  final String? profileImageStoragePath;

  const VisitorUser({
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.interestedEventIds = const [],
    this.savedAttractionIds = const [],
    this.interestCategories = const [],
    this.interestPriorities = const [],
    this.notificationsEnabled = true,
    this.eventRemindersEnabled = true,
    this.reminderTiming = '24h',
    this.eventUpdatesEnabled = true,
    this.nearbyEventsEnabled = true,
    this.recommendedEventsEnabled = true,
    this.emailNotificationsEnabled = true,
    this.useCurrentLocation = true,
    this.locationRadiusKm = 20,
    this.locationAccessEnabled = true,
    this.themePreference = 'system',
    this.textScaleFactor = 1.0,
    this.profileImageBase64,
    this.profileImageUrl,
    this.profileImageStoragePath,
  });

  VisitorUser copyWith({
    String? name,
    String? email,
    String? password,
    String? phone,
    List<String>? interestedEventIds,
    List<String>? savedAttractionIds,
    List<String>? interestCategories,
    List<String>? interestPriorities,
    bool? notificationsEnabled,
    bool? eventRemindersEnabled,
    String? reminderTiming,
    bool? eventUpdatesEnabled,
    bool? nearbyEventsEnabled,
    bool? recommendedEventsEnabled,
    bool? emailNotificationsEnabled,
    bool? useCurrentLocation,
    int? locationRadiusKm,
    bool? locationAccessEnabled,
    String? themePreference,
    double? textScaleFactor,
    String? profileImageBase64,
    String? profileImageUrl,
    String? profileImageStoragePath,
  }) {
    return VisitorUser(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      interestedEventIds: interestedEventIds ?? this.interestedEventIds,
      savedAttractionIds: savedAttractionIds ?? this.savedAttractionIds,
      interestCategories: interestCategories ?? this.interestCategories,
      interestPriorities: interestPriorities ?? this.interestPriorities,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      eventRemindersEnabled:
          eventRemindersEnabled ?? this.eventRemindersEnabled,
      reminderTiming: reminderTiming ?? this.reminderTiming,
      eventUpdatesEnabled: eventUpdatesEnabled ?? this.eventUpdatesEnabled,
      nearbyEventsEnabled: nearbyEventsEnabled ?? this.nearbyEventsEnabled,
      recommendedEventsEnabled:
          recommendedEventsEnabled ?? this.recommendedEventsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
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
    );
  }
}

class VisitorAuth {
  static final List<VisitorUser> _users = [];
  static VisitorUser? _currentVisitor;
  static final ValueNotifier<int> _interestedEventsVersion = ValueNotifier<int>(0);
  static final ValueNotifier<int> _profileVersion = ValueNotifier<int>(0);
  static String? _lastErrorMessage;
  static bool _isEmailUnverified = false;

  static VisitorUser? get currentVisitor => _currentVisitor;
  static bool get isVisitorLoggedIn => _currentVisitor != null;
  static bool get isEmailUnverified => _isEmailUnverified;
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
        final callable = FirebaseFunctions.instanceFor(region: AppConfig.firebaseFunctionsRegion)
          .httpsCallable('resolveUsername');
      final result = await callable.call<Map<String, dynamic>>({
        'username': normalized,
        'userType': 'visitor',
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
    return _users.any((user) => user.email.toLowerCase() == normalized);
  }

  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
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
        'phone': phone.trim(),
        'username': _deriveUsername(normalizedEmail),
        'role': 'visitor',
        'interestedEventIds': const <String>[],
        'savedAttractionIds': const <String>[],
        'interestCategories': const <String>[],
        'interestPriorities': const <String>[],
        'notificationsEnabled': true,
        'eventRemindersEnabled': true,
        'reminderTiming': '24h',
        'eventUpdatesEnabled': true,
        'nearbyEventsEnabled': true,
        'recommendedEventsEnabled': true,
        'emailNotificationsEnabled': true,
        'useCurrentLocation': true,
        'locationRadiusKm': 20,
        'locationAccessEnabled': true,
        'themePreference': 'system',
        'textScaleFactor': 1.0,
        'profileImageBase64': null,
        'profileImageUrl': null,
        'profileImageStoragePath': null,
        'passwordHash': _passwordHash(password),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await VisitorEmailNotificationService().queueRegistrationReceivedEmail(
          recipientEmail: normalizedEmail,
          visitorName: name.trim(),
        );
      } catch (error) {
        debugPrint(
          '[VisitorAuth] Failed to queue visitor welcome email: $error',
        );
      }

      if (phone.trim().isNotEmpty) {
        try {
          await SmsNotificationService().queueVisitorRegistrationReceivedSms(
            recipientPhone: phone.trim(),
            visitorName: name.trim(),
          );
        } catch (error) {
          debugPrint('[VisitorAuth] Failed to queue visitor welcome SMS: $error');
        }
      }

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
          phone: phone.trim(),
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

      _isEmailUnverified = false;

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
        phone: (data['phone'] as String?) ?? '',
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        savedAttractionIds: ((data['savedAttractionIds'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        interestCategories: ((data['interestCategories'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        interestPriorities: ((data['interestPriorities'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        eventRemindersEnabled:
          (data['eventRemindersEnabled'] as bool?) ?? true,
        reminderTiming: (data['reminderTiming'] as String?) ?? '24h',
        eventUpdatesEnabled: (data['eventUpdatesEnabled'] as bool?) ?? true,
        nearbyEventsEnabled: (data['nearbyEventsEnabled'] as bool?) ?? true,
        recommendedEventsEnabled:
          (data['recommendedEventsEnabled'] as bool?) ?? true,
        emailNotificationsEnabled:
          (data['emailNotificationsEnabled'] as bool?) ?? true,
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
      AppDisplaySettingsController.applyFromPersisted(
        locationAccessEnabled: user.locationAccessEnabled,
        themePreference: user.themePreference,
        textScaleFactor: user.textScaleFactor,
      );
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

  static Future<bool> sendPasswordReset({required String emailOrUsername}) async {
    debugPrint('[VisitorAuth] sendPasswordReset called with: $emailOrUsername');
    _lastErrorMessage = null;

    final normalized = emailOrUsername.trim().toLowerCase();
    debugPrint('[VisitorAuth] normalized email: $normalized');
    if (normalized.isEmpty) {
      _lastErrorMessage = 'Please enter your email address.';
      debugPrint('[VisitorAuth] email is empty');
      return false;
    }

    if (!normalized.contains('@')) {
      _lastErrorMessage = 'Please enter your email address (not your username) to reset your password.';
      debugPrint('[VisitorAuth] email does not contain @');
      return false;
    }

    try {
      debugPrint('[VisitorAuth] calling Firebase sendPasswordResetEmail for: $normalized');
      await fb_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalized,
      );
      debugPrint('[VisitorAuth] password reset email sent successfully');
      return true;
    } on fb_auth.FirebaseAuthException catch (error) {
      debugPrint('[VisitorAuth] Firebase error: code=${error.code}, message=${error.message}');
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
      debugPrint('[VisitorAuth] error message set to: $_lastErrorMessage');
      return false;
    } catch (e) {
      debugPrint('[VisitorAuth] Unexpected error: $e');
      _lastErrorMessage = 'Could not send reset email. Please try again.';
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
    return (_currentVisitor?.interestedEventIds ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool isInterestedInEvent(String eventId) {
    final normalized = eventId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _currentVisitor?.interestedEventIds
            .map((id) => id.trim())
            .contains(normalized) ??
        false;
  }

  static bool toggleInterestedEvent(String eventId) {
    final current = _currentVisitor;
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
    final wasAlreadyInterested = updatedIds.contains(normalized);
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

    if (!wasAlreadyInterested) {
      SmsNotificationService()
          .queueVisitorSavedEventSms(
            visitorEmail: current.email,
            eventId: normalized,
          )
          .catchError((e) {
        debugPrint('[VisitorAuth] Failed to queue saved-event SMS: $e');
        return false;
      });

      _queueEventSavedEmail(current.email, current.name, normalized);

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
        debugPrint('[VisitorAuth] Failed to record save metric: $e');
      });
    }

    return true;
  }

  static void _queueEventSavedEmail(String email, String name, String eventId) {
    FirebaseFirestore.instance.collection('events').doc(eventId).get().then((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      final title = ((data['title'] as String?) ?? '').trim();
      final date = ((data['date'] as String?) ?? '').trim();
      final location = ((data['location'] as String?) ?? '').trim();
      if (title.isEmpty) return;
      VisitorEmailNotificationService()
          .queueEventSavedEmail(
            recipientEmail: email,
            visitorName: name,
            eventTitle: title,
            eventDate: date,
            eventLocation: location,
          )
          .catchError((e) {
        debugPrint('[VisitorAuth] Failed to queue saved-event email: $e');
      });
    }).catchError((e) {
      debugPrint('[VisitorAuth] Failed to fetch event for email: $e');
    });
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

  /// Updates the visitor's display name and phone in Firestore and in-memory.
  static Future<bool> updateProfileInfo({
    required String newName,
    required String newPhone,
  }) async {
    final current = _currentVisitor;
    if (current == null) return false;

    final trimmedName = newName.trim();
    final trimmedPhone = newPhone.trim();
    if (trimmedName.isEmpty) return false;

    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(current.email)
          .set(
        {
          'name': trimmedName,
          'phone': trimmedPhone,
        },
        SetOptions(merge: true),
      );

      final updated = current.copyWith(
        name: trimmedName,
        phone: trimmedPhone,
      );
      _replaceCurrentVisitor(updated);
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[VisitorAuth] updateProfileInfo failed: ${e.code}');
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
        phone: (data['phone'] as String?) ?? '',
        interestedEventIds: ((data['interestedEventIds'] as List?) ?? const [])
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        savedAttractionIds: ((data['savedAttractionIds'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        interestCategories: ((data['interestCategories'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        interestPriorities: ((data['interestPriorities'] as List?) ?? const [])
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
        notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
        eventRemindersEnabled:
          (data['eventRemindersEnabled'] as bool?) ?? true,
        reminderTiming: (data['reminderTiming'] as String?) ?? '24h',
        eventUpdatesEnabled: (data['eventUpdatesEnabled'] as bool?) ?? true,
        nearbyEventsEnabled: (data['nearbyEventsEnabled'] as bool?) ?? true,
        recommendedEventsEnabled:
          (data['recommendedEventsEnabled'] as bool?) ?? true,
        emailNotificationsEnabled:
          (data['emailNotificationsEnabled'] as bool?) ?? true,
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
      );
      _currentVisitor = user;
      _interestedEventsVersion.value++;
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

  static bool areEventRemindersEnabled() {
    return _currentVisitor?.eventRemindersEnabled ?? true;
  }

  static String getReminderTiming() {
    return _currentVisitor?.reminderTiming ?? '24h';
  }

  static bool isEmailNotificationsEnabled() {
    return _currentVisitor?.emailNotificationsEnabled ?? true;
  }

  static bool isLocationAccessEnabled() {
    return _currentVisitor?.locationAccessEnabled ?? true;
  }

  static String getThemePreference() {
    return _currentVisitor?.themePreference ?? 'system';
  }

  static double getTextScaleFactor() {
    return _currentVisitor?.textScaleFactor ?? 1.0;
  }

  static Future<List<String>> getInterestCategories() async {
    return List<String>.from(_currentVisitor?.interestCategories ?? const []);
  }

  static Future<bool> setInterestCategories(List<String> categories) async {
    return _mergeCurrentVisitor(
      firestoreData: {'interestCategories': categories},
      updatedUser: (current) => current.copyWith(interestCategories: categories),
    );
  }

  static List<String> getInterestPriorities() {
    return List<String>.from(
      _currentVisitor?.interestPriorities ?? _currentVisitor?.interestCategories ?? const [],
    );
  }

  static Future<bool> setInterestPriorities(List<String> priorities) async {
    return _mergeCurrentVisitor(
      firestoreData: {'interestPriorities': priorities},
      updatedUser: (current) => current.copyWith(interestPriorities: priorities),
    );
  }

  static Set<String> getSavedAttractionIds() {
    return Set<String>.from(_currentVisitor?.savedAttractionIds ?? const []);
  }

  static bool isAttractionSaved(String attractionId) {
    return _currentVisitor?.savedAttractionIds.contains(attractionId) ?? false;
  }

  static bool toggleSavedAttraction(String attractionId) {
    final current = _currentVisitor;
    if (current == null) {
      return false;
    }

    final updatedIds = List<String>.from(current.savedAttractionIds);
    if (updatedIds.contains(attractionId)) {
      updatedIds.remove(attractionId);
    } else {
      updatedIds.add(attractionId);
    }

    final updated = current.copyWith(savedAttractionIds: updatedIds);
    _replaceCurrentVisitor(updated);

    FirebaseFirestore.instance
        .collection('visitor_users')
        .doc(current.email)
        .set({'savedAttractionIds': updatedIds}, SetOptions(merge: true))
        .catchError((error) {
      debugPrint('[VisitorAuth] Failed to persist saved attractions: $error');
    });

    return true;
  }

  static Future<bool> setLocationSettings({
    bool? useCurrentLocation,
    int? locationRadiusKm,
  }) async {
    return _mergeCurrentVisitor(
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
    return _mergeCurrentVisitor(
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
    bool? emailNotificationsEnabled,
  }) async {
    return _mergeCurrentVisitor(
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
        if (emailNotificationsEnabled != null)
          'emailNotificationsEnabled': emailNotificationsEnabled,
      },
      updatedUser: (current) => current.copyWith(
        notificationsEnabled: notificationsEnabled,
        eventRemindersEnabled: eventRemindersEnabled,
        reminderTiming: reminderTiming,
        eventUpdatesEnabled: eventUpdatesEnabled,
        nearbyEventsEnabled: nearbyEventsEnabled,
        recommendedEventsEnabled: recommendedEventsEnabled,
        emailNotificationsEnabled: emailNotificationsEnabled,
      ),
    );
  }

  static Future<bool> updateProfileImage({
    String? base64Image,
    String? imageUrl,
    String? storagePath,
  }) async {
    final current = _currentVisitor;
    if (current == null) return false;
    final resolvedBase64 = base64Image;

    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
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
      _replaceCurrentVisitor(updated);
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[VisitorAuth] updateProfileImage failed: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _mergeCurrentVisitor({
    required Map<String, Object?> firestoreData,
    required VisitorUser Function(VisitorUser current) updatedUser,
  }) async {
    final current = _currentVisitor;
    if (current == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('visitor_users')
          .doc(current.email)
          .set(firestoreData, SetOptions(merge: true));
      _replaceCurrentVisitor(updatedUser(current));
      return true;
    } on FirebaseException catch (error) {
      debugPrint('[VisitorAuth] Failed to persist visitor settings: ${error.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  static void _replaceCurrentVisitor(VisitorUser updated) {
    _currentVisitor = updated;
    final idx = _users.indexWhere((u) => u.email == updated.email);
    if (idx != -1) {
      _users[idx] = updated;
    } else {
      _users.add(updated);
    }
    _interestedEventsVersion.value++;
    _profileVersion.value++;
  }
}
