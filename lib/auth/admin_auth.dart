class AdminAuth {
  static const String _adminUsername = 'admin@brisconnect.com';
  static const String _adminPassword = 'Admin@123';

  static bool _isAdminLoggedIn = false;

  static bool get isAdminLoggedIn => _isAdminLoggedIn;

  static bool login({required String usernameOrEmail, required String password}) {
    final normalized = usernameOrEmail.trim().toLowerCase();
    final valid = normalized == _adminUsername && password == _adminPassword;

    _isAdminLoggedIn = valid;
    return valid;
  }

  static void logout() {
    _isAdminLoggedIn = false;
  }
}
