class Event {
  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String address;
  final double? latitude;
  final double? longitude;
  final String category;
  final String imageUrl;
  final double price;
  final String currency;
  final int capacity;
  final int registeredAttendees;
  final String organizer;
  final String organizerEmail;
  final String organizerPhone;
  final List<String> tags;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.address,
    this.latitude,
    this.longitude,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.currency,
    required this.capacity,
    required this.registeredAttendees,
    required this.organizer,
    required this.organizerEmail,
    required this.organizerPhone,
    required this.tags,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      location: json['location'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      category: json['category'],
      imageUrl: json['image_url'] ?? '',
      price: json['price']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'AUD',
      capacity: json['capacity'] ?? 0,
      registeredAttendees: json['registered_attendees'] ?? 0,
      organizer: json['organizer'],
      organizerEmail: json['organizer_email'],
      organizerPhone: json['organizer_phone'],
      tags: List<String>.from(json['tags'] ?? []),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'location': location,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'image_url': imageUrl,
      'price': price,
      'currency': currency,
      'capacity': capacity,
      'registered_attendees': registeredAttendees,
      'organizer': organizer,
      'organizer_email': organizerEmail,
      'organizer_phone': organizerPhone,
      'tags': tags,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isFree => price == 0;
  bool get isFullyBooked => registeredAttendees >= capacity;
  int get availableSpots => capacity - registeredAttendees;
  double get attendanceRate => capacity > 0 ? (registeredAttendees / capacity) * 100 : 0;
}