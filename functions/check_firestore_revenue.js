#!/usr/bin/env node

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ service-account-key.json not found at', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkFirestoreRevenueData() {
  console.log('🔍 Checking Firestore Revenue & Subscription Data...\n');

  try {
    // 1. Get revenue from Firestore (last 30 days)
    console.log('📊 PAYMENT RECORDS (Last 30 Days)');
    console.log('==================================\n');

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    // Query without compound index - filter in code instead
    const paymentsSnapshot = await db
      .collection('business_payments')
      .where('status', '==', 'paid')
      .get();
    
    // Filter by date in code
    const allPayments = paymentsSnapshot.docs.filter(doc => {
      const data = doc.data();
      if (!data.paidAt) return false;
      const paidDate = data.paidAt.toDate();
      return paidDate >= thirtyDaysAgo && paidDate <= now;
    }).sort((a, b) => {
      const dateA = a.data().paidAt?.toDate() || 0;
      const dateB = b.data().paidAt?.toDate() || 0;
      return dateB - dateA; // newest first
    });

    console.log(`Found ${allPayments.length} payments in last 30 days:\n`);

    let totalRevenueCents = 0;
    let subscriptionPayments = 0;
    let promotionPayments = 0;
    const paymentsByOwner = {};
    const paymentsByType = {};
    const paymentDetails = [];

    allPayments.forEach((doc) => {
      const data = doc.data();
      const amountCents = data.amountCents || data.amount || 0;
      const type = data.type || 'unknown';
      const ownerId = data.ownerId || 'unknown';
      const email = data.email || 'unknown';

      totalRevenueCents += amountCents;

      if (type === 'subscription') subscriptionPayments++;
      if (type === 'promotion') promotionPayments++;

      paymentDetails.push({
        id: doc.id,
        type,
        ownerId,
        email,
        amount: amountCents,
        paidAt: data.paidAt ? data.paidAt.toDate().toISOString() : 'unknown',
        planName: data.planName || 'N/A',
        stripeSessionId: data.stripeSessionId || data.stripeInvoiceId || 'N/A',
      });

      if (!paymentsByOwner[ownerId]) {
        paymentsByOwner[ownerId] = { count: 0, total: 0, email };
      }
      paymentsByOwner[ownerId].count++;
      paymentsByOwner[ownerId].total += amountCents;

      if (!paymentsByType[type]) {
        paymentsByType[type] = { count: 0, total: 0 };
      }
      paymentsByType[type].count++;
      paymentsByType[type].total += amountCents;
    });

    console.log(`💰 Total Revenue (30 days): A$${(totalRevenueCents / 100).toFixed(2)}`);
    console.log(`📝 Subscription Payments: ${subscriptionPayments}`);
    console.log(`🎯 Promotion Payments: ${promotionPayments}\n`);

    console.log('📈 Breakdown by Type:');
    Object.entries(paymentsByType).forEach(([type, data]) => {
      console.log(
        `  • ${type}: ${data.count} payments = A$${(data.total / 100).toFixed(2)}`
      );
    });

    console.log('\n👤 Top 10 Owners by Revenue:');
    Object.entries(paymentsByOwner)
      .sort((a, b) => b[1].total - a[1].total)
      .slice(0, 10)
      .forEach(([ownerId, data], idx) => {
        console.log(
          `  ${idx + 1}. ${ownerId} (${data.email}): ${data.count} payments = A$${(
            data.total / 100
          ).toFixed(2)}`
        );
      });

    console.log('\n📋 All Payment Details (sorted by date):');
    console.log('========================================\n');
    paymentDetails.forEach((payment, idx) => {
      console.log(`${idx + 1}. ${payment.type.toUpperCase()}`);
      console.log(`   Owner: ${payment.ownerId}`);
      console.log(`   Email: ${payment.email}`);
      console.log(`   Amount: A$${(payment.amount / 100).toFixed(2)}`);
      console.log(`   Plan: ${payment.planName}`);
      console.log(`   Date: ${payment.paidAt}`);
      console.log(`   ID: ${payment.stripeSessionId}`);
      console.log('');
    });

    // 2. Get subscriptions from Firestore
    console.log('\n📱 SUBSCRIPTION RECORDS');
    console.log('======================\n');

    const subscriptionsSnapshot = await db.collection('business_subscriptions').get();

    console.log(`Found ${subscriptionsSnapshot.size} subscription records:\n`);

    const subscriptionsByStatus = {};
    const subscriptionDetails = [];

    subscriptionsSnapshot.forEach((doc) => {
      const data = doc.data();
      const status = data.status || 'unknown';
      const ownerId = data.ownerId || doc.id;

      if (!subscriptionsByStatus[status]) {
        subscriptionsByStatus[status] = 0;
      }
      subscriptionsByStatus[status]++;

      subscriptionDetails.push({
        ownerId,
        email: data.email || 'N/A',
        status,
        planName: data.planName || 'N/A',
        stripeSubscriptionId: data.stripeSubscriptionId || 'N/A',
        currentPeriodStart: data.currentPeriodStart
          ? data.currentPeriodStart.toDate().toISOString().split('T')[0]
          : 'N/A',
        currentPeriodEnd: data.currentPeriodEnd
          ? data.currentPeriodEnd.toDate().toISOString().split('T')[0]
          : 'N/A',
        cancelAtPeriodEnd: data.cancelAtPeriodEnd || false,
      });
    });

    Object.entries(subscriptionsByStatus).forEach(([status, count]) => {
      console.log(`  • ${status}: ${count} subscriptions`);
    });

    console.log('\n📋 All Subscriptions:\n');
    subscriptionDetails.forEach((sub, idx) => {
      console.log(`${idx + 1}. ${sub.ownerId}`);
      console.log(`   Email: ${sub.email}`);
      console.log(`   Status: ${sub.status}`);
      console.log(`   Plan: ${sub.planName}`);
      console.log(`   Period: ${sub.currentPeriodStart} to ${sub.currentPeriodEnd}`);
      console.log(`   Cancel at period end: ${sub.cancelAtPeriodEnd}`);
      console.log(`   Stripe ID: ${sub.stripeSubscriptionId}`);
      console.log('');
    });

    // 3. Calculate expected MRR
    const activeSubscriptions = subscriptionDetails.filter(
      (s) => s.status === 'active'
    );
    const expectedMRRCents = activeSubscriptions.length * 999; // A$9.99 per subscription
    console.log(`\n💳 EXPECTED METRICS`);
    console.log('==================\n');
    console.log(
      `Active Subscriptions: ${activeSubscriptions.length}`
    );
    console.log(
      `Expected MRR (at A$9.99/month): A$${(expectedMRRCents / 100).toFixed(2)}`
    );

    console.log('\n✅ Report complete!\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkFirestoreRevenueData();
