const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, '../service-account-key.json');
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function verify() {
  // Check one of the businesses that was monitored
  const doc = await db.collection('food_businesses').doc('1889_enoteca').get();
  if (doc.exists) {
    const data = doc.data();
    console.log('\n✅ Business Sync Metadata Updated:\n');
    console.log(`Business: ${data.name}`);
    console.log(`lastGoogleCheckAtMs: ${data.lastGoogleCheckAtMs}`);
    console.log(`googleSyncStatus: ${data.googleSyncStatus}`);
    console.log(`googleSyncLastAlertId: ${data.googleSyncLastAlertId}`);
  }
  process.exit(0);
}

verify();
