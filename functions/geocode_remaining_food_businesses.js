/**
 * Geocode food_businesses documents that have addresses but no coordinates.
 * Uses Google Places Text Search API and writes top-level latitude/longitude.
 */
const admin = require('firebase-admin');
const https = require('https');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();
const API_KEY = 'AIzaSyCgEZo0LJD6ksf9Vfe8owyGm22xYygW8ps';

function makeRequest(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function geocodeAddress(address) {
  const query = encodeURIComponent(address);
  const url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${query}&key=${API_KEY}`;
  const result = await makeRequest(url);
  if (result.results?.length > 0) {
    const loc = result.results[0].geometry.location;
    return { lat: loc.lat, lng: loc.lng };
  }
  return null;
}

async function backfillMissing() {
  const snapshot = await db.collection('food_businesses').get();
  let updated = 0;
  let stillMissing = [];
  let errors = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const topLat = data.latitude ?? data.lat ?? null;
    const topLng = data.longitude ?? data.lng ?? null;
    const nestedLat = data.coordinates?.latitude ?? null;
    const nestedLng = data.coordinates?.longitude ?? null;

    const hasCoords = (typeof topLat === 'number' && typeof topLng === 'number') ||
                      (typeof nestedLat === 'number' && typeof nestedLng === 'number');
    if (hasCoords) continue;

    const address = data.address;
    if (!address) {
      stillMissing.push({ id: doc.id, name: data.name, reason: 'no address' });
      continue;
    }

    try {
      const coords = await geocodeAddress(address);
      if (coords) {
        await doc.ref.update({
          latitude: coords.lat,
          longitude: coords.lng,
        });
        updated++;
        console.log(`Updated ${data.name || doc.id}: ${coords.lat}, ${coords.lng}`);
      } else {
        stillMissing.push({ id: doc.id, name: data.name, address, reason: 'geocode returned no results' });
      }
    } catch (e) {
      errors.push({ id: doc.id, name: data.name, error: e.message });
    }
  }

  console.log(`\nUpdated: ${updated}`);
  console.log(`Still missing: ${stillMissing.length}`);
  if (stillMissing.length > 0) {
    stillMissing.forEach(m => console.log(`  - ${m.name || m.id}: ${m.reason} (${m.address || 'no address'})`));
  }
  if (errors.length > 0) {
    console.log(`Errors: ${errors.length}`);
    errors.forEach(e => console.log(`  - ${e.name || e.id}: ${e.error}`));
  }
  process.exit(0);
}

backfillMissing().catch(e => {
  console.error(e);
  process.exit(1);
});
