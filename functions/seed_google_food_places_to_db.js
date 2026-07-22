/**
 * Seed Brisbane CBD food businesses from Google Places API
 * 
 * Searches for restaurants, cafes, and local food businesses
 * in Brisbane CBD using Google Places Text Search API
 * and seeds them into food_businesses collection
 * 
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
 *   node seed_google_food_places_to_db.js
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

// Brisbane CBD coordinates and radius
const BRISBANE_CBD_LAT = -27.4679;
const BRISBANE_CBD_LNG = 153.0281;
const SEARCH_RADIUS = 8000; // 8km radius around CBD

// Search queries for different types of food businesses
const SEARCH_QUERIES = [
  'restaurants Brisbane CBD',
  'cafes Brisbane CBD',
  'bars Brisbane CBD',
  'pizza Brisbane CBD',
  'asian food Brisbane CBD',
  'thai restaurant Brisbane CBD',
  'japanese restaurant Brisbane CBD',
  'indian restaurant Brisbane CBD',
  'mexican restaurant Brisbane CBD',
  'seafood Brisbane CBD',
  'brunch cafe Brisbane CBD',
  'coffee shop Brisbane CBD',
  'burger Brisbane CBD',
  'modern australian Brisbane CBD',
  'mediterranean Brisbane CBD',
];

// Helper: Make HTTPS request
function makeRequest(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
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

// Extract unique cuisine types from place types
function extractCuisines(placeTypes, name) {
  const cuisineMap = {
    'restaurant': 'Restaurant',
    'cafe': 'Cafe',
    'bar': 'Bar',
    'bakery': 'Bakery',
    'pizza': 'Pizza',
    'sushi': 'Japanese',
    'asian': 'Asian',
    'thai': 'Thai',
    'indian': 'Indian',
    'mexican': 'Mexican',
    'italian': 'Italian',
    'chinese': 'Chinese',
    'vietnamese': 'Vietnamese',
    'korean': 'Korean',
    'japanese': 'Japanese',
    'seafood': 'Seafood',
    'steakhouse': 'Steakhouse',
    'brunch': 'Brunch',
    'coffee': 'Coffee',
    'mediterranean': 'Mediterranean',
  };

  const cuisines = [];
  const lowerName = name.toLowerCase();

  for (const [key, cuisine] of Object.entries(cuisineMap)) {
    if (lowerName.includes(key)) {
      if (!cuisines.includes(cuisine)) {
        cuisines.push(cuisine);
      }
    }
  }

  // Default to Restaurant if no specific cuisine found
  if (cuisines.length === 0) {
    cuisines.push('Restaurant');
  }

  return cuisines;
}

// Determine price range from rating and other factors
function determinePriceRange(name) {
  const affordable = ['cafe', 'coffee', 'bakery', 'burger', 'pizza', 'noodle', 'pho'];
  const moderate = ['restaurant', 'bistro', 'thai', 'indian', 'asian', 'mediterranean'];
  const premium = ['fine dining', 'steakhouse', 'seafood', 'contemporary', 'modern', 'upscale'];

  const lower = name.toLowerCase();
  
  for (const word of premium) {
    if (lower.includes(word)) return '$$$';
  }
  
  for (const word of moderate) {
    if (lower.includes(word)) return '$$';
  }
  
  for (const word of affordable) {
    if (lower.includes(word)) return '$';
  }

  return '$$';
}

// Check if place is within Brisbane CBD area
function isInBrisbaneCBD(lat, lng) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat - BRISBANE_CBD_LAT) * Math.PI / 180;
  const dLng = (lng - BRISBANE_CBD_LNG) * Math.PI / 180;
  const a = Math.sin(dLat/2) ** 2 + 
    Math.cos(BRISBANE_CBD_LAT * Math.PI / 180) * 
    Math.cos(lat * Math.PI / 180) * 
    Math.sin(dLng/2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c;
  return distance <= (SEARCH_RADIUS / 1000);
}

// Clean and normalize place data
function normalizePlaceData(place, index) {
  const name = place.name || 'Unknown';
  const lat = place.geometry?.location?.lat;
  const lng = place.geometry?.location?.lng;

  // Skip if no coordinates
  if (!lat || !lng) return null;

  // Skip if outside Brisbane CBD area
  if (!isInBrisbaneCBD(lat, lng)) return null;

  const address = place.formatted_address || '';
  const rating = place.rating || 4.0;
  const reviewCount = place.user_ratings_total || 0;

  // Skip places with very low reviews (likely incomplete data)
  if (reviewCount < 5) return null;

  const cuisineTypes = extractCuisines(place.types || [], name);
  const priceRange = determinePriceRange(name);

  // Ensure rating is in valid range
  const normalizedRating = Math.min(4.9, Math.max(3.5, rating));

  return {
    name,
    description: `${cuisineTypes.join(', ')} in Brisbane CBD`,
    address,
    phone: place.formatted_phone_number || '',
    website: place.website || '',
    cuisineTypes,
    imageUrl: 'https://images.unsplash.com/photo-1504674900967-965ba998e5e2?w=400&h=300&fit=crop', // Fallback image
    coordinates: { latitude: lat, longitude: lng },
    rating: normalizedRating,
    reviewCount,
    priceRange,
    createdAt: new Date().toISOString(),
    source: 'google_places',
    googlePlaceId: place.place_id,
  };
}

// Seed a single place to Firestore
async function seedPlace(place, index) {
  const normalized = normalizePlaceData(place, index);
  
  if (!normalized) return null;

  const docId = normalized.name
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 80);

  try {
    await db.collection('food_businesses').doc(docId).set(normalized, { merge: true });
    return { success: true, name: normalized.name, docId };
  } catch (error) {
    return { success: false, name: normalized.name, error: error.message };
  }
}

// Main seeding function
async function seedGoogleFoodPlaces() {
  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║  GOOGLE PLACES FOOD SEEDING - Brisbane CBD                      ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  const allPlaces = new Map(); // Use Map to avoid duplicates
  let totalSearched = 0;
  let successCount = 0;
  let skipCount = 0;
  let errors = [];

  // Search for food places
  console.log(`🔍 Searching for food businesses with ${SEARCH_QUERIES.length} queries...\n`);

  for (const query of SEARCH_QUERIES) {
    try {
      const searchUrl = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
      searchUrl.searchParams.set('query', query);
      searchUrl.searchParams.set('key', API_KEY);
      searchUrl.searchParams.set('region', 'au');

      const result = await makeRequest(searchUrl.toString());

      if (result.results) {
        for (const place of result.results) {
          const key = `${place.name}|${place.geometry.location.lat}|${place.geometry.location.lng}`;
          if (!allPlaces.has(key)) {
            allPlaces.set(key, place);
          }
        }
        totalSearched += result.results.length;
        console.log(`  ✓ "${query}" - Found ${result.results.length} places`);
      }

      // Rate limiting
      await new Promise(r => setTimeout(r, 500));
    } catch (error) {
      errors.push(`Query "${query}": ${error.message}`);
    }
  }

  console.log(`\n📊 Total unique places found: ${allPlaces.size}`);
  console.log(`🌐 Starting Firestore seeding...\n`);

  // Seed to Firestore
  let index = 1;
  for (const [, place] of allPlaces) {
    const result = await seedPlace(place, index);
    
    if (result) {
      if (result.success) {
        console.log(`✓ [${index}/${allPlaces.size}] ${result.name} - Seeded`);
        successCount++;
      } else {
        console.log(`❌ [${index}/${allPlaces.size}] ${result.name}: ${result.error}`);
      }
    } else {
      skipCount++;
    }

    index++;
    
    // Rate limiting to avoid overwhelming Firestore
    if (index % 10 === 0) {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  console.log(`\n${'='.repeat(64)}`);
  console.log(`✅ Successfully seeded: ${successCount} businesses`);
  console.log(`⏭️  Skipped (outside area/low reviews): ${skipCount}`);
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
