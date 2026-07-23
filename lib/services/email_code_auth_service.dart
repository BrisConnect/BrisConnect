import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:brisconnect/config/app_config.dart';

/// Result of sending a login code to an email address.
enum SendCodeResult {
  sent,
  invalidEmail,
  tooManyRequests,
  networkError,
  unknownError,
}

/// Service that handles email + code verification login for visitors and locals.
///
/// The actual code generation, email delivery, and verification happen in
/// Cloud Functions so that secrets (email provider API keys, code hashing)
/// never leave the server.
class EmailCodeAuthService {
  static String? _lastErrorMessage;

  static String? get lastErrorMessage => _lastErrorMessage;

  static HttpsCallable _callable(String name) {
    return FirebaseFunctions.instanceFor(
      region: AppConfig.firebaseFunctionsRegion,
    ).httpsCallable(name);
  }

  /// Sends a one-time login code to [email].
  ///
  /// [userType] must be 'visitor' or 'local' so the Cloud Function can route
  /// the user to the correct Firestore collection after verification.
  static Future<SendCodeResult> sendCode({
    required String email,
    required String userType,
  }) async {
    _lastErrorMessage = null;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !_looksLikeEmail(normalized)) {
      _lastErrorMessage = 'Please enter a valid email address.';
      return SendCodeResult.invalidEmail;
    }

    try {
      final callable = _callable('sendEmailLoginCode');
      await callable.call<Map<String, dynamic>>({
        'email': normalized,
        'userType': userType,
      });
      return SendCodeResult.sent;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _authErrorMessage(e);
      return _mapAuthError(e);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[EmailCodeAuthService] sendCode failed: ${e.code} ${e.message}');
      _lastErrorMessage = e.message ?? 'Could not send code. Please try again.';
      if (e.code == 'resource-exhausted' || e.code == 'too-many-requests') {
        return SendCodeResult.tooManyRequests;
      }
      if (e.code == 'invalid-argument') {
        return SendCodeResult.invalidEmail;
      }
      return SendCodeResult.unknownError;
    } catch (e) {
      debugPrint('[EmailCodeAuthService] sendCode unexpected error: $e');
      _lastErrorMessage = 'No internet connection. Please try again.';
      return SendCodeResult.networkError;
    }
  }

  /// Verifies [code] for [email] and signs the user into Firebase Auth using
  /// a custom token returned by the Cloud Function.
  ///
  /// Returns `true` if sign-in succeeded and a Firebase user now exists.
  static Future<bool> verifyCode({
    required String email,
    required String code,
    required String userType,
  }) async {
    _lastErrorMessage = null;
    final normalized = email.trim().toLowerCase();
    final trimmedCode = code.trim();

    if (normalized.isEmpty || !_looksLikeEmail(normalized)) {
      _lastErrorMessage = 'Please enter a valid email address.';
      return false;
    }
    if (trimmedCode.isEmpty || trimmedCode.length < 4) {
      _lastErrorMessage = 'Please enter the code sent to your email.';
      return false;
    }

    try {
      final callable = _callable('verifyEmailLoginCode');
      final result = await callable.call<Map<String, dynamic>>({
        'email': normalized,
        'code': trimmedCode,
        'userType': userType,
      });

      final token = result.data['token'] as String?;
      if (token == null || token.isEmpty) {
        _lastErrorMessage = 'Login failed. Please try again.';
        return false;
      }

      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _authErrorMessage(e);
      return false;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[EmailCodeAuthService] verifyCode failed: ${e.code} ${e.message}');
      _lastErrorMessage = e.message ?? 'Could not verify code. Please try again.';
      return false;
    } catch (e) {
      debugPrint('[EmailCodeAuthService] verifyCode unexpected error: $e');
      _lastErrorMessage = 'No internet connection. Please try again.';
      return false;
    }
  }

  static bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  static String _authErrorMessage(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  static SendCodeResult _mapAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return SendCodeResult.invalidEmail;
      case 'too-many-requests':
        return SendCodeResult.tooManyRequests;
      case 'network-request-failed':
        return SendCodeResult.networkError;
      default:
        return SendCodeResult.unknownError;
    }
  }
}
