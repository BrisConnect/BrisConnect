/**
 * Manual seed for Google-sourced Brisbane attractions and event venues.
 *
 * The Google Places API billing is disabled on the GCP project, so this
 * script seeds the same attractions/venues that were previously imported,
 * using human-readable document IDs.
 *
 * Usage:
 *   cd functions
 *   node seed_google_places_manual.js
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

// ─── ATTRACTIONS ─────────────────────────────────────────────────────────────

const attractions = [
  {
    id: "google-attraction-south-bank-parklands",
    name: "South Bank Parklands",
    location: "Stanley St Plaza, South Brisbane QLD 4101",
    latitude: -27.4787, longitude: 153.0229,
    sourceTypes: ["tourist_attraction", "park", "point_of_interest"],
    rating: 4.6, userRatingCount: 18200,
    websiteUri: "https://www.visitsouthbank.com.au/",
  },
  {
    id: "google-attraction-lone-pine-koala-sanctuary",
    name: "Lone Pine Koala Sanctuary",
    location: "708 Jesmond Rd, Fig Tree Pocket QLD 4069",
    latitude: -27.5329, longitude: 152.9693,
    sourceTypes: ["zoo", "tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 14500,
    websiteUri: "https://lonepinekoalasanctuary.com/",
  },
  {
    id: "google-attraction-gallery-of-modern-art",
    name: "Gallery of Modern Art",
    location: "Stanley Pl, South Brisbane QLD 4101",
    latitude: -27.4732, longitude: 153.0173,
    sourceTypes: ["art_gallery", "museum", "tourist_attraction"],
    rating: 4.6, userRatingCount: 7800,
    websiteUri: "https://www.qagoma.qld.gov.au/",
  },
  {
    id: "google-attraction-queensland-art-gallery",
    name: "Queensland Art Gallery",
    location: "Melbourne St, South Brisbane QLD 4101",
    latitude: -27.4710, longitude: 153.0175,
    sourceTypes: ["art_gallery", "museum", "tourist_attraction"],
    rating: 4.5, userRatingCount: 5200,
    websiteUri: "https://www.qagoma.qld.gov.au/",
  },
  {
    id: "google-attraction-queensland-museum-kurilpa",
    name: "Queensland Museum Kurilpa",
    location: "Cnr Grey & Melbourne Sts, South Brisbane QLD 4101",
    latitude: -27.4714, longitude: 153.0167,
    sourceTypes: ["museum", "tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 9100,
    websiteUri: "https://www.museum.qld.gov.au/kurilpa",
  },
  {
    id: "google-attraction-museum-of-brisbane",
    name: "Museum of Brisbane",
    location: "Level 3, Brisbane City Hall, 64 Adelaide St, Brisbane QLD 4000",
    latitude: -27.4688, longitude: 153.0236,
    sourceTypes: ["museum", "tourist_attraction"],
    rating: 4.5, userRatingCount: 3200,
    websiteUri: "https://www.museumofbrisbane.com.au/",
  },
  {
    id: "google-attraction-roma-street-parkland",
    name: "Roma Street Parkland",
    location: "1 Parkland Blvd, Brisbane QLD 4000",
    latitude: -27.4618, longitude: 153.0155,
    sourceTypes: ["park", "tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 6400,
    websiteUri: "https://www.brisbane.qld.gov.au/",
  },
  {
    id: "google-attraction-city-botanic-gardens",
    name: "City Botanic Gardens",
    location: "Alice St, Brisbane City QLD 4000",
    latitude: -27.4750, longitude: 153.0300,
    sourceTypes: ["park", "tourist_attraction", "point_of_interest"],
    rating: 4.6, userRatingCount: 8900,
    websiteUri: "https://www.brisbane.qld.gov.au/",
  },
  {
    id: "google-attraction-mount-coot-tha-summit-lookout",
    name: "Mt Coot-tha Summit Lookout",
    location: "1220 Sir Samuel Griffith Dr, Mt Coot-tha QLD 4066",
    latitude: -27.4756, longitude: 152.9588,
    sourceTypes: ["tourist_attraction", "point_of_interest", "natural_feature"],
    rating: 4.6, userRatingCount: 11200,
    websiteUri: "https://www.brisbane.qld.gov.au/",
  },
  {
    id: "google-attraction-kangaroo-point-cliffs-park",
    name: "Kangaroo Point Cliffs Park",
    location: "River Terrace, Kangaroo Point QLD 4169",
    latitude: -27.4780, longitude: 153.0340,
    sourceTypes: ["park", "tourist_attraction", "point_of_interest"],
    rating: 4.7, userRatingCount: 7600,
  },
  {
    id: "google-attraction-new-farm-park",
    name: "New Farm Park",
    location: "Brunswick St, New Farm QLD 4005",
    latitude: -27.4690, longitude: 153.0510,
    sourceTypes: ["park", "tourist_attraction", "point_of_interest"],
    rating: 4.7, userRatingCount: 8100,
  },
  {
    id: "google-attraction-story-bridge",
    name: "Story Bridge",
    location: "Story Bridge, Brisbane QLD 4000",
    latitude: -27.4635, longitude: 153.0358,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.6, userRatingCount: 5400,
  },
  {
    id: "google-attraction-brisbane-city-hall",
    name: "Brisbane City Hall",
    location: "64 Adelaide St, Brisbane City QLD 4000",
    latitude: -27.46885, longitude: 153.023602,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 6200,
  },
  {
    id: "google-attraction-queensland-maritime-museum",
    name: "Queensland Maritime Museum",
    location: "Stanley St, South Brisbane QLD 4101",
    latitude: -27.4835, longitude: 153.0296,
    sourceTypes: ["museum", "tourist_attraction"],
    rating: 4.3, userRatingCount: 2800,
    websiteUri: "https://www.maritimemuseum.com.au/",
  },
  {
    id: "google-attraction-sir-thomas-brisbane-planetarium",
    name: "Sir Thomas Brisbane Planetarium",
    location: "Mt Coot-tha Rd, Toowong QLD 4066",
    latitude: -27.4769, longitude: 152.9735,
    sourceTypes: ["museum", "tourist_attraction", "point_of_interest"],
    rating: 4.4, userRatingCount: 3500,
    websiteUri: "https://www.brisbane.qld.gov.au/",
  },
  {
    id: "google-attraction-streets-beach",
    name: "Streets Beach",
    location: "Stanley St Plaza, South Brisbane QLD 4101",
    latitude: -27.4797, longitude: 153.0225,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.4, userRatingCount: 9800,
  },
  {
    id: "google-attraction-boggo-road-gaol",
    name: "Boggo Road Gaol",
    location: "144 Annerley Rd, Dutton Park QLD 4102",
    latitude: -27.4965, longitude: 153.0280,
    sourceTypes: ["museum", "tourist_attraction"],
    rating: 4.4, userRatingCount: 2100,
    websiteUri: "https://www.boggoroadgaol.com.au/",
  },
  {
    id: "google-attraction-howard-smith-wharves",
    name: "Howard Smith Wharves",
    location: "5 Boundary St, Brisbane City QLD 4000",
    latitude: -27.4592, longitude: 153.0362,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 12300,
    websiteUri: "https://howardsmithwharves.com/",
  },
  {
    id: "google-attraction-eat-street-northshore",
    name: "Eat Street Northshore",
    location: "221D MacArthur Ave, Hamilton QLD 4007",
    latitude: -27.4383, longitude: 153.0735,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.2, userRatingCount: 5600,
    websiteUri: "https://www.eatstreetmarkets.com/",
  },
  {
    id: "google-attraction-fort-lytton-national-park",
    name: "Fort Lytton National Park",
    location: "South St, Lytton QLD 4178",
    latitude: -27.4130, longitude: 153.1320,
    sourceTypes: ["park", "tourist_attraction", "point_of_interest"],
    rating: 4.4, userRatingCount: 1900,
  },
  {
    id: "google-attraction-daisy-hill-koala-centre",
    name: "Daisy Hill Koala Centre",
    location: "Daisy Hill Rd, Daisy Hill QLD 4127",
    latitude: -27.6347, longitude: 153.1530,
    sourceTypes: ["zoo", "tourist_attraction", "point_of_interest"],
    rating: 4.3, userRatingCount: 2400,
  },
  {
    id: "google-attraction-brisbane-powerhouse",
    name: "Brisbane Powerhouse",
    location: "119 Lamington St, New Farm QLD 4005",
    latitude: -27.4527, longitude: 153.0456,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.4, userRatingCount: 4100,
    websiteUri: "https://brisbanepowerhouse.org/",
  },
  {
    id: "google-attraction-newstead-house",
    name: "Newstead House",
    location: "Breakfast Creek Rd, Newstead QLD 4006",
    latitude: -27.4500, longitude: 153.0483,
    sourceTypes: ["museum", "tourist_attraction"],
    rating: 4.3, userRatingCount: 1600,
  },
  {
    id: "google-attraction-rocks-riverside-park",
    name: "Rocks Riverside Park",
    location: "Counihan Rd, Seventeen Mile Rocks QLD 4073",
    latitude: -27.5440, longitude: 152.9510,
    sourceTypes: ["park", "point_of_interest"],
    rating: 4.6, userRatingCount: 4500,
  },
];

// ─── EVENT VENUES ────────────────────────────────────────────────────────────

const eventVenues = [
  {
    id: "google-event-suncorp-stadium",
    name: "Suncorp Stadium",
    location: "40 Castlemaine St, Milton QLD 4064",
    latitude: -27.4648, longitude: 153.0094,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.5, userRatingCount: 16800,
    websiteUri: "https://www.suncorpstadium.com.au/",
  },
  {
    id: "google-event-the-gabba",
    name: "The Gabba",
    location: "411 Vulture St, Woolloongabba QLD 4102",
    latitude: -27.4858, longitude: 153.0381,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.4, userRatingCount: 12500,
    websiteUri: "https://www.thegabba.com.au/",
  },
  {
    id: "google-event-brisbane-entertainment-centre",
    name: "Brisbane Entertainment Centre",
    location: "Melton Rd, Boondall QLD 4034",
    latitude: -27.3463, longitude: 153.0657,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.3, userRatingCount: 8900,
  },
  {
    id: "google-event-riverstage",
    name: "Riverstage",
    location: "City Botanic Gardens, Brisbane QLD 4000",
    latitude: -27.4725, longitude: 153.0312,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.4, userRatingCount: 5600,
  },
  {
    id: "google-event-qpac",
    name: "Queensland Performing Arts Centre",
    location: "Cnr Grey & Melbourne Sts, South Brisbane QLD 4101",
    latitude: -27.4740, longitude: 153.0180,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.6, userRatingCount: 7200,
    websiteUri: "https://www.qpac.com.au/",
  },
  {
    id: "google-event-fortitude-music-hall",
    name: "Fortitude Music Hall",
    location: "312 Brunswick St, Fortitude Valley QLD 4006",
    latitude: -27.4553, longitude: 153.0353,
    sourceTypes: ["night_club", "point_of_interest"],
    rating: 4.5, userRatingCount: 4800,
    websiteUri: "https://www.fortitudemusichall.com.au/",
  },
  {
    id: "google-event-the-tivoli",
    name: "The Tivoli",
    location: "52 Costin St, Fortitude Valley QLD 4006",
    latitude: -27.4553, longitude: 153.0361,
    sourceTypes: ["night_club", "point_of_interest"],
    rating: 4.4, userRatingCount: 3200,
    websiteUri: "https://thetivoli.com.au/",
  },
  {
    id: "google-event-brisbane-convention-centre",
    name: "Brisbane Convention & Exhibition Centre",
    location: "Merivale St, South Brisbane QLD 4101",
    latitude: -27.4785, longitude: 153.0180,
    sourceTypes: ["conference_center", "point_of_interest"],
    rating: 4.4, userRatingCount: 6100,
    websiteUri: "https://www.bcec.com.au/",
  },
  {
    id: "google-event-event-cinemas-brisbane",
    name: "Event Cinemas Brisbane",
    location: "Queen Street Mall, Brisbane City QLD 4000",
    latitude: -27.4710, longitude: 153.0250,
    sourceTypes: ["movie_theater", "point_of_interest"],
    rating: 4.1, userRatingCount: 4500,
  },
  {
    id: "google-event-palace-cinemas-james-street",
    name: "Palace Cinemas James Street",
    location: "39 James St, Fortitude Valley QLD 4006",
    latitude: -27.4540, longitude: 153.0375,
    sourceTypes: ["movie_theater", "point_of_interest"],
    rating: 4.3, userRatingCount: 3100,
    websiteUri: "https://www.palacecinemas.com.au/",
  },
  {
    id: "google-event-ballymore-stadium",
    name: "Ballymore Stadium",
    location: "Butterfield St, Herston QLD 4006",
    latitude: -27.4360, longitude: 153.0080,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.2, userRatingCount: 2100,
  },
  {
    id: "google-event-redcliffe-entertainment-centre",
    name: "Redcliffe Entertainment Centre",
    location: "Downs St, Redcliffe QLD 4020",
    latitude: -27.2296, longitude: 153.1063,
    sourceTypes: ["stadium", "point_of_interest"],
    rating: 4.3, userRatingCount: 1800,
  },
  {
    id: "google-event-brisbane-powerhouse",
    name: "Brisbane Powerhouse",
    location: "119 Lamington St, New Farm QLD 4005",
    latitude: -27.4527, longitude: 153.0456,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.4, userRatingCount: 4100,
    websiteUri: "https://brisbanepowerhouse.org/",
  },
  {
    id: "google-event-lone-pine-koala-sanctuary",
    name: "Lone Pine Koala Sanctuary",
    location: "708 Jesmond Rd, Fig Tree Pocket QLD 4069",
    latitude: -27.5329, longitude: 152.9693,
    sourceTypes: ["zoo", "tourist_attraction"],
    rating: 4.5, userRatingCount: 14500,
    websiteUri: "https://lonepinekoalasanctuary.com/",
  },
  {
    id: "google-event-city-botanic-gardens",
    name: "City Botanic Gardens",
    location: "Alice St, Brisbane City QLD 4000",
    latitude: -27.4750, longitude: 153.0300,
    sourceTypes: ["park", "tourist_attraction"],
    rating: 4.6, userRatingCount: 8900,
  },
  {
    id: "google-event-south-bank-parklands",
    name: "South Bank Parklands",
    location: "Stanley St Plaza, South Brisbane QLD 4101",
    latitude: -27.4787, longitude: 153.0229,
    sourceTypes: ["tourist_attraction", "park"],
    rating: 4.6, userRatingCount: 18200,
    websiteUri: "https://www.visitsouthbank.com.au/",
  },
  {
    id: "google-event-howard-smith-wharves",
    name: "Howard Smith Wharves",
    location: "5 Boundary St, Brisbane City QLD 4000",
    latitude: -27.4592, longitude: 153.0362,
    sourceTypes: ["tourist_attraction", "point_of_interest"],
    rating: 4.5, userRatingCount: 12300,
    websiteUri: "https://howardsmithwharves.com/",
  },
  {
    id: "google-event-heritage-hotel",
    name: "The Heritage Hotel",
    location: "Cnr Edward & Margaret Sts, Brisbane QLD 4000",
    latitude: -27.4670, longitude: 153.0270,
    sourceTypes: ["night_club", "point_of_interest"],
    rating: 4.0, userRatingCount: 1800,
  },
  {
    id: "google-event-woolly-mammoth",
    name: "Woolly Mammoth",
    location: "633 Ann St, Fortitude Valley QLD 4006",
    latitude: -27.4565, longitude: 153.0340,
    sourceTypes: ["night_club", "point_of_interest"],
    rating: 4.2, userRatingCount: 2200,
  },
];

// ─── DISCOVER SECTION HELPER ─────────────────────────────────────────────────

function determineSection(types) {
  const s = (types || []).join("|").toLowerCase();
  if (s.includes("museum") || s.includes("art_gallery")) return "historical";
  if (s.includes("park") || s.includes("zoo") || s.includes("aquarium") ||
      s.includes("amusement") || s.includes("tourist_attraction") ||
      s.includes("stadium") || s.includes("natural_feature")) return "attraction";
  if (s.includes("restaurant") || s.includes("cafe") || s.includes("bar") ||
      s.includes("food")) return "food";
  return "food";
}

// ─── SEED ────────────────────────────────────────────────────────────────────

async function seed() {
  console.log("=== Seeding Google-sourced attractions ===\n");

  const batch1 = db.batch();
  for (const a of attractions) {
    const ref = db.collection("attractions").doc(a.id);
    batch1.set(ref, {
      id: a.id,
      name: a.name,
      description: `Imported from Google Places. Rating: ${a.rating ?? "N/A"} (${a.userRatingCount} reviews).`,
      location: a.location,
      latitude: a.latitude,
      longitude: a.longitude,
      category: "Google Places",
      webLink: a.websiteUri || "",
      imageUrl: "",
      sourceProvider: "google_places",
      sourceTypes: a.sourceTypes,
      approvalStatus: "approved",
      status: "approved",
      isApproved: true,
      importedBy: "google_places_import",
      updatedAt: now,
    }, { merge: true });
  }
  await batch1.commit();
  console.log(`  ✓ ${attractions.length} attractions written`);

  console.log("\n=== Seeding Google-sourced event venues ===\n");

  const batch2 = db.batch();
  for (const e of eventVenues) {
    const ref = db.collection("events").doc(e.id);
    batch2.set(ref, {
      id: e.id,
      title: `${e.name} (Venue)`,
      date: "TBA",
      time: "TBA",
      category: "Venue",
      location: e.location,
      venue: e.name,
      suburb: "Brisbane",
      description: "Imported event venue from Google Places.",
      latitude: e.latitude,
      longitude: e.longitude,
      imageUrl: "",
      sourceProvider: "google_places",
      sourceTypes: e.sourceTypes,
      reviewStatus: "approved",
      approvalStatus: "approved",
      status: "approved",
      badge: "Approved",
      isApproved: true,
      importedBy: "google_places_import",
      updatedAt: now,
    }, { merge: true });
  }
  await batch2.commit();
  console.log(`  ✓ ${eventVenues.length} event venues written`);

  console.log("\n=== Converting to discover_items ===\n");

  // Read back all google_places attractions + events
  const attrSnap = await db.collection("attractions")
    .where("sourceProvider", "==", "google_places")
    .get();
  const evtSnap = await db.collection("events")
    .where("sourceProvider", "==", "google_places")
    .get();

  const batch3 = db.batch();
  let discoverCount = 0;

  attrSnap.docs.forEach((doc) => {
    const a = doc.data();
    const section = determineSection(a.sourceTypes);
    const discId = `discover-${a.id}`;
    batch3.set(db.collection("discover_items").doc(discId), {
      id: discId,
      section,
      title: a.name,
      description: a.description,
      imageUrl: a.imageUrl || "",
      location: a.location,
      latitude: a.latitude,
      longitude: a.longitude,
      categories: ["google_places", section, ...(a.sourceTypes || []).slice(0, 3)],
      webLink: a.webLink || "",
      badge: "Imported",
      approvalStatus: "approved",
      sourceProvider: "google_places",
      sourceAttractionId: a.id,
      importedFrom: "google_places_catalog",
      updatedAt: now,
    }, { merge: true });
    discoverCount++;
  });

  evtSnap.docs.forEach((doc) => {
    const e = doc.data();
    const discId = `discover-${e.id}`;
    batch3.set(db.collection("discover_items").doc(discId), {
      id: discId,
      section: "events",
      title: e.title || e.venue,
      description: e.description,
      imageUrl: e.imageUrl || "",
      location: e.location,
      venue: e.venue,
      suburb: e.suburb,
      date: e.date,
      time: e.time,
      latitude: e.latitude,
      longitude: e.longitude,
      categories: ["google_places", "events", "venue"],
      badge: "Imported",
      approvalStatus: "approved",
      sourceProvider: "google_places",
      sourceEventId: e.id,
      importedFrom: "google_places_catalog",
      updatedAt: now,
    }, { merge: true });
    discoverCount++;
  });

  await batch3.commit();
  console.log(`  ✓ ${discoverCount} discover_items written`);

  // Update metadata
  await db.collection("seed_metadata").doc("google_places_import").set({
    sourceProvider: "google_places",
    center: { lat: -27.4679, lng: 153.0281 },
    radiusMeters: 30000,
    attractionCount: attractions.length,
    eventCount: eventVenues.length,
    writeCount: attractions.length + eventVenues.length + discoverCount,
    lastSyncedAt: now,
  }, { merge: true });

  console.log("\n=== Final counts ===\n");
  for (const coll of ["attractions", "events", "discover_items"]) {
    const snap = await db.collection(coll).get();
    console.log(`${coll}: ${snap.size} docs`);
    snap.docs.forEach((d) => console.log(`  ${d.id}`));
    console.log();
  }

  console.log("Done!");
  process.exit(0);
}

seed().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
