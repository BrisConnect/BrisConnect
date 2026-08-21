import 'dart:async';

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

  /// Check if a business is a Google Listing (external import from Google Places).
  /// Google Listings do not allow crowd reports or other crowdsourcing features.
  Future<bool> _isGoogleListing(String businessId) async {
    try {
      final doc = await _withRetry(
        () => firestore.collection('businesses').doc(businessId).get(),
        operationName: '_isGoogleListing',
      );
      final data = doc.data();
      return data?['isGoogleListing'] == true ||
          data?['sourceProvider'] == 'google_places';
    } catch (e) {
      debugPrint(
          '[CrowdReportService] Failed to check if business is Google Listing: $e');
      return false;
    }
  }

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

  /// Returns true if the user can submit a report (not within cooldown and
  /// the business is not a Google Listing).
  Future<bool> canSubmitReport(String eventId) async {
    // Check if business is a Google Listing - crowd reports not allowed
    if (await _isGoogleListing(eventId)) {
      return false;
    }

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

  /// Submits a crowd level report for an event or business.
  ///
  /// [eventId] may be a business id when the widget is used on a business
  /// detail screen.
  ///
  /// Throws an exception if the business is a Google Listing (external import
  /// with crowdsourcing disabled).
  Future<void> submitReport(String eventId, CrowdLevel level) async {
    // Check if business is a Google Listing - crowd reports not allowed
    if (await _isGoogleListing(eventId)) {
      throw Exception(
        'Crowd reports are not available for this Google Listing. '
        'Only BrisConnect-owned businesses accept crowd reports.'
      );
    }

    await _assertOnline();
    final userId = _currentUserIdOrAuth;
    final now = DateTime.now();

    await _withRetry(
      () => _reportsCollection.add({
        'eventId': eventId,
        'businessId': eventId,
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

  /// Crowd status for a business id. Aggregates reports that include the
  /// business id in either [eventId] or [businessId].
  Stream<CrowdStatus?> watchBusinessCrowdStatus(String businessId) {
    final since = DateTime.now().subtract(const Duration(hours: 2));
    final eventQuery = _reportsCollection
        .where('eventId', isEqualTo: businessId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true);
    final businessQuery = _reportsCollection
        .where('businessId', isEqualTo: businessId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true);

    return _combineLatest2(
      eventQuery.snapshots(),
      businessQuery.snapshots(),
      (eventSnap, businessSnap) {
        final reports = [...eventSnap.docs, ...businessSnap.docs]
          ..sort((a, b) => b['timestamp']
              .compareTo(a['timestamp']));
        if (reports.isEmpty) return null;
        final totalWeight = reports.fold<num>(
          0,
          (total, d) => total + ((d['weight'] as num? ?? 2)),
        );
        final avg = totalWeight / reports.length;
        return CrowdStatus(
          level: CrowdLevelExtension.fromWeight(avg),
          reportCount: reports.length,
          lastReported: (reports.first['timestamp'] as Timestamp).toDate(),
        );
      },
    );
  }

  Stream<T> _combineLatest2<T, A, B>(
    Stream<A> stream1,
    Stream<B> stream2,
    T Function(A, B) combiner,
  ) {
    A? latest1;
    B? latest2;
    var has1 = false;
    var has2 = false;
    StreamSubscription<A>? sub1;
    StreamSubscription<B>? sub2;
    final controller = StreamController<T>.broadcast();

    void emit() {
      if (has1 && has2 && !controller.isClosed) {
        controller.add(combiner(latest1 as A, latest2 as B));
      }
    }

    sub1 = stream1.listen(
      (value) {
        latest1 = value;
        has1 = true;
        emit();
      },
      onError: controller.addError,
    );
    sub2 = stream2.listen(
      (value) {
        latest2 = value;
        has2 = true;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
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
          reports.fold<num>(0, (total, d) => total + ((d['weight'] as num)));
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
