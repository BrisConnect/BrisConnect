const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'brisconnect-68b78',
  });
}

const db = admin.firestore();

async function seedTestReviews() {
  try {
    console.log('Fetching businesses...');
    
    // Get first few businesses to add reviews to
    const businessesSnapshot = await db.collection('businesses').limit(5).get();
    
    if (businessesSnapshot.empty) {
      console.log('No businesses found. Please add businesses first.');
      return;
    }

    const testReviews = [
      {
        rating: 5,
        comment: 'Amazing experience! Highly recommended. The staff was friendly and professional.',
        visitorName: 'Sarah M.'
      },
      {
        rating: 4,
        comment: 'Great place! Had a wonderful time. Would definitely come back again.',
        visitorName: 'John D.'
      },
      {
        rating: 5,
        comment: 'Fantastic! Exceeded all my expectations. Worth every penny!',
        visitorName: 'Emma L.'
      },
      {
        rating: 3,
        comment: 'Good, but could be better. Service was slow but friendly.',
        visitorName: 'Mike R.'
      },
      {
        rating: 4,
        comment: 'Really enjoyed my visit. Will definitely be back soon!',
        visitorName: 'Lisa W.'
      },
    ];

    let reviewsAdded = 0;

    // Add reviews to each business
    for (const businessDoc of businessesSnapshot.docs) {
      const businessId = businessDoc.id;
      console.log(`Adding reviews for business: ${businessDoc.data().businessName}`);

      // Add 2-3 reviews per business
      const reviewCount = Math.floor(Math.random() * 2) + 2;
      const selectedReviews = testReviews.sort(() => Math.random() - 0.5).slice(0, reviewCount);

      for (let i = 0; i < selectedReviews.length; i++) {
        const review = selectedReviews[i];
        const visitorId = `test-visitor-${businessId}-${i}`;
        
        const reviewData = {
          businessId: businessId,
          visitorId: visitorId,
          visitorName: review.visitorName,
          rating: review.rating,
          comment: review.comment,
          isReported: false,
          reportReason: null,
          createdAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000) // Random date in last 7 days
          ),
          updatedAt: admin.firestore.Timestamp.now(),
        };

        await db.collection('reviews').add(reviewData);
        reviewsAdded++;
        console.log(`  ✓ Added review by ${review.visitorName} (${review.rating} stars)`);
      }
    }

    console.log(`\n✅ Successfully added ${reviewsAdded} test reviews!`);
    process.exit(0);
  } catch (error) {
    console.error('Error seeding reviews:', error);
    process.exit(1);
  }
}

seedTestReviews();
