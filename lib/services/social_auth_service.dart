import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

/// Result of a social sign-in attempt.
enum SocialSignInResult {
  success,
  cancelled,
  noAccount,
  disabled,
  networkError,
  unknownError,
}

class SocialAuthResult {
  final SocialSignInResult result;
  final String? role;
  final String? errorMessage;

  const SocialAuthResult._({
    required this.result,
    this.role,
    this.errorMessage,
  });

  static const SocialAuthResult successVisitor = SocialAuthResult._(
    result: SocialSignInResult.success,
    role: 'visitor',
  );
  static const SocialAuthResult cancelled = SocialAuthResult._(
    result: SocialSignInResult.cancelled,
  );
  static const SocialAuthResult noAccount = SocialAuthResult._(
    result: SocialSignInResult.noAccount,
    errorMessage: 'No BrisConnect account found for this email.',
  );
  static const SocialAuthResult disabled = SocialAuthResult._(
    result: SocialSignInResult.disabled,
    errorMessage: 'This account has been disabled.',
  );
  static const SocialAuthResult networkError = SocialAuthResult._(
    result: SocialSignInResult.networkError,
    errorMessage: 'Network error. Please check your connection.',
  );
  static const SocialAuthResult unknownError = SocialAuthResult._(
    result: SocialSignInResult.unknownError,
    errorMessage: 'Sign in failed. Please try again.',
  );

  bool get isSuccess => result == SocialSignInResult.success;
}

/// Handles Google and Apple social sign-in, maps the resulting Firebase user
/// to the correct BrisConnect role, and ensures the underlying Firestore
/// account exists before granting access.
class SocialAuthService {
  static String? _lastErrorMessage;

  static String? get lastErrorMessage => _lastErrorMessage;

  static final _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  /// Looks up the user's role across the three role collections.
  /// Returns null if no matching account exists.
  static Future<String?> _detectRole(String email) async {
    final firestore = FirebaseFirestore.instance;
    final normalized = email.trim().toLowerCase();

    final adminDoc = await firestore.collection('admins').doc(normalized).get();
    if (adminDoc.exists) return 'admin';

    final localDoc =
        await firestore.collection('local_users').doc(normalized).get();
    if (localDoc.exists) return 'local';

    final visitorDoc =
        await firestore.collection('visitor_users').doc(normalized).get();
    if (visitorDoc.exists) return 'visitor';

    return null;
  }

  /// Returns whether the account for [email] is active.
  /// Defaults to true for visitors and true when the field is missing.
  static Future<bool> _isActive(String email, String role) async {
    final firestore = FirebaseFirestore.instance;
    final normalized = email.trim().toLowerCase();

    DocumentSnapshot? doc;
    switch (role) {
      case 'admin':
        doc = await firestore.collection('admins').doc(normalized).get();
      case 'local':
        doc = await firestore.collection('local_users').doc(normalized).get();
      case 'visitor':
      default:
        doc = await firestore.collection('visitor_users').doc(normalized).get();
    }

    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return true;

    final active = data['active'] as bool?;
    if (active != null) return active;

    // Legacy accounts may not have an active flag; treat as active.
    return true;
  }

  static SocialAuthResult _fail(SocialAuthResult result) {
    _lastErrorMessage = result.errorMessage;
    return result;
  }

  static Future<SocialAuthResult> signInWithGoogle() async {
    _lastErrorMessage = null;
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return _fail(SocialAuthResult.cancelled);
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final email = userCredential.user?.email;
      if (email == null || email.isEmpty) {
        await _signOutFirebaseAndGoogle();
        return _fail(SocialAuthResult.unknownError);
      }

      return _finalize(email);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('[SocialAuthService] Google sign-in auth error: ${e.code}');
      if (e.code == 'network-request-failed') {
        return _fail(SocialAuthResult.networkError);
      }
      if (e.code == 'user-disabled') {
        return _fail(SocialAuthResult.disabled);
      }
      return _fail(SocialAuthResult.unknownError);
    } catch (e) {
      debugPrint('[SocialAuthService] Google sign-in error: $e');
      if (e.toString().contains('network')) {
        return _fail(SocialAuthResult.networkError);
      }
      return _fail(SocialAuthResult.unknownError);
    }
  }

  static Future<SocialAuthResult> signInWithApple() async {
    _lastErrorMessage = null;
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
        ],
        nonce: nonce,
      );

      final oauthCredential = fb_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      final userCredential = await fb_auth.FirebaseAuth.instance
          .signInWithCredential(oauthCredential);
      final email = userCredential.user?.email ?? appleCredential.email;
      if (email == null || email.isEmpty) {
        await _signOutFirebaseAndApple();
        return _fail(SocialAuthResult.unknownError);
      }

      return _finalize(email);
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[SocialAuthService] Apple sign-in error: ${e.code}');
      if (e.code == AuthorizationErrorCode.canceled) {
        return _fail(SocialAuthResult.cancelled);
      }
      return _fail(SocialAuthResult.unknownError);
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('[SocialAuthService] Apple sign-in auth error: ${e.code}');
      if (e.code == 'network-request-ffailed') {
        return _fail(SocialAuthResult.networkError);
      }
      if (e.code == 'user-disabled') {
        return _fail(SocialAuthResult.disabled);
      }
      return _fail(SocialAuthResult.unknownError);
    } catch (e) {
      debugPrint('[SocialAuthService] Apple sign-in error: $e');
      if (e.toString().contains('network')) {
        return _fail(SocialAuthResult.networkError);
      }
      return _fail(SocialAuthResult.unknownError);
    }
  }

  static Future<SocialAuthResult> _finalize(String email) async {
    final role = await _detectRole(email);
    if (role == null) {
      await _signOutAll();
      return _fail(SocialAuthResult.noAccount);
    }

    final active = await _isActive(email, role);
    if (!active) {
      await _signOutAll();
      return _fail(SocialAuthResult.disabled);
    }

    return SocialAuthResult._(result: SocialSignInResult.success, role: role);
  }

  static Future<void> _signOutFirebaseAndGoogle() async {
    await _googleSignIn.signOut();
    await fb_auth.FirebaseAuth.instance.signOut();
  }

  static Future<void> _signOutFirebaseAndApple() async {
    await fb_auth.FirebaseAuth.instance.signOut();
  }

  static Future<void> _signOutAll() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if not signed in with Google.
    }
    await fb_auth.FirebaseAuth.instance.signOut();
  }

  static String _generateNonce({int length = 32}) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
