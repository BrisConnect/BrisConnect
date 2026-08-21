/**
 * Mark existing food_businesses as Google Listings for testing
 * This sets isGoogleListing: true on businesses to test the feature
 * 
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="../service-account-key.json"
 *   node mark_google_listings.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
  path.join(__dirname, '../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found at:', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function markGoogleListings() {
  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║  MARK BUSINESSES AS GOOGLE LISTINGS - Testing                   ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  try {
    // Get first 10 food_businesses
    const snapshot = await db.collection('food_businesses').limit(10).get();

    if (snapshot.empty) {
      console.log('❌ No businesses found in food_businesses collection');
      process.exit(1);
    }

    console.log(`📊 Found ${snapshot.size} businesses to mark as Google Listings\n`);

    let updated = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      try {
        const data = doc.data();
        
        await db.collection('food_businesses').doc(doc.id).update({
          isGoogleListing: true,
          sourceProvider: 'google_places',
          googlePlaceId: `test_${doc.id}`,
        });

        console.log(`✅ [${updated + 1}/${snapshot.size}] ${data.name || doc.id}`);
        updated++;
      } catch (error) {
        console.log(`❌ Error updating ${doc.id}: ${error.message}`);
        failed++;
      }
    }

    console.log(`\n================================================================`);
    console.log(`✅ Updated: ${updated} businesses`);
    console.log(`❌ Failed: ${failed} businesses`);
    console.log(`================================================================\n`);

    if (updated > 0) {
      console.log('🎯 Test with these businesses - they now have isGoogleListing: true');
      console.log('⚠️  Reviews and crowd reports should be disabled for these listings\n');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

markGoogleListings();
