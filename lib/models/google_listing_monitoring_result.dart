import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single field change detected between BrisConnect and Google
class GoogleListingChange {
  final String field; // 'name', 'address', 'phone', 'website', 'hours', 'status'
  final String brisconnectValue;
  final String googleValue;
  final double similarity; // 0.0 to 1.0, higher = more similar
  final bool differs;

  GoogleListingChange({
    required this.field,
    required this.brisconnectValue,
    required this.googleValue,
    required this.similarity,
    required this.differs,
  });

  factory GoogleListingChange.fromMap(String fieldName, Map<String, dynamic> data) {
    return GoogleListingChange(
      field: fieldName,
      brisconnectValue: data['brisconnect'] ?? '',
      googleValue: data['google'] ?? '',
      similarity: (data['similarity'] ?? 0.0).toDouble(),
      differs: data['differs'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brisconnect': brisconnectValue,
      'google': googleValue,
      'similarity': similarity,
      'differs': differs,
    };
  }

  @override
  String toString() =>
      'GoogleListingChange($field: $brisconnectValue → $googleValue, similarity: ${(similarity * 100).toStringAsFixed(1)}%)';
}

/// Represents complete Google Places data fetched for comparison
class GooglePlaceData {
  final String displayName;
  final String formattedAddress;
  final String? internationalPhoneNumber;
  final String? websiteUri;
  final List<String> weekdayDescriptions;
  final String businessStatus; // 'OPERATIONAL', 'CLOSED_TEMPORARILY', 'CLOSED_PERMANENTLY'
  final double? latitude;
  final double? longitude;

  GooglePlaceData({
    required this.displayName,
    required this.formattedAddress,
    this.internationalPhoneNumber,
    this.websiteUri,
    required this.weekdayDescriptions,
    required this.businessStatus,
    this.latitude,
    this.longitude,
  });

  factory GooglePlaceData.fromMap(Map<String, dynamic> data) {
    final weekdayDescs = <String>[];
    if (data['currentOpeningHours'] != null) {
      final weekday = data['currentOpeningHours']['weekdayDescriptions'];
      if (weekday is List) {
        weekdayDescs.addAll(weekday.cast<String>());
      }
    }

    final location = data['location'] as Map<String, dynamic>?;
    double? lat, lng;
    if (location != null) {
      lat = (location['latitude'] as num?)?.toDouble();
      lng = (location['longitude'] as num?)?.toDouble();
    }

    return GooglePlaceData(
      displayName: data['displayName'] ?? '',
      formattedAddress: data['formattedAddress'] ?? '',
      internationalPhoneNumber: data['internationalPhoneNumber'],
      websiteUri: data['websiteUri'],
      weekdayDescriptions: weekdayDescs,
      businessStatus: data['businessStatus'] ?? 'UNKNOWN',
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'formattedAddress': formattedAddress,
      'internationalPhoneNumber': internationalPhoneNumber,
      'websiteUri': websiteUri,
      'currentOpeningHours': {
        'weekdayDescriptions': weekdayDescriptions,
      },
      'businessStatus': businessStatus,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }

  bool get isClosed => businessStatus == 'CLOSED_PERMANENTLY';
  bool get isTemporarilyClosed => businessStatus == 'CLOSED_TEMPORARILY';
  bool get isOperational => businessStatus == 'OPERATIONAL';
}

/// Severity level for monitoring alerts
enum GoogleListingSeverity {
  info,      // No critical issues, informational
  attention, // Some fields differ or need review
  critical;  // Business closed or critical info changed

  String get label {
    switch (this) {
      case GoogleListingSeverity.info:
        return 'Info';
      case GoogleListingSeverity.attention:
        return 'Attention';
      case GoogleListingSeverity.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case GoogleListingSeverity.info:
        return 'Listing checked, no action needed';
      case GoogleListingSeverity.attention:
        return 'Some fields differ, admin review recommended';
      case GoogleListingSeverity.critical:
        return 'Business closure or critical info change detected';
    }
  }
}

/// Status of monitoring check
enum MonitoringStatus {
  verified,   // No changes found
  mismatch,   // Differences detected
  closed,     // Business closed on Google
  error;      // API error during check

  String get label {
    switch (this) {
      case MonitoringStatus.verified:
        return 'Verified';
      case MonitoringStatus.mismatch:
        return 'Mismatch';
      case MonitoringStatus.closed:
        return 'Closed';
      case MonitoringStatus.error:
        return 'Error';
    }
  }
}

/// Admin review status
enum AdminReviewStatus {
  pending,        // Not yet reviewed by admin
  reviewed,       // Admin has seen this
  accepted,       // Admin confirmed Google data is correct
  rejected,       // Admin confirmed BrisConnect data is correct
  ignored;        // Admin marked as non-actionable

  String get label {
    switch (this) {
      case AdminReviewStatus.pending:
        return 'Pending Review';
      case AdminReviewStatus.reviewed:
        return 'Reviewed';
      case AdminReviewStatus.accepted:
        return 'Accepted Changes';
      case AdminReviewStatus.rejected:
        return 'Rejected Changes';
      case AdminReviewStatus.ignored:
        return 'Ignored';
    }
  }
}

/// Complete monitoring result for a business
class GoogleListingMonitoringResult {
  final String id; // Firestore document ID
  final String businessId;
  final String businessName;
  final String googlePlaceId;
  final String businessCollection; // 'food_businesses' or 'businesses'
  final DateTime checkTimestamp;
  final MonitoringStatus status;
  final GoogleListingSeverity severity;
  final bool hasChanges;
  final Map<String, GoogleListingChange> changes; // field name -> change
  final GooglePlaceData? googleData;
  final bool alertSent;
  final AdminReviewStatus adminReviewStatus;
  final String? adminReviewNotes;
  final DateTime? adminReviewTimestamp;

  GoogleListingMonitoringResult({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.googlePlaceId,
    required this.businessCollection,
    required this.checkTimestamp,
    required this.status,
    required this.severity,
    required this.hasChanges,
    required this.changes,
    this.googleData,
    required this.alertSent,
    required this.adminReviewStatus,
    this.adminReviewNotes,
    this.adminReviewTimestamp,
  });

  /// Create from Firestore document
  factory GoogleListingMonitoringResult.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoogleListingMonitoringResult.fromMap(data, doc.id);
  }

  /// Create from map (used by fromDoc and for testing)
  factory GoogleListingMonitoringResult.fromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    // Parse changes
    final changesMap = <String, GoogleListingChange>{};
    if (data['changes'] is Map) {
      (data['changes'] as Map<String, dynamic>).forEach((fieldName, changeData) {
        if (changeData is Map<String, dynamic>) {
          changesMap[fieldName] = GoogleListingChange.fromMap(fieldName, changeData);
        }
      });
    }

    // Parse Google data
    GooglePlaceData? googleData;
    if (data['googleData'] is Map<String, dynamic>) {
      googleData = GooglePlaceData.fromMap(data['googleData'] as Map<String, dynamic>);
    }

    // Parse enums
    MonitoringStatus status;
    switch (data['status'] as String?) {
      case 'mismatch':
        status = MonitoringStatus.mismatch;
      case 'closed':
        status = MonitoringStatus.closed;
      case 'error':
        status = MonitoringStatus.error;
      default:
        status = MonitoringStatus.verified;
    }

    GoogleListingSeverity severity;
    switch (data['severity'] as String?) {
      case 'attention':
        severity = GoogleListingSeverity.attention;
      case 'critical':
        severity = GoogleListingSeverity.critical;
      default:
        severity = GoogleListingSeverity.info;
    }

    AdminReviewStatus reviewStatus;
    switch (data['adminReviewStatus'] as String?) {
      case 'reviewed':
        reviewStatus = AdminReviewStatus.reviewed;
      case 'accepted':
        reviewStatus = AdminReviewStatus.accepted;
      case 'rejected':
        reviewStatus = AdminReviewStatus.rejected;
      case 'ignored':
        reviewStatus = AdminReviewStatus.ignored;
      default:
        reviewStatus = AdminReviewStatus.pending;
    }

    // Parse timestamps
    final checkTs = data['checkTimestamp'];
    final checkTime = checkTs is Timestamp
        ? checkTs.toDate()
        : checkTs is String
            ? DateTime.tryParse(checkTs) ?? DateTime.now()
            : DateTime.now();

    final reviewTs = data['adminReviewTimestamp'];
    final reviewTime = reviewTs is Timestamp
        ? reviewTs.toDate()
        : reviewTs is String
            ? DateTime.tryParse(reviewTs)
            : null;

    return GoogleListingMonitoringResult(
      id: docId,
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      googlePlaceId: data['googlePlaceId'] ?? '',
      businessCollection: data['businessCollection'] ?? 'food_businesses',
      checkTimestamp: checkTime,
      status: status,
      severity: severity,
      hasChanges: data['hasChanges'] ?? false,
      changes: changesMap,
      googleData: googleData,
      alertSent: data['alertSent'] ?? false,
      adminReviewStatus: reviewStatus,
      adminReviewNotes: data['adminReviewNotes'],
      adminReviewTimestamp: reviewTime,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'googlePlaceId': googlePlaceId,
      'businessCollection': businessCollection,
      'checkTimestamp': Timestamp.fromDate(checkTimestamp),
      'status': status.name,
      'severity': severity.name,
      'hasChanges': hasChanges,
      'changes': Map.fromEntries(
        changes.entries.map((e) => MapEntry(e.key, e.value.toMap())),
      ),
      'googleData': googleData?.toMap(),
      'alertSent': alertSent,
      'adminReviewStatus': adminReviewStatus.name,
      'adminReviewNotes': adminReviewNotes,
      'adminReviewTimestamp': adminReviewTimestamp != null
          ? Timestamp.fromDate(adminReviewTimestamp!)
          : null,
    };
  }

  /// Copy with optional field overrides
  GoogleListingMonitoringResult copyWith({
    String? id,
    String? businessId,
    String? businessName,
    String? googlePlaceId,
    String? businessCollection,
    DateTime? checkTimestamp,
    MonitoringStatus? status,
    GoogleListingSeverity? severity,
    bool? hasChanges,
    Map<String, GoogleListingChange>? changes,
    GooglePlaceData? googleData,
    bool? alertSent,
    AdminReviewStatus? adminReviewStatus,
    String? adminReviewNotes,
    DateTime? adminReviewTimestamp,
  }) {
    return GoogleListingMonitoringResult(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      businessCollection: businessCollection ?? this.businessCollection,
      checkTimestamp: checkTimestamp ?? this.checkTimestamp,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      hasChanges: hasChanges ?? this.hasChanges,
      changes: changes ?? this.changes,
      googleData: googleData ?? this.googleData,
      alertSent: alertSent ?? this.alertSent,
      adminReviewStatus: adminReviewStatus ?? this.adminReviewStatus,
      adminReviewNotes: adminReviewNotes ?? this.adminReviewNotes,
      adminReviewTimestamp: adminReviewTimestamp ?? this.adminReviewTimestamp,
    );
  }

  @override
  String toString() =>
      'GoogleListingMonitoringResult($businessName, status: $status, severity: $severity, hasChanges: $hasChanges)';
}
