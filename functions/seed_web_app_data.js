/**
 * Seed script for web app data (events, attractions, categories).
 *
 * Seeds sample events, attractions, and categories into Firestore
 * for the BrisConnect+ web application.
 *
 * Usage:
 *   cd functions
 *   npm install firebase-admin
 *   node seed_web_app_data.js
 */

const admin = require("firebase-admin");

// Initialize Firebase using environment or default credentials
if (!admin.apps.length) {
  try {
    // Try to use default credentials (from GOOGLE_APPLICATION_CREDENTIALS env var)
    admin.initializeApp({
      projectId: "brisconnect-68b78",
    });
  } catch (error) {
    console.log("Using default credentials from environment...");
    admin.initializeApp();
  }
}

const db = admin.firestore();

// ─── EVENT CATEGORIES ────────────────────────────────────────────────────────

const categories = [
  { name: "Music", color: "#FF6B6B", icon: "music_note" },
  { name: "Sports", color: "#4ECDC4", icon: "sports_soccer" },
  { name: "Art & Culture", color: "#FFE66D", icon: "palette" },
  { name: "Food & Drink", color: "#95E1D3", icon: "restaurant" },
  { name: "Community", color: "#C7CEEA", icon: "people" },
  { name: "Family", color: "#FF9FF3", icon: "family_restroom" },
  { name: "Education", color: "#54A0FF", icon: "school" },
  { name: "Markets", color: "#48DBFB", icon: "storefront" },
];

// ─── EVENTS ──────────────────────────────────────────────────────────────────

const events = [
  {
    title: "Brisbane Festival 2026",
    category: "Music",
    description: "The annual Brisbane Festival celebrates diverse performing arts with theatre, dance, music, visual art and family events.",
    imageUrl: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&h=300&fit=crop",
    date: "2026-09-01",
    location: "South Bank Parklands",
    latitude: -27.4810,
    longitude: 153.0228,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane Powerhouse Comedy Show",
    category: "Art & Culture",
    description: "World-class comedy performances at Brisbane's premier arts venue in New Farm.",
    imageUrl: "https://images.unsplash.com/photo-1514306688286-2ad16fe4f947?w=500&h=300&fit=crop",
    date: "2026-08-15",
    location: "Brisbane Powerhouse, New Farm",
    latitude: -27.4610,
    longitude: 153.0550,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "South Bank Markets",
    category: "Markets",
    description: "Fresh produce, craft items, and local goods every Saturday and Sunday at South Bank Parklands.",
    imageUrl: "https://images.unsplash.com/photo-1488459716781-6d7d73c2c640?w=500&h=300&fit=crop",
    date: "2026-08-09",
    location: "South Bank Parklands",
    latitude: -27.4820,
    longitude: 153.0190,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane Music Festival",
    category: "Music",
    description: "A celebration of live music featuring local and international artists across multiple venues in Brisbane.",
    imageUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&h=300&fit=crop",
    date: "2026-10-03",
    location: "Multiple Venues",
    latitude: -27.4698,
    longitude: 153.0251,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane Food & Wine Festival",
    category: "Food & Drink",
    description: "Celebrate Brisbane's culinary scene with food stalls, wine tastings, and cooking demonstrations.",
    imageUrl: "https://images.unsplash.com/photo-1555939594-58d7cb561404?w=500&h=300&fit=crop",
    date: "2026-09-15",
    location: "Eagle Street Pier",
    latitude: -27.4715,
    longitude: 153.0309,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane Ekka",
    category: "Family",
    description: "The Royal Queensland Show is a major annual event featuring rides, entertainment, and agricultural displays.",
    imageUrl: "https://images.unsplash.com/photo-1533753322935-ed3fa643f033?w=500&h=300&fit=crop",
    date: "2026-08-12",
    location: "Brisbane Showgrounds",
    latitude: -27.5150,
    longitude: 153.0870,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
];

// ─── ATTRACTIONS ─────────────────────────────────────────────────────────────

const attractions = [
  {
    title: "South Bank Parklands",
    category: "Art & Culture",
    description: "A cultural oasis featuring gardens, museums, galleries, and cultural institutions in a 17-hectare riverside precinct.",
    imageUrl: "https://images.unsplash.com/photo-1469515782759-481cda802842?w=500&h=300&fit=crop",
    location: "South Bank Parklands",
    latitude: -27.4810,
    longitude: 153.0228,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Story Bridge",
    category: "Art & Culture",
    description: "An iconic steel cantilever bridge offering panoramic views of Brisbane and the Brisbane River from the Story Bridge ClimbTM.",
    imageUrl: "https://images.unsplash.com/photo-1570361235855-9f834042e8f3?w=500&h=300&fit=crop",
    location: "Story Bridge",
    latitude: -27.4635,
    longitude: 153.0358,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Lone Pine Koala Sanctuary",
    category: "Family",
    description: "Australia's first and most popular wildlife sanctuary where you can interact with native Australian animals including koalas and kangaroos.",
    imageUrl: "https://images.unsplash.com/photo-1478098711619-69891b0ec21a?w=500&h=300&fit=crop",
    location: "Fig Tree Pocket",
    latitude: -27.5360,
    longitude: 152.9880,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane City Botanic Gardens",
    category: "Community",
    description: "A peaceful 12-hectare garden featuring tropical plants, palms, ferns, and scenic walking paths along the Brisbane River.",
    imageUrl: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=500&h=300&fit=crop",
    location: "Alice St, Brisbane",
    latitude: -27.4762,
    longitude: 153.0219,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Queensland Museum & Sciencentre",
    category: "Education",
    description: "An interactive museum featuring natural history, dinosaurs, cultural artifacts, and hands-on science exhibitions.",
    imageUrl: "https://images.unsplash.com/photo-1578926078328-123b82f29bda?w=500&h=300&fit=crop",
    location: "South Bank Parklands",
    latitude: -27.4820,
    longitude: 153.0190,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Gallery of Modern Art (GOMA)",
    category: "Art & Culture",
    description: "Queensland's premier contemporary art museum showcasing modern and contemporary Australian and international art.",
    imageUrl: "https://images.unsplash.com/photo-1577720643272-265f434e36f9?w=500&h=300&fit=crop",
    location: "South Bank Parklands",
    latitude: -27.4845,
    longitude: 153.0210,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Brisbane City Hall",
    category: "Art & Culture",
    description: "An iconic Italian Renaissance-style building with a 91-metre clock tower and housed museum, offering heritage tours and cultural events.",
    imageUrl: "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=500&h=300&fit=crop",
    location: "King George Square",
    latitude: -27.46885,
    longitude: 153.02449,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    title: "Mount Coot-tha Lookout",
    category: "Community",
    description: "A scenic hilltop offering 360-degree panoramic views of Brisbane, the Brisbane River, Moreton Bay Islands, and surrounding regions.",
    imageUrl: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500&h=300&fit=crop",
    location: "Mount Coot-tha",
    latitude: -27.4789,
    longitude: 153.0059,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
];

// ─── SEED DATABASE ────────────────────────────────────────────────────────────

async function seedDatabase() {
  try {
    console.log("🌱 Starting database seeding...\n");

    // Seed categories
    console.log("📂 Seeding event categories...");
    const categoriesRef = db.collection("event_categories");
    for (const category of categories) {
      await categoriesRef.add(category);
    }
    console.log(`✅ Added ${categories.length} categories\n`);

    // Seed events
    console.log("🎉 Seeding events...");
    const eventsRef = db.collection("events");
    for (const event of events) {
      await eventsRef.add(event);
    }
    console.log(`✅ Added ${events.length} events\n`);

    // Seed attractions
    console.log("🏛️ Seeding attractions...");
    const attractionsRef = db.collection("approved_attractions");
    for (const attraction of attractions) {
      await attractionsRef.add(attraction);
    }
    console.log(`✅ Added ${attractions.length} attractions\n`);

    console.log("🎉 Database seeding complete!\n");
    process.exit(0);
  } catch (error) {
    console.error("❌ Error seeding database:", error);
    process.exit(1);
  }
}

// Run the seed
seedDatabase();
