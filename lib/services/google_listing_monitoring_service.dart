// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/models/google_listing_monitoring_result.dart';

/// Service for querying and managing Google listing monitoring records
class GoogleListingMonitoringService {
  final FirebaseFirestore _firestore;

  GoogleListingMonitoringService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of recent monitoring records (with pagination)
  Stream<List<GoogleListingMonitoringResult>> watchRecentMonitoringRecords({
    int limit = 50,
  }) {
    return _firestore
        .collection('google_listing_monitoring')
        .orderBy('checkTimestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
    });
  }

  /// Stream of monitoring records filtered by status
  Stream<List<GoogleListingMonitoringResult>> watchMonitoringByStatus({
    required MonitoringStatus status,
    int limit = 50,
  }) {
    return _firestore
        .collection('google_listing_monitoring')
        .where('status', isEqualTo: status.name)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
      // Sort by checkTimestamp client-side to avoid composite index
      docs.sort((a, b) => b.checkTimestamp.compareTo(a.checkTimestamp));
      return docs.take(limit).toList();
    });
  }

  /// Stream of monitoring records filtered by severity
  Stream<List<GoogleListingMonitoringResult>> watchMonitoringBySeverity({
    required GoogleListingSeverity severity,
    int limit = 50,
  }) {
    return _firestore
        .collection('google_listing_monitoring')
        .where('severity', isEqualTo: severity.name)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
      // Sort by checkTimestamp client-side to avoid composite index
      docs.sort((a, b) => b.checkTimestamp.compareTo(a.checkTimestamp));
      return docs.take(limit).toList();
    });
  }

  /// Stream of unreviewed monitoring records requiring admin action
  Stream<List<GoogleListingMonitoringResult>> watchUnreviewedChanges({
    int limit = 50,
  }) {
    return _firestore
        .collection('google_listing_monitoring')
        .where('adminReviewStatus', isEqualTo: AdminReviewStatus.pending.name)
        .limit(limit * 3) // Fetch extra to account for client-side filtering and sorting
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
      
      // Filter by hasChanges and sort by severity and timestamp client-side
      final filtered = docs.where((r) => r.hasChanges).toList();
      filtered.sort((a, b) {
        // Sort by severity first (critical first)
        final severityOrder = {'critical': 0, 'attention': 1, 'info': 2};
        final aOrder = severityOrder[a.severity.name] ?? 3;
        final bOrder = severityOrder[b.severity.name] ?? 3;
        final severityComparison = aOrder.compareTo(bOrder);
        if (severityComparison != 0) return severityComparison;
        // Then by timestamp (newest first)
        return b.checkTimestamp.compareTo(a.checkTimestamp);
      });
      return filtered.take(limit).toList();
    });
  }

  /// Stream of critical alerts (closed businesses or critical changes)
  Stream<List<GoogleListingMonitoringResult>> watchCriticalAlerts({
    int limit = 50,
  }) {
    return _firestore
        .collection('google_listing_monitoring')
        .where('severity', isEqualTo: GoogleListingSeverity.critical.name)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
      // Sort by checkTimestamp client-side to avoid composite index
      docs.sort((a, b) => b.checkTimestamp.compareTo(a.checkTimestamp));
      return docs.take(limit).toList();
    });
  }

  /// Get single monitoring record by ID
  Future<GoogleListingMonitoringResult?> getMonitoringRecord(String recordId) async {
    try {
      final doc = await _firestore
          .collection('google_listing_monitoring')
          .doc(recordId)
          .get();
      if (doc.exists) {
        return GoogleListingMonitoringResult.fromDoc(doc);
      }
    } catch (e) {
      print('Error fetching monitoring record: $e');
    }
    return null;
  }

  /// Get most recent monitoring record for a business
  Future<GoogleListingMonitoringResult?> getLatestMonitoringForBusiness(
    String businessId,
  ) async {
    try {
      final query = await _firestore
          .collection('google_listing_monitoring')
          .where('businessId', isEqualTo: businessId)
          .limit(10) // Fetch more to sort client-side
          .get();
      
      if (query.docs.isNotEmpty) {
        final results = query.docs
            .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
            .toList();
        // Sort by checkTimestamp descending client-side to avoid composite index
        results.sort((a, b) => b.checkTimestamp.compareTo(a.checkTimestamp));
        return results.first;
      }
    } catch (e) {
      print('Error fetching latest monitoring record: $e');
    }
    return null;
  }

  /// Update admin review status and notes
  Future<void> updateAdminReviewStatus(
    String recordId, {
    required AdminReviewStatus reviewStatus,
    String? reviewNotes,
  }) async {
    try {
      await _firestore
          .collection('google_listing_monitoring')
          .doc(recordId)
          .update({
        'adminReviewStatus': reviewStatus.name,
        'adminReviewNotes': reviewNotes,
        'adminReviewTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating admin review status: $e');
      rethrow;
    }
  }

  /// Mark alert as sent (after admin is notified)
  Future<void> markAlertAsSent(String recordId) async {
    try {
      await _firestore
          .collection('google_listing_monitoring')
          .doc(recordId)
          .update({'alertSent': true});
    } catch (e) {
      print('Error marking alert as sent: $e');
      rethrow;
    }
  }

  /// Search monitoring records by business name (case-insensitive)
  Future<List<GoogleListingMonitoringResult>> searchByBusinessName(
    String query, {
    int limit = 50,
  }) async {
    try {
      final queryLower = query.toLowerCase();
      final snapshot = await _firestore
          .collection('google_listing_monitoring')
          .orderBy('checkTimestamp', descending: true)
          .limit(limit * 2) // Fetch more to account for filtering
          .get();

      final results = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .where((result) =>
              result.businessName.toLowerCase().contains(queryLower) ||
              result.businessId.toLowerCase().contains(queryLower))
          .take(limit)
          .toList();

      return results;
    } catch (e) {
      print('Error searching monitoring records: $e');
      return [];
    }
  }

  /// Get count of unreviewed records
  /// Note: Uses simple query without composite index for performance
  Future<int> getUnreviewedCount() async {
    try {
      // Query only on adminReviewStatus (no composite index needed)
      final snapshot = await _firestore
          .collection('google_listing_monitoring')
          .where('adminReviewStatus', isEqualTo: AdminReviewStatus.pending.name)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unreviewed count: $e');
      return 0;
    }
  }

  /// Get count of critical alerts
  /// Note: Uses simple query without composite index for performance
  Future<int> getCriticalCount() async {
    try {
      // Query only on severity (no composite index needed)
      final snapshot = await _firestore
          .collection('google_listing_monitoring')
          .where('severity', isEqualTo: GoogleListingSeverity.critical.name)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting critical count: $e');
      return 0;
    }
  }

  /// Stream of unreviewed critical alerts count
  Stream<int> watchCriticalCount() {
    return _firestore
        .collection('google_listing_monitoring')
        .where('severity', isEqualTo: GoogleListingSeverity.critical.name)
        .snapshots()
        .map((snapshot) {
          // Filter by adminReviewStatus client-side to avoid composite index
          return snapshot.docs
              .where((doc) => doc['adminReviewStatus'] == AdminReviewStatus.pending.name)
              .length;
        });
  }

  /// Get monitoring records for a specific time range
  Future<List<GoogleListingMonitoringResult>> getRecordsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('google_listing_monitoring')
          .orderBy('checkTimestamp', descending: true)
          .limit(limit * 2) // Fetch extra to account for client-side filtering
          .get();

      final results = snapshot.docs
          .map((doc) => GoogleListingMonitoringResult.fromDoc(doc))
          .toList();
      
      // Filter by date range client-side to avoid composite index
      return results
          .where((r) => r.checkTimestamp.isAfter(startDate) && 
                        r.checkTimestamp.isBefore(endDate))
          .take(limit)
          .toList();
    } catch (e) {
      print('Error fetching records by date range: $e');
      return [];
    }
  }

  /// Get summary statistics for monitoring
  Future<Map<String, dynamic>> getMonitoringSummary({
    Duration lookbackDays = const Duration(days: 30),
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(lookbackDays);

      final snapshot = await _firestore
          .collection('google_listing_monitoring')
          .where('checkTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get();

      final records =
          snapshot.docs.map((doc) => GoogleListingMonitoringResult.fromDoc(doc)).toList();

      int verified = 0;
      int mismatches = 0;
      int closed = 0;
      int errors = 0;
      int critical = 0;
      int unreviewed = 0;

      for (final record in records) {
        if (record.status == MonitoringStatus.verified) verified++;
        if (record.status == MonitoringStatus.mismatch) mismatches++;
        if (record.status == MonitoringStatus.closed) closed++;
        if (record.status == MonitoringStatus.error) errors++;
        if (record.severity == GoogleListingSeverity.critical) critical++;
        if (record.adminReviewStatus == AdminReviewStatus.pending) unreviewed++;
      }

      return {
        'totalChecks': records.length,
        'verified': verified,
        'mismatches': mismatches,
        'closed': closed,
        'errors': errors,
        'critical': critical,
        'unreviewed': unreviewed,
        'businessesWithChanges':
            records.where((r) => r.hasChanges).map((r) => r.businessId).toSet().length,
      };
    } catch (e) {
      print('Error getting monitoring summary: $e');
      return {};
    }
  }

  /// Accept Google changes (update admin review status to accepted)
  Future<void> acceptGoogleChanges(
    String recordId, {
    String? notes,
  }) async {
    await updateAdminReviewStatus(
      recordId,
      reviewStatus: AdminReviewStatus.accepted,
      reviewNotes: notes ?? 'Accepted Google listing data',
    );
  }

  /// Reject Google changes, keep BrisConnect data (update admin review status to rejected)
  Future<void> rejectGoogleChanges(
    String recordId, {
    String? notes,
  }) async {
    await updateAdminReviewStatus(
      recordId,
      reviewStatus: AdminReviewStatus.rejected,
      reviewNotes: notes ?? 'Kept BrisConnect data',
    );
  }

  /// Mark record as reviewed/ignored (non-actionable)
  Future<void> ignoreMonitoringRecord(
    String recordId, {
    String? notes,
  }) async {
    await updateAdminReviewStatus(
      recordId,
      reviewStatus: AdminReviewStatus.ignored,
      reviewNotes: notes ?? 'Marked as non-actionable',
    );
  }
}
