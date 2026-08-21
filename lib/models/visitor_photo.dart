import 'package:cloud_firestore/cloud_firestore.dart';

/// A photo contributed by a Visitor for a food business or event.
///
/// Photos are published immediately and are publicly visible without
/// admin moderation.
class VisitorPhoto {
  final String id;
  final String? businessId;
  final String? eventId;
  final String visitorId;
  final String visitorName;
  final String imageUrl;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String? caption;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  const VisitorPhoto({
    required this.id,
    this.businessId,
    this.eventId,
    required this.visitorId,
    required this.visitorName,
    required this.imageUrl,
    required this.storagePath,
    required this.mimeType,
    required this.fileSize,
    this.caption,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy,
  });

  bool get isApproved => status == 'approved';
  bool get isDeleted => deletedAt != null;
  bool get isBusinessPhoto => businessId != null && businessId!.isNotEmpty;
  bool get isEventPhoto => eventId != null && eventId!.isNotEmpty;

  Map<String, dynamic> toFirestore() {
    return {
      if (businessId != null) 'businessId': businessId,
      if (eventId != null) 'eventId': eventId,
      'visitorId': visitorId,
      'visitorName': visitorName,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'caption': caption,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'deletedBy': deletedBy,
    };
  }

  factory VisitorPhoto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitorPhoto(
      id: doc.id,
      businessId: data['businessId'] as String?,
      eventId: data['eventId'] as String?,
      visitorId: data['visitorId'] ?? '',
      visitorName: data['visitorName'] ?? 'Anonymous',
      imageUrl: data['imageUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      mimeType: data['mimeType'] ?? 'image/jpeg',
      fileSize: data['fileSize'] ?? 0,
      caption: data['caption'] as String?,
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: data['deletedBy'] as String?,
    );
  }

  VisitorPhoto copyWith({
    String? id,
    String? businessId,
    String? eventId,
    String? visitorId,
    String? visitorName,
    String? imageUrl,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    String? caption,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedBy,
  }) {
    return VisitorPhoto(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      eventId: eventId ?? this.eventId,
      visitorId: visitorId ?? this.visitorId,
      visitorName: visitorName ?? this.visitorName,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      caption: caption ?? this.caption,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}
