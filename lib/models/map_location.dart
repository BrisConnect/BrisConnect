enum MapLocationCategory { food }

class MapLocation {
  final String id;
  final String title;
  final String description;
  final String address;
  final double lat;
  final double lng;
  final MapLocationCategory category;

  /// Optional network image URL shown in the detail bottom-sheet.
  final String? imageUrl;

  const MapLocation({
    required this.id,
    required this.title,
    required this.description,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.imageUrl,
  });

  String get categoryLabel {
    switch (category) {
      case MapLocationCategory.food:
        return 'Food';
    }
  }
}
