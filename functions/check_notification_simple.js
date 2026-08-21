const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function check() {
  // Query without orderBy first (single-field index only)
  const snapshot = await admin.firestore()
    .collection('admin_notifications')
    .where('adminEmail', '==', 'brisconnect0@gmail.com')
    .limit(5)
    .get();

  console.log(`Found ${snapshot.size} notifications (without orderBy):`);
  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    console.log(`\n  ID: ${doc.id}`);
    console.log(`  Title: ${data.title}`);
    console.log(`  Read: ${data.read}`);
    console.log(`  AdminEmail: ${data.adminEmail}`);
  });

  if (snapshot.empty) {
    console.log('\nTrying all notifications...');
    const allSnapshot = await admin.firestore()
      .collection('admin_notifications')
      .limit(10)
      .get();
    console.log(`\nTotal notifications in collection: ${allSnapshot.size}`);
  }
}

check().catch(console.error);
