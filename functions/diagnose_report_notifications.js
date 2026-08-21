#!/usr/bin/env node
/**
 * Diagnostic tool to check why report submissions aren't alerting admins.
 * Checks:
 * 1. Recent report submissions in all collections
 * 2. Admin notification records created
 * 3. Admin FCM tokens registered
 * 4. Cloud Functions deployment status
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
const logger = console;

async function diagnoseReportNotifications() {
  logger.log('\n🔍 REPORT NOTIFICATION DIAGNOSTIC\n');

  try {
    // 1. Check for recent reports
    logger.log('1️⃣  CHECKING FOR RECENT REPORTS\n');

    const reportCollections = [
      'event_reports',
      'photo_reports',
      'business_reports',
      'user_reports',
      'community_post_reports',
    ];

    let totalReports = 0;
    const recentReports = {};

    for (const collectionName of reportCollections) {
      try {
        const snapshot = await db
          .collection(collectionName)
          .orderBy('createdAt', 'desc')
          .limit(5)
          .get();

        recentReports[collectionName] = snapshot.docs.length;
        totalReports += snapshot.docs.length;

        if (snapshot.docs.length > 0) {
          logger.log(`✅ Found ${snapshot.docs.length} recent reports in ${collectionName}:`);
          snapshot.docs.forEach((doc) => {
            const data = doc.data();
            const createdAt = data.createdAt?.toDate?.() || new Date(data.createdAt);
            logger.log(`   - ID: ${doc.id}`);
            logger.log(`     Created: ${createdAt.toISOString()}`);
            logger.log(`     Reason: ${data.reason || 'N/A'}`);
          });
        } else {
          logger.log(`❌ No reports found in ${collectionName}\n`);
        }
      } catch (e) {
        logger.log(`⚠️  Error checking ${collectionName}: ${e.message}`);
      }
    }

    logger.log(`\n📊 Total recent reports across all types: ${totalReports}\n`);

    // 2. Check if admin notifications were created for recent reports
    logger.log('2️⃣  CHECKING ADMIN NOTIFICATIONS\n');

    const adminNotifSnapshot = await db
      .collection('admin_notifications')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    const reportedContentNotifs = adminNotifSnapshot.docs.filter(
      (doc) => doc.data().type === 'reported_content',
    );

    if (reportedContentNotifs.length === 0) {
      logger.log('❌ NO ADMIN NOTIFICATIONS FOR REPORTED_CONTENT FOUND\n');
      logger.log('   This suggests the Cloud Functions are not triggering!\n');
    } else {
      logger.log(`✅ Found ${reportedContentNotifs.length} admin notifications for reported content:`);
      reportedContentNotifs.forEach((doc) => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate?.() || new Date(data.createdAt);
        logger.log(`   - ID: ${doc.id}`);
        logger.log(`     Title: ${data.title}`);
        logger.log(`     Created: ${createdAt.toISOString()}`);
        logger.log(`     Admin: ${data.adminEmail || 'N/A'}`);
      });
    }

    logger.log(`\nTotal admin notifications in system: ${adminNotifSnapshot.docs.length}`);

    // 3. Check admin configuration
    logger.log('\n3️⃣  CHECKING ADMIN CONFIGURATION\n');

    const adminsSnapshot = await db.collection('admins').get();
    if (adminsSnapshot.empty) {
      logger.log('❌ NO ADMINS CONFIGURED\n');
    } else {
      logger.log(`✅ ${adminsSnapshot.docs.length} admin(s) found:`);
      for (const doc of adminsSnapshot.docs) {
        const adminEmail = doc.id;
        const tokensSnapshot = await db
          .collection('local_users')
          .doc(adminEmail)
          .collection('fcmTokens')
          .get();
        logger.log(`   - ${adminEmail}: ${tokensSnapshot.docs.length} FCM token(s)`);
      }
    }

    // 4. Check Cloud Functions logs (latest 10 minutes)
    logger.log('\n4️⃣  CLOUD FUNCTIONS STATUS\n');
    logger.log('To check Cloud Functions logs:');
    logger.log('👉 https://console.firebase.google.com/project/brisconnect-68b78/functions/list');
    logger.log('');
    logger.log('Look for these function names:');
    logger.log('  - onEventReported');
    logger.log('  - onPhotoReported');
    logger.log('  - onBusinessReported');
    logger.log('  - onUserReported');
    logger.log('  - onCommunityPostReported');
    logger.log('');

    // 5. Final recommendations
    logger.log('\n5️⃣  WHAT TO DO NEXT\n');

    if (totalReports === 0) {
      logger.log('❌ No reports found in Firestore');
      logger.log('   → Verify that reports are actually being submitted by visitors');
      logger.log('   → Check visitor app for errors when submitting reports\n');
    } else if (adminNotifSnapshot.empty) {
      logger.log('❌ Reports exist but admin notifications NOT created');
      logger.log('   → Cloud Functions may not be deploying correctly');
      logger.log('   → Run: firebase deploy --only functions\n');
    } else {
      logger.log('✅ Reports are triggering admin notifications correctly!');
      logger.log('   → Check if notifications are reaching admin via FCM/Email\n');
    }

    logger.log('\n✨ DIAGNOSTIC COMPLETE\n');
  } catch (error) {
    logger.error('Fatal error during diagnosis:', error);
    process.exit(1);
  }
}

diagnoseReportNotifications().catch((error) => {
  logger.error('Error:', error);
  process.exit(1);
});
