/**
 * Manual seed for Google-sourced Brisbane food places.
 *
 * Seeds popular Brisbane restaurants, cafes, and food precincts into
 * discover_items with section "food" and human-readable IDs.
 *
 * Usage:
 *   cd functions
 *   node seed_google_food_places.js
 */

const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(
  path.resolve("C:/Users/ibzso/Downloads/brisconnect-68b78-firebase-adminsdk-fbsvc-efef6e1518.json")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const now = admin.firestore.FieldValue.serverTimestamp();

const foodPlaces = [
  // --- Precincts & Markets ---
  {
    id: "google-food-south-bank-little-stanley-street",
    title: "Little Stanley Street",
    suburb: "South Brisbane",
    location: "Little Stanley St, South Brisbane",
    latitude: -27.4808, longitude: 153.0228,
    cuisine: "Dining precinct",
    price: "$$",
    dateTime: "Open daily",
    description: "A bustling dining strip in South Bank with dozens of restaurants, cafes, and bars offering cuisines from around the world. Popular for pre-show dining near QPAC.",
    categories: ["Food", "Dining", "Culture"],
    websiteUri: "https://www.visitsouthbank.com.au/",
    rating: 4.4, userRatingCount: 6200,
  },
  {
    id: "google-food-james-street-precinct",
    title: "James Street Precinct",
    suburb: "Fortitude Valley",
    location: "James St, Fortitude Valley",
    latitude: -27.4540, longitude: 153.0380,
    cuisine: "Fine dining & cafes",
    price: "$$$",
    dateTime: "Open daily",
    description: "Brisbane's premium dining and lifestyle precinct featuring award-winning restaurants, boutique shopping, and chic cafes in a leafy, walkable streetscape.",
    categories: ["Food", "Fine Dining", "Lifestyle"],
    websiteUri: "https://www.jamesst.com.au/",
    rating: 4.5, userRatingCount: 4800,
  },
  {
    id: "google-food-boundary-street-west-end",
    title: "Boundary Street, West End",
    suburb: "West End",
    location: "Boundary St, West End",
    latitude: -27.4840, longitude: 153.0100,
    cuisine: "Multicultural",
    price: "$$",
    dateTime: "Open daily",
    description: "A vibrant multicultural food strip in West End packed with Vietnamese, Greek, Italian, and modern Australian eateries. The Saturday Davies Park Markets are a foodie highlight.",
    categories: ["Food", "Multicultural", "Markets"],
    rating: 4.5, userRatingCount: 5100,
  },
  {
    id: "google-food-davies-park-market",
    title: "Davies Park Market",
    suburb: "West End",
    location: "Davies Park, West End",
    latitude: -27.4870, longitude: 153.0060,
    cuisine: "Fresh produce & street food",
    price: "$",
    dateTime: "Saturday mornings",
    description: "A beloved Saturday morning market offering fresh local produce, artisan baked goods, multicultural street food, and handmade crafts in a riverside park setting.",
    categories: ["Food", "Markets", "Family"],
    rating: 4.6, userRatingCount: 3800,
  },
  {
    id: "google-food-jan-powers-farmers-market",
    title: "Jan Powers Farmers Markets",
    suburb: "Brisbane City",
    location: "Brisbane Powerhouse, New Farm",
    latitude: -27.4527, longitude: 153.0456,
    cuisine: "Fresh produce & artisan food",
    price: "$",
    dateTime: "Saturday mornings",
    description: "One of Brisbane's longest-running farmers markets, held at the Powerhouse every Saturday. Known for farm-fresh produce, gourmet treats, and a community-friendly atmosphere.",
    categories: ["Food", "Markets", "Family"],
    websiteUri: "https://www.janpowersfarmersmarkets.com.au/",
    rating: 4.5, userRatingCount: 2900,
  },

  // --- Restaurants & Cafes ---
  {
    id: "google-food-e-oi",
    title: "e'cco bistro",
    suburb: "Brisbane City",
    location: "63 Adelaide St, Brisbane City",
    latitude: -27.4690, longitude: 153.0265,
    cuisine: "Modern Australian",
    price: "$$$",
    dateTime: "Lunch & Dinner",
    description: "An iconic Brisbane fine-dining restaurant serving modern Australian cuisine with seasonal, locally sourced ingredients. Multiple award winner and a Brisbane institution since 1995.",
    categories: ["Food", "Fine Dining", "Australian"],
    websiteUri: "https://eccobistro.com.au/",
    rating: 4.5, userRatingCount: 2400,
  },
  {
    id: "google-food-gauge",
    title: "Gauge",
    suburb: "South Brisbane",
    location: "77 Grey St, South Brisbane",
    latitude: -27.4730, longitude: 153.0180,
    cuisine: "Modern Australian",
    price: "$$$",
    dateTime: "Lunch & Dinner",
    description: "A contemporary restaurant in the heart of South Bank featuring a regularly evolving menu of modern Australian dishes. Known for its elegant yet unpretentious atmosphere.",
    categories: ["Food", "Fine Dining", "Australian"],
    rating: 4.4, userRatingCount: 1800,
  },
  {
    id: "google-food-happy-boy",
    title: "Happy Boy",
    suburb: "South Brisbane",
    location: "53 Hope St, South Brisbane",
    latitude: -27.4795, longitude: 153.0195,
    cuisine: "Chinese",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A modern Chinese restaurant from acclaimed Brisbane chef Ben Williamson. Serves inventive dishes inspired by regional Chinese cooking with local produce and bold flavours.",
    categories: ["Food", "Chinese", "Asian"],
    rating: 4.3, userRatingCount: 2100,
  },
  {
    id: "google-food-longtime",
    title: "Longtime",
    suburb: "Fortitude Valley",
    location: "196 Ann St, Fortitude Valley",
    latitude: -27.4570, longitude: 153.0310,
    cuisine: "Southeast Asian",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A lively Southeast Asian eatery known for its share-plate menu, creative cocktails, and vibrant atmosphere. Features flavours from Thailand, Laos, and Vietnam.",
    categories: ["Food", "Asian", "Bars"],
    websiteUri: "https://longtime.com.au/",
    rating: 4.3, userRatingCount: 3200,
  },
  {
    id: "google-food-julius-pizzeria",
    title: "Julius Pizzeria",
    suburb: "South Brisbane",
    location: "77 Grey St, South Brisbane",
    latitude: -27.4726, longitude: 153.0178,
    cuisine: "Italian / Pizza",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A beloved Brisbane pizzeria serving Neapolitan-style wood-fired pizza with locally sourced toppings. Located in the bustling Fish Lane precinct near South Bank.",
    categories: ["Food", "Italian", "Pizza"],
    rating: 4.5, userRatingCount: 4200,
  },
  {
    id: "google-food-king-arthur-cafe",
    title: "King Arthur Cafe",
    suburb: "New Farm",
    location: "130 Merthyr Rd, New Farm",
    latitude: -27.4630, longitude: 153.0480,
    cuisine: "Breakfast & Brunch",
    price: "$$",
    dateTime: "Breakfast & Lunch",
    description: "A popular New Farm brunch spot known for its creative breakfast dishes, specialty coffee, and relaxed neighbourhood vibe. Often has a weekend queue.",
    categories: ["Food", "Cafe", "Brunch"],
    rating: 4.4, userRatingCount: 2600,
  },
  {
    id: "google-food-le-bon-choix",
    title: "Le Bon Choix",
    suburb: "Brisbane City",
    location: "29 Mary St, Brisbane City",
    latitude: -27.4706, longitude: 153.0282,
    cuisine: "French patisserie",
    price: "$$",
    dateTime: "Breakfast & Lunch",
    description: "An authentic French patisserie in the CBD offering freshly baked croissants, tarts, quiches, and artisan breads. A slice of Paris in Brisbane.",
    categories: ["Food", "French", "Cafe"],
    rating: 4.6, userRatingCount: 1900,
  },
  {
    id: "google-food-south-bank-surf-club",
    title: "South Bank Surf Club",
    suburb: "South Brisbane",
    location: "Stanley St Plaza, South Brisbane",
    latitude: -27.4800, longitude: 153.0225,
    cuisine: "Australian pub food",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A quirky, retro-styled surf club right by Streets Beach. Offers classic pub fare, cocktails, and unbeatable views of the Brisbane skyline.",
    categories: ["Food", "Australian", "Bars"],
    rating: 4.2, userRatingCount: 3500,
  },
  {
    id: "google-food-riverbar-and-kitchen",
    title: "Riverbar & Kitchen",
    suburb: "Brisbane City",
    location: "71 Eagle St Pier, Brisbane City",
    latitude: -27.4670, longitude: 153.0310,
    cuisine: "Modern Australian",
    price: "$$$",
    dateTime: "Lunch & Dinner",
    description: "A riverside dining destination at Eagle Street Pier offering stunning river and bridge views, modern Australian cuisine, and a popular cocktail bar.",
    categories: ["Food", "Fine Dining", "Waterfront"],
    rating: 4.3, userRatingCount: 2800,
  },
  {
    id: "google-food-the-charming-squire",
    title: "The Charming Squire",
    suburb: "South Brisbane",
    location: "133 Grey St, South Brisbane",
    latitude: -27.4745, longitude: 153.0173,
    cuisine: "Craft beer & gastropub",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A James Squire brewhouse in South Bank offering craft beer, hearty gastropub meals, and a large outdoor terrace. Popular pre- and post-event dining near QPAC.",
    categories: ["Food", "Bars", "Pub"],
    rating: 4.2, userRatingCount: 4000,
  },
  {
    id: "google-food-stokehouse-q",
    title: "Stokehouse Q",
    suburb: "South Brisbane",
    location: "Sidon St, South Brisbane",
    latitude: -27.4798, longitude: 153.0220,
    cuisine: "Modern Australian",
    price: "$$$$",
    dateTime: "Lunch & Dinner",
    description: "An upscale waterfront restaurant overlooking the Brisbane River. Stokehouse Q offers refined modern Australian cuisine with a focus on seafood and seasonal produce.",
    categories: ["Food", "Fine Dining", "Waterfront"],
    websiteUri: "https://www.stokehouseq.com.au/",
    rating: 4.4, userRatingCount: 3100,
  },
  {
    id: "google-food-nodo-donuts",
    title: "Nodo",
    suburb: "Newstead",
    location: "1 Breakfast Creek Rd, Newstead",
    latitude: -27.4490, longitude: 153.0440,
    cuisine: "Gluten-free donuts & brunch",
    price: "$$",
    dateTime: "Breakfast & Lunch",
    description: "Brisbane's famous gluten-free donut shop and cafe. Nodo serves colourful handcrafted donuts alongside a full brunch menu using wholesome, locally sourced ingredients.",
    categories: ["Food", "Cafe", "Healthy"],
    websiteUri: "https://nfrg.com.au/",
    rating: 4.5, userRatingCount: 3400,
  },
  {
    id: "google-food-morning-after",
    title: "Morning After",
    suburb: "Brisbane City",
    location: "339 Brunswick St, Fortitude Valley",
    latitude: -27.4560, longitude: 153.0355,
    cuisine: "Breakfast & Brunch",
    price: "$$",
    dateTime: "Breakfast & Lunch",
    description: "A popular brunch destination in Fortitude Valley known for Instagram-worthy dishes, creative flavour combinations, and a fun, vibrant setting.",
    categories: ["Food", "Cafe", "Brunch"],
    rating: 4.3, userRatingCount: 2400,
  },
  {
    id: "google-food-the-bavarian-eagle-street",
    title: "The Bavarian",
    suburb: "Brisbane City",
    location: "Eagle Street Pier, Brisbane City",
    latitude: -27.4668, longitude: 153.0305,
    cuisine: "German",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A German-inspired beer hall at Eagle Street serving pork knuckle, schnitzels, pretzels, and an extensive German beer list with views over the Brisbane River.",
    categories: ["Food", "German", "Bars"],
    rating: 4.1, userRatingCount: 3700,
  },
  {
    id: "google-food-sunnybank-plaza-food-court",
    title: "Sunnybank Plaza Food Court",
    suburb: "Sunnybank",
    location: "358 Mains Rd, Sunnybank",
    latitude: -27.5790, longitude: 153.0610,
    cuisine: "Asian food court",
    price: "$",
    dateTime: "Open daily",
    description: "Widely regarded as Brisbane's best Asian food court. A huge range of authentic Chinese, Vietnamese, Korean, Japanese, and Malaysian dining under one roof.",
    categories: ["Food", "Asian", "Budget"],
    rating: 4.3, userRatingCount: 5500,
  },
  {
    id: "google-food-gemelli-italian",
    title: "Gemelli Italian",
    suburb: "Broadbeach / Brisbane City",
    location: "100 Boundary St, West End",
    latitude: -27.4842, longitude: 153.0105,
    cuisine: "Italian",
    price: "$$",
    dateTime: "Lunch & Dinner",
    description: "A lively Italian restaurant in West End serving handmade pasta, woodfired pizza, and classic Italian dishes in a warm, family-friendly atmosphere.",
    categories: ["Food", "Italian", "Family"],
    rating: 4.4, userRatingCount: 2900,
  },
  {
    id: "google-food-fish-lane-precinct",
    title: "Fish Lane Precinct",
    suburb: "South Brisbane",
    location: "Fish Lane, South Brisbane",
    latitude: -27.4738, longitude: 153.0170,
    cuisine: "Laneway dining",
    price: "$$",
    dateTime: "Open daily",
    description: "A creative laneway precinct near South Bank transformed from an industrial strip into one of Brisbane's coolest dining destinations with bars, restaurants, and street art.",
    categories: ["Food", "Dining", "Culture"],
    rating: 4.5, userRatingCount: 4100,
  },
  {
    id: "google-food-1889-enoteca",
    title: "1889 Enoteca",
    suburb: "Woolloongabba",
    location: "12 Logan Rd, Woolloongabba",
    latitude: -27.4880, longitude: 153.0370,
    cuisine: "Italian wine bar",
    price: "$$$",
    dateTime: "Dinner",
    description: "An intimate Italian wine bar and restaurant near The Gabba serving seasonal pasta, antipasti, and an outstanding wine list in a cosy heritage-listed building.",
    categories: ["Food", "Italian", "Wine"],
    rating: 4.5, userRatingCount: 1600,
  },
  {
    id: "google-food-plenty-valley",
    title: "Plenty",
    suburb: "Fortitude Valley",
    location: "284 Brunswick St, Fortitude Valley",
    latitude: -27.4565, longitude: 153.0345,
    cuisine: "Modern Australian / Brunch",
    price: "$$",
    dateTime: "Breakfast & Lunch",
    description: "A beloved brunch cafe in the Valley known for its creative seasonal breakfast menu, house-baked goods, and specialty coffee.",
    categories: ["Food", "Cafe", "Brunch"],
    rating: 4.4, userRatingCount: 2100,
  },
  {
    id: "google-food-hellenika",
    title: "Hellenika",
    suburb: "Fortitude Valley",
    location: "14 James St, Fortitude Valley",
    latitude: -27.4540, longitude: 153.0375,
    cuisine: "Greek",
    price: "$$$",
    dateTime: "Lunch & Dinner",
    description: "Simon Gloftis' celebrated Greek restaurant on James Street, serving refined modern Greek dishes using traditional techniques and the freshest local seafood.",
    categories: ["Food", "Greek", "Fine Dining"],
    websiteUri: "https://www.hellenika.com.au/",
    rating: 4.4, userRatingCount: 3600,
  },
];

async function seed() {
  console.log("=== Seeding Google-sourced food places ===\n");

  const batch = db.batch();

  for (const f of foodPlaces) {
    const ref = db.collection("discover_items").doc(f.id);
    batch.set(ref, {
      id: f.id,
      section: "food",
      title: f.title,
      suburb: f.suburb,
      location: f.location,
      latitude: f.latitude,
      longitude: f.longitude,
      cuisine: f.cuisine,
      price: f.price,
      dateTime: f.dateTime,
      description: f.description,
      categories: f.categories,
      webLink: f.websiteUri || "",
      imageUrl: "",
      badge: "Food",
      mapQuery: `${f.title} ${f.suburb} Brisbane`,
      source: "Google Places",
      sourceProvider: "google_places",
      approvalStatus: "approved",
      importedFrom: "google_places_catalog",
      updatedAt: now,
    }, { merge: true });
  }

  await batch.commit();
  console.log(`  ✓ ${foodPlaces.length} food places written to discover_items\n`);

  // Print all food items
  const snap = await db.collection("discover_items").get();
  const foods = snap.docs.filter((d) => d.data().section === "food");
  console.log(`Total food discover_items: ${foods.length}`);
  foods.forEach((d) => console.log(`  ${d.id}`));

  console.log("\nDone!");
  process.exit(0);
}

seed().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
