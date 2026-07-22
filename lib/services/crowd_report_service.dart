import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CrowdLevel { low, moderate, high }

extension CrowdLevelExtension on CrowdLevel {
  String get label {
    switch (this) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.moderate:
        return 'Moderate';
      case CrowdLevel.high:
        return 'High';
    }
  }

  int get weight {
    switch (this) {
      case CrowdLevel.low:
        return 1;
      case CrowdLevel.moderate:
        return 2;
      case CrowdLevel.high:
        return 3;
    }
  }

  static CrowdLevel fromWeight(double w) {
    if (w < 1.67) return CrowdLevel.low;
    if (w < 2.34) return CrowdLevel.moderate;
    return CrowdLevel.high;
  }
}

class CrowdReportService {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final Connectivity? _connectivity;
  final SharedPreferences? _prefs;
  final String? _currentUserId;
  final bool _useFirebaseAuth;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  // Duplicate prevention window (30 minutes)
  static const _cooldownMinutes = 30;

  CrowdReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Connectivity? connectivity,
    SharedPreferences? prefs,
    String? currentUserId,
    bool useFirebaseAuth = true,
  })  : _firestore = firestore,
        _auth = auth,
        _connectivity = connectivity,
        _prefs = prefs,
        _currentUserId = currentUserId,
        _useFirebaseAuth = useFirebaseAuth;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  Connectivity get connectivity => _connectivity ?? Connectivity();

  String? get _currentUserIdOrAuth {
    if (_currentUserId != null) return _currentUserId;
    final auth = _auth;
    if (auth != null) return auth.currentUser?.uid;
    if (_useFirebaseAuth) return FirebaseAuth.instance.currentUser?.uid;
    return null;
  }

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      firestore.collection('crowd_reports');

  /// Cooldown key stored in shared preferences for anonymous users
  String _prefsKey(String eventId) => 'crowd_report_${eventId}_last';

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    var attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        final isRetryable = _isRetryableError(e);
        if (isRetryable && attempts < _maxRetries) {
          debugPrint(
            '[$operationName] attempt $attempts failed, retrying: $e',
          );
          await Future.delayed(_retryDelay * attempts);
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'network-request-failed' ||
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded';
    }
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('timeout') ||
        message.contains('connection') ||
        message.contains('unavailable');
  }

  Future<void> _assertOnline() async {
    final results = await connectivity.checkConnectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      throw Exception(
        'No internet connection. Please check your connection and try again.',
      );
    }
  }

  /// Returns true if the user can submit a report (not within cooldown)
  Future<bool> canSubmitReport(String eventId) async {
    final userId = _currentUserIdOrAuth;
    if (userId != null) {
      try {
        final since = DateTime.now().subtract(
          const Duration(minutes: _cooldownMinutes),
        );
        final existing = await _withRetry(
          () => _reportsCollection
              .where('eventId', isEqualTo: eventId)
              .where('userId', isEqualTo: userId)
              .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
              .limit(1)
              .get(),
          operationName: 'canSubmitReport',
        );
        return existing.docs.isEmpty;
      } catch (e) {
        // If collection doesn't exist or permission denied, allow submission
        return true;
      }
    } else {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefsKey(eventId));
      if (lastMs == null) return true;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      return DateTime.now().difference(last).inMinutes >= _cooldownMinutes;
    }
  }

  /// Submits a crowd level report for an event
  Future<void> submitReport(String eventId, CrowdLevel level) async {
    await _assertOnline();
    final userId = _currentUserIdOrAuth;
    final now = DateTime.now();

    await _withRetry(
      () => _reportsCollection.add({
        'eventId': eventId,
        'userId': userId ?? 'anonymous',
        'level': level.label,
        'weight': level.weight,
        'timestamp': Timestamp.fromDate(now),
      }),
      operationName: 'submitReport',
    );

    // Track last submission for anonymous users
    if (userId == null) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey(eventId), now.millisecondsSinceEpoch);
    }
  }

  /// Returns a stream of the current crowd status for an event.
  /// Uses reports from the last 2 hours, weighted average.
  Stream<CrowdStatus?> watchCrowdStatus(String eventId) {
    final since = DateTime.now().subtract(const Duration(hours: 2));
    return _reportsCollection
        .where('eventId', isEqualTo: eventId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final reports = snap.docs;
      final totalWeight =
          reports.fold<int>(0, (sum, d) => sum + ((d['weight'] as num).toInt()));
      final avg = totalWeight / reports.length;
      return CrowdStatus(
        level: CrowdLevelExtension.fromWeight(avg),
        reportCount: reports.length,
        lastReported: (reports.first['timestamp'] as Timestamp).toDate(),
      );
    });
  }
}

class CrowdStatus {
  final CrowdLevel level;
  final int reportCount;
  final DateTime lastReported;

  const CrowdStatus({
    required this.level,
    required this.reportCount,
    required this.lastReported,
  });
}
