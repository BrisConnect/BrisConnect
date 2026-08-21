/// A handle to a checkout window/tab opened synchronously on the user's
/// button click. On non-web platforms this is a no-op.
abstract class CheckoutWindow {
  /// Whether the window/tab was actually opened (some pop-up blockers prevent
  /// `window.open` from returning a window).
  bool get isOpen;

  void close();
  void navigate(String url);
}
