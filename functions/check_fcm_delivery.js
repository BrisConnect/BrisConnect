#!/usr/bin/env node
/**
 * Check recent FCM send attempts and delivery status
 */
const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

async function checkFcmDelivery() {
  console.log('\n🔍 CHECKING FCM DELIVERY FOR ADMIN\n');

  try {
    // 1. Get admin email
    const adminsSnapshot = await db.collection('admins').get();
    if (adminsSnapshot.empty) {
      console.log('❌ No admins found');
      return;
    }

    const adminEmail = adminsSnapshot.docs[0].id;
    console.log(`Admin: ${adminEmail}\n`);

    // 2. Check FCM tokens
    const tokensSnapshot = await db
      .collection('local_users')
      .doc(adminEmail)
      .collection('fcmTokens')
      .get();

    console.log(`📱 FCM Tokens registered: ${tokensSnapshot.docs.length}`);
    tokensSnapshot.docs.forEach((doc, idx) => {
      const data = doc.data();
      console.log(`  ${idx + 1}. ${doc.id.substring(0, 30)}...`);
      console.log(`     Platform: ${data.platform || 'unknown'}`);
      console.log(`     Registered: ${data.registeredAt?.toDate?.().toISOString() || 'unknown'}`);
    });

    // 3. Check for recent admin notifications
    console.log('\n📬 Recent admin notifications:');
    const notificationsSnapshot = await db
      .collection('admin_notifications')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    notificationsSnapshot.docs.forEach((doc, idx) => {
      const data = doc.data();
      const createdAt = data.createdAt?.toDate?.().toISOString() || 'unknown';
      console.log(`  ${idx + 1}. [${createdAt}] ${data.title}`);
      console.log(`     Type: ${data.type}`);
      console.log(`     Admin: ${data.adminEmail}`);
    });

    // 4. Check if recent crowd reports exist
    console.log('\n👥 Recent crowd reports:');
    const crowdReportsSnapshot = await db
      .collection('crowd_reports')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    if (crowdReportsSnapshot.empty) {
      console.log('  ❌ No crowd reports found in Firestore');
    } else {
      crowdReportsSnapshot.docs.forEach((doc, idx) => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate?.().toISOString() || 'unknown';
        console.log(`  ${idx + 1}. [${createdAt}] Event: ${data.eventId}`);
        console.log(`     Severity: ${data.severity}`);
      });
    }

    console.log('\n💡 TROUBLESHOOTING STEPS:\n');
    console.log('1. Check if notification permission dialog appeared when admin logged in');
    console.log('   → If not, permission prompt may not be triggering correctly\n');
    console.log('2. Check browser notification permission settings:');
    console.log('   Chrome: Settings > Privacy > Site Settings > Notifications');
    console.log('   → Should show "Allow" for brisconnect-68b78.web.app\n');
    console.log('3. Open browser DevTools Console and look for:');
    console.log('   → "[FCM]" log messages');
    console.log('   → "Notification permission denied" warnings');
    console.log('   → Any Firebase initialization errors\n');
    console.log('4. If permission is denied, clear site data:');
    console.log('   Chrome: Settings > Privacy > Clear browsing data');
    console.log('   → Select "Cookies and other site data"');
    console.log('   → Reload admin dashboard\n');

  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkFcmDelivery().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
