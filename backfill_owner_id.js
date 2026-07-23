const admin = require('firebase-admin');

// Backfill ownerId on audience_interactions, promotions, and business_events
// documents that are missing it.
//
// Usage:
//   npm install firebase-admin
//   node backfill_owner_id.js
//
// Requires service-account-key.json in the project root with Firestore write
// access.

const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function backfillCollection(collectionName, getOwnerId) {
  console.log(`\n🔧 Backfilling ${collectionName}...`);

  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) {
    console.log(`   ✅ ${collectionName} is empty`);
    return 0;
  }

  let updated = 0;
  let skipped = 0;
  const batchSize = 400;

  for (let i = 0; i < snapshot.docs.length; i += batchSize) {
    const batch = db.batch();
    let batchCount = 0;
    const end = Math.min(i + batchSize, snapshot.docs.length);

    for (let j = i; j < end; j++) {
      const doc = snapshot.docs[j];
      const data = doc.data();

      if (data.ownerId) {
        skipped++;
        continue;
      }

      const ownerId = await getOwnerId(data, doc.id);
      if (!ownerId) {
        console.log(`   ⚠️  Could not resolve ownerId for ${doc.id}`);
        skipped++;
        continue;
      }

      batch.update(doc.ref, { ownerId });
      batchCount++;
    }

    if (batchCount > 0) {
      await batch.commit();
      updated += batchCount;
    }
  }

  console.log(`   ✅ Updated ${updated}, skipped ${skipped}`);
  return updated;
}

async function getBusinessOwnerId(businessId) {
  if (!businessId) return null;
  const doc = await db.collection('businesses').doc(businessId).get();
  return doc.exists ? doc.data().ownerId : null;
}

async function main() {
  try {
    await backfillCollection('audience_interactions', async (data) => {
      return getBusinessOwnerId(data.businessId);
    });

    await backfillCollection('promotions', async (data) => {
      return data.ownerId || (await getBusinessOwnerId(data.businessId));
    });

    await backfillCollection('business_events', async (data) => {
      return data.ownerId || (await getBusinessOwnerId(data.businessId));
    });

    console.log('\n🎉 Backfill complete');
  } catch (error) {
    console.error('\n❌ Backfill failed:', error.message);
    process.exit(1);
  }
}

main();
