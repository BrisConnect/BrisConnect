/**
 * Backfill contact and operating-hour details for food_businesses documents.
 *
 * For each food_businesses document that has a googlePlaceId, this script
 * calls the Google Places Details API and writes any available fields back
 * to Firestore:
 *   - phone              (formatted_phone_number)
 *   - website
 *   - openingHours       (weekday_text joined with newlines)
 *   - googleMapsUrl      (the official Google Maps listing URL)
 *
 * Usage:
 *   cd functions
 *   GOOGLE_PLACES_API_KEY=YOUR_KEY node backfill_food_business_details.js
 */

const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../service-account-key.json');
const API_KEY = process.env.GOOGLE_PLACES_API_KEY;

if (!API_KEY) {
  console.error('❌ Please set the GOOGLE_PLACES_API_KEY environment variable.');
  console.error('   Example: GOOGLE_PLACES_API_KEY=YOUR_KEY node backfill_food_business_details.js');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

function makeRequest(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on('error', reject);
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchPlaceDetails(placeId) {
  const fields = [
    'formatted_phone_number',
    'website',
    'opening_hours',
    'url',
  ].join(',');
  const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=${fields}&key=${API_KEY}`;
  const result = await makeRequest(url);
  return result.result || {};
}

async function processDocument(doc) {
  const data = doc.data();
  const placeId = data.googlePlaceId;

  if (!placeId) {
    return { skipped: true, reason: 'no googlePlaceId' };
  }

  const details = await fetchPlaceDetails(placeId);
  const update = {};

  if (details.formatted_phone_number) {
    update.phone = details.formatted_phone_number;
  }
  if (details.website) {
    update.website = details.website;
  }
  if (details.opening_hours && Array.isArray(details.opening_hours.weekday_text)) {
    update.openingHours = details.opening_hours.weekday_text.join('\n');
  }
  if (details.url) {
    update.googleMapsUrl = details.url;
  }

  if (Object.keys(update).length === 0) {
    return { skipped: true, reason: 'no new data from Places' };
  }

  await doc.ref.update(update);
  return { success: true, fields: Object.keys(update) };
}

async function main() {
  try {
    const snapshot = await db.collection('food_businesses').get();
    console.log(`Found ${snapshot.size} food business documents\n`);

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      const name = doc.data().name || doc.id;
      try {
        const result = await processDocument(doc);
        if (result.success) {
          updated++;
          console.log(`✅ ${name} (${result.fields.join(', ')})`);
        } else {
          skipped++;
          console.log(`⏭️  ${name}: ${result.reason}`);
        }
      } catch (error) {
        failed++;
        console.error(`❌ ${name}: ${error.message}`);
      }

      // Stay well within the Google Places API rate limits.
      await delay(200);
    }

    console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
    process.exit(0);
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

main();
