import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of content that can appear in the community activity feed.
enum ActivityFeedType {
  all,
  review,
  event,
  business,
  photo,
}

/// A normalized item shown in the Visitor community activity feed.
///
/// Source collections vary (reviews, business_events, businesses), but the
/// feed UI consumes a single shape so cards can be rendered consistently.
class ActivityFeedItem {
  final String id;
  final ActivityFeedType type;
  final String title;
  final String subtitle;
  final String body;
  final String imageUrl;
  final DateTime createdAt;

  /// Id of the related entity the card should deep-link to.
  /// - review → businessId
  /// - event → event id
  /// - business → business id
  /// - photo → source entity id
  final String targetId;

  /// Optional secondary id for routing (e.g. a review's businessId).
  final String? secondaryTargetId;

  const ActivityFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
    required this.targetId,
    this.secondaryTargetId,
  });

  static ActivityFeedItem? fromReviewDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final visible = data['visible'] ?? true;
    final isFlagged = data['isFlagged'] ?? false;
    if (!visible || isFlagged) return null;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return null;

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.review,
      title: data['visitorName']?.toString().trim().isNotEmpty == true
          ? data['visitorName'].toString().trim()
          : 'Anonymous',
      subtitle: 'left a recommendation',
      body: data['comment']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      createdAt: createdAt,
      targetId: data['businessId']?.toString() ?? doc.id,
      secondaryTargetId: doc.id,
    );
  }

  static ActivityFeedItem? fromBusinessEventDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final status = data['status']?.toString() ?? 'published';
    if (status != 'published') return null;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return null;

    final title = data['title']?.toString().trim() ?? 'Untitled Event';
    final date = data['date']?.toString().trim() ?? '';
    final time = data['time']?.toString().trim() ?? '';
    final dateTime = time.isNotEmpty ? '$date • $time' : date;

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.event,
      title: title,
      subtitle: dateTime,
      body: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      createdAt: createdAt,
      targetId: doc.id,
    );
  }

  static ActivityFeedItem? fromBusinessDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return null;

    final name = (data['businessName']?.toString().trim().isNotEmpty == true
            ? data['businessName']
            : data['name'])
        ?.toString()
        .trim();

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.business,
      title: name ?? 'New Business',
      subtitle: 'joined BrisConnect+',
      body: data['description']?.toString() ?? '',
      imageUrl: data['logoUrl']?.toString() ??
          data['imageUrl']?.toString() ??
          data['coverImageUrl']?.toString() ??
          '',
      createdAt: createdAt,
      targetId: doc.id,
    );
  }
}
