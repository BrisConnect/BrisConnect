/**
 * One-time script: delete old hash-based / placeId-suffix documents from
 * discover_items, events, and attractions, then re-trigger the BCC sync
 * and Google Places → discover conversion with human-readable IDs.
 *
 * Usage:
 *   cd functions
 *   node reseed_readable_ids.js
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

/** Delete docs whose ID matches a regex pattern, in batches of 500. */
async function deleteMatching(collectionName, pattern) {
  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) return 0;

  let deleted = 0;
  const batchSize = 500;
  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    if (pattern.test(doc.id)) {
      batch.delete(doc.ref);
      count++;
      deleted++;

      if (count >= batchSize) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
  }

  if (count > 0) await batch.commit();
  return deleted;
}

async function run() {
  console.log("=== Cleaning old hash-based / placeId-suffix document IDs ===\n");

  // Old BCC format: bcc_events_<20-hex-chars> or bcc_historical_<20-hex-chars>
  const oldBccPattern = /^bcc_(events|historical)_[0-9a-f]{20}$/;
  // Old Google Places: any doc with _ChIJ suffix (Google Place ID prefix)
  const oldGooglePattern = /^google_(attraction|event)_.+_ChIJ/;
  // Old discover items derived from Google Places with old IDs
  const oldDiscoverGooglePattern = /^discover_google_(attraction|event)_.+_ChIJ/;

  let n;

  n = await deleteMatching("discover_items", oldBccPattern);
  console.log(`  discover_items: deleted ${n} old BCC docs`);

  n = await deleteMatching("discover_items", oldGooglePattern);
  console.log(`  discover_items: deleted ${n} old Google Places docs`);

  n = await deleteMatching("discover_items", oldDiscoverGooglePattern);
  console.log(`  discover_items: deleted ${n} old discover_google_ docs`);

  n = await deleteMatching("events", oldBccPattern);
  console.log(`  events: deleted ${n} old BCC docs`);

  n = await deleteMatching("events", oldGooglePattern);
  console.log(`  events: deleted ${n} old Google Places docs`);

  n = await deleteMatching("attractions", oldGooglePattern);
  console.log(`  attractions: deleted ${n} old Google Places docs`);

  console.log("\n=== Listing remaining document IDs per collection ===\n");

  for (const coll of ["discover_items", "events", "attractions"]) {
    const snap = await db.collection(coll).get();
    console.log(`${coll} (${snap.size} docs):`);
    snap.docs.forEach((d) => console.log(`  ${d.id}`));
    console.log();
  }

  console.log("Done! Now re-trigger syncBrisbaneCouncilCatalog and importGooglePlacesCatalog from the app or Firebase console to populate with readable IDs.");
  process.exit(0);
}

run().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
