/**
 * Backfill top-level latitude/longitude on food_businesses documents.
 *
 * Many Google-Places-seeded documents store coordinates as:
 *   coordinates: { latitude: ..., longitude: ... }
 * but the Flutter app reads top-level fields. This script copies nested
 * coordinates to the top level and reports documents that still cannot be
 * geocoded.
 */
const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function backfill() {
  const snapshot = await db.collection('food_businesses').get();
  let updated = 0;
  let alreadyOk = 0;
  let stillMissing = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const topLat = data.latitude ?? data.lat ?? null;
    const topLng = data.longitude ?? data.lng ?? null;
    const nestedLat = data.coordinates?.latitude ?? null;
    const nestedLng = data.coordinates?.longitude ?? null;

    const hasTop = typeof topLat === 'number' && typeof topLng === 'number';
    const hasNested = typeof nestedLat === 'number' && typeof nestedLng === 'number';

    if (hasTop) {
      alreadyOk++;
      continue;
    }

    if (hasNested) {
      await doc.ref.update({
        latitude: nestedLat,
        longitude: nestedLng,
      });
      updated++;
      continue;
    }

    stillMissing.push({
      id: doc.id,
      name: data.businessName || data.name || '(unnamed)',
      address: data.address || '(no address)',
    });
  }

  console.log(`Total food_businesses docs: ${snapshot.size}`);
  console.log(`Already had top-level coords: ${alreadyOk}`);
  console.log(`Backfilled from nested coords: ${updated}`);
  console.log(`Still missing coords: ${stillMissing.length}`);
  if (stillMissing.length > 0) {
    console.log('Documents still missing coordinates:');
    stillMissing.forEach(m => console.log(`  - ${m.name} (${m.id}): ${m.address}`));
  }
  process.exit(0);
}

backfill().catch(e => {
  console.error(e);
  process.exit(1);
});
