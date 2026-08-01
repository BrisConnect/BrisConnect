class PhoneValidation {
  /// Converts common Australian phone inputs to E.164 format.
  ///
  /// Accepts +61 405 800 214, 0405 800 214, 61405800214, etc.
  /// Returns null if the input cannot be normalized.
  static String? toE164Au(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('61')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 9) {
      return null;
    }

    return '+61$digits';
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (toE164Au(value) == null) {
      return 'Enter a valid Australian phone number';
    }
    return null;
  }
}
