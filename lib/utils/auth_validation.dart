class AuthValidation {
  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredField(value, 'Email');
    if (required != null) {
      return required;
    }

    final normalized = value!.trim();
    final pattern = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!pattern.hasMatch(normalized)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? emailOrUsername(String? value) {
    final required = requiredField(value, 'Email or Username');
    if (required != null) {
      return required;
    }

    final normalized = value!.trim();
    if (normalized.contains('@')) {
      final pattern = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!pattern.hasMatch(normalized)) {
        return 'Enter a valid email address';
      }
    }

    return null;
  }

  static String? password(String? value) {
    final required = requiredField(value, 'Password');
    if (required != null) {
      return required;
    }

    final password = value!;
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number';
    }
    return null;
  }
}
