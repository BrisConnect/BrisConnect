class AppErrorMessages {
  static String fromException(Object? error, {required String fallback}) {
    if (error == null) {
      return fallback;
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('unavailable') ||
        raw.contains('timeout') ||
        raw.contains('failed host lookup')) {
      return 'No internet connection. Please try again.';
    }

    if (raw.contains('permission-denied')) {
      return 'You do not have permission to access this data.';
    }

    if (raw.contains('failed-precondition') || raw.contains('index')) {
      return 'Notification data is not ready yet. Please try again shortly.';
    }

    return fallback;
  }
}
