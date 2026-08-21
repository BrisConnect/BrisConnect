import 'package:flutter/material.dart';
import 'package:brisconnect/main.dart';
import 'package:brisconnect/services/fcm_service.dart';

enum AppThemePreference { system, light, dark }

/// Notifies listeners when the app's locale changes.
/// Used by widgets to rebuild when the user changes their language preference.
final localeChangeNotifier = ValueNotifier<Locale?>(null);

class AppDisplaySettings {
  const AppDisplaySettings({
    required this.locationAccessEnabled,
    required this.themePreference,
    required this.textScaleFactor,
  });

  final bool locationAccessEnabled;
  final AppThemePreference themePreference;
  final double textScaleFactor;

  AppDisplaySettings copyWith({
    bool? locationAccessEnabled,
    AppThemePreference? themePreference,
    double? textScaleFactor,
  }) {
    return AppDisplaySettings(
      locationAccessEnabled:
          locationAccessEnabled ?? this.locationAccessEnabled,
      themePreference: themePreference ?? this.themePreference,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }
}

class AppDisplaySettingsController {
  static final ValueNotifier<AppDisplaySettings> settings =
      ValueNotifier<AppDisplaySettings>(
    const AppDisplaySettings(
      locationAccessEnabled: true,
      themePreference: AppThemePreference.system,
      textScaleFactor: 1.0,
    ),
  );

  static AppThemePreference themeFromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  static String themeToString(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.system:
        return 'system';
    }
  }

  static ThemeMode toThemeMode(AppThemePreference value) {
    switch (value) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  static double normalizeTextScale(double value) {
    return value.clamp(0.9, 1.3);
  }

  static void apply({
    bool? locationAccessEnabled,
    AppThemePreference? themePreference,
    double? textScaleFactor,
  }) {
    settings.value = settings.value.copyWith(
      locationAccessEnabled: locationAccessEnabled,
      themePreference: themePreference,
      textScaleFactor:
          textScaleFactor != null ? normalizeTextScale(textScaleFactor) : null,
    );
  }

  static void applyFromPersisted({
    required bool locationAccessEnabled,
    required String? themePreference,
    required double textScaleFactor,
    String? language,
  }) {
    apply(
      locationAccessEnabled: locationAccessEnabled,
      themePreference: themeFromString(themePreference),
      textScaleFactor: textScaleFactor,
    );
    if (language != null && language.isNotEmpty) {
      setAppLocale(language);
    }
  }

  /// Updates the app's active locale from anywhere in the app.
  /// Notifies all listeners so widgets can rebuild with the new locale.
  static void setAppLocale(String language) {
    final trimmed = language.trim();
    if (trimmed.isEmpty) return;
    final locale = Locale(trimmed);
    final context = navigatorKey.currentContext;
    if (context != null) {
      BrisConnectApp.of(context)?.setLocale(locale);
    }
    // Notify listeners so widgets can detect locale changes and rebuild.
    localeChangeNotifier.value = locale;
  }
}
