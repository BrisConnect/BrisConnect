/**
 * Re-trigger BCC Catalog Sync + Google Places → Discover Items conversion
 * using the new human-readable document ID logic.
 *
 * NOTE: The Google Places *import* (fetching from Google API) requires
 * an API key stored in Firebase Secrets. Trigger that from the app's
 * admin panel, then re-run this script to convert to discover_items.
 *
 * Usage:
 *   cd functions
 *   node retrigger_sync.js
 */

const admin = require("firebase-admin");
const path = require("path");

const serviceAccount = require(
  path.resolve("C:/Users/ibzso/Downloads/brisconnect-68b78-firebase-adminsdk-fbsvc-efef6e1518.json")
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// --- Inline the core functions from index.js with the updated ID logic ---

const crypto = require("crypto");
const https = require("https");

const db = admin.firestore();

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function determineDiscoverSection(types) {
  if (!Array.isArray(types)) return 'food';
  const typeStr = types.join('|').toLowerCase();
  if (typeStr.includes('museum') || typeStr.includes('art_gallery') || typeStr.includes('historical') || typeStr.includes('church') || typeStr.includes('place_of_worship')) return 'historical';
  if (typeStr.includes('park') || typeStr.includes('zoo') || typeStr.includes('aquarium') || typeStr.includes('amusement') || typeStr.includes('tourist_attraction') || typeStr.includes('point_of_interest') || typeStr.includes('stadium') || typeStr.includes('campground') || typeStr.includes('natural_feature')) return 'attraction';
  if (typeStr.includes('restaurant') || typeStr.includes('cafe') || typeStr.includes('bar') || typeStr.includes('bakery') || typeStr.includes('meal') || typeStr.includes('food')) return 'food';
  return 'food';
}

async function convertGooglePlacesToDiscoverItems() {
  const attractionsSnapshot = await db
    .collection('attractions')
    .where('sourceProvider', '==', 'google_places')
    .where('approvalStatus', '==', 'approved')
    .get();

  const eventsSnapshot = await db
    .collection('events')
    .where('sourceProvider', '==', 'google_places')
    .where('approvalStatus', '==', 'approved')
    .get();

  let itemCount = 0;
  let writeCount = 0;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const chunkSize = 400;
  const allWrites = [];

  attractionsSnapshot.docs.forEach((doc) => {
    const attraction = doc.data();
    const sourceTypes = Array.isArray(attraction.sourceTypes) ? attraction.sourceTypes : [];
    const section = determineDiscoverSection(sourceTypes);

    const discoverItem = {
      id: `discover_${attraction.id}`,
      section,
      title: attraction.name,
      description: attraction.description,
      imageUrl: attraction.imageUrl,
      location: attraction.location,
      latitude: attraction.latitude,
      longitude: attraction.longitude,
      categories: ['google_places', section, ...sourceTypes.slice(0, 3)],
      webLink: attraction.webLink,
      badge: 'Imported',
      approvalStatus: 'approved',
      sourceProvider: 'google_places',
      sourceAttractionId: attraction.id,
      sourcePlaceId: attraction.sourcePlaceId || null,
      importedFrom: 'google_places_catalog',
      updatedAt: now,
    };

    allWrites.push({ collection: 'discover_items', record: discoverItem });
    itemCount += 1;
  });

  eventsSnapshot.docs.forEach((doc) => {
    const event = doc.data();

    const discoverItem = {
      id: `discover_${event.id}`,
      section: 'events',
      title: event.title || event.venue,
      description: event.description,
      imageUrl: event.imageUrl,
      location: event.location,
      venue: event.venue,
      suburb: event.suburb,
      date: event.date,
      time: event.time,
      latitude: event.latitude,
      longitude: event.longitude,
      categories: ['google_places', 'events', 'venue'],
      badge: 'Imported',
      approvalStatus: 'approved',
      sourceProvider: 'google_places',
      sourceEventId: event.id,
      sourcePlaceId: event.sourcePlaceId || null,
      importedFrom: 'google_places_catalog',
      updatedAt: now,
    };

    allWrites.push({ collection: 'discover_items', record: discoverItem });
    itemCount += 1;
  });

  for (let index = 0; index < allWrites.length; index += chunkSize) {
    const chunk = allWrites.slice(index, index + chunkSize);
    const batch = db.batch();
    for (const item of chunk) {
      const ref = db.collection(item.collection).doc(item.record.id);
      batch.set(ref, item.record, { merge: true });
      writeCount += 1;
    }
    await batch.commit();
  }

  return { attractionCount: attractionsSnapshot.docs.length, eventCount: eventsSnapshot.docs.length, itemCount, writeCount };
}

async function run() {
  console.log("=== Re-triggering Google Places → discover_items conversion ===\n");
  const gpResult = await convertGooglePlacesToDiscoverItems();
  console.log("  Google Places → discover_items:", gpResult);

  console.log("\n=== Sampling new document IDs ===\n");

  for (const coll of ["discover_items", "events", "attractions"]) {
    const snap = await db.collection(coll).limit(10).get();
    console.log(`${coll} (first 10 of ${(await db.collection(coll).count().get()).data().count}):`);
    snap.docs.forEach((d) => console.log(`  ${d.id}`));
    console.log();
  }

  console.log("Done!");
  process.exit(0);
}

run().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
