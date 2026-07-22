/**
 * Seed Brisbane CBD food businesses from Google Places Nearby Search API
 * 
 * Uses Nearby Search (more reliable than Text Search) to find
 * restaurants, cafes, and food establishments in Brisbane CBD
 * and seeds them into food_businesses collection
 * 
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
 *   node seed_google_places_nearby.js
 */

const admin = require('firebase-admin');
const https = require('https');
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
const API_KEY = 'AIzaSyCgEZo0LJD6ksf9Vfe8owyGm22xYygW8ps';

// Brisbane CBD center and search radius
const BRISBANE_CBD = { lat: -27.4679, lng: 153.0281 };
const SEARCH_RADIUS = 3000; // 3km radius

// Place types to search for (food-related)
const PLACE_TYPES = [
  'restaurant',
  'cafe',
  'bar',
  'food',
];

// Helper: Make HTTPS request with timeout
function makeRequest(url, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.setTimeout(timeout, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

// Extract cuisine types from place name and types
function extractCuisines(name, placeTypes = []) {
  const cuisineKeywords = {
    'Restaurant': ['restaurant'],
    'Cafe': ['cafe', 'coffee', 'bakery'],
    'Bar': ['bar', 'pub'],
    'Pizza': ['pizza'],
    'Japanese': ['japanese', 'sushi', 'ramen'],
    'Thai': ['thai'],
    'Indian': ['indian', 'curry'],
    'Mexican': ['mexican', 'taco'],
    'Chinese': ['chinese', 'dim sum'],
    'Vietnamese': ['vietnamese', 'pho'],
    'Korean': ['korean', 'bbq'],
    'Seafood': ['seafood', 'fish', 'oyster'],
    'Steakhouse': ['steakhouse', 'steak'],
    'Italian': ['italian'],
    'Mediterranean': ['mediterranean', 'greek'],
    'Asian': ['asian'],
    'Brunch': ['brunch', 'breakfast'],
    'Burger': ['burger'],
  };

  const cuisines = [];
  const lowerName = name.toLowerCase();

  for (const [cuisine, keywords] of Object.entries(cuisineKeywords)) {
    for (const keyword of keywords) {
      if (lowerName.includes(keyword)) {
        if (!cuisines.includes(cuisine)) {
          cuisines.push(cuisine);
        }
        break;
      }
    }
  }

  if (cuisines.length === 0) {
    cuisines.push('Restaurant');
  }

  return cuisines.slice(0, 5); // Limit to 5 cuisine types
}

// Determine price range
function determinePriceRange(priceLevel) {
  if (priceLevel === 1) return '$';
  if (priceLevel === 2 || priceLevel === 3) return '$$';
  if (priceLevel === 4) return '$$$';
  return '$$'; // Default
}

// Normalize place data for Firestore
function normalizePlaceData(place) {
  const name = place.name || 'Unknown';
  const lat = place.geometry?.location?.lat;
  const lng = place.geometry?.location?.lng;

  if (!lat || !lng) return null;

  const address = place.vicinity || '';
  const rating = place.rating || 4.0;
  const reviewCount = place.user_ratings_total || 0;

  // Skip if very few reviews (incomplete data)
  if (reviewCount < 10) return null;

  const cuisineTypes = extractCuisines(name, place.types || []);
  const priceRange = determinePriceRange(place.price_level || 2);

  return {
    name,
    description: `${cuisineTypes.join(', ')} in Brisbane CBD`,
    address,
    phone: place.formatted_phone_number || '',
    website: place.website || '',
    cuisineTypes,
    imageUrl: 'https://images.unsplash.com/photo-1504674900967-965ba998e5e2?w=400&h=300&fit=crop',
    coordinates: { latitude: lat, longitude: lng },
    rating: Math.min(4.9, Math.max(3.5, rating)),
    reviewCount,
    priceRange,
    createdAt: new Date().toISOString(),
    source: 'google_places',
    googlePlaceId: place.place_id,
    openNow: place.opening_hours?.open_now,
  };
}

// Seed place to Firestore
async function seedPlace(place) {
  const normalized = normalizePlaceData(place);
  
  if (!normalized) return null;

  const docId = normalized.name
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 80);

  try {
    await db.collection('food_businesses').doc(docId).set(normalized, { merge: true });
    return { success: true, name: normalized.name, rating: normalized.rating };
  } catch (error) {
    return { success: false, name: normalized.name, error: error.message };
  }
}

// Main seeding function using Nearby Search
async function seedGoogleFoodPlaces() {
  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║  GOOGLE PLACES NEARBY SEARCH - Brisbane CBD                     ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  const allPlaces = new Map();
  let successCount = 0;
  let skipCount = 0;
  let errors = [];

  console.log(`🔍 Searching for food businesses near Brisbane CBD...\n`);

  // Search each place type
  for (const placeType of PLACE_TYPES) {
    try {
      const searchUrl = new URL('https://maps.googleapis.com/maps/api/place/nearbysearch/json');
      searchUrl.searchParams.set('location', `${BRISBANE_CBD.lat},${BRISBANE_CBD.lng}`);
      searchUrl.searchParams.set('radius', SEARCH_RADIUS);
      searchUrl.searchParams.set('type', placeType);
      searchUrl.searchParams.set('key', API_KEY);

      console.log(`  Searching for: ${placeType}...`);
      const result = await makeRequest(searchUrl.toString());

      if (result.results && Array.isArray(result.results)) {
        for (const place of result.results) {
          const key = place.place_id;
          if (!allPlaces.has(key)) {
            allPlaces.set(key, place);
          }
        }
        console.log(`    ✓ Found ${result.results.length} places`);
      }

      // Handle pagination
      let pageToken = result.next_page_token;
      let pageCount = 1;
      while (pageToken && pageCount < 3) {
        await new Promise(r => setTimeout(r, 2000)); // Wait for token to be valid
        
        const nextUrl = new URL('https://maps.googleapis.com/maps/api/place/nearbysearch/json');
        nextUrl.searchParams.set('pagetoken', pageToken);
        nextUrl.searchParams.set('key', API_KEY);

        const nextResult = await makeRequest(nextUrl.toString());
        if (nextResult.results) {
          for (const place of nextResult.results) {
            const key = place.place_id;
            if (!allPlaces.has(key)) {
              allPlaces.set(key, place);
            }
          }
          console.log(`    ✓ Page ${pageCount + 1}: Found ${nextResult.results.length} places`);
        }

        pageToken = nextResult.next_page_token;
        pageCount++;
      }

      await new Promise(r => setTimeout(r, 1000));
    } catch (error) {
      errors.push(`Type "${placeType}": ${error.message}`);
    }
  }

  console.log(`\n📊 Total unique places found: ${allPlaces.size}`);
  console.log(`🌐 Starting Firestore seeding...\n`);

  // Seed to Firestore
  let index = 1;
  for (const [, place] of allPlaces) {
    const result = await seedPlace(place);
    
    if (result) {
      if (result.success) {
        console.log(`✓ [${index}/${allPlaces.size}] ${result.name} (${result.rating}⭐)`);
        successCount++;
      } else {
        console.log(`❌ [${index}/${allPlaces.size}] ${result.name}: ${result.error}`);
      }
    } else {
      skipCount++;
    }

    index++;
    
    if (index % 10 === 0) {
      await new Promise(r => setTimeout(r, 500));
    }
  }

  console.log(`\n${'='.repeat(64)}`);
  console.log(`✅ Successfully seeded: ${successCount} businesses from Google Places`);
  console.log(`⏭️  Skipped (low reviews): ${skipCount}`);
  if (errors.length > 0) {
    console.log(`⚠️  Errors: ${errors.length}`);
  }
  console.log(`📊 Total processed: ${successCount + skipCount}`);
  console.log(`${'='.repeat(64)}\n`);

  if (errors.length > 0) {
    console.log('Error details:');
    errors.forEach(e => console.log(`  - ${e}`));
    console.log();
  }

  process.exit(successCount > 0 ? 0 : 1);
}

// Run seeding
seedGoogleFoodPlaces().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
