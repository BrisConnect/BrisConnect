const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'brisconnect-68b78',
});

const db = admin.firestore();

async function check() {
  const collections = ['businesses', 'food_businesses'];
  for (const coll of collections) {
    console.log(`\n=== ${coll} ===`);
    const snapshot = await db.collection(coll).get();
    console.log(`Total docs: ${snapshot.size}`);
    const missing = [];
    const nestedOnly = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const topLat = data.latitude ?? data.lat ?? null;
      const topLng = data.longitude ?? data.lng ?? null;
      const nestedLat = data.coordinates?.latitude ?? null;
      const nestedLng = data.coordinates?.longitude ?? null;
      const hasTop = typeof topLat === 'number' && typeof topLng === 'number';
      const hasNested = typeof nestedLat === 'number' && typeof nestedLng === 'number';

      if (!hasTop && !hasNested) {
        missing.push({
          id: doc.id,
          name: data.businessName || data.name || '(unnamed)',
          address: data.address || '(no address)',
          latitude: null,
          longitude: null,
          collection: coll,
        });
      } else if (!hasTop && hasNested) {
        nestedOnly.push({
          id: doc.id,
          name: data.businessName || data.name || '(unnamed)',
          address: data.address || '(no address)',
          latitude: nestedLat,
          longitude: nestedLng,
          collection: coll,
        });
      }
    });
    if (nestedOnly.length > 0) {
      console.log(`Coordinates only nested under 'coordinates' in ${nestedOnly.length} documents (sample):`);
      nestedOnly.slice(0, 5).forEach(m => console.log(`  - ${m.name} (${m.id}): lat=${m.latitude}, lng=${m.longitude}`));
    }
    if (missing.length === 0) {
      console.log('All documents have top-level or nested coordinates.');
    } else {
      console.log(`Missing coordinates entirely in ${missing.length} documents:`);
      missing.slice(0, 10).forEach(m => console.log(`  - ${m.name} (${m.id}): addr=${m.address}`));
    }
  }
  process.exit(0);
}

check().catch(e => {
  console.error(e);
  process.exit(1);
});
