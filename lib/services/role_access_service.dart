import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/services/session_persistence_service.dart';

class RoleAccessService {
  static Future<AppUserRole> resolveCurrentRole() async {
    if (AdminAuth.isAdminLoggedIn) {
      return AppUserRole.admin;
    }
    if (LocalAuth.isLocalLoggedIn) {
      return AppUserRole.local;
    }
    if (VisitorAuth.isVisitorLoggedIn) {
      return AppUserRole.visitor;
    }

    // Use a persisted role hint as a fast, synchronous signal while Firebase
    // Auth restores its cached user after a page refresh or external redirect.
    final lastRole = await SessionPersistenceService.getLastRole();

    // On web, Firebase Auth restores the cached user asynchronously after a
    // page refresh. Wait up to 5 seconds for a non-null auth-state event so
    // we don't incorrectly treat a logged-in user as unknown. The persisted
    // role hint tells callers they should keep waiting rather than redirect.
    fb_auth.User? fbUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      try {
        fbUser = await fb_auth.FirebaseAuth.instance
            .authStateChanges()
            .where((u) => u != null)
            .first
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        fbUser = null;
      }
    }

    final email = fbUser?.email?.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      if (await AdminAuth.restoreSession(email)) return AppUserRole.admin;
      if (await LocalAuth.restoreSession(email)) return AppUserRole.local;
      if (await VisitorAuth.restoreSession(email)) return AppUserRole.visitor;

      // A Firebase user exists but the Firestore profile read failed (e.g.
      // temporary permission/index delay) or the role didn't match. Fall back
      // to the persisted hint rather than returning unknown, so the guard can
      // keep polling instead of redirecting immediately.
      if (lastRole != null) {
        switch (lastRole) {
          case 'admin':
            return AppUserRole.admin;
          case 'local':
            return AppUserRole.local;
          case 'visitor':
            return AppUserRole.visitor;
        }
      }
    }

    // If we have a persisted role hint but no Firebase user, keep the hint
    // so the guard can show a loading state instead of redirecting.
    if (lastRole != null) {
      switch (lastRole) {
        case 'admin':
          return AppUserRole.admin;
        case 'local':
          return AppUserRole.local;
        case 'visitor':
          return AppUserRole.visitor;
      }
    }

    // No cached user or no matching profile.
    return AppUserRole.unknown;
  }

  static Future<bool> hasAnyRole(Set<AppUserRole> allowedRoles) async {
    // Prefer explicit in-memory sessions so the active login flow can access
    // its portal even when another role was previously cached in-memory.
    if (allowedRoles.contains(AppUserRole.admin) && AdminAuth.isAdminLoggedIn) {
      return true;
    }
    if (allowedRoles.contains(AppUserRole.local) && LocalAuth.isLocalLoggedIn) {
      return true;
    }
    if (allowedRoles.contains(AppUserRole.visitor) && VisitorAuth.isVisitorLoggedIn) {
      return true;
    }

    final role = await resolveCurrentRole();
    return allowedRoles.contains(role);
  }

  /// Attempts to restore an in-memory session from a cached Firebase Auth
  /// token on app restart.
  ///
  /// Prefer the persisted last-known role so users with both a local and
  /// visitor profile resume the portal they actually used last. If that
  /// role cannot be restored, fall back to the default admin → local →
  /// visitor order.
  ///
  /// This function never signs the user out on failure; callers (e.g.
  /// [RoleGuard]) decide whether to keep waiting or redirect to a login
  /// screen. This avoids stripping the cached Firebase Auth session when
  /// Firestore is temporarily unavailable or an index is still building.
  static Future<AppUserRole> restoreAndResolveSession([fb_auth.User? user]) async {
    final fbUser = user ?? fb_auth.FirebaseAuth.instance.currentUser;
    final email = fbUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return AppUserRole.unknown;

    final lastRole = await SessionPersistenceService.getLastRole();

    // Try the last active role first so multi-role users resume the right
    // portal and FCM tokens are associated with the correct collection.
    switch (lastRole) {
      case 'admin':
        if (await AdminAuth.restoreSession(email)) return AppUserRole.admin;
        break;
      case 'local':
        if (await LocalAuth.restoreSession(email)) return AppUserRole.local;
        break;
      case 'visitor':
        if (await VisitorAuth.restoreSession(email)) return AppUserRole.visitor;
        break;
    }

    if (await AdminAuth.restoreSession(email)) return AppUserRole.admin;
    if (await LocalAuth.restoreSession(email)) return AppUserRole.local;
    if (await VisitorAuth.restoreSession(email)) return AppUserRole.visitor;

    return AppUserRole.unknown;
  }
}
