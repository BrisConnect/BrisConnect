import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'package:brisconnect/config/app_config.dart';

/// Service that checks the health of business-owner notification services.
///
/// Calls a Cloud Function synthetic monitor and optionally watches the
/// recorded health-check history in Firestore.
class NotificationHealthService {
  final FirebaseFunctions? _functions;
  final FirebaseFirestore? _firestore;

  NotificationHealthService({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functions = functions,
        _firestore = firestore;

  FirebaseFunctions get _functionsInstance =>
      _functions ?? FirebaseFunctions.instanceFor(region: AppConfig.firebaseFunctionsRegion);

  FirebaseFirestore get _firestoreInstance => _firestore ?? FirebaseFirestore.instance;

  /// Invokes the `notificationHealth` callable Cloud Function and returns the
  /// latest availability snapshot.
  Future<NotificationHealthResult> checkHealth() async {
    try {
      final callable = _functionsInstance.httpsCallable('notificationHealth');
      final result = await callable.call<Map<String, dynamic>>();
      final data = result.data;
      return NotificationHealthResult.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[NotificationHealthService] checkHealth failed: ${e.code} ${e.message}');
      return NotificationHealthResult.unavailable('Cloud Function error: ${e.message}');
    } catch (e) {
      debugPrint('[NotificationHealthService] checkHealth unexpected error: $e');
      return NotificationHealthResult.unavailable('Unexpected error: $e');
    }
  }

  /// Returns a stream of the most recent health-check records, ordered by
  /// checkedAt descending.
  Stream<List<NotificationHealthResult>> watchRecentChecks({int limit = 100}) {
    return _firestoreInstance
        .collection('notification_health_checks')
        .orderBy('checkedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationHealthResult.fromJson(doc.data()))
            .toList());
  }

  /// Calculates an approximate availability percentage from recent health-check
  /// records. Returns null if no records exist.
  static double? calculateAvailability(List<NotificationHealthResult> checks) {
    if (checks.isEmpty) return null;
    final okCount = checks.where((c) => c.status == 'ok').length;
    return (okCount / checks.length) * 100;
  }
}

/// Result of a notification health check.
class NotificationHealthResult {
  final String status;
  final bool firestoreReachable;
  final bool fcmReachable;
  final int latencyMs;
  final DateTime? checkedAt;
  final String? message;

  const NotificationHealthResult({
    required this.status,
    required this.firestoreReachable,
    required this.fcmReachable,
    required this.latencyMs,
    this.checkedAt,
    this.message,
  });

  factory NotificationHealthResult.fromJson(Map<String, dynamic> json) {
    final checkedAtRaw = json['checkedAt'];
    DateTime? checkedAt;
    if (checkedAtRaw is Timestamp) {
      checkedAt = checkedAtRaw.toDate();
    } else if (checkedAtRaw is Map<String, dynamic> && checkedAtRaw['_seconds'] != null) {
      checkedAt = DateTime.fromMillisecondsSinceEpoch(
        (checkedAtRaw['_seconds'] as int) * 1000 +
            ((checkedAtRaw['_nanoseconds'] as int?) ?? 0) ~/ 1000000,
      );
    }

    return NotificationHealthResult(
      status: json['status'] as String? ?? 'unknown',
      firestoreReachable: json['firestoreReachable'] == true,
      fcmReachable: json['fcmReachable'] == true,
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      checkedAt: checkedAt,
      message: json['message'] as String?,
    );
  }

  factory NotificationHealthResult.unavailable(String reason) {
    return NotificationHealthResult(
      status: 'unavailable',
      firestoreReachable: false,
      fcmReachable: false,
      latencyMs: 0,
      checkedAt: DateTime.now(),
      message: reason,
    );
  }

  bool get isHealthy => status == 'ok';
}
