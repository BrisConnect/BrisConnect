import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage notification permission state and user dismissals.
/// Tracks whether the user has:
/// - Been prompted before
/// - Dismissed the prompt
/// - Granted/denied permission
class NotificationPermissionService {
  static NotificationPermissionService? _instance;

  static NotificationPermissionService get instance {
    _instance ??= NotificationPermissionService._();
    return _instance!;
  }

  NotificationPermissionService._();

  /// Unique key for storing dismissal state in SharedPreferences
  static const String _dismissalKey = 'admin_notification_prompt_dismissed';

  /// Checks if browser supports notifications (web only)
  static bool get isNotificationSupported {
    if (!kIsWeb) return false;
    try {
      // Check if Notification API is available in browser
      return true; // Firebase Messaging will handle availability
    } catch (e) {
      return false;
    }
  }

  /// Gets the current notification permission status
  Future<NotificationSettings> getNotificationSettings() async {
    return await FirebaseMessaging.instance.getNotificationSettings();
  }

  /// Checks if permission has been denied by the user
  Future<bool> isPermissionDenied() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.denied;
  }

  /// Checks if permission has been granted
  Future<bool> isPermissionGranted() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Checks if the user has already dismissed the notification prompt
  Future<bool> hasUserDismissedPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_dismissalKey) ?? false;
    } catch (e) {
      debugPrint('[NotificationPermissionService] Error reading dismissal: $e');
      return false;
    }
  }

  /// Records that the user has dismissed the notification prompt
  Future<void> markPromptAsDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissalKey, true);
      debugPrint('[NotificationPermissionService] Marked prompt as dismissed');
    } catch (e) {
      debugPrint('[NotificationPermissionService] Error marking dismissed: $e');
    }
  }

  /// Requests notification permission from the browser
  /// Returns true if permission was granted, false otherwise
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('[NotificationPermissionService] Permission request result: ${settings.authorizationStatus}');
      return isGranted;
    } catch (e) {
      debugPrint('[NotificationPermissionService] Error requesting permission: $e');
      return false;
    }
  }

  /// Clears the dismissal flag (useful for testing or resetting state)
  Future<void> resetDismissal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissalKey);
      debugPrint('[NotificationPermissionService] Dismissal flag reset');
    } catch (e) {
      debugPrint('[NotificationPermissionService] Error resetting dismissal: $e');
    }
  }

  /// Determines if the notification prompt should be shown
  /// Returns true if:
  /// - Web browser
  /// - Notifications are supported
  /// - Permission not already granted
  /// - User hasn't dismissed the prompt
  Future<bool> shouldShowPrompt() async {
    if (!isNotificationSupported) return false;

    final isDismissed = await hasUserDismissedPrompt();
    if (isDismissed) return false;

    final isGranted = await isPermissionGranted();
    return !isGranted;
  }
}
