/**
 * Fetch real business photos from Google Places and upload to Firebase Storage.
 *
 * For each food_businesses document, this script:
 *   1. Searches Google Places Text Search by business name + address
 *   2. Downloads the first available business photo
 *   3. Uploads the photo to Firebase Storage
 *   4. Updates the Firestore document with the Firebase Storage URL
 *
 * Usage:
 *   cd functions
 *   node seed_food_business_real_images.js
 */

const admin = require('firebase-admin');
const https = require('https');
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const serviceAccount = require('../service-account-key.json');
const API_KEY = process.env.GOOGLE_PLACES_API_KEY;

if (!API_KEY) {
  console.error('❌ Please set the GOOGLE_PLACES_API_KEY environment variable.');
  console.error('   Example: GOOGLE_PLACES_API_KEY=YOUR_KEY node seed_food_business_real_images.js');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
  storageBucket: 'brisconnect-68b78.firebasestorage.app',
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

function downloadBuffer(url, maxRedirects = 5) {
  return new Promise((resolve, reject) => {
    if (maxRedirects <= 0) {
      reject(new Error('Too many redirects'));
      return;
    }

    https
      .get(url, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          const redirectUrl = new URL(res.headers.location, url).toString();
          resolve(downloadBuffer(redirectUrl, maxRedirects - 1));
          return;
        }
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode}`));
          return;
        }
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve(Buffer.concat(chunks)));
      })
      .on('error', reject);
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Build a public Firebase Storage download URL using a download token.
 */
function buildStorageUrl(bucketName, filePath, token) {
  const encodedPath = encodeURIComponent(filePath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;
}

async function uploadImage(buffer, destination, contentType) {
  const token = require('crypto').randomUUID();
  const file = bucket.file(destination);

  await file.save(buffer, {
    metadata: {
      contentType,
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    },
    resumable: false,
  });

  await file.makePublic().catch(() => {
    // Public access may already be enabled; ignore failures.
  });

  return buildStorageUrl(bucket.name, destination, token);
}

async function findPlace(business) {
  const name = business.name || '';
  if (!name.trim()) return null;

  const query = `${name} Brisbane QLD Australia`;
  const url = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
  url.searchParams.set('query', query);
  url.searchParams.set('key', API_KEY);
  url.searchParams.set('region', 'au');

  const result = await makeRequest(url.toString());
  if (!result.results || result.results.length === 0) return null;

  // Pick the result whose name is most similar to the business name.
  const lowerName = name.toLowerCase();
  const scored = result.results.map((place) => {
    const placeName = (place.name || '').toLowerCase();
    let score = 0;
    if (placeName === lowerName) score += 100;
    if (placeName.includes(lowerName) || lowerName.includes(placeName)) score += 50;
    if (place.photos && place.photos.length > 0) score += 25;
    return { place, score };
  });

  scored.sort((a, b) => b.score - a.score);
  return scored[0].place;
}

async function fetchPhotoUrl(photoReference, maxWidth = 800) {
  const url = new URL('https://maps.googleapis.com/maps/api/place/photo');
  url.searchParams.set('photoreference', photoReference);
  url.searchParams.set('maxwidth', maxWidth.toString());
  url.searchParams.set('key', API_KEY);
  return url.toString();
}

async function processDocument(doc) {
  const data = doc.data();
  const name = data.name || data.businessName || 'unknown';

  // Skip if already has a real (non-placeholder, non-unsplash) image URL.
  const existing = (data.imageUrl || '').trim();
  if (
    existing &&
    !existing.includes('images.unsplash.com') &&
    !existing.includes('picsum.photos') &&
    !existing.includes('placehold.co')
  ) {
    return { skipped: true, name, reason: 'already has real image' };
  }

  const place = await findPlace(data);
  if (!place) {
    return { skipped: true, name, reason: 'no Google Places match' };
  }

  if (!place.photos || place.photos.length === 0) {
    return { skipped: true, name, reason: 'no photos in Places result' };
  }

  const photoReference = place.photos[0].photo_reference;
  const photoUrl = await fetchPhotoUrl(photoReference, 800);

  // Download the photo through the redirect endpoint.
  const buffer = await downloadBuffer(photoUrl);
  if (!buffer || buffer.length === 0) {
    return { skipped: true, name, reason: 'empty photo download' };
  }

  const contentType = 'image/jpeg';
  const safeName = name
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 60);
  const destination = `food_businesses/${doc.id}_${safeName}.jpg`;

  const downloadUrl = await uploadImage(buffer, destination, contentType);

  await doc.ref.update({
    imageUrl: downloadUrl,
    logoUrl: data.logoUrl ? downloadUrl : undefined,
    coverImageUrl: data.coverImageUrl ? downloadUrl : undefined,
    googlePlaceId: place.place_id,
  });

  return { success: true, name, url: downloadUrl };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  try {
    const snapshot = await db.collection('food_businesses').get();
    console.log(`Found ${snapshot.size} food business documents\n`);

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      try {
        const result = await processDocument(doc);
        if (result.success) {
          updated++;
          console.log(`✅ ${result.name}`);
        } else {
          skipped++;
          console.log(`⏭️  ${result.name}: ${result.reason}`);
        }
      } catch (error) {
        failed++;
        console.error(`❌ ${doc.data().name || doc.id}: ${error.message}`);
      }

      // Rate limit to avoid hitting Google Places API quotas.
      await delay(400);
    }

    console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
    process.exit(0);
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

main();
