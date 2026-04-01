class StadiumVenue {
  final String id;
  final String name;
  final String badge;
  final String dateTime;
  final String price;
  final String location;
  final String imageUrl;
  final String description;
  final String mapQuery;
  final String webLink;
  final List<String> categories;
  final String aiAudio;

  const StadiumVenue({
    required this.id,
    required this.name,
    required this.badge,
    required this.dateTime,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.description,
    required this.mapQuery,
    required this.webLink,
    required this.categories,
    this.aiAudio = '',
  });

  factory StadiumVenue.fromJson(Map<String, dynamic> json) {
    return StadiumVenue(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      badge: (json['badge'] as String?) ?? 'Stadium',
      dateTime: (json['dateTime'] as String?) ?? '',
      price: (json['price'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      mapQuery: (json['mapQuery'] as String?) ?? '',
      webLink: (json['webLink'] as String?) ?? '',
      categories: List<String>.from((json['categories'] as List?) ?? const []),
      aiAudio: (json['aiAudio'] as String?) ?? '',
    );
  }
}
