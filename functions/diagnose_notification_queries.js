#!/usr/bin/env node
/**
 * Check the structure of notifications in Firestore and verify admin email matching
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

async function diagnoseNotificationQueries() {
  console.log('\n🔍 DIAGNOSING ADMIN NOTIFICATION QUERIES\n');

  try {
    // 1. Get admin email
    const adminsSnapshot = await db.collection('admins').get();
    if (adminsSnapshot.empty) {
      console.log('❌ No admins found');
      return;
    }

    const adminEmail = adminsSnapshot.docs[0].id;
    console.log(`Admin Email: ${adminEmail}\n`);

    // 2. Get all notifications
    console.log('📋 ALL notifications in admin_notifications collection:');
    const allNotifs = await db
      .collection('admin_notifications')
      .orderBy('createdAt', 'desc')
      .get();

    if (allNotifs.empty) {
      console.log('  ❌ No notifications at all\n');
    } else {
      console.log(`  Total: ${allNotifs.docs.length}\n`);
      
      // Group by adminEmail
      const byEmail = {};
      allNotifs.docs.forEach((doc) => {
        const data = doc.data();
        const email = data.adminEmail || 'NO_EMAIL_FIELD';
        if (!byEmail[email]) byEmail[email] = [];
        byEmail[email].push({
          id: doc.id,
          title: data.title,
          createdAt: data.createdAt?.toDate?.().toISOString() || 'unknown',
        });
      });

      Object.entries(byEmail).forEach(([email, notifs]) => {
        console.log(`  For admin "${email}": ${notifs.length} notification(s)`);
        notifs.slice(0, 3).forEach((n) => {
          console.log(`    - ${n.title} (${n.createdAt})`);
        });
        if (notifs.length > 3) {
          console.log(`    ... and ${notifs.length - 3} more`);
        }
      });
    }

    // 3. Check notifications for CURRENT admin
    console.log(`\n📌 Notifications for CURRENT admin (${adminEmail}):`);
    const currentAdminNotifs = allNotifs.docs
      .filter((doc) => (doc.data().adminEmail || 'NO_EMAIL_FIELD') === adminEmail);

    if (currentAdminNotifs.length === 0) {
      console.log(`  ❌ NO NOTIFICATIONS FOR ${adminEmail}`);
      console.log(`     All notifications are assigned to other admins!\n`);
    } else {
      console.log(`  ✅ Found ${currentAdminNotifs.length} notification(s):`);
      currentAdminNotifs.slice(0, 5).forEach((doc) => {
        const data = doc.data();
        console.log(`     - ${data.title}`);
      });
    }

    // 4. Sample a notification document to see structure
    if (allNotifs.docs.length > 0) {
      console.log('\n📄 Sample notification document structure:');
      const sample = allNotifs.docs[0].data();
      console.log(`  Document ID: ${allNotifs.docs[0].id}`);
      console.log(`  Fields present:`, Object.keys(sample).sort().join(', '));
      console.log(`  adminEmail: "${sample.adminEmail}"`);
      console.log(`  type: "${sample.type}"`);
      console.log(`  title: "${sample.title}"`);
    }

    // 5. Issue diagnosis
    console.log('\n🔧 POTENTIAL ISSUES:\n');
    
    if (currentAdminNotifs.length === 0 && allNotifs.docs.length > 0) {
      console.log('❌ ISSUE FOUND: Notifications exist but NOT assigned to current admin!');
      console.log('   Possible causes:');
      console.log('   1. Cloud Function created notifications for wrong admin email');
      console.log('   2. Admin email in Firestore doesn\'t match Firebase Auth email');
      console.log('   3. Multiple admin accounts - notifications going to different one\n');
    } else if (currentAdminNotifs.length > 0) {
      console.log('✅ Notifications ARE correctly stored for this admin!');
      console.log('   Issue is likely in the Flutter app filtering/displaying them.\n');
    } else {
      console.log('❌ No notifications at all - either none created or all deleted.\n');
    }

  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

diagnoseNotificationQueries().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
