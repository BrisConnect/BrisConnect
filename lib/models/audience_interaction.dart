import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of audience interactions that can be recorded for analytics.
enum AudienceInteractionType { view, save }

/// A single anonymised audience interaction with a business profile.
///
/// The [visitorHash] is a privacy-preserving stable identifier derived from
/// the visitor's Firebase Auth UID (hashed + truncated) so we can distinguish
/// new from returning viewers without storing personal data.
class AudienceInteraction {
  final String? id;
  final String businessId;
  final String ownerId;
  final String visitorHash;
  final AudienceInteractionType type;
  final DateTime timestamp;

  const AudienceInteraction({
    this.id,
    required this.businessId,
    required this.ownerId,
    required this.visitorHash,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'visitorHash': visitorHash,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AudienceInteraction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AudienceInteraction(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      visitorHash: data['visitorHash'] ?? '',
      type: _parseType(data['type'] as String?),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  static AudienceInteractionType _parseType(String? value) {
    switch (value) {
      case 'save':
        return AudienceInteractionType.save;
      case 'view':
      default:
        return AudienceInteractionType.view;
    }
  }

  AudienceInteraction copyWith({
    String? id,
    String? businessId,
    String? ownerId,
    String? visitorHash,
    AudienceInteractionType? type,
    DateTime? timestamp,
  }) {
    return AudienceInteraction(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      visitorHash: visitorHash ?? this.visitorHash,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
