class HistoricalSight {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final String description;
  final List<String> categories;

  const HistoricalSight({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.description,
    required this.categories,
  });

  factory HistoricalSight.fromJson(Map<String, dynamic> json) {
    return HistoricalSight(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
      categories: List<String>.from(json['categories'] as List),
    );
  }
}
