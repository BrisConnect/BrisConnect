import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight synchronous hint about the last signed-in user role.
///
/// This is stored in SharedPreferences (localStorage on web) so the app can
/// quickly decide whether to keep showing a loading state while Firebase Auth
/// restores the cached user after a page refresh or external redirect (e.g.
/// returning from Stripe Checkout).
class SessionPersistenceService {
  static const _roleKey = 'brisconnect_last_role';

  static Future<void> setLastRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role);
    } catch (_) {
      // Storage is best-effort; do not block login on failures.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roleKey);
    } catch (_) {}
  }

  static Future<String?> getLastRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_roleKey);
    } catch (_) {
      return null;
    }
  }
}
