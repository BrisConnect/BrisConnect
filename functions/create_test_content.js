const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function createTestEvent() {
  const eventRef = admin.firestore().collection('events').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  
  await eventRef.set({
    title: 'Live Test Crowd Report Event',
    description: 'Test event for crowd report notification system',
    businessId: 'test-business-' + Date.now(),
    createdAt: now,
    reviewStatus: 'approved',
    status: 'approved',
    startTime: new Date(Date.now() + 3600000), // 1 hour from now
    endTime: new Date(Date.now() + 7200000), // 2 hours from now
  });

  console.log('Created test event: ' + eventRef.id);
  return eventRef.id;
}

createTestEvent().catch(console.error);
