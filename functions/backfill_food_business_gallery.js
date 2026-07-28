/**
 * Backfill photo galleries for existing food_businesses documents.
 * Uses the existing cover image plus Unsplash food photos as extra gallery items.
 *
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="../service-account-key.json"
 *   node backfill_food_business_gallery.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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

const foodPhotos = [
  'https://images.unsplash.com/photo-1504674900967-965ba998e5e2?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1551218808-94e220e084d2?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=800&h=600&fit=crop',
  'https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800&h=600&fit=crop',
];

function pickPhotos(seed, count = 4) {
  // Use the seed string to deterministically pick varied photos.
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash << 5) - hash + seed.charCodeAt(i);
    hash |= 0;
  }
  const picks = [];
  for (let i = 0; i < count; i++) {
    const index = Math.abs(hash + i) % foodPhotos.length;
    picks.push(foodPhotos[index]);
  }
  return picks;
}

async function backfillGalleries() {
  console.log('🖼️  Backfilling photo galleries for food_businesses...');
  const snapshot = await db.collection('food_businesses').get();
  let updated = 0;
  let skipped = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (Array.isArray(data.photoGallery) && data.photoGallery.length >= 3) {
      skipped += 1;
      continue;
    }

    const cover = (data.imageUrl || data.logoUrl || data.coverImageUrl || '').trim();
    const extras = pickPhotos(doc.id);
    const gallery = cover && !extras.includes(cover)
      ? [cover, ...extras]
      : extras;

    try {
      await doc.ref.update({ photoGallery: gallery });
      updated += 1;
      console.log(`✅ ${doc.id}: added ${gallery.length} gallery photos`);
    } catch (error) {
      errors += 1;
      console.error(`❌ ${doc.id}: ${error.message}`);
    }
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Errors: ${errors}`);
}

backfillGalleries()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exit(1);
  });
