import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';

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

    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    final email = currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return AppUserRole.unknown;
    }

    try {
      final db = FirebaseFirestore.instance;

      final adminDoc = await db.collection('admins').doc(email).get();
      if (adminDoc.exists) {
        final data = adminDoc.data() ?? const <String, dynamic>{};
        final isActive = (data['active'] as bool?) ?? true;
        final role = (data['role'] as String?)?.toLowerCase() ?? 'admin';
        if (isActive && role == 'admin') {
          return AppUserRole.admin;
        }
      }

      final localDoc = await db.collection('local_users').doc(email).get();
      if (localDoc.exists) {
        final data = localDoc.data() ?? const <String, dynamic>{};
        final role = (data['role'] as String?)?.toLowerCase();
        final accountType = (data['accountType'] as String?)?.toLowerCase();
        if (role == 'local' || accountType == 'local') {
          return AppUserRole.local;
        }
      }

      final visitorDoc = await db.collection('visitor_users').doc(email).get();
      if (visitorDoc.exists) {
        final data = visitorDoc.data() ?? const <String, dynamic>{};
        final role = (data['role'] as String?)?.toLowerCase() ?? 'visitor';
        if (role == 'visitor') {
          return AppUserRole.visitor;
        }
      }
    } catch (_) {
      return AppUserRole.unknown;
    }

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
  /// token on app restart. Tries admin → local → visitor in order.
  /// Signs out the stale token if no matching Firestore profile is found.
  static Future<AppUserRole> restoreAndResolveSession() async {
    final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
    final email = fbUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return AppUserRole.unknown;

    if (await AdminAuth.restoreSession(email)) return AppUserRole.admin;
    if (await LocalAuth.restoreSession(email)) return AppUserRole.local;
    if (await VisitorAuth.restoreSession(email)) return AppUserRole.visitor;

    // No matching profile — clear the stale auth token.
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {}
    return AppUserRole.unknown;
  }
}
