class Event {
  final String id;
  final String title;
  final String date;
  final String time;
  final String venue;
  final String suburb;
  final String imageUrl;
  final String description;
  final List<String> categories;

  const Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    required this.suburb,
    required this.imageUrl,
    required this.description,
    required this.categories,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      venue: json['venue'] as String,
      suburb: json['suburb'] as String,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
      categories: List<String>.from(json['categories'] as List),
    );
  }
}
