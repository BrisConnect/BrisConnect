enum EventReviewStatus {
  pending,
  approved,
  rejected,
}

class EventItem {
  final String id;
  final String title;
  final String date;
  final String time;
  final String category;
  final String location;
  final String description;
  final EventReviewStatus reviewStatus;
  final String? createdByLocalEmail;
  final String? imageAsset;
  final String? imageStoragePath;
  final String? audioUrl;
  final String? audioStoragePath;
  final String? videoUrl;
  final String? videoStoragePath;
  final double? latitude;
  final double? longitude;

  bool get isApproved => reviewStatus == EventReviewStatus.approved;
  bool get isPending => reviewStatus == EventReviewStatus.pending;
  bool get isRejected => reviewStatus == EventReviewStatus.rejected;

  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    this.category = 'General',
    required this.location,
    required this.description,
    required this.reviewStatus,
    this.createdByLocalEmail,
    this.imageAsset,
    this.imageStoragePath,
    this.audioUrl,
    this.audioStoragePath,
    this.videoUrl,
    this.videoStoragePath,
    this.latitude,
    this.longitude,
  });

  EventItem copyWith({
    String? id,
    String? title,
    String? date,
    String? time,
    String? category,
    String? location,
    String? description,
    EventReviewStatus? reviewStatus,
    String? createdByLocalEmail,
    String? imageAsset,
    String? imageStoragePath,
    String? audioUrl,
    String? audioStoragePath,
    String? videoUrl,
    String? videoStoragePath,
    double? latitude,
    double? longitude,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      category: category ?? this.category,
      location: location ?? this.location,
      description: description ?? this.description,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      createdByLocalEmail: createdByLocalEmail ?? this.createdByLocalEmail,
      imageAsset: imageAsset ?? this.imageAsset,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioStoragePath: audioStoragePath ?? this.audioStoragePath,
      videoUrl: videoUrl ?? this.videoUrl,
      videoStoragePath: videoStoragePath ?? this.videoStoragePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
