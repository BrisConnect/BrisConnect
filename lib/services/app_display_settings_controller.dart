import 'package:flutter/material.dart';

enum AppThemePreference { system, light, dark }

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
  }) {
    apply(
      locationAccessEnabled: locationAccessEnabled,
      themePreference: themeFromString(themePreference),
      textScaleFactor: textScaleFactor,
    );
  }
}
