class VisitorUser {
  final String name;
  final String email;
  final String password;
  final List<String> interestedEventIds;

  const VisitorUser({
    required this.name,
    required this.email,
    required this.password,
    this.interestedEventIds = const [],
  });

  VisitorUser copyWith({
    String? name,
    String? email,
    String? password,
    List<String>? interestedEventIds,
  }) {
    return VisitorUser(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      interestedEventIds: interestedEventIds ?? this.interestedEventIds,
    );
  }
}

class VisitorAuth {
  static final List<VisitorUser> _users = [
    // Demo / dummy account for testing
    VisitorUser(
      name: 'Demo Visitor',
      email: 'visitor@brisconnect.com',
      password: 'Visitor@123',
    ),
  ];
  static VisitorUser? _currentVisitor;

  static VisitorUser? get currentVisitor => _currentVisitor;
  static bool get isVisitorLoggedIn => _currentVisitor != null;

  static bool emailExists(String email) {
    final normalized = email.trim().toLowerCase();
    return _users.any((user) => user.email.toLowerCase() == normalized);
  }

  static bool register({
    required String name,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();

    if (emailExists(normalizedEmail)) {
      return false;
    }

    _users.add(
      VisitorUser(
        name: name.trim(),
        email: normalizedEmail,
        password: password,
      ),
    );

    return true;
  }

  static bool login({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final user = _users.firstWhere(
        (item) =>
            item.email.toLowerCase() == normalizedEmail && item.password == password,
      );
      _currentVisitor = user;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void logout() {
    _currentVisitor = null;
  }

  static Set<String> getInterestedEventIds() {
    return Set<String>.from(_currentVisitor?.interestedEventIds ?? const []);
  }

  static bool isInterestedInEvent(String eventId) {
    return _currentVisitor?.interestedEventIds.contains(eventId) ?? false;
  }

  static bool toggleInterestedEvent(String eventId) {
    final current = _currentVisitor;
    if (current == null) {
      return false;
    }

    final updatedIds = List<String>.from(current.interestedEventIds);
    if (updatedIds.contains(eventId)) {
      updatedIds.remove(eventId);
    } else {
      updatedIds.add(eventId);
    }

    final updatedUser = current.copyWith(interestedEventIds: updatedIds);
    final userIndex = _users.indexWhere(
      (user) => user.email.toLowerCase() == current.email.toLowerCase(),
    );
    if (userIndex != -1) {
      _users[userIndex] = updatedUser;
    }
    _currentVisitor = updatedUser;
    return true;
  }
}
