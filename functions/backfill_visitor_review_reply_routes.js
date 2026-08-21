const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

const STALE_ROUTE = '/visitor/notifications';

async function backfill() {
  const db = admin.firestore();
  const visitorsSnap = await db.collection('visitor_users').get();
  console.log(`Scanning ${visitorsSnap.size} visitor(s) for stale review_reply notifications...`);

  let staleCount = 0;
  let batch = db.batch();
  let opsInBatch = 0;

  for (const visitorDoc of visitorsSnap.docs) {
    const notifsSnap = await visitorDoc.ref
      .collection('notifications')
      .where('type', '==', 'review_reply')
      .where('actionRoute', '==', STALE_ROUTE)
      .get();

    notifsSnap.docs.forEach((doc) => {
      const data = doc.data();
      const businessId = data.businessId || data.data?.businessId;
      if (!businessId) return;

      const fixedRoute = `/business/${businessId}`;
      staleCount += 1;
      batch.update(doc.ref, { actionRoute: fixedRoute });
      opsInBatch += 1;
      console.log(`  Fixing: ${doc.ref.path} -> ${fixedRoute}`);

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
    console.log('No stale review_reply notifications found. Nothing to fix.');
    return;
  }

  console.log(`\n✅ Fixed ${staleCount} stale review_reply notification(s) across all visitors.`);
}

backfill().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
