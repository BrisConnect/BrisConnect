/// Provides category-aware fallback images for venue cards so that
/// different venue types show relevant, distinct placeholder images instead
/// of a single generic Brisbane photo.
class VenueImageFallback {
  VenueImageFallback._();

  // ── image pools per venue category ──────────────────────────────────

  static const _stadiumImages = [
    'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1577223625816-7546f13df25d?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1531415074968-036ba1b575da?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1487466365202-1afdb86c764e?auto=format&fit=crop&w=800&q=80',
  ];

  static const _cinemaImages = [
    'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1595769816263-9b910be24d5f?auto=format&fit=crop&w=800&q=80',
  ];

  static const _foodImages = [
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1539136788836-5699e78bfc75?auto=format&fit=crop&w=800&q=80',
  ];

  static const _eventImages = [
    'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?auto=format&fit=crop&w=800&q=80',
  ];

  static const _parkImages = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1588392382834-a891154bca4d?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?auto=format&fit=crop&w=800&q=80',
  ];

  static const _museumImages = [
    'https://images.unsplash.com/photo-1568992687947-868a62a9f521?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&q=80',
  ];

  static const _defaultImages = [
    'https://images.unsplash.com/photo-1472653431158-6364773b2a56?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1566734904496-9309bb1798ae?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1487466365202-1afdb86c764e?auto=format&fit=crop&w=800&q=80',
  ];

  /// Returns a category-appropriate image URL selected deterministically
  /// from the venue title so that different venues show different images.
  static String forVenue({
    String? title,
    String? section,
    String? badge,
  }) {
    final t = (title ?? '').toLowerCase();
    final s = (section ?? '').toLowerCase();

    List<String> pool;

    if (_matchesAny(t, ['cinema', 'movie', 'film', 'theater', 'theatre'])) {
      pool = _cinemaImages;
    } else if (s == 'stadiums' ||
        _matchesAny(t, ['stadium', 'arena', 'oval', 'ground'])) {
      pool = _stadiumImages;
    } else if (s == 'food' ||
        _matchesAny(t, [
          'restaurant',
          'cafe',
          'dining',
          'food',
          'eat',
          'kitchen',
          'bar',
          'bistro',
        ])) {
      pool = _foodImages;
    } else if (_matchesAny(t, ['park', 'garden', 'botanic', 'reserve'])) {
      pool = _parkImages;
    } else if (s == 'historical' ||
        _matchesAny(t, ['museum', 'gallery', 'heritage', 'hall', 'library'])) {
      pool = _museumImages;
    } else if (s == 'events') {
      pool = _eventImages;
    } else {
      pool = _defaultImages;
    }

    // Use title hashCode to deterministically pick from the pool so the
    // same venue always gets the same image, but different venues get
    // different images.
    final hash = (title ?? '').hashCode;
    return pool[hash.abs() % pool.length];
  }

  /// Convenience for Map-based items from Firestore.
  static String forItem(Map<String, dynamic> item) {
    return forVenue(
      title: item['title'] as String? ?? item['name'] as String?,
      section: item['section'] as String?,
      badge: item['badge'] as String?,
    );
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}
