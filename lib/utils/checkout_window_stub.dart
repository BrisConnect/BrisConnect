import 'checkout_window.dart';

export 'checkout_window.dart';

/// No-op implementation used on mobile/desktop.
CheckoutWindow openBlankCheckoutWindow() => const _NoOpCheckoutWindow();

class _NoOpCheckoutWindow implements CheckoutWindow {
  const _NoOpCheckoutWindow();

  @override
  bool get isOpen => false;

  @override
  void close() {}

  @override
  void navigate(String url) {}
}
