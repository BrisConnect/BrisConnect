const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function verify() {
  const snapshot = await admin.firestore()
    .collection('admin_notifications')
    .where('adminEmail', '==', 'brisconnect0@gmail.com')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  console.log(`Found ${snapshot.size} recent notifications for admin:`);
  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    console.log(`\n  ID: ${doc.id}`);
    console.log(`  Title: ${data.title}`);
    console.log(`  Read: ${data.read}`);
    console.log(`  CreatedAt: ${data.createdAt}`);
  });
}

verify().catch(console.error);
