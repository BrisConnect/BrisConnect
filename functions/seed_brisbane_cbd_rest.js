/**
 * Seed Brisbane CBD food businesses using Firestore REST API
 * This approach doesn't require service account credentials
 * 
 * Usage:
 *   cd functions
 *   node seed_brisbane_cbd_rest.js
 */

const https = require('https');

// Firebase configuration
const PROJECT_ID = 'brisconnect-68b78';
const API_KEY = 'AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Firestore REST API URL for batch write
const BATCH_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:batchWrite?key=${API_KEY}`;

const businesses = [
  // Fine Dining & Steakhouses
  {
    id: 'grill-house-cbd',
    name: 'The Grill House',
    description: 'Premium steakhouse featuring aged Australian beef and fine wines.',
    address: '123 Eagle Street, Brisbane CBD QLD 4000',
    phone: '(07) 3221 5544',
    website: 'https://thegrillhouse.com.au',
    cuisineTypes: ['Steakhouse', 'Modern Australian', 'Fine Dining'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4733,
    longitude: 153.0284,
    averageRating: 4.7,
    reviewCount: 284,
    priceRange: '$$$'
  },
  {
    id: 'scene-restaurant-cbd',
    name: 'Scene Restaurant',
    description: 'Upscale dining with contemporary Australian cuisine and river views.',
    address: '71 Merivale Street, South Brisbane QLD 4101',
    phone: '(07) 3010 8888',
    website: 'https://scenerestaurant.com.au',
    cuisineTypes: ['Contemporary', 'Modern Australian', 'Fine Dining'],
    imageUrl: 'https://images.unsplash.com/photo-1559339352-11d3fbb35b1b?w=500&h=500',
    latitude: -27.4820,
    longitude: 153.0218,
    averageRating: 4.6,
    reviewCount: 156,
    priceRange: '$$$'
  },
  {
    id: 'aria-restaurant-south-bank',
    name: 'Aria Restaurant',
    description: 'Fine dining establishment with modern Australian menu overlooking the river.',
    address: '93 South Bank Parkway, South Brisbane QLD 4101',
    phone: '(07) 3211 2000',
    website: 'https://aria.com.au',
    cuisineTypes: ['Modern Australian', 'Fine Dining'],
    imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&h=500',
    latitude: -27.4805,
    longitude: 153.0229,
    averageRating: 4.5,
    reviewCount: 198,
    priceRange: '$$$'
  },
  // Asian Cuisine
  {
    id: 'noodle-palace-valley',
    name: 'Noodle Palace',
    description: 'Authentic Asian noodle house with hand-pulled noodles and traditional recipes.',
    address: '42 Fortitude Valley, Brisbane QLD 4006',
    phone: '(07) 3369 9888',
    website: 'https://noodlepalace.com.au',
    cuisineTypes: ['Asian', 'Chinese', 'Noodles'],
    imageUrl: 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=500&h=500',
    latitude: -27.4568,
    longitude: 153.0345,
    averageRating: 4.4,
    reviewCount: 342,
    priceRange: '$$'
  },
  {
    id: 'dragon-palace-cbd',
    name: 'Dragon Palace',
    description: 'Premier Cantonese restaurant with dim sum and authentic Chinese dishes.',
    address: '88 Queen Street, Brisbane CBD QLD 4000',
    phone: '(07) 3221 7788',
    website: 'https://dragonpalace.com.au',
    cuisineTypes: ['Chinese', 'Cantonese', 'Dim Sum'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4751,
    longitude: 153.0288,
    averageRating: 4.5,
    reviewCount: 267,
    priceRange: '$$'
  },
  {
    id: 'sushi-kingdom-valley',
    name: 'Sushi Kingdom',
    description: 'Premium Japanese sushi bar with fresh fish and authentic preparation.',
    address: '15 James Street, Fortitude Valley QLD 4006',
    phone: '(07) 3854 1122',
    website: 'https://sushikingdom.com.au',
    cuisineTypes: ['Japanese', 'Sushi', 'Asian'],
    imageUrl: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=500&h=500',
    latitude: -27.4572,
    longitude: 153.0352,
    averageRating: 4.6,
    reviewCount: 298,
    priceRange: '$$'
  },
  {
    id: 'thai-orchid-cbd',
    name: 'Thai Orchid',
    description: 'Traditional Thai cuisine with authentic spices and family recipes.',
    address: '201 Charlotte Street, Brisbane CBD QLD 4000',
    phone: '(07) 3229 4455',
    website: 'https://thaiorchid.com.au',
    cuisineTypes: ['Thai', 'Asian', 'Southeast Asian'],
    imageUrl: 'https://images.unsplash.com/photo-1455619452474-d2be8b1e4e1a?w=500&h=500',
    latitude: -27.4767,
    longitude: 153.0301,
    averageRating: 4.5,
    reviewCount: 201,
    priceRange: '$$'
  },
  {
    id: 'vietnamese-street-paddington',
    name: 'Vietnamese Street Kitchen',
    description: 'Street-style Vietnamese food with fresh ingredients and bold flavors.',
    address: '234 Latrobe Terrace, Paddington QLD 4064',
    phone: '(07) 3871 5566',
    website: 'https://vietnamesestreet.com.au',
    cuisineTypes: ['Vietnamese', 'Asian', 'Street Food'],
    imageUrl: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=500&h=500',
    latitude: -27.4567,
    longitude: 152.9956,
    averageRating: 4.4,
    reviewCount: 215,
    priceRange: '$'
  },
  // Cafes & Brunch
  {
    id: 'urban-cafe-south-bank',
    name: 'Urban Cafe',
    description: 'Trendy cafe with specialty coffee and modern brunch menu.',
    address: '12 South Bank Parkway, South Brisbane QLD 4101',
    phone: '(07) 3844 7723',
    website: 'https://urbancafe.com.au',
    cuisineTypes: ['Cafe', 'Brunch', 'Coffee'],
    imageUrl: 'https://images.unsplash.com/photo-1504674900759-481cdf1f5d0e?w=500&h=500',
    latitude: -27.4810,
    longitude: 153.0233,
    averageRating: 4.5,
    reviewCount: 423,
    priceRange: '$$'
  },
  {
    id: 'brew-co-valley',
    name: 'Brew & Co',
    description: 'Artisan coffee roastery and cafe with fresh pastries.',
    address: '67 James Street, Fortitude Valley QLD 4006',
    phone: '(07) 3852 2211',
    website: 'https://brewco.com.au',
    cuisineTypes: ['Cafe', 'Coffee', 'Pastries'],
    imageUrl: 'https://images.unsplash.com/photo-1511920170033-f8396924c348?w=500&h=500',
    latitude: -27.4575,
    longitude: 153.0358,
    averageRating: 4.6,
    reviewCount: 356,
    priceRange: '$$'
  },
  {
    id: 'egg-kitchen-cbd',
    name: 'The Egg Kitchen',
    description: 'Breakfast specialist with creative egg dishes and fresh juices.',
    address: '156 Edward Street, Brisbane CBD QLD 4000',
    phone: '(07) 3211 8899',
    website: 'https://theeggkitchen.com.au',
    cuisineTypes: ['Cafe', 'Breakfast', 'Brunch'],
    imageUrl: 'https://images.unsplash.com/photo-1495195134817-aeb325d50911?w=500&h=500',
    latitude: -27.4762,
    longitude: 153.0294,
    averageRating: 4.4,
    reviewCount: 289,
    priceRange: '$$'
  },
  {
    id: 'black-star-coffee-paddington',
    name: 'Black Star Coffee',
    description: 'Independent cafe with house-roasted beans and cozy atmosphere.',
    address: '89 Given Terrace, Paddington QLD 4064',
    phone: '(07) 3368 4422',
    website: 'https://blackstarcoffee.com.au',
    cuisineTypes: ['Cafe', 'Coffee', 'Brunch'],
    imageUrl: 'https://images.unsplash.com/photo-1442512595331-e89e90ea1e9a?w=500&h=500',
    latitude: -27.4580,
    longitude: 152.9945,
    averageRating: 4.5,
    reviewCount: 302,
    priceRange: '$$'
  },
  // Mediterranean & European
  {
    id: 'olive-tree-south-bank',
    name: 'The Olive Tree',
    description: 'Mediterranean cuisine with Greek specialties and fresh seafood.',
    address: '45 Grey Street, South Brisbane QLD 4101',
    phone: '(07) 3844 5566',
    website: 'https://olivetree.com.au',
    cuisineTypes: ['Mediterranean', 'Greek', 'European'],
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&h=500',
    latitude: -27.4815,
    longitude: 153.0201,
    averageRating: 4.6,
    reviewCount: 234,
    priceRange: '$$'
  },
  {
    id: 'bella-napoli-valley',
    name: 'Bella Napoli',
    description: 'Authentic Italian restaurant with wood-fired pizza and pasta.',
    address: '123 Melbourne Street, South Brisbane QLD 4101',
    phone: '(07) 3217 8899',
    website: 'https://bellanapoli.com.au',
    cuisineTypes: ['Italian', 'Pizza', 'Pasta'],
    imageUrl: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?w=500&h=500',
    latitude: -27.4809,
    longitude: 153.0196,
    averageRating: 4.5,
    reviewCount: 267,
    priceRange: '$$'
  },
  {
    id: 'greek-taverna-paddington',
    name: 'Greek Taverna',
    description: 'Traditional Greek taverna with Mediterranean flavors and warm hospitality.',
    address: '176 Latrobe Terrace, Paddington QLD 4064',
    phone: '(07) 3871 7788',
    website: 'https://greektaverna.com.au',
    cuisineTypes: ['Greek', 'Mediterranean', 'European'],
    imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=500&h=500',
    latitude: -27.4570,
    longitude: 152.9950,
    averageRating: 4.4,
    reviewCount: 189,
    priceRange: '$$'
  },
  // Indian & Curry
  {
    id: 'spice-route-cbd',
    name: 'Spice Route',
    description: 'Indian restaurant featuring tandoori specialties and curries.',
    address: '234 Queen Street, Brisbane CBD QLD 4000',
    phone: '(07) 3211 2233',
    website: 'https://spiceroute.com.au',
    cuisineTypes: ['Indian', 'Curry', 'Tandoori'],
    imageUrl: 'https://images.unsplash.com/photo-1596040281341-f9e3c8ee4b1f?w=500&h=500',
    latitude: -27.4755,
    longitude: 153.0285,
    averageRating: 4.5,
    reviewCount: 312,
    priceRange: '$$'
  },
  {
    id: 'maharaja-palace-valley',
    name: 'Maharaja Palace',
    description: 'Upscale Indian dining with modern preparations of classic dishes.',
    address: '56 Fortitude Valley, Brisbane QLD 4006',
    phone: '(07) 3369 4444',
    website: 'https://maharajapalace.com.au',
    cuisineTypes: ['Indian', 'Curry', 'South Asian'],
    imageUrl: 'https://images.unsplash.com/photo-1585883557679-cdfeef45c93e?w=500&h=500',
    latitude: -27.4570,
    longitude: 153.0360,
    averageRating: 4.3,
    reviewCount: 245,
    priceRange: '$$'
  },
  // Modern Australian & Local
  {
    id: 'riverfront-kitchen-south-bank',
    name: 'Riverfront Kitchen',
    description: 'Contemporary Australian cuisine with Queensland produce.',
    address: '1 South Bank Parkway, South Brisbane QLD 4101',
    phone: '(07) 3844 6666',
    website: 'https://riverfrontkitchen.com.au',
    cuisineTypes: ['Modern Australian', 'Contemporary', 'Local'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4820,
    longitude: 153.0225,
    averageRating: 4.6,
    reviewCount: 378,
    priceRange: '$$$'
  },
  {
    id: 'local-harvest-paddington',
    name: 'Local Harvest',
    description: 'Farm-to-table restaurant showcasing local Brisbane produce.',
    address: '234 Given Terrace, Paddington QLD 4064',
    phone: '(07) 3368 5555',
    website: 'https://localharvest.com.au',
    cuisineTypes: ['Modern Australian', 'Farm-to-Table', 'Local'],
    imageUrl: 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=500&h=500',
    latitude: -27.4575,
    longitude: 152.9955,
    averageRating: 4.5,
    reviewCount: 223,
    priceRange: '$$'
  },
  {
    id: 'pantry-cbd',
    name: 'The Pantry',
    description: 'Casual dining with locally-sourced ingredients and modern comfort food.',
    address: '89 Creek Street, Brisbane CBD QLD 4000',
    phone: '(07) 3221 3333',
    website: 'https://thepantry.com.au',
    cuisineTypes: ['Modern Australian', 'Casual', 'Local'],
    imageUrl: 'https://images.unsplash.com/photo-1476899926935-ea707b1f6d82?w=500&h=500',
    latitude: -27.4748,
    longitude: 153.0277,
    averageRating: 4.3,
    reviewCount: 198,
    priceRange: '$$'
  },
  // Burgers & Casual
  {
    id: 'burger-bros-valley',
    name: 'Burger Bros',
    description: 'Gourmet burgers with craft beer selection and loaded fries.',
    address: '78 Ann Street, Fortitude Valley QLD 4006',
    phone: '(07) 3852 1111',
    website: 'https://burgerbros.com.au',
    cuisineTypes: ['Burgers', 'American', 'Casual'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4562,
    longitude: 153.0340,
    averageRating: 4.4,
    reviewCount: 267,
    priceRange: '$$'
  },
  {
    id: 'craft-burger-co-south-bank',
    name: 'Craft Burger Co',
    description: 'Artisanal burgers with gourmet toppings and homemade sauces.',
    address: '34 South Bank Parkway, South Brisbane QLD 4101',
    phone: '(07) 3846 2222',
    website: 'https://craftburgerco.com.au',
    cuisineTypes: ['Burgers', 'American', 'Gourmet'],
    imageUrl: 'https://images.unsplash.com/photo-1550547660-d9449f4cb336?w=500&h=500',
    latitude: -27.4818,
    longitude: 153.0228,
    averageRating: 4.5,
    reviewCount: 289,
    priceRange: '$$'
  },
  // Seafood
  {
    id: 'fish-house-cbd',
    name: 'The Fish House',
    description: 'Fresh seafood restaurant with daily specials and oyster bar.',
    address: '167 Eagle Street, Brisbane CBD QLD 4000',
    phone: '(07) 3221 9999',
    website: 'https://thefishhouse.com.au',
    cuisineTypes: ['Seafood', 'Fish', 'Australian'],
    imageUrl: 'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=500&h=500',
    latitude: -27.4735,
    longitude: 153.0290,
    averageRating: 4.6,
    reviewCount: 301,
    priceRange: '$$$'
  },
  {
    id: 'oyster-lounge-valley',
    name: 'Oyster Lounge',
    description: 'Upscale seafood bar with fresh oysters and premium fish.',
    address: '45 Brunswick Street, Fortitude Valley QLD 4006',
    phone: '(07) 3854 8888',
    website: 'https://oysterlounge.com.au',
    cuisineTypes: ['Seafood', 'Oysters', 'Fine Dining'],
    imageUrl: 'https://images.unsplash.com/photo-1504674900759-481cdf1f5d0e?w=500&h=500',
    latitude: -27.4548,
    longitude: 153.0330,
    averageRating: 4.5,
    reviewCount: 267,
    priceRange: '$$$'
  },
  // Mexican
  {
    id: 'taco-fiesta-south-bank',
    name: 'Taco Fiesta',
    description: 'Authentic Mexican street tacos and traditional dishes.',
    address: '123 Merivale Street, South Brisbane QLD 4101',
    phone: '(07) 3844 3333',
    website: 'https://tacofiesta.com.au',
    cuisineTypes: ['Mexican', 'Tacos', 'Latin'],
    imageUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=500&h=500',
    latitude: -27.4822,
    longitude: 153.0215,
    averageRating: 4.4,
    reviewCount: 215,
    priceRange: '$$'
  },
  {
    id: 'hacienda-paddington',
    name: 'Hacienda',
    description: 'Mexican restaurant with traditional recipes and vibrant atmosphere.',
    address: '201 Given Terrace, Paddington QLD 4064',
    phone: '(07) 3368 9999',
    website: 'https://hacienda.com.au',
    cuisineTypes: ['Mexican', 'Latin', 'Spanish'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4585,
    longitude: 152.9960,
    averageRating: 4.3,
    reviewCount: 187,
    priceRange: '$$'
  },
  // Korean
  {
    id: 'seoul-kitchen-valley',
    name: 'Seoul Kitchen',
    description: 'Korean restaurant with BBQ and traditional kimchi specialties.',
    address: '89 James Street, Fortitude Valley QLD 4006',
    phone: '(07) 3852 5555',
    website: 'https://seoulkitchen.com.au',
    cuisineTypes: ['Korean', 'BBQ', 'Asian'],
    imageUrl: 'https://images.unsplash.com/photo-1553163147-f1ede38e5cdc?w=500&h=500',
    latitude: -27.4573,
    longitude: 153.0350,
    averageRating: 4.5,
    reviewCount: 234,
    priceRange: '$$'
  }
];

function makeHttpsRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, 'https://firestore.googleapis.com');
    
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    if (data) {
      const jsonData = JSON.stringify(data);
      options.headers['Content-Length'] = Buffer.byteLength(jsonData);
    }

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            body: body ? JSON.parse(body) : null
          });
        } catch (e) {
          resolve({ status: res.statusCode, body: body });
        }
      });
    });

    req.on('error', reject);
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function seedData() {
  console.log('Starting to seed Brisbane CBD food businesses via REST API...\n');
  
  let successCount = 0;
  let errorCount = 0;

  for (const business of businesses) {
    try {
      const documentPath = `${BASE_URL}/food_businesses/${business.id}?key=${API_KEY}`;
      
      const payload = {
        fields: {
          name: { stringValue: business.name },
          description: { stringValue: business.description },
          address: { stringValue: business.address },
          phone: { stringValue: business.phone },
          website: { stringValue: business.website },
          cuisineTypes: { arrayValue: { values: business.cuisineTypes.map(ct => ({ stringValue: ct })) } },
          imageUrl: { stringValue: business.imageUrl },
          latitude: { doubleValue: business.latitude },
          longitude: { doubleValue: business.longitude },
          averageRating: { doubleValue: business.averageRating },
          reviewCount: { integerValue: business.reviewCount },
          priceRange: { stringValue: business.priceRange },
          createdAt: { timestampValue: new Date().toISOString() }
        }
      };

      const response = await makeHttpsRequest('PATCH', documentPath, payload);
      
      if (response.status >= 200 && response.status < 300) {
        console.log(`✅ ${business.name}`);
        successCount++;
      } else {
        console.log(`❌ ${business.name}: ${response.status}`);
        errorCount++;
      }
    } catch (error) {
      console.log(`❌ ${business.name}: ${error.message}`);
      errorCount++;
    }
  }

  console.log(`\n✅ Successfully seeded: ${successCount} businesses`);
  console.log(`❌ Failed: ${errorCount} businesses`);
  console.log(`📊 Total: ${businesses.length} businesses`);
}

seedData().catch(error => {
  console.error('Error seeding data:', error);
  process.exit(1);
});
