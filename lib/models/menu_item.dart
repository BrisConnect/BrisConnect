/// A single item on a business menu.
///
/// Backwards compatible with plain string menu items stored in older
/// Firestore documents.
class MenuItem {
  final String name;
  final String? description;
  final double? price;
  final String? imageUrl;
  final List<String> tags; // e.g. 'Popular', 'Chef Recommendation'

  const MenuItem({
    required this.name,
    this.description,
    this.price,
    this.imageUrl,
    this.tags = const [],
  });

  factory MenuItem.fromDynamic(dynamic value) {
    if (value is String) {
      return MenuItem(name: value);
    }
    if (value is Map<String, dynamic>) {
      return MenuItem.fromFirestore(value);
    }
    return const MenuItem(name: '');
  }

  factory MenuItem.fromFirestore(Map<String, dynamic> data) {
    return MenuItem(
      name: (data['name'] ?? '').toString(),
      description: data['description']?.toString(),
      price: (data['price'] as num?)?.toDouble(),
      imageUrl: data['imageUrl']?.toString(),
      tags: data['tags'] is List
          ? (data['tags'] as List).whereType<String>().toList()
          : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (price != null) 'price': price,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  String get formattedPrice {
    if (price == null) return '';
    return '\$${price!.toStringAsFixed(price! == price!.roundToDouble() ? 0 : 2)}';
  }

  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? tags,
  }) {
    return MenuItem(
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
    );
  }
}
