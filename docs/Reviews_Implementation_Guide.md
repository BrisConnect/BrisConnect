# Implementation Guide - Reviews & Ratings Integration

## Quick Start

### Step 1: Add Dependencies
All required dependencies are already in `pubspec.yaml`:
- `cloud_firestore: ^4.11.0`
- `firebase_auth: ^4.10.0`
- `intl: ^0.19.0`

### Step 2: Initialize ReviewService
The `ReviewService` is stateless and can be instantiated anywhere:

```dart
final reviewService = ReviewService();
```

### Step 3: Integrate into Business Profile Detail Screen

Update `lib/screens/business_profile_detail_screen.dart`:

#### Add Import
```dart
import 'package:brisconnect/widgets/submit_review_bottom_sheet.dart';
import 'package:brisconnect/widgets/reviews_display_widget.dart';
import 'package:brisconnect/services/review_service.dart';
```

#### Add Review Button to AppBar or Action Bar
```dart
class BusinessProfileDetailScreen extends StatefulWidget {
  final String businessId;
  
  // ... existing code ...
}

class _BusinessProfileDetailScreenState extends State<BusinessProfileDetailScreen> {
  final ReviewService _reviewService = ReviewService();

  void _showReviewSubmitSheet() async {
    // Get current user info (from auth provider or widget)
    final user = getCurrentUser(); // Your auth method
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave a review')),
      );
      return;
    }

    // Check if user already reviewed
    final hasReviewed = await _reviewService.hasVisitorReviewedBusiness(
      widget.businessId,
      user.uid,
    );

    if (hasReviewed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reviewed this business')),
      );
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SubmitReviewBottomSheet(
          businessId: widget.businessId,
          visitorId: user.uid,
          visitorName: user.displayName ?? 'Anonymous',
          onReviewSubmitted: (reviewId) {
            // Optional: Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thank you for your review!')),
            );
            // Reviews will auto-update via stream in ReviewsDisplayWidget
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(businessName),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review),
            tooltip: 'Leave a Review',
            onPressed: _showReviewSubmitSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... existing business details (logo, hours, etc.) ...

            const Divider(height: 32),

            // Add Reviews Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: ReviewsDisplayWidget(
                businessId: widget.businessId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 4: Update Average Rating Display

Add to business card or header:

```dart
StreamBuilder<double>(
  stream: reviewService.getAverageRatingStream(businessId),
  builder: (context, snapshot) {
    final rating = snapshot.data ?? 0.0;
    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.orange,
            size: 16,
          );
        }),
        const SizedBox(width: 8),
        Text('${rating.toStringAsFixed(1)}/5'),
      ],
    );
  },
)
```

### Step 5: Update Business Model (Optional)

To cache average rating in the business document:

```dart
// In business.dart
class Business {
  // ... existing fields ...
  final double averageRating; // Add this
  final int reviewCount;      // Add this

  // Update toFirestore() to include:
  'averageRating': averageRating,
  'reviewCount': reviewCount,

  // Update fromFirestore() to extract:
  averageRating: data['averageRating'] ?? 0.0,
  reviewCount: data['reviewCount'] ?? 0,
}
```

## Advanced Usage

### Getting Review Statistics

```dart
Future<void> showReviewStats(String businessId) async {
  final average = await reviewService.getAverageRating(businessId);
  final count = await reviewService.getReviewCount(businessId);
  
  print('Average: $average, Count: $count');
}
```

### Handling One Review Per User

```dart
bool hasReviewedAlready = await reviewService.hasVisitorReviewedBusiness(
  businessId,
  userId,
);

if (hasReviewedAlready) {
  // Show "Edit Review" instead of "Leave Review"
}
```

### Admin Dashboard - View Reported Reviews

```dart
Future<void> loadReportedReviews() async {
  final reportedReviews = await reviewService.getReportedReviews();
  
  for (final review in reportedReviews) {
    print('Review: ${review.id}');
    print('Reason: ${review.reportReason}');
    print('Reported At: ${review.updatedAt}');
  }
}
```

## Firestore Queries Explained

### Query 1: Get Reviews for a Business
```dart
db.collection('reviews')
  .where('businessId', '==', businessId)
  .where('isReported', '==', false)
  .orderBy('createdAt', descending: true)
```
- Uses index: `businessId` + `isReported` + `createdAt`
- Returns: All non-reported reviews, newest first

### Query 2: Calculate Average Rating
```dart
db.collection('reviews')
  .where('businessId', '==', businessId)
  .where('isReported', '==', false)
  .get()
```
- Aggregates: Sums rating, divides by count
- Cost: 1 read per document

### Query 3: Check If User Reviewed
```dart
db.collection('reviews')
  .where('businessId', '==', businessId)
  .where('visitorId', '==', userId)
  .limit(1)
  .get()
```
- Returns: First review found or empty
- Optimization: Uses `.limit(1)` to minimize cost

## Error Handling

```dart
try {
  final reviewId = await reviewService.createReview(
    businessId: businessId,
    visitorId: userId,
    visitorName: userName,
    rating: rating,
    comment: comment,
  );
  print('Review created: $reviewId');
} on FirebaseException catch (e) {
  print('Firebase error: ${e.code}');
  print('Message: ${e.message}');
} catch (e) {
  print('Error: $e');
}
```

## Performance Optimization

1. **Use Streams for Real-time**: Don't poll, use streams
   ```dart
   reviewService.getBusinessReviewsStream(businessId)
   ```

2. **Limit Query Results**: Show paginated results
   ```dart
   query.limit(10).startAfter(lastDocument)
   ```

3. **Cache Ratings**: Consider caching average rating in Business document
   - Updated via Cloud Functions on review changes
   - Reduces query cost for popular businesses

4. **Batch Operations**: Use transactions for consistency
   ```dart
   db.runTransaction((transaction) async {
     // Multiple operations
   });
   ```

## Deployment Steps

1. **Deploy Firestore Indexes:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Deploy Security Rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Test in Firebase Emulator (Local Development):**
   ```bash
   firebase emulators:start
   ```

4. **Monitor in Firebase Console:**
   - Go to Firestore Database → Operations
   - Check "Realtime Database Audit Logs"
   - Monitor for quota usage

## Troubleshooting

### Issue: "Missing or insufficient permissions"
**Cause**: Security rules blocking access
**Solution**: Check firestore.rules - ensure user is authenticated

### Issue: "No index found for this query"
**Cause**: Index not deployed
**Solution**: Run `firebase deploy --only firestore:indexes`

### Issue: Reviews appear with delay
**Cause**: Firestore eventual consistency
**Solution**: This is normal - usually <1 second

### Issue: Can't create review
**Cause**: User limit or permission issue
**Solution**: Check `ReviewService.createReview()` validation

## Testing in Emulator

```dart
// In test_setup.dart
setUp(() {
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
});

test('Create review', () async {
  final reviewId = await reviewService.createReview(
    businessId: 'test-business',
    visitorId: 'test-visitor',
    visitorName: 'Test User',
    rating: 5,
    comment: 'Great business!',
  );
  expect(reviewId, isNotEmpty);
});
```
