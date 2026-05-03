import 'package:cloud_firestore/cloud_firestore.dart';

class BrisbaneStory {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String content;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime? publishedAt;

  const BrisbaneStory({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.content,
    this.latitude,
    this.longitude,
    this.locationName,
    this.publishedAt,
  });

  factory BrisbaneStory.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BrisbaneStory(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      locationName: data['locationName'] as String?,
      publishedAt: _toDateTime(data['publishedAt']),
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class BrisbaneVoice {
  final String id;
  final String name;
  final String quote;
  final String profileImageUrl;

  const BrisbaneVoice({
    required this.id,
    required this.name,
    required this.quote,
    required this.profileImageUrl,
  });

  factory BrisbaneVoice.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BrisbaneVoice(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      quote: (data['quote'] as String?) ?? '',
      profileImageUrl: (data['profileImageUrl'] as String?) ?? '',
    );
  }
}

class BrisbaneStoriesService {
  BrisbaneStoriesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<BrisbaneStory>> watchApprovedStories() {
    return _firestore
        .collection('brisbane_stories')
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final stories = snapshot.docs.map(BrisbaneStory.fromDoc).toList();
      stories.sort((a, b) {
        final aDate = a.publishedAt ?? DateTime(2000);
        final bDate = b.publishedAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return stories;
    });
  }

  Stream<List<BrisbaneVoice>> watchVoices() {
    return _firestore
        .collection('brisbane_voices')
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BrisbaneVoice.fromDoc).toList());
  }

  Future<List<BrisbaneStory>> fetchStoriesByCategory(String category) async {
    final snapshot = await _firestore
        .collection('brisbane_stories')
        .where('approvalStatus', isEqualTo: 'approved')
        .where('category', isEqualTo: category)
        .get();
    return snapshot.docs.map(BrisbaneStory.fromDoc).toList();
  }
}
