/**
 * Local script: Import Google Places attractions & events, then convert
 * to discover_items — all with human-readable document IDs.
 *
 * Usage:
 *   cd functions
 *   node import_google_places_local.js
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

// ─── CONFIG ──────────────────────────────────────────────────────────────────

const API_KEY = "AIzaSyBPxl4d-ZDVmEKvP13GnnJTos1zHzPdjN4";

const BRISBANE_CBD = { lat: -27.4679, lng: 153.0281 };
const RADIUS_METERS = 30000;

const ATTRACTION_TYPES = [
  "tourist_attraction", "museum", "art_gallery", "park",
  "zoo", "aquarium", "amusement_park",
];

const EVENT_VENUE_TYPES = [
  "stadium", "movie_theater", "night_club",
  "conference_center", "tourist_attraction",
];

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function degreesToRadians(v) { return (v * Math.PI) / 180; }

function distanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = degreesToRadians(lat2 - lat1);
  const dLon = degreesToRadians(lon2 - lon1);
  const a = Math.sin(dLat/2)**2 + Math.cos(degreesToRadians(lat1)) * Math.cos(degreesToRadians(lat2)) * Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function withinRadius(place) {
  const coords = extractCoords(place);
  if (!coords) return false;
  return distanceKm(BRISBANE_CBD.lat, BRISBANE_CBD.lng, coords.lat, coords.lng) <= RADIUS_METERS / 1000;
}

function extractCoords(place) {
  const loc = place?.location || place?.geometry?.location;
  const lat = loc?.latitude ?? loc?.lat ?? null;
  const lng = loc?.longitude ?? loc?.lng ?? null;
  if (lat == null || lng == null) return null;
  return { lat, lng };
}

function normalizeRecord(place) {
  const placeId = String(place.id || place.place_id || "").trim();
  const name = String((place.displayName?.text) || place.name || "").trim();
  const address = String(place.formattedAddress || place.vicinity || "").trim();
  const types = Array.isArray(place.types) ? place.types.filter(Boolean) : [];
  const photoRef = place.photos?.[0]?.name || place.photos?.[0]?.photo_reference || "";
  const rating = typeof place.rating === "number" ? place.rating : null;
  const userRatingCount = place.userRatingCount ?? place.user_ratings_total ?? 0;
  const websiteUri = String(place.websiteUri || place.url || "").trim();
  return { placeId, name, address, types, photoRef, rating, userRatingCount, websiteUri };
}

function photoUrl(ref) {
  if (!ref) return "";
  if (ref.startsWith("places/")) {
    const u = new URL(`https://places.googleapis.com/v1/${ref}/media`);
    u.searchParams.set("key", API_KEY);
    u.searchParams.set("maxWidthPx", "1000");
    return u.toString();
  }
  const u = new URL("https://maps.googleapis.com/maps/api/place/photo");
  u.searchParams.set("key", API_KEY);
  u.searchParams.set("photoreference", ref);
  u.searchParams.set("maxwidth", "1000");
  return u.toString();
}

function dedupeByPlaceId(records) {
  const map = new Map();
  for (const r of records) {
    if (r?.sourcePlaceId) map.set(r.sourcePlaceId, r);
  }
  return [...map.values()];
}

function determineSection(types) {
  if (!Array.isArray(types)) return "food";
  const s = types.join("|").toLowerCase();
  if (s.includes("museum") || s.includes("art_gallery") || s.includes("historical") || s.includes("church") || s.includes("place_of_worship")) return "historical";
  if (s.includes("park") || s.includes("zoo") || s.includes("aquarium") || s.includes("amusement") || s.includes("tourist_attraction") || s.includes("point_of_interest") || s.includes("stadium") || s.includes("campground") || s.includes("natural_feature")) return "attraction";
  if (s.includes("restaurant") || s.includes("cafe") || s.includes("bar") || s.includes("bakery") || s.includes("meal") || s.includes("food")) return "food";
  return "food";
}

// ─── FETCH ───────────────────────────────────────────────────────────────────

async function fetchByType(type) {
  const endpoint = "https://places.googleapis.com/v1/places:searchNearby";
  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": API_KEY,
      "X-Goog-FieldMask": [
        "places.id", "places.displayName", "places.formattedAddress",
        "places.location", "places.types", "places.rating",
        "places.userRatingCount", "places.photos.name", "places.websiteUri",
      ].join(","),
    },
    body: JSON.stringify({
      includedTypes: [type],
      maxResultCount: 20,
      locationRestriction: {
        circle: {
          center: { latitude: BRISBANE_CBD.lat, longitude: BRISBANE_CBD.lng },
          radius: RADIUS_METERS,
        },
      },
    }),
  });
  if (!resp.ok) throw new Error(`Google Places ${resp.status} for ${type}`);
  const data = await resp.json();
  if (data.error?.message) throw new Error(`Google Places error for ${type}: ${data.error.message}`);
  return Array.isArray(data.places) ? data.places : [];
}

function toAttraction(place) {
  const coords = extractCoords(place);
  if (!coords) return null;
  const r = normalizeRecord(place);
  if (!r.placeId || !r.name) return null;
  return {
    id: `google-attraction-${slugify(r.name)}`,
    name: r.name,
    description: `Imported from Google Places. Rating: ${r.rating ?? "N/A"} (${r.userRatingCount} reviews).`,
    location: r.address || "Brisbane",
    latitude: coords.lat, longitude: coords.lng,
    category: "Google Places",
    webLink: r.websiteUri,
    imageUrl: photoUrl(r.photoRef),
    sourceProvider: "google_places", sourcePlaceId: r.placeId, sourceTypes: r.types,
    approvalStatus: "approved", status: "approved", isApproved: true,
    importedBy: "google_places_import",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function toEvent(place) {
  const coords = extractCoords(place);
  if (!coords) return null;
  const r = normalizeRecord(place);
  if (!r.placeId || !r.name) return null;
  return {
    id: `google-event-${slugify(r.name)}`,
    title: `${r.name} (Venue)`,
    date: "TBA", time: "TBA", category: "Venue",
    location: r.address || "Brisbane", venue: r.name, suburb: "Brisbane",
    description: "Imported event venue from Google Places.",
    latitude: coords.lat, longitude: coords.lng,
    imageUrl: photoUrl(r.photoRef),
    sourceProvider: "google_places", sourcePlaceId: r.placeId, sourceTypes: r.types,
    reviewStatus: "approved", approvalStatus: "approved", status: "approved",
    badge: "Approved", isApproved: true,
    importedBy: "google_places_import",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

async function run() {
  console.log("=== Step 1: Import Google Places ===\n");

  const attractionResults = [];
  for (const type of ATTRACTION_TYPES) {
    try {
      const places = await fetchByType(type);
      console.log(`  attractions/${type}: ${places.length} results`);
      attractionResults.push(...places);
    } catch (e) { console.warn(`  ⚠ ${type}: ${e.message}`); }
  }

  const venueResults = [];
  for (const type of EVENT_VENUE_TYPES) {
    try {
      const places = await fetchByType(type);
      console.log(`  events/${type}: ${places.length} results`);
      venueResults.push(...places);
    } catch (e) { console.warn(`  ⚠ ${type}: ${e.message}`); }
  }

  const attractions = dedupeByPlaceId(attractionResults.filter(withinRadius).map(toAttraction).filter(Boolean));
  const events = dedupeByPlaceId(venueResults.filter(withinRadius).map(toEvent).filter(Boolean));

  console.log(`\n  Deduped: ${attractions.length} attractions, ${events.length} events`);

  // Write to Firestore
  const now = admin.firestore.FieldValue.serverTimestamp();
  let writes = 0;
  const chunkSize = 400;
  const allWrites = [
    ...attractions.map(r => ({ collection: "attractions", record: r })),
    ...events.map(r => ({ collection: "events", record: r })),
  ];

  for (let i = 0; i < allWrites.length; i += chunkSize) {
    const chunk = allWrites.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const item of chunk) {
      batch.set(db.collection(item.collection).doc(item.record.id), item.record, { merge: true });
      writes++;
    }
    await batch.commit();
  }

  await db.collection("seed_metadata").doc("google_places_import").set({
    sourceProvider: "google_places",
    center: BRISBANE_CBD,
    radiusMeters: RADIUS_METERS,
    attractionCount: attractions.length,
    eventCount: events.length,
    writeCount: writes,
    lastSyncedAt: now,
  }, { merge: true });

  console.log(`  Wrote ${writes} docs to attractions + events\n`);

  // ─── Step 2: Convert to discover_items ───────────────────────────────────

  console.log("=== Step 2: Convert to discover_items ===\n");

  const attrSnap = await db.collection("attractions")
    .where("sourceProvider", "==", "google_places")
    .where("approvalStatus", "==", "approved")
    .get();

  const evtSnap = await db.collection("events")
    .where("sourceProvider", "==", "google_places")
    .where("approvalStatus", "==", "approved")
    .get();

  const discoverWrites = [];

  attrSnap.docs.forEach(doc => {
    const a = doc.data();
    const sourceTypes = Array.isArray(a.sourceTypes) ? a.sourceTypes : [];
    const section = determineSection(sourceTypes);
    discoverWrites.push({
      collection: "discover_items",
      record: {
        id: `discover-${a.id}`,
        section,
        title: a.name,
        description: a.description,
        imageUrl: a.imageUrl,
        location: a.location,
        latitude: a.latitude, longitude: a.longitude,
        categories: ["google_places", section, ...sourceTypes.slice(0, 3)],
        webLink: a.webLink,
        badge: "Imported",
        approvalStatus: "approved",
        sourceProvider: "google_places",
        sourceAttractionId: a.id,
        sourcePlaceId: a.sourcePlaceId,
        importedFrom: "google_places_catalog",
        updatedAt: now,
      },
    });
  });

  evtSnap.docs.forEach(doc => {
    const e = doc.data();
    discoverWrites.push({
      collection: "discover_items",
      record: {
        id: `discover-${e.id}`,
        section: "events",
        title: e.title || e.venue,
        description: e.description,
        imageUrl: e.imageUrl,
        location: e.location,
        venue: e.venue, suburb: e.suburb,
        date: e.date, time: e.time,
        latitude: e.latitude, longitude: e.longitude,
        categories: ["google_places", "events", "venue"],
        badge: "Imported",
        approvalStatus: "approved",
        sourceProvider: "google_places",
        sourceEventId: e.id,
        sourcePlaceId: e.sourcePlaceId,
        importedFrom: "google_places_catalog",
        updatedAt: now,
      },
    });
  });

  let discoverCount = 0;
  for (let i = 0; i < discoverWrites.length; i += chunkSize) {
    const chunk = discoverWrites.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const item of chunk) {
      batch.set(db.collection(item.collection).doc(item.record.id), item.record, { merge: true });
      discoverCount++;
    }
    await batch.commit();
  }

  console.log(`  Converted ${discoverCount} discover_items\n`);

  // ─── Summary ─────────────────────────────────────────────────────────────

  console.log("=== Final document IDs ===\n");
  for (const coll of ["attractions", "events", "discover_items"]) {
    const snap = await db.collection(coll).get();
    console.log(`${coll} (${snap.size} docs):`);
    snap.docs.forEach(d => console.log(`  ${d.id}`));
    console.log();
  }

  console.log("Done!");
  process.exit(0);
}

run().catch(err => {
  console.error("Failed:", err);
  process.exit(1);
});
