#!/usr/bin/env node

/**
 * Test script to send a test notification to a specific admin
 * Usage: node send_test_admin_notification.js <adminEmail>
 * Example: node send_test_admin_notification.js brisconnect0@gmail.com
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
const serviceAccount = require('../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'brisconnect-68b78',
});

const db = admin.firestore();
const messaging = admin.messaging();

const args = process.argv.slice(2);
const adminEmail = args[0]?.toLowerCase().trim();

if (!adminEmail || !adminEmail.includes('@')) {
  console.error('\n❌ Usage: node send_test_admin_notification.js <adminEmail>');
  console.error('Example: node send_test_admin_notification.js brisconnect0@gmail.com\n');
  process.exit(1);
}

async function sendTestNotification() {
  console.log(`\n📤 Sending test notification to: ${adminEmail}\n`);

  try {
    // 1. Verify admin exists
    const adminDoc = await db.collection('admins').doc(adminEmail).get();
    if (!adminDoc.exists) {
      console.error(`❌ Admin ${adminEmail} not found in admins collection`);
      process.exit(1);
    }
    console.log(`✅ Admin verified: ${adminEmail}`);

    // 2. Get FCM tokens
    const tokensSnapshot = await db
      .collection('local_users')
      .doc(adminEmail)
      .collection('fcmTokens')
      .get();

    if (tokensSnapshot.empty) {
      console.error(`❌ No FCM tokens found for ${adminEmail}`);
      console.error('\n   Possible reasons:');
      console.error('   1. Admin has not visited the app yet');
      console.error('   2. Notification permissions not granted in browser');
      console.error('   3. Tokens expired or invalid');
      process.exit(1);
    }

    const tokens = tokensSnapshot.docs.map(d => d.id);
    console.log(`✅ Found ${tokens.length} FCM token(s):`);
    tokens.forEach((token, i) => {
      console.log(`   ${i + 1}. ${token.substring(0, 40)}...`);
    });

    // 3. Persist notification record
    const now = admin.firestore.FieldValue.serverTimestamp();
    const notificationId = db.collection('admin_notifications').doc().id;

    await db
      .collection('admin_notifications')
      .doc(`${notificationId}_${adminEmail}`)
      .set({
        title: '🧪 Test notification',
        message: 'If you see this, notifications are working correctly!',
        type: 'test',
        data: { test: 'true' },
        createdAt: now,
        read: false,
        adminEmail,
      });

    console.log(`✅ Notification persisted to Firestore`);

    // 4. Send FCM
    const payload = {
      notification: {
        title: '🧪 Test Notification',
        body: 'If you see this, notifications are working correctly!',
      },
      data: {
        type: 'test',
        test: 'true',
      },
    };

    const response = await messaging.sendEachForMulticast({
      tokens,
      ...payload,
    });

    console.log(`\n📊 FCM Send Results:`);
    console.log(`   ✅ Successful: ${response.successCount}/${tokens.length}`);
    console.log(`   ❌ Failed: ${response.failures}`);

    if (response.failures > 0) {
      console.log(`\n⚠️  Failed tokens:`);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log(`   • ${tokens[idx].substring(0, 40)}...`);
          console.log(`     Error: ${resp.error?.message || resp.error?.code || 'unknown'}`);
        }
      });
    }

    console.log('\n📋 What to do next:');
    if (response.successCount === 0) {
      console.log('   1. Open the admin portal in your browser: https://brisconnect-68b78.web.app/admin/dashboard');
      console.log('   2. Check browser console for FCM initialization messages');
      console.log('   3. Enable notifications in browser settings (⚙️ > Notifications)');
      console.log('   4. Run this test again after refreshing the page');
    } else {
      console.log('   1. Check browser for notification (may appear as browser notification)');
      console.log('   2. Check browser console for "[FCM]" messages');
      console.log('   3. If notification center shows the test, notifications are working!');
    }

    console.log('\n');
    process.exit(0);
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
  }
}

sendTestNotification();
