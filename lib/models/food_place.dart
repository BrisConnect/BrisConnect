class FoodPlace {
  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final String suburb;
  final String imageUrl;
  final String snippet;
  final String mapQuery;
  final List<String> categories;
  final String aiAudio;

  const FoodPlace({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.suburb,
    required this.imageUrl,
    required this.snippet,
    required this.mapQuery,
    required this.categories,
    this.aiAudio = '',
  });

  factory FoodPlace.fromJson(Map<String, dynamic> json) {
    return FoodPlace(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      cuisine: (json['cuisine'] as String?) ?? 'Brisbane dining',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      suburb: (json['suburb'] as String?) ?? '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
      mapQuery: (json['mapQuery'] as String?) ?? '',
      categories: List<String>.from((json['categories'] as List?) ?? const []),
      aiAudio: (json['aiAudio'] as String?) ?? '',
    );
  }
}
