// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'checkout_window.dart';

export 'checkout_window.dart';

/// Web implementation: opens a blank tab synchronously and navigates it later.
class WebCheckoutWindow implements CheckoutWindow {
  final html.WindowBase? _window;

  WebCheckoutWindow(this._window);

  @override
  bool get isOpen => _window != null;

  @override
  void close() {
    try {
      _window?.close();
    } catch (_) {}
  }

  @override
  void navigate(String url) {
    try {
      _window?.location.href = url;
    } catch (_) {}
  }
}

CheckoutWindow openBlankCheckoutWindow() {
  try {
    return WebCheckoutWindow(html.window.open('', '_blank'));
  } catch (_) {
    return WebCheckoutWindow(null);
  }
}
