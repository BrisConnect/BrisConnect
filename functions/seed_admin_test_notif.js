const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.join(__dirname, '..', 'service-account-key.json')),
  });
}

async function seed() {
  const ref = admin.firestore().collection('admin_notifications').doc();
  await ref.set({
    adminEmail: 'brisconnect0@gmail.com',
    title: '🧪 Nav test notification',
    message: 'Click test for navigation debug',
    type: 'reported_content',
    data: { screen: '/admin/reports' },
    relatedItemId: null,
    relatedItemType: null,
    actionRoute: '/admin/reports',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('Seeded: ' + ref.id);
}
seed().catch(console.error);
