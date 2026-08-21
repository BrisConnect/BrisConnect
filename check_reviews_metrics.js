const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkReviews() {
  try {
    // Get businesses for the owner
    const businessesSnap = await db.collection('businesses')
      .where('ownerId', '==', 'brisconnect0@gmail.com')
      .get();
    
    console.log('Businesses found:', businessesSnap.size);
    
    for (const doc of businessesSnap.docs) {
      const businessId = doc.id;
      const businessName = doc.data().name || 'Unnamed';
      
      // Check all reviews
      const allReviews = await db.collection('reviews')
        .where('businessId', '==', businessId)
        .get();
      
      // Check visible reviews
      const visibleReviews = await db.collection('reviews')
        .where('businessId', '==', businessId)
        .where('visible', '==', true)
        .get();
      
      console.log(`\n📍 Business: ${businessName} (${businessId})`);
      console.log(`   Total reviews: ${allReviews.size}`);
      console.log(`   Visible reviews: ${visibleReviews.size}`);
      
      if (visibleReviews.size > 0) {
        let totalRating = 0;
        let totalBuzz = 0;
        let buzzCount = 0;
        
        visibleReviews.docs.forEach(doc => {
          const data = doc.data();
          totalRating += (data.rating || 0);
          const buzz = data.buzzRating || 0;
          if (buzz > 0) {
            totalBuzz += buzz;
            buzzCount++;
          }
        });
        const avgRating = (totalRating / visibleReviews.size).toFixed(2);
        const avgBuzz = buzzCount > 0 ? (totalBuzz / buzzCount).toFixed(2) : 0;
        console.log(`   Average rating: ${avgRating}`);
        console.log(`   Average buzz: ${avgBuzz}`);
        console.log(`   Buzz votes: ${buzzCount}`);
        
        // Show sample reviews
        console.log(`   Sample reviews:`);
        visibleReviews.docs.slice(0, 3).forEach((doc, idx) => {
          const data = doc.data();
          const createdAt = data.createdAt?.toDate?.() || data.createdAt || 'N/A';
          console.log(`     ${idx + 1}. Rating: ${data.rating}, Buzz: ${data.buzzRating}, Created: ${createdAt}`);
        });
      }
    }
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkReviews();
