const admin = require('firebase-admin');

const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'brisconnect-68b78',
});

const db = admin.firestore();

// Map cuisine types to reliable, openly-licensed placeholder images.
// These are from picsum.photos and placehold.co which are stable.
const cuisineImages = {
  default: 'https://picsum.photos/seed/restaurant/500/500',
  steakhouse: 'https://picsum.photos/seed/steak/500/500',
  australian: 'https://picsum.photos/seed/aussie/500/500',
  seafood: 'https://picsum.photos/seed/seafood/500/500',
  chinese: 'https://picsum.photos/seed/chinese/500/500',
  japanese: 'https://picsum.photos/seed/sushi/500/500',
  thai: 'https://picsum.photos/seed/thai/500/500',
  vietnamese: 'https://picsum.photos/seed/pho/500/500',
  korean: 'https://picsum.photos/seed/kbbq/500/500',
  indian: 'https://picsum.photos/seed/curry/500/500',
  italian: 'https://picsum.photos/seed/pizza/500/500',
  mexican: 'https://picsum.photos/seed/tacos/500/500',
  cafe: 'https://picsum.photos/seed/cafe/500/500',
  bakery: 'https://picsum.photos/seed/bakery/500/500',
  bar: 'https://picsum.photos/seed/bar/500/500',
  dessert: 'https://picsum.photos/seed/dessert/500/500',
};

function pickImageUrl(cuisineTypes) {
  if (Array.isArray(cuisineTypes) && cuisineTypes.length > 0) {
    const first = cuisineTypes[0].toString().toLowerCase();
    if (cuisineImages[first]) return cuisineImages[first];
    for (const type of cuisineTypes) {
      const key = type.toString().toLowerCase();
      if (cuisineImages[key]) return cuisineImages[key];
    }
  }
  return cuisineImages.default;
}

async function seedImages() {
  try {
    const snapshot = await db.collection('food_businesses').get();
    console.log(`Found ${snapshot.size} food business documents`);

    let updated = 0;
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const existing =
        (data.imageUrl || '').trim() ||
        (data.logoUrl || '').trim() ||
        (data.coverImageUrl || '').trim();

      // Skip documents that already have a non-unsplash image URL.
      if (existing && !existing.includes('images.unsplash.com')) {
        continue;
      }

      const imageUrl = pickImageUrl(data.cuisineTypes);
      await doc.ref.update({
        imageUrl,
        logoUrl: data.logoUrl || imageUrl,
        coverImageUrl: data.coverImageUrl || imageUrl,
      });
      updated++;
      console.log(`Updated ${data.name || doc.id}: ${imageUrl}`);
    }

    console.log(`✅ Updated ${updated} food business images`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding images:', error);
    process.exit(1);
  }
}

seedImages();
