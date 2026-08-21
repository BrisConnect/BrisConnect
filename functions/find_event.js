const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function findEvent() {
  const snapshot = await admin.firestore()
    .collection('events')
    .limit(1)
    .get();

  if (snapshot.empty) {
    console.log('No events found');
    process.exit(1);
  }

  const event = snapshot.docs[0];
  console.log(JSON.stringify({
    id: event.id,
    title: event.data().title,
    businessId: event.data().businessId,
  }, null, 2));
}

findEvent().catch(console.error);
