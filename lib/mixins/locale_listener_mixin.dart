import 'package:flutter/material.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';

/// Mixin that enables State classes to listen for locale changes and rebuild.
/// Use this on any State class that displays localized strings and should
/// update automatically when the user changes their language preference.
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LocaleListenerMixin {
///   @override
///   void initState() {
///     super.initState();
///     setupLocaleListener();  // Add this line
///   }
/// }
/// ```
mixin LocaleListenerMixin<T extends StatefulWidget> on State<T> {
  /// Starts listening for locale changes and rebuilds the widget when they occur.
  /// Call this from your State's initState() method.
  void setupLocaleListener() {
    localeChangeNotifier.addListener(_onLocaleChanged);
  }

  /// Stops listening for locale changes. Called automatically in dispose(),
  /// but you can override dispose() and call super.dispose() if you need
  /// additional cleanup.
  void removeLocaleListener() {
    localeChangeNotifier.removeListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(() {
      // Trigger rebuild so localized strings are updated
    });
  }

  @override
  void dispose() {
    removeLocaleListener();
    super.dispose();
  }
}
