/// Shared HTML email formatting helpers used by notification and broadcast
/// services. These preserve the exact email styling and behaviour previously
/// duplicated across the codebase.
class EmailFormatter {
  EmailFormatter._();

  /// Returns the BrisConnect+ email header HTML.
  static String emailHeader() {
    return '''
      <div style="background-color:#E8820C;padding:20px 24px;border-radius:8px 8px 0 0;text-align:center;">
        <span style="font-size:24px;font-weight:900;color:#ffffff;letter-spacing:1px;">BrisConnect+</span>
      </div>
      <div style="background-color:#ffffff;padding:24px;border-radius:0 0 8px 8px;border:1px solid #e0e0e0;border-top:none;">
    ''';
  }

  /// Returns the BrisConnect+ email footer HTML.
  static String emailFooter() {
    return '''
      </div>
      <p style="text-align:center;font-size:11px;color:#999999;margin-top:16px;">&copy; 2026 BrisConnect+. All rights reserved.</p>
    ''';
  }

  /// Wraps [body] in the standard BrisConnect+ email shell.
  static String wrapEmail(String body) {
    return '''
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        ${emailHeader()}
        $body
        ${emailFooter()}
      </div>
    ''';
  }

  /// Escapes HTML special characters so user-provided text is safe to embed.
  static String escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Creates a URL/path-friendly slug from a free-form string.
  static String slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"['']+"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
