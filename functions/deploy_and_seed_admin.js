const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, '../service-account-key.json');

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
const firestoreClient = admin.firestore();

// 27 Brisbane CBD Food Businesses
const businesses = [
  {
    name: "The Grill House",
    description: "Premium Brazilian churrasco steakhouse with wood-fired grills",
    address: "Level 5, 259 Queen St, Brisbane QLD 4000",
    phone: "+61 7 3221 4567",
    website: "https://www.thegrillhouse.com.au",
    cuisineTypes: ["Brazilian", "Steakhouse", "BBQ"],
    imageUrl: "https://images.unsplash.com/photo-1555939594-58d7cb561549?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4708, longitude: 153.0325 },
    rating: 4.7,
    reviewCount: 243,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Scene Restaurant",
    description: "Modern Australian restaurant showcasing local ingredients and flavours",
    address: "Eagle Street Pier, Brisbane QLD 4000",
    phone: "+61 7 3229 8888",
    website: "https://www.scenerestaurant.com.au",
    cuisineTypes: ["Modern Australian", "Contemporary"],
    imageUrl: "https://images.unsplash.com/photo-1517457373614-b7152f800fd1?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4750, longitude: 153.0380 },
    rating: 4.6,
    reviewCount: 187,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Aria Restaurant",
    description: "Fine dining Italian restaurant with world-class wine selection",
    address: "80 George St, Brisbane QLD 4000",
    phone: "+61 7 3211 5566",
    website: "https://www.ariarestaurant.com.au",
    cuisineTypes: ["Italian", "Fine Dining", "Contemporary"],
    imageUrl: "https://images.unsplash.com/photo-1504674900967-965ba998e5e2?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4720, longitude: 153.0310 },
    rating: 4.8,
    reviewCount: 312,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Noodle Palace",
    description: "Authentic Vietnamese pho and noodle dishes",
    address: "Chinatown, Brisbane QLD 4000",
    phone: "+61 7 3210 2340",
    website: "https://www.noodlepalace.com.au",
    cuisineTypes: ["Vietnamese", "Noodles", "Asian"],
    imageUrl: "https://images.unsplash.com/photo-1558462053-61d81e798e74?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4775, longitude: 153.0290 },
    rating: 4.5,
    reviewCount: 456,
    priceRange: "$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Dragon Palace",
    description: "Traditional Chinese cuisine with dim sum specialties",
    address: "Chinatown Plaza, Brisbane QLD 4000",
    phone: "+61 7 3210 8765",
    website: "https://www.dragonpalace.com.au",
    cuisineTypes: ["Chinese", "Dim Sum", "Asian"],
    imageUrl: "https://images.unsplash.com/photo-1585521891492-da1842efcaa0?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4770, longitude: 153.0295 },
    rating: 4.4,
    reviewCount: 523,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Sushi Kingdom",
    description: "Premium Japanese sushi bar with fresh daily imports",
    address: "Level 2, 175 Eagle St, Brisbane QLD 4000",
    phone: "+61 7 3221 4321",
    website: "https://www.sushikingdom.com.au",
    cuisineTypes: ["Japanese", "Sushi", "Asian"],
    imageUrl: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4715, longitude: 153.0340 },
    rating: 4.7,
    reviewCount: 389,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Thai Orchid",
    description: "Authentic Thai cuisine with traditional cooking methods",
    address: "28 Astor Terrace, Spring Hill QLD 4000",
    phone: "+61 7 3831 5757",
    website: "https://www.thaiorchid.com.au",
    cuisineTypes: ["Thai", "Asian", "Curry"],
    imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4695, longitude: 153.0305 },
    rating: 4.5,
    reviewCount: 267,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Vietnamese Street Kitchen",
    description: "Street food inspired Vietnamese dishes in casual setting",
    address: "71 Fortitude Valley, Brisbane QLD 4006",
    phone: "+61 7 3852 1234",
    website: "https://www.vietnamesestreet.com.au",
    cuisineTypes: ["Vietnamese", "Street Food", "Asian"],
    imageUrl: "https://images.unsplash.com/photo-1576921294636-c7e0b89f2f82?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4650, longitude: 153.0365 },
    rating: 4.3,
    reviewCount: 342,
    priceRange: "$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Urban Cafe",
    description: "Hip coffee roastery with all-day brunch menu",
    address: "30 Melbourne Street, South Brisbane QLD 4101",
    phone: "+61 7 3846 1111",
    website: "https://www.urbancafe.com.au",
    cuisineTypes: ["Cafe", "Breakfast", "Coffee"],
    imageUrl: "https://images.unsplash.com/photo-1541521227883-2ee70e7dc95f?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4790, longitude: 153.0220 },
    rating: 4.6,
    reviewCount: 612,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Brew & Co",
    description: "Craft beer brewery with gastropub menu",
    address: "123 Boundary Street, West End QLD 4101",
    phone: "+61 7 3846 5555",
    website: "https://www.brewco.com.au",
    cuisineTypes: ["Pub Food", "Craft Beer", "Burgers"],
    imageUrl: "https://images.unsplash.com/photo-1535958636474-b021ee887b13?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4780, longitude: 153.0185 },
    rating: 4.4,
    reviewCount: 478,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "The Egg Kitchen",
    description: "Brunch specialist with creative egg dishes",
    address: "57 Paddington Street, Paddington QLD 4064",
    phone: "+61 7 3369 2222",
    website: "https://www.theeggkitchen.com.au",
    cuisineTypes: ["Brunch", "Breakfast", "Contemporary"],
    imageUrl: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4620, longitude: 153.0045 },
    rating: 4.5,
    reviewCount: 389,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Black Star Coffee",
    description: "Specialty coffee roastery and espresso bar",
    address: "42 Paddington Street, Paddington QLD 4064",
    phone: "+61 7 3369 8844",
    website: "https://www.blackstarcoffee.com.au",
    cuisineTypes: ["Coffee", "Cafe"],
    imageUrl: "https://images.unsplash.com/photo-1528316292326-25ac2976b480?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4625, longitude: 153.0040 },
    rating: 4.7,
    reviewCount: 523,
    priceRange: "$",
    createdAt: new Date().toISOString()
  },
  {
    name: "The Olive Tree",
    description: "Mediterranean cuisine with fresh seasonal ingredients",
    address: "Level 1, 100 Eagle Street, Brisbane QLD 4000",
    phone: "+61 7 3211 7777",
    website: "https://www.theolivetree.com.au",
    cuisineTypes: ["Mediterranean", "European", "Greek"],
    imageUrl: "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4720, longitude: 153.0335 },
    rating: 4.6,
    reviewCount: 301,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Bella Napoli",
    description: "Traditional Italian pizzeria with wood-fired oven",
    address: "51 James Street, Fortitude Valley QLD 4006",
    phone: "+61 7 3852 3333",
    website: "https://www.bellanapoli.com.au",
    cuisineTypes: ["Italian", "Pizza", "European"],
    imageUrl: "https://images.unsplash.com/photo-1555939594-58d7cb561549?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4645, longitude: 153.0368 },
    rating: 4.5,
    reviewCount: 445,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Greek Taverna",
    description: "Authentic Greek restaurant with family recipes",
    address: "65 Toorak Road, Toorak QLD 4066",
    phone: "+61 7 3371 2244",
    website: "https://www.greektaverna.com.au",
    cuisineTypes: ["Greek", "Mediterranean", "European"],
    imageUrl: "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4600, longitude: 153.0080 },
    rating: 4.4,
    reviewCount: 267,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Spice Route",
    description: "Indian cuisine with modern fusion elements",
    address: "Level 2, Fortitude Valley, Brisbane QLD 4006",
    phone: "+61 7 3852 8899",
    website: "https://www.spiceroute.com.au",
    cuisineTypes: ["Indian", "Curry", "Fusion"],
    imageUrl: "https://images.unsplash.com/photo-1606787620121-c282293b5956?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4648, longitude: 153.0370 },
    rating: 4.3,
    reviewCount: 334,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Maharaja Palace",
    description: "Premium Indian fine dining experience",
    address: "123 Adelaide Street, Brisbane QLD 4000",
    phone: "+61 7 3210 5555",
    website: "https://www.maharajapalace.com.au",
    cuisineTypes: ["Indian", "Fine Dining", "Curry"],
    imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4705, longitude: 153.0305 },
    rating: 4.6,
    reviewCount: 412,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Riverfront Kitchen",
    description: "Casual dining with river views and fresh local produce",
    address: "South Bank Parklands, Brisbane QLD 4101",
    phone: "+61 7 3846 2222",
    website: "https://www.riverfrontkitchen.com.au",
    cuisineTypes: ["Modern Australian", "Casual"],
    imageUrl: "https://images.unsplash.com/photo-1414235077418-3a2c2b8d15e5?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4800, longitude: 153.0200 },
    rating: 4.5,
    reviewCount: 556,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Local Harvest",
    description: "Farm-to-table restaurant celebrating Brisbane produce",
    address: "47 Burnett Lane, Brisbane QLD 4000",
    phone: "+61 7 3229 4444",
    website: "https://www.localharvest.com.au",
    cuisineTypes: ["Modern Australian", "Farm-to-Table"],
    imageUrl: "https://images.unsplash.com/photo-1537381052736-fe75a628f8c0?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4730, longitude: 153.0340 },
    rating: 4.7,
    reviewCount: 478,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "The Pantry",
    description: "European delicatessen with artisanal products",
    address: "32 Charlotte Street, Brisbane QLD 4000",
    phone: "+61 7 3221 8899",
    website: "https://www.thepantry.com.au",
    cuisineTypes: ["European", "Deli", "Cafe"],
    imageUrl: "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4745, longitude: 153.0325 },
    rating: 4.4,
    reviewCount: 289,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Burger Bros",
    description: "Gourmet burger bar with premium beef selections",
    address: "55 James Street, Fortitude Valley QLD 4006",
    phone: "+61 7 3852 9999",
    website: "https://www.burgerbrosz.com.au",
    cuisineTypes: ["Burgers", "American", "Fast Casual"],
    imageUrl: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4643, longitude: 153.0365 },
    rating: 4.3,
    reviewCount: 534,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Craft Burger Co",
    description: "Artisanal burgers with craft beer selection",
    address: "Level 1, 99 Elizabeth Street, Brisbane QLD 4000",
    phone: "+61 7 3211 3333",
    website: "https://www.craftburgerco.com.au",
    cuisineTypes: ["Burgers", "American", "Pub Food"],
    imageUrl: "https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4725, longitude: 153.0310 },
    rating: 4.5,
    reviewCount: 401,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "The Fish House",
    description: "Seafood specialist with fresh daily catches",
    address: "Riverside Centre, Brisbane QLD 4000",
    phone: "+61 7 3211 7788",
    website: "https://www.thefishhouse.com.au",
    cuisineTypes: ["Seafood", "Modern Australian"],
    imageUrl: "https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4740, longitude: 153.0350 },
    rating: 4.7,
    reviewCount: 423,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Oyster Lounge",
    description: "Upmarket oyster bar with champagne selection",
    address: "Level 35, 111 Eagle Street, Brisbane QLD 4000",
    phone: "+61 7 3211 5544",
    website: "https://www.oysterlounge.com.au",
    cuisineTypes: ["Seafood", "Oysters", "Fine Dining"],
    imageUrl: "https://images.unsplash.com/photo-1589985643453-16381f00de64?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4710, longitude: 153.0338 },
    rating: 4.8,
    reviewCount: 356,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Taco Fiesta",
    description: "Mexican street food with authentic recipes",
    address: "42 James Street, Fortitude Valley QLD 4006",
    phone: "+61 7 3852 6666",
    website: "https://www.tacofiesta.com.au",
    cuisineTypes: ["Mexican", "Street Food", "Latin American"],
    imageUrl: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4640, longitude: 153.0360 },
    rating: 4.2,
    reviewCount: 278,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Hacienda",
    description: "Upscale Mexican restaurant with regional specialties",
    address: "Level 2, 200 Queen Street, Brisbane QLD 4000",
    phone: "+61 7 3221 2211",
    website: "https://www.hacienda.com.au",
    cuisineTypes: ["Mexican", "Latin American", "Fine Dining"],
    imageUrl: "https://images.unsplash.com/photo-1567521464027-f127ff144326?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4705, longitude: 153.0315 },
    rating: 4.5,
    reviewCount: 312,
    priceRange: "$$$",
    createdAt: new Date().toISOString()
  },
  {
    name: "Seoul Kitchen",
    description: "Korean BBQ and modern Korean cuisine",
    address: "39 King Street, Brisbane QLD 4000",
    phone: "+61 7 3210 1234",
    website: "https://www.seoulkitchen.com.au",
    cuisineTypes: ["Korean", "BBQ", "Asian"],
    imageUrl: "https://images.unsplash.com/photo-1555661662-0ac8b3c8f2e6?w=400&h=300&fit=crop",
    coordinates: { latitude: -27.4750, longitude: 153.0290 },
    rating: 4.6,
    reviewCount: 389,
    priceRange: "$$",
    createdAt: new Date().toISOString()
  }
];

async function seedBusinesses() {
  console.log('\n╔════════════════════════════════════════════════════════════════╗');
  console.log('║  FIRESTORE SEEDING - ADMIN SDK (Direct Write)                  ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  let successCount = 0;
  let failureCount = 0;

  console.log(`🚀 Seeding ${businesses.length} Brisbane CBD food businesses...\n`);

  for (let i = 0; i < businesses.length; i++) {
    const business = businesses[i];
    const index = i + 1;

    try {
      // Generate a readable ID from the business name
      const readableId = business.name
        .toLowerCase()
        .replace(/\s+/g, '_')
        .replace(/[^a-z0-9_]/g, '');

      // Write directly to Firestore using Admin SDK
      await db.collection('food_businesses').doc(readableId).set(business, { merge: true });
      
      console.log(`✓ [${index}/27] ${business.name} - Seeded`);
      successCount++;
    } catch (error) {
      console.log(`❌ [${index}/27] ${business.name}: ${error.message}`);
      failureCount++;
    }
  }

  console.log(`\n${'='.repeat(64)}`);
  console.log(`✅ Successfully seeded: ${successCount} businesses`);
  if (failureCount > 0) {
    console.log(`❌ Failed: ${failureCount} businesses`);
  }
  console.log(`📊 Total: ${businesses.length} businesses`);
  console.log(`${'='.repeat(64)}\n`);

  if (successCount === businesses.length) {
    console.log('🎉 All Brisbane food businesses seeded successfully!');
    console.log('📱 The businesses are now available in the BrisConnect app.\n');
  }

  process.exit(successCount === businesses.length ? 0 : 1);
}

// Run the seeding
seedBusinesses().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
