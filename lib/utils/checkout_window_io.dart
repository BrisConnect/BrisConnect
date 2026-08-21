import 'checkout_window.dart';

export 'checkout_window.dart';

/// Mobile/desktop implementation: no synchronous blank window is needed;
/// url_launcher will be used after the checkout URL is fetched.
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
