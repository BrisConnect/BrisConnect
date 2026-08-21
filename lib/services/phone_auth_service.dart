import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:brisconnect/config/app_config.dart';

/// Result of starting Firebase Phone Auth verification.
enum PhoneAuthSendResult {
  codeSent,
  invalidPhone,
  tooManyRequests,
  networkError,
  unknownError,
}

/// Handles Firebase Phone Auth sign-in for local/visitor accounts.
///
/// The user receives an SMS from Firebase directly. After the client signs in
/// with the SMS code, a Cloud Function issues a custom token linked to the
/// registered local/visitor profile so the app keeps its existing role logic.
class PhoneAuthService {
  static String? _lastErrorMessage;
  static String? get lastErrorMessage => _lastErrorMessage;

  static String? _verificationId;
  static int? _resendToken;

  static HttpsCallable _callable(String name) {
    return FirebaseFunctions.instanceFor(
      region: AppConfig.firebaseFunctionsRegion,
    ).httpsCallable(name);
  }

  /// Starts phone verification for [phoneNumber].
  ///
  /// [phoneNumber] should be in E.164 format, e.g. +61405800214.
  static Future<PhoneAuthSendResult> sendCodeToPhone(
    String phoneNumber,
  ) async {
    _lastErrorMessage = null;
    final normalized = phoneNumber.trim();

    if (!_looksLikePhone(normalized)) {
      _lastErrorMessage = 'Please enter a valid phone number.';
      return PhoneAuthSendResult.invalidPhone;
    }

    final completer = Completer<PhoneAuthSendResult>();

    await fb_auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        // Automatic verification on Android only.
        debugPrint('[PhoneAuthService] auto-verification completed');
        try {
          final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
          final phoneUser = userCredential.user;
          if (phoneUser != null) {
            _lastErrorMessage = null;
            if (!completer.isCompleted) {
              completer.complete(PhoneAuthSendResult.codeSent);
            }
          }
        } on fb_auth.FirebaseAuthException catch (e) {
          _lastErrorMessage = _signInErrorMessage(e);
          if (!completer.isCompleted) {
            completer.complete(_mapVerificationError(e));
          }
        }
      },
      verificationFailed: (e) {
        debugPrint('[PhoneAuthService] verificationFailed: ${e.code} ${e.message}');
        _lastErrorMessage = _verificationErrorMessage(e);
        final result = _mapVerificationError(e);
        if (!completer.isCompleted) completer.complete(result);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(PhoneAuthSendResult.codeSent);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// Verifies the SMS [code] for sign-up phone verification only.
  ///
  /// Signs the temporary Firebase Phone Auth user in and immediately out again
  /// to prove ownership of the number, without exchanging for a BrisConnect
  /// custom token. Returns `true` if the code was valid.
  static Future<bool> verifyCodeOnly(String code) async {
    _lastErrorMessage = null;

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      _lastErrorMessage = 'Phone verification session expired. Please request a new code.';
      return false;
    }

    final trimmedCode = code.trim();
    if (trimmedCode.length < 4) {
      _lastErrorMessage = 'Please enter the code sent to your phone.';
      return false;
    }

    try {
      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: trimmedCode,
      );

      final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user == null) {
        _lastErrorMessage = 'Phone verification failed. Please try again.';
        return false;
      }

      // Phone number verified. Sign out the temporary Firebase Phone Auth user
      // so the caller can create the real email/password account.
      await fb_auth.FirebaseAuth.instance.signOut();
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _signInErrorMessage(e);
      return false;
    } catch (e) {
      debugPrint('[PhoneAuthService] verifyCodeOnly unexpected error: $e');
      _lastErrorMessage = 'No internet connection. Please try again.';
      return false;
    }
  }

  /// Verifies the SMS [code] and signs the user in, then exchanges the
  /// Firebase Auth ID token for a custom token linked to the local profile.
  static Future<bool> verifyCodeAndSignIn(String code) async {
    _lastErrorMessage = null;

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      _lastErrorMessage = 'Phone verification session expired. Please request a new code.';
      return false;
    }

    final trimmedCode = code.trim();
    if (trimmedCode.length < 4) {
      _lastErrorMessage = 'Please enter the code sent to your phone.';
      return false;
    }

    try {
      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: trimmedCode,
      );

      final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final phoneUser = userCredential.user;
      if (phoneUser == null) {
        _lastErrorMessage = 'Phone sign-in failed. Please try again.';
        return false;
      }

      final idToken = await phoneUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        _lastErrorMessage = 'Could not retrieve phone credentials. Please try again.';
        return false;
      }

      final callable = _callable('exchangePhoneIdTokenForCustomToken');
      final result = await callable.call<Map<String, dynamic>>({
        'idToken': idToken,
        'userType': 'local',
      });

      final customToken = result.data['token'] as String?;
      if (customToken == null || customToken.isEmpty) {
        _lastErrorMessage = 'Could not complete sign-in. Please try again.';
        return false;
      }

      await fb_auth.FirebaseAuth.instance.signInWithCustomToken(customToken);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      _lastErrorMessage = _signInErrorMessage(e);
      return false;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PhoneAuthService] exchange failed: ${e.code} ${e.message}');
      _lastErrorMessage = e.message ?? 'Sign-in failed. Please try again.';
      return false;
    } catch (e) {
      debugPrint('[PhoneAuthService] verifyCodeAndSignIn unexpected error: $e');
      _lastErrorMessage = 'No internet connection. Please try again.';
      return false;
    }
  }

  static bool _looksLikePhone(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  static String _verificationErrorMessage(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try email sign-in instead.';
      case 'web-context-cancelled':
      case 'captcha-check-failed':
        return 'Phone verification was cancelled. Please try again.';
      case 'app-not-authorized':
        return 'This app is not authorized for phone sign-in. Please use email sign-in instead.';
      default:
        return e.message ?? 'Could not send code. Please try again.';
    }
  }

  static PhoneAuthSendResult _mapVerificationError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return PhoneAuthSendResult.invalidPhone;
      case 'too-many-requests':
      case 'quota-exceeded':
        return PhoneAuthSendResult.tooManyRequests;
      case 'network-request-failed':
        return PhoneAuthSendResult.networkError;
      default:
        return PhoneAuthSendResult.unknownError;
    }
  }

  static String _signInErrorMessage(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid code. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code.';
      case 'session-expired':
        return 'Code expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
