import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of content that can appear in the community activity feed.
enum ActivityFeedType {
  all,
  review,
  event,
  business,
  photo,
  trending,
  nearby,
  following,
  newest,
  popular,
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

  /// Whether this item is pinned to the top of the community feed.
  final bool isPinned;

  /// Timestamp when the item was pinned. Used to sort pinned items.
  final DateTime? pinnedAt;

  /// Whether this item is highlighted/promoted in the community feed.
  final bool isHighlighted;

  /// Timestamp when the item was highlighted. Used to sort highlighted items.
  final DateTime? highlightedAt;

  /// Optional promotion label shown as a colored badge on the card.
  /// Expected values: 'Limited Time', 'Today Only', 'New', 'Featured'.
  final String? promotionLabel;

  /// Event-specific suburb or location name.
  final String? eventSuburb;

  /// Whether an event is free to attend. Null when not applicable.
  final bool? isFreeEntry;

  /// Id of the related entity the card should deep-link to.
  /// - review → businessId
  /// - event → event id
  /// - business → business id
  /// - photo → source entity id
  final String targetId;

  /// Optional secondary id for routing (e.g. a review's businessId).
  final String? secondaryTargetId;

  /// Display name of the actor that created this item (reviewer, business, etc).
  /// Falls back to [title] when not available.
  final String? actorName;

  /// Optional profile image URL of the actor.
  final String? actorPhotoUrl;

  /// Optional business name associated with this item (e.g. the reviewed business).
  final String? businessName;

  const ActivityFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
    this.isPinned = false,
    this.pinnedAt,
    this.isHighlighted = false,
    this.highlightedAt,
    required this.targetId,
    this.secondaryTargetId,
    this.promotionLabel,
    this.eventSuburb,
    this.isFreeEntry,
    this.actorName,
    this.actorPhotoUrl,
    this.businessName,
  });

  static ActivityFeedItem? fromReviewDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final visible = data['visible'] ?? true;
    final isFlagged = data['isFlagged'] ?? false;
    if (!visible || isFlagged) return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final pinnedAt = _parseDateTime(data['pinnedAt']);
    final highlightedAt = _parseDateTime(data['highlightedAt']);

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
      isPinned: data['isPinned'] == true,
      pinnedAt: pinnedAt,
      isHighlighted: data['isHighlighted'] == true,
      highlightedAt: highlightedAt,
      targetId: data['businessId']?.toString() ?? doc.id,
      secondaryTargetId: doc.id,
      actorName: data['visitorName']?.toString().trim().isNotEmpty == true
          ? data['visitorName'].toString().trim()
          : 'Anonymous',
      actorPhotoUrl: data['visitorPhotoUrl']?.toString(),
      businessName: data['businessName']?.toString(),
    );
  }

  static ActivityFeedItem? fromBusinessEventDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final status = data['status']?.toString() ?? 'published';
    if (status != 'published') return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final title = data['title']?.toString().trim() ?? 'Untitled Event';
    final date = data['date']?.toString().trim() ?? '';
    final time = data['time']?.toString().trim() ?? '';
    final dateTime = time.isNotEmpty ? '$date • $time' : date;

    final pinnedAt = _parseDateTime(data['pinnedAt']);
    final highlightedAt = _parseDateTime(data['highlightedAt']);

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.event,
      title: title,
      subtitle: dateTime,
      body: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      createdAt: createdAt,
      isPinned: data['isPinned'] == true,
      pinnedAt: pinnedAt,
      isHighlighted: data['isHighlighted'] == true,
      highlightedAt: highlightedAt,
      targetId: doc.id,
      secondaryTargetId: data['businessId']?.toString(),
      eventSuburb: _extractSuburb(data['location']?.toString() ??
          data['address']?.toString() ??
          data['venue']?.toString()),
      isFreeEntry: _parseIsFreeEntry(data['price']),
      businessName:
          data['businessName']?.toString() ?? data['businessName']?.toString(),
      actorName: data['organiserName']?.toString().trim().isNotEmpty == true
          ? data['organiserName'].toString().trim()
          : data['businessName']?.toString().trim().isNotEmpty == true
              ? data['businessName'].toString().trim()
              : null,
      actorPhotoUrl: data['organiserPhotoUrl']?.toString() ??
          data['businessLogoUrl']?.toString(),
    );
  }

  static ActivityFeedItem? fromBusinessDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    // Removed/deactivated businesses should not appear in the feed.
    if (data['isActive'] == false || data['deletedAt'] != null) return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final name = (data['businessName']?.toString().trim().isNotEmpty == true
            ? data['businessName']
            : data['name'])
        ?.toString()
        .trim();

    final pinnedAt = _parseDateTime(data['pinnedAt']);
    final highlightedAt = _parseDateTime(data['highlightedAt']);

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
      isPinned: data['isPinned'] == true,
      pinnedAt: pinnedAt,
      isHighlighted: data['isHighlighted'] == true,
      highlightedAt: highlightedAt,
      createdAt: createdAt,
      targetId: doc.id,
      actorName: name,
      actorPhotoUrl: data['logoUrl']?.toString() ??
          data['imageUrl']?.toString() ??
          data['coverImageUrl']?.toString(),
    );
  }

  /// Compatibility factory for legacy `food_businesses` documents that pre-date
  /// the canonical [businesses] collection.
  static ActivityFeedItem? fromFoodBusinessDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final name = (data['name']?.toString().trim().isNotEmpty == true
            ? data['name']
            : data['businessName'])
        ?.toString()
        .trim();

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.business,
      title: name ?? 'New Business',
      subtitle: 'joined BrisConnect+',
      body: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ??
          data['logoUrl']?.toString() ??
          data['coverImageUrl']?.toString() ??
          '',
      createdAt: createdAt,
      targetId: doc.id,
      actorName: name,
      actorPhotoUrl: data['imageUrl']?.toString() ??
          data['logoUrl']?.toString() ??
          data['coverImageUrl']?.toString(),
    );
  }

  /// Parses a Firestore [Timestamp], an ISO-8601 string, or a [DateTime].
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static ActivityFeedItem? fromPromotionDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status != 'active') return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final title = data['title']?.toString().trim();
    if (title == null || title.isEmpty) return null;

    final endAt = _parseDateTime(data['endAt']);
    if (endAt != null && endAt.isBefore(DateTime.now())) return null;

    final pinnedAt = _parseDateTime(data['pinnedAt']);
    final highlightedAt = _parseDateTime(data['highlightedAt']);

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.business,
      title: title,
      subtitle: 'Promotion',
      body: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ??
          data['promoImageUrl']?.toString() ??
          '',
      isPinned: data['isPinned'] == true,
      pinnedAt: pinnedAt,
      isHighlighted: data['isHighlighted'] == true,
      highlightedAt: highlightedAt,
      createdAt: createdAt,
      targetId: data['businessId']?.toString() ?? doc.id,
      promotionLabel: _promotionLabelForPromotionData(data),
      actorName: data['businessName']?.toString().trim().isNotEmpty == true
          ? data['businessName'].toString().trim()
          : null,
      businessName: data['businessName']?.toString(),
      actorPhotoUrl: data['businessLogoUrl']?.toString(),
    );
  }

  static ActivityFeedItem? fromAiGeneratedPostDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status != 'published') return null;

    final postType = data['postType']?.toString().toLowerCase() ?? '';
    if (postType != 'promotion') return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final title = data['title']?.toString().trim();
    if (title == null || title.isEmpty) return null;

    final pinnedAt = _parseDateTime(data['pinnedAt']);
    final highlightedAt = _parseDateTime(data['highlightedAt']);

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.business,
      title: title,
      subtitle: 'Promotion',
      body: data['generatedContent']?.toString() ??
          data['description']?.toString() ??
          '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      isPinned: data['isPinned'] == true,
      pinnedAt: pinnedAt,
      isHighlighted: data['isHighlighted'] == true,
      highlightedAt: highlightedAt,
      createdAt: createdAt,
      targetId: data['businessId']?.toString() ?? doc.id,
      promotionLabel: _promotionLabelForPromotionData(data),
      actorName: data['businessName']?.toString().trim().isNotEmpty == true
          ? data['businessName'].toString().trim()
          : null,
      businessName: data['businessName']?.toString(),
      actorPhotoUrl:
          data['businessLogoUrl']?.toString() ?? data['imageUrl']?.toString(),
    );
  }

  static ActivityFeedItem? fromVisitorPhotoDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    // Removed/rejected photos should not appear in the feed.
    final status = data['status']?.toString() ?? '';
    if (status == 'rejected') return null;
    if (data['deletedAt'] != null) return null;

    final createdAt = _parseDateTime(data['createdAt']);
    if (createdAt == null) return null;

    final visitorName = data['visitorName']?.toString().trim().isNotEmpty == true
        ? data['visitorName'].toString().trim()
        : 'Anonymous';
    final caption = data['caption']?.toString().trim();
    final businessId = data['businessId']?.toString();
    final eventId = data['eventId']?.toString();
    final targetId = businessId?.isNotEmpty == true
        ? businessId!
        : (eventId?.isNotEmpty == true ? eventId! : doc.id);

    return ActivityFeedItem(
      id: doc.id,
      type: ActivityFeedType.photo,
      title: visitorName,
      subtitle: 'shared a photo',
      body: caption ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      createdAt: createdAt,
      targetId: targetId,
      secondaryTargetId: data['visitorId']?.toString(),
      actorName: visitorName,
      businessName: data['businessName']?.toString().trim().isNotEmpty == true
          ? data['businessName'].toString().trim()
          : null,
    );
  }

  /// Extracts a suburb/neighbourhood from a comma-separated address string.
  static String? _extractSuburb(String? address) {
    final parts = (address ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length >= 3) return parts[parts.length - 2];
    if (parts.length == 2) return parts.first;
    return parts.first;
  }

  /// Interprets a price value as free vs paid for events.
  static bool? _parseIsFreeEntry(dynamic price) {
    if (price == null) return null;
    if (price is bool) return price;
    final text = price.toString().toLowerCase().trim();
    if (text.isEmpty) return null;
    if (text == 'free' || text == '0' || text.startsWith('\$0')) return true;
    if (text.startsWith('\$') ||
        RegExp(r'\d').hasMatch(text) && !text.contains('free')) {
      return false;
    }
    return null;
  }

  /// Derives a display label for promotions based on available metadata.
  static String? _promotionLabelForPromotionData(Map<String, dynamic> data) {
    final explicit = data['promotionLabel']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final endAt = (data['endAt'] as Timestamp?)?.toDate();
    final startAt = (data['startAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();

    if (endAt != null) {
      final hoursRemaining = endAt.difference(now).inHours;
      if (hoursRemaining >= 0 && hoursRemaining < 24) return 'Today Only';
      if (hoursRemaining >= 0 && hoursRemaining < 72) return 'Limited Time';
    }

    if (startAt != null) {
      final ageInDays = now.difference(startAt).inDays;
      if (ageInDays >= 0 && ageInDays <= 7) return 'New';
    }

    if (data['isFeatured'] == true || data['featured'] == true) {
      return 'Featured';
    }

    // Default active promotions to Featured so they stand out.
    return 'Featured';
  }
}
