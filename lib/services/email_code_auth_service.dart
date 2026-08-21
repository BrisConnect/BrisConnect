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
  static String? _lastDetectedUserType;

  static String? get lastErrorMessage => _lastErrorMessage;

  /// The user type detected by the server on the most recent [sendCode] call.
  ///
  /// Will be `'visitor'`, `'local'`, or `'admin'` when a code was sent
  /// successfully, otherwise `null`.
  static String? get lastDetectedUserType => _lastDetectedUserType;

  static HttpsCallable _callable(String name) {
    return FirebaseFunctions.instanceFor(
      region: AppConfig.firebaseFunctionsRegion,
    ).httpsCallable(name);
  }

  /// Calls [operation] up to [maxAttempts] times when a retryable error occurs.
  static Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        final retryable = e is FirebaseFunctionsException &&
                (e.code == 'unavailable' ||
                    e.code == 'deadline-exceeded' ||
                    e.code == 'resource-exhausted') ||
            e.toString().toLowerCase().contains('network');
        if (attempt >= maxAttempts || !retryable) rethrow;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// Sends a one-time login code to [email].
  ///
  /// [userType] must be 'visitor' or 'local' so the Cloud Function can route
  /// the user to the correct Firestore collection after verification.
  /// Set [method] to 'sms' to send the code via SMS to the registered phone.
  static Future<SendCodeResult> sendCode({
    required String email,
    String userType = 'auto',
    String method = 'email',
  }) async {
    _lastErrorMessage = null;
    _lastDetectedUserType = null;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !_looksLikeEmail(normalized)) {
      _lastErrorMessage = 'Please enter a valid email address.';
      return SendCodeResult.invalidEmail;
    }

    final functionName =
        method.trim().toLowerCase() == 'sms' ? 'sendSmsLoginCode' : 'sendEmailLoginCode';

    try {
      final callable = _callable(functionName);
      final result = await _withRetry(
        () => callable.call<Map<String, dynamic>>({
          'email': normalized,
          'userType': userType,
        }),
      );
      _lastDetectedUserType =
          (result.data['userType'] as String?)?.trim().toLowerCase();
      return SendCodeResult.sent;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _authErrorMessage(e);
      return _mapAuthError(e);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          '[EmailCodeAuthService] sendCode failed: ${e.code} ${e.message}');
      final rawMessage = e.message ?? '';
      _lastErrorMessage = _cleanFunctionError(
          rawMessage, 'Could not send code. Please try again.');
      if (e.code == 'resource-exhausted' || e.code == 'too-many-requests') {
        return SendCodeResult.tooManyRequests;
      }
      if (e.code == 'invalid-argument') {
        return SendCodeResult.invalidEmail;
      }
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        _lastErrorMessage =
            'Sign-in service unavailable. Please check your connection and try again.';
        return SendCodeResult.unknownError;
      }
      if (e.code == 'internal' || e.code == 'unavailable') {
        _lastErrorMessage =
            'Email service temporarily unavailable. Please try again in a moment.';
        return SendCodeResult.unknownError;
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
  /// Set [method] to 'sms' when the code was delivered by SMS.
  static Future<bool> verifyCode({
    required String email,
    required String code,
    String userType = 'auto',
    String method = 'email',
  }) async {
    _lastErrorMessage = null;
    _lastDetectedUserType = null;
    final normalized = email.trim().toLowerCase();
    final trimmedCode = code.trim();

    if (normalized.isEmpty || !_looksLikeEmail(normalized)) {
      _lastErrorMessage = 'Please enter a valid email address.';
      return false;
    }
    if (trimmedCode.isEmpty || trimmedCode.length < 4) {
      _lastErrorMessage = method.trim().toLowerCase() == 'sms'
          ? 'Please enter the code sent to your phone.'
          : 'Please enter the code sent to your email.';
      return false;
    }

    try {
      final callable = _callable('verifyEmailLoginCode');
      final result = await _withRetry(
        () => callable.call<Map<String, dynamic>>({
          'email': normalized,
          'code': trimmedCode,
          'userType': userType,
          'method': method,
        }),
      );

      final token = result.data['token'] as String?;
      if (token == null || token.isEmpty) {
        _lastErrorMessage = 'Login failed. Please try again.';
        return false;
      }

      _lastDetectedUserType =
          (result.data['userType'] as String?)?.trim().toLowerCase();
      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(token);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _authErrorMessage(e);
      return false;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          '[EmailCodeAuthService] verifyCode failed: ${e.code} ${e.message}');
      final rawMessage = e.message ?? '';
      _lastErrorMessage = _cleanFunctionError(
          rawMessage, 'Could not verify code. Please try again.');
      if (e.code == 'permission-denied') {
        _lastErrorMessage = 'Invalid code. Please check your email and try again, or request a new code.';
      } else if (e.code == 'unauthenticated') {
        _lastErrorMessage = 'Sign-in session expired. Please request a new code.';
      } else if (e.code == 'not-found') {
        _lastErrorMessage = 'Code not found. Please request a new code.';
      } else if (e.code == 'deadline-exceeded') {
        _lastErrorMessage = 'This code has expired. Please request a new one.';
      } else if (e.code == 'resource-exhausted') {
        _lastErrorMessage = 'Too many failed attempts. Please request a new code.';
      }
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

  static String _cleanFunctionError(String rawMessage, String fallback) {
    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.toUpperCase() == 'INTERNAL') {
      return 'Sign-in service is temporarily unavailable. Please try again later.';
    }
    return trimmed;
  }
}
