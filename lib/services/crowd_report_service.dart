import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _db = FirebaseFirestore.instance;

  // Duplicate prevention window (30 minutes)
  static const _cooldownMinutes = 30;

  /// Cooldown key stored in shared preferences for anonymous users
  String _prefsKey(String eventId) => 'crowd_report_${eventId}_last';

  /// Returns true if the user can submit a report (not within cooldown)
  Future<bool> canSubmitReport(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check Firestore for authenticated users
      try {
        final since = DateTime.now().subtract(
          const Duration(minutes: _cooldownMinutes),
        );
        final existing = await _db
            .collection('crowd_reports')
            .where('eventId', isEqualTo: eventId)
            .where('userId', isEqualTo: user.uid)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .limit(1)
            .get();
        return existing.docs.isEmpty;
      } catch (e) {
        // If collection doesn't exist or permission denied, allow submission
        return true;
      }
    } else {
      // For anonymous users, use shared preferences
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefsKey(eventId));
      if (lastMs == null) return true;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      return DateTime.now().difference(last).inMinutes >= _cooldownMinutes;
    }
  }

  /// Submits a crowd level report for an event
  Future<void> submitReport(String eventId, CrowdLevel level) async {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    await _db.collection('crowd_reports').add({
      'eventId': eventId,
      'userId': user?.uid ?? 'anonymous',
      'level': level.label,
      'weight': level.weight,
      'timestamp': Timestamp.fromDate(now),
    });

    // Track last submission for anonymous users
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey(eventId), now.millisecondsSinceEpoch);
    }
  }

  /// Returns a stream of the current crowd status for an event.
  /// Uses reports from the last 2 hours, weighted average.
  Stream<CrowdStatus?> watchCrowdStatus(String eventId) {
    final since = DateTime.now().subtract(const Duration(hours: 2));
    return _db
        .collection('crowd_reports')
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
