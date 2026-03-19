enum AccountApprovalStatus { pending, approved, rejected }

class LocalUser {
  final String name;
  final String email;
  final String password;
  final String phone;
  final String suburb;
  final String accountType = 'local';
  final AccountApprovalStatus approvalStatus;

  const LocalUser({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.suburb,
    this.approvalStatus = AccountApprovalStatus.pending,
  });

  LocalUser copyWith({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? suburb,
    AccountApprovalStatus? approvalStatus,
  }) {
    return LocalUser(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      suburb: suburb ?? this.suburb,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}

class LocalAuth {
  static final List<LocalUser> _users = [
    // Demo / dummy account for testing - set as approved for testing
    LocalUser(
      name: 'Demo Local',
      email: 'local@brisconnect.com',
      password: 'Local@123',
      phone: '0400000000',
      suburb: 'South Brisbane',
      approvalStatus: AccountApprovalStatus.approved,
    ),
  ];

  static LocalUser? _currentLocal;

  static LocalUser? get currentLocal => _currentLocal;
  static bool get isLocalLoggedIn => _currentLocal != null;

  static bool emailExists(String email) {
    final normalized = email.trim().toLowerCase();
    return _users.any((u) => u.email.toLowerCase() == normalized);
  }

  static bool register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String suburb,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (emailExists(normalizedEmail)) return false;

    _users.add(LocalUser(
      name: name.trim(),
      email: normalizedEmail,
      password: password,
      phone: phone.trim(),
      suburb: suburb.trim(),
      approvalStatus: AccountApprovalStatus.pending,
    ));
    return true;
  }

  static bool login({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final user = _users.firstWhere(
        (u) => u.email.toLowerCase() == normalizedEmail && u.password == password,
      );
      _currentLocal = user;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void logout() {
    _currentLocal = null;
  }

  // Account approval methods
  static List<LocalUser> getPendingAccounts() {
    return _users.where((u) => u.approvalStatus == AccountApprovalStatus.pending).toList();
  }

  static List<LocalUser> getApprovedAccounts() {
    return _users.where((u) => u.approvalStatus == AccountApprovalStatus.approved).toList();
  }

  static List<LocalUser> getReviewedAccounts() {
    return _users
        .where((u) => u.approvalStatus == AccountApprovalStatus.approved || u.approvalStatus == AccountApprovalStatus.rejected)
        .toList();
  }

  static void approveAccount(LocalUser user) {
    final index = _users.indexWhere((u) => u.email == user.email);
    if (index >= 0) {
      _users[index] = _users[index].copyWith(approvalStatus: AccountApprovalStatus.approved);
      // If this is the currently logged-in user, update the reference
      if (_currentLocal?.email == user.email) {
        _currentLocal = _users[index];
      }
    }
  }

  static void rejectAccount(LocalUser user) {
    final index = _users.indexWhere((u) => u.email == user.email);
    if (index >= 0) {
      _users[index] = _users[index].copyWith(approvalStatus: AccountApprovalStatus.rejected);
      // If this is the currently logged-in user, logout
      if (_currentLocal?.email == user.email) {
        _currentLocal = null;
      }
    }
  }
}
