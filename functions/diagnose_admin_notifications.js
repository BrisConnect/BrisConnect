#!/usr/bin/env node

/**
 * Diagnostic script to check admin notification system status
 * Usage: node diagnose_admin_notifications.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'brisconnect-68b78',
});

const db = admin.firestore();

async function diagnose() {
  console.log('\n=== ADMIN NOTIFICATION SYSTEM DIAGNOSTIC ===\n');

  try {
    // Check 1: Admins in admins collection
    console.log('1️⃣  Checking admins in `admins` collection...');
    const adminsSnapshot = await db.collection('admins').get();
    console.log(`   Found: ${adminsSnapshot.size} admin(s)`);
    adminsSnapshot.docs.forEach((doc) => {
      console.log(`   - ${doc.id}`);
    });

    if (adminsSnapshot.empty) {
      console.log('   ⚠️  WARNING: No admins found. Notifications cannot be sent.');
    }

    // Check 2: FCM tokens for each admin
    console.log('\n2️⃣  Checking FCM tokens for each admin...');
    let totalTokens = 0;
    for (const adminDoc of adminsSnapshot.docs) {
      const adminEmail = adminDoc.id;
      const tokensSnapshot = await db
        .collection('local_users')
        .doc(adminEmail)
        .collection('fcmTokens')
        .get();
      console.log(`   ${adminEmail}: ${tokensSnapshot.size} token(s)`);
      tokensSnapshot.docs.forEach((tokenDoc) => {
        console.log(`      - ${tokenDoc.id.substring(0, 32)}...`);
      });
      totalTokens += tokensSnapshot.size;
    }

    if (totalTokens === 0) {
      console.log('   ⚠️  WARNING: No FCM tokens registered for any admin.');
      console.log('      This means push notifications cannot be sent.');
      console.log('      Admins need to enable notifications on their device.');
    }

    // Check 3: Recent admin notifications
    console.log('\n3️⃣  Checking recent admin notifications in database...');
    const recentNotifications = await db
      .collection('admin_notifications')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    console.log(`   Found: ${recentNotifications.size} recent notification record(s)`);
    recentNotifications.docs.forEach((doc) => {
      const data = doc.data();
      console.log(`   - [${data.type}] ${data.title}`);
      console.log(`     Created: ${data.createdAt?.toDate?.() || 'N/A'}`);
      console.log(`     Admin: ${data.adminEmail}`);
      console.log(`     Read: ${data.read}`);
    });

    // Check 4: Notification health
    console.log('\n4️⃣  Checking notification system health...');
    const healthChecks = await db
      .collection('notification_health_checks')
      .orderBy('checkedAt', 'desc')
      .limit(5)
      .get();
    console.log(`   Found: ${healthChecks.size} health check record(s)`);
    healthChecks.docs.forEach((doc) => {
      const data = doc.data();
      console.log(`   - Status: ${data.status}`);
      console.log(`     Firestore reachable: ${data.firestoreReachable}`);
      console.log(`     FCM reachable: ${data.fcmReachable}`);
      console.log(`     Checked: ${data.checkedAt?.toDate?.() || 'N/A'}`);
    });

    // Check 5: Cloud Function logs
    console.log('\n5️⃣  Summary and recommendations...');
    if (adminsSnapshot.empty) {
      console.log('   ❌ ACTION REQUIRED:');
      console.log('      1. Add at least one admin email to the `admins` collection');
      console.log('      2. Each admin must have an entry: db.collection("admins").doc(email).set({})');
    }

    if (totalTokens === 0 && !adminsSnapshot.empty) {
      console.log('   ⚠️  ACTION REQUIRED:');
      console.log('      Admins have not enabled notifications on their device.');
      console.log('      1. Open admin portal on browser/app');
      console.log('      2. Accept notification permission when prompted');
      console.log('      3. Close and reopen to re-register FCM token');
    }

    if (recentNotifications.size === 0) {
      console.log('   ℹ️  No recent notifications persisted in Firestore.');
      console.log('      Check Cloud Function logs for sendAdminNotification calls.');
      console.log('      Run: firebase functions:log');
    }

    console.log('\n=== END DIAGNOSTIC ===\n');

    process.exit(0);
  } catch (error) {
    console.error('Error during diagnostic:', error.message);
    process.exit(1);
  }
}

diagnose();
