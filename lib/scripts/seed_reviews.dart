import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await seedTestReviews();
}

Future<void> seedTestReviews() async {
  final db = FirebaseFirestore.instance;

  try {
    print('Fetching businesses...');
    final businessesSnapshot = await db.collection('businesses').limit(5).get();

    if (businessesSnapshot.docs.isEmpty) {
      print('❌ No businesses found. Please add businesses first.');
      return;
    }

    final testReviews = [
      {
        'rating': 5,
        'comment': 'Amazing experience! Highly recommended. The staff was friendly and professional.',
        'visitorName': 'Sarah M.'
      },
      {
        'rating': 4,
        'comment': 'Great place! Had a wonderful time. Would definitely come back again.',
        'visitorName': 'John D.'
      },
      {
        'rating': 5,
        'comment': 'Fantastic! Exceeded all my expectations. Worth every penny!',
        'visitorName': 'Emma L.'
      },
      {
        'rating': 3,
        'comment': 'Good, but could be better. Service was slow but friendly.',
        'visitorName': 'Mike R.'
      },
      {
        'rating': 4,
        'comment': 'Really enjoyed my visit. Will definitely be back soon!',
        'visitorName': 'Lisa W.'
      },
    ];

    int reviewsAdded = 0;

    // Add reviews to each business
    for (final businessDoc in businessesSnapshot.docs) {
      final businessId = businessDoc.id;
      final businessName = businessDoc['businessName'] as String? ?? 'Unknown';
      print('Adding reviews for business: $businessName');

      // Add 2-3 reviews per business
      final reviewCount = (DateTime.now().millisecondsSinceEpoch % 2) + 2;
      final selectedReviews = (testReviews.toList()..shuffle()).take(reviewCount).toList();

      for (int i = 0; i < selectedReviews.length; i++) {
        final review = selectedReviews[i];
        final visitorId = 'test-visitor-$businessId-$i';

        final reviewData = {
          'businessId': businessId,
          'visitorId': visitorId,
          'visitorName': review['visitorName'],
          'rating': review['rating'],
          'comment': review['comment'],
          'isReported': false,
          'reportReason': null,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        await db.collection('reviews').add(reviewData);
        reviewsAdded++;
        print('  ✓ Added review by ${review['visitorName']} (${review['rating']} stars)');
      }
    }

    print('\n✅ Successfully added $reviewsAdded test reviews!');
  } catch (e) {
    print('❌ Error seeding reviews: $e');
  }
}
