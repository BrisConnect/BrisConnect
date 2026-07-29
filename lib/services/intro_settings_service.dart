import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has completed the first-launch onboarding flow.
class IntroSettingsService {
  static const String _onboardingKey = 'brisconnect_onboarding_seen';

  static Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (_) {
      // Ignore persistence errors so onboarding does not block the app.
    }
  }

  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
    } catch (_) {
      // Ignore persistence errors.
    }
  }
}
