const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

const STALE_ROUTE = '/admin/reports';
const FIXED_ROUTE = '/local/portal';

async function backfill() {
  const db = admin.firestore();
  const ownersSnap = await db.collection('local_users').get();
  console.log(`Scanning ${ownersSnap.size} owner(s) for stale review notifications...`);

  let staleCount = 0;
  let batch = db.batch();
  let opsInBatch = 0;

  for (const ownerDoc of ownersSnap.docs) {
    const notifsSnap = await ownerDoc.ref
      .collection('notifications')
      .where('type', '==', 'new_review')
      .where('actionRoute', '==', STALE_ROUTE)
      .get();

    notifsSnap.docs.forEach((doc) => {
      staleCount += 1;
      batch.update(doc.ref, { actionRoute: FIXED_ROUTE });
      opsInBatch += 1;
      console.log(`  Fixing: ${doc.ref.path}`);

      if (opsInBatch >= 400) {
        batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    });
  }

  if (opsInBatch > 0) {
    await batch.commit();
  }

  if (staleCount === 0) {
    console.log('No stale review notifications found. Nothing to fix.');
    return;
  }

  console.log(`\n✅ Fixed ${staleCount} stale review notification(s) across all owners.`);
}

backfill().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
