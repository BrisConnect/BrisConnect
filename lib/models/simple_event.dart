class SimpleEvent {
  final String title;
  final String date;
  final String location;
  final String description;
  final bool isApproved;
  final double lat;
  final double lng;

  const SimpleEvent({
    required this.title,
    required this.date,
    required this.location,
    required this.description,
    required this.isApproved,
    required this.lat,
    required this.lng,
  });
}