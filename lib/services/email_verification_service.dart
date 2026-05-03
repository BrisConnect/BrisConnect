import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

class EmailVerificationService {
  EmailVerificationService({fb_auth.FirebaseAuth? auth})
      : _auth = auth;

  final fb_auth.FirebaseAuth? _auth;

  fb_auth.FirebaseAuth get _firebaseAuth =>
      _auth ?? fb_auth.FirebaseAuth.instance;

  /// Sends a verification email to the currently signed-in user.
  Future<bool> sendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await user.sendEmailVerification();
      return true;
    } catch (error) {
      debugPrint('[EmailVerification] Failed to send verification: $error');
      return false;
    }
  }

  /// Returns true if the current user's email is verified.
  Future<bool> isEmailVerified() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await user.reload();
      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } catch (error) {
      debugPrint('[EmailVerification] Failed to check verification: $error');
      return false;
    }
  }

  /// Returns the current user's email verified status without network refresh.
  bool get isVerifiedCached {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }
}
