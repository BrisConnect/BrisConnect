import 'package:cloud_firestore/cloud_firestore.dart';

/// Business event model for food business owners to promote events
class BusinessEvent {
  final String? id; // Firestore document ID
  final String businessId; // Link to the Business profile
  final String ownerId; // UID of the business owner
  final String ownerEmail; // Email of the business owner (for permission checks)
  final String title; // Event title
  final String date; // Event date (formatted as dd/mm/yyyy)
  final String time; // Event time (formatted as hh:mm)
  final String location; // Event location
  final String description; // Event description
  final String? imageUrl; // Firebase Storage URL for event image
  final String? imageStoragePath; // Storage path for deletion
  final String status; // published, cancelled, draft
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BusinessEvent({
    this.id,
    required this.businessId,
    required this.ownerId,
    required this.ownerEmail,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    this.imageUrl,
    this.imageStoragePath,
    this.status = 'published',
    this.createdAt,
    this.updatedAt,
  });

  /// Check if event is published
  bool get isPublished => status == 'published';

  /// Check if event is cancelled
  bool get isCancelled => status == 'cancelled';

  /// Convert BusinessEvent to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail.trim().toLowerCase(),
      'title': title.trim(),
      'date': date.trim(),
      'time': time.trim(),
      'location': location.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl?.trim(),
      'imageStoragePath': imageStoragePath?.trim(),
      'status': status.trim(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// Create BusinessEvent from Firestore document
  factory BusinessEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessEvent(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      title: data['title'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      imageStoragePath: data['imageStoragePath'],
      status: data['status'] ?? 'published',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy with modifications
  BusinessEvent copyWith({
    String? id,
    String? businessId,
    String? ownerId,
    String? ownerEmail,
    String? title,
    String? date,
    String? time,
    String? location,
    String? description,
    String? imageUrl,
    String? imageStoragePath,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessEvent(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'BusinessEvent($id, $title, $businessId)';
}
