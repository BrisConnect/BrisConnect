#!/usr/bin/env node

const admin = require('firebase-admin');
const Stripe = require('stripe');
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

// Get Stripe secret key from environment or from .env file
let stripeSecretKey = process.env.STRIPE_SECRET_KEY;
if (!stripeSecretKey) {
  try {
    const envFile = path.join(__dirname, '..', '.env');
    const envContent = fs.readFileSync(envFile, 'utf-8');
    const match = envContent.match(/STRIPE_SECRET_KEY=(.+)/);
    if (match) {
      stripeSecretKey = match[1].trim();
    }
  } catch (e) {
    console.warn('⚠️  Could not find STRIPE_SECRET_KEY in environment or .env file');
  }
}

if (!stripeSecretKey) {
  console.error('❌ STRIPE_SECRET_KEY not found. Set it as environment variable or in .env file');
  process.exit(1);
}

const stripe = new Stripe(stripeSecretKey, { apiVersion: '2024-06-20' });

async function checkRevenueAndSubscriptions() {
  console.log('🔍 Checking Revenue and Subscriptions...\n');

  try {
    // 1. Get revenue from Firestore (last 30 days)
    console.log('📊 FIRESTORE ANALYSIS');
    console.log('====================\n');

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const paymentsSnapshot = await db
      .collection('business_payments')
      .where('status', '==', 'paid')
      .where('paidAt', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    console.log(`Found ${paymentsSnapshot.size} payments in last 30 days:\n`);

    let totalRevenueCents = 0;
    let subscriptionPayments = 0;
    let promotionPayments = 0;
    const paymentsByOwner = {};
    const paymentsByType = {};

    paymentsSnapshot.forEach((doc) => {
      const data = doc.data();
      const amountCents = data.amountCents || data.amount || 0;
      const type = data.type || 'unknown';
      const ownerId = data.ownerId || 'unknown';

      totalRevenueCents += amountCents;

      if (type === 'subscription') subscriptionPayments++;
      if (type === 'promotion') promotionPayments++;

      if (!paymentsByOwner[ownerId]) {
        paymentsByOwner[ownerId] = { count: 0, total: 0, payments: [] };
      }
      paymentsByOwner[ownerId].count++;
      paymentsByOwner[ownerId].total += amountCents;
      paymentsByOwner[ownerId].payments.push({
        id: doc.id,
        type,
        amount: (amountCents / 100).toFixed(2),
        date: data.paidAt ? data.paidAt.toDate() : 'unknown',
      });

      if (!paymentsByType[type]) {
        paymentsByType[type] = { count: 0, total: 0 };
      }
      paymentsByType[type].count++;
      paymentsByType[type].total += amountCents;
    });

    console.log(`Total Revenue (30 days): A$${(totalRevenueCents / 100).toFixed(2)}`);
    console.log(`Subscription Payments: ${subscriptionPayments}`);
    console.log(`Promotion Payments: ${promotionPayments}\n`);

    console.log('Breakdown by Type:');
    Object.entries(paymentsByType).forEach(([type, data]) => {
      console.log(
        `  ${type}: ${data.count} payments = A$${(data.total / 100).toFixed(2)}`
      );
    });

    console.log('\nTop 10 Owners by Revenue:');
    Object.entries(paymentsByOwner)
      .sort((a, b) => b[1].total - a[1].total)
      .slice(0, 10)
      .forEach(([ownerId, data]) => {
        console.log(`  ${ownerId}: ${data.count} payments = A$${(data.total / 100).toFixed(2)}`);
      });

    // 2. Get subscriptions from Firestore
    console.log('\n\n📱 FIRESTORE SUBSCRIPTIONS');
    console.log('=========================\n');

    const subscriptionsSnapshot = await db.collection('business_subscriptions').get();

    console.log(`Found ${subscriptionsSnapshot.size} subscription records:\n`);

    const subscriptionsByStatus = {};
    subscriptionsSnapshot.forEach((doc) => {
      const data = doc.data();
      const status = data.status || 'unknown';

      if (!subscriptionsByStatus[status]) {
        subscriptionsByStatus[status] = 0;
      }
      subscriptionsByStatus[status]++;
    });

    Object.entries(subscriptionsByStatus).forEach(([status, count]) => {
      console.log(`  ${status}: ${count} subscriptions`);
    });

    // 3. Get subscriptions from Stripe
    console.log('\n\n💳 STRIPE ANALYSIS');
    console.log('==================\n');

    const allSubscriptions = [];
    let hasMore = true;
    let startingAfter = null;

    while (hasMore) {
      const listParams = { limit: 100 };
      if (startingAfter) {
        listParams.starting_after = startingAfter;
      }

      const subscriptionsPage = await stripe.subscriptions.list(listParams);
      allSubscriptions.push(...subscriptionsPage.data);

      hasMore = subscriptionsPage.has_more;
      if (subscriptionsPage.data.length > 0) {
        startingAfter = subscriptionsPage.data[subscriptionsPage.data.length - 1].id;
      }
    }

    console.log(`Found ${allSubscriptions.length} subscriptions in Stripe:\n`);

    const stripeByStatus = {};
    let totalMRRCents = 0;

    allSubscriptions.forEach((sub) => {
      const status = sub.status;
      if (!stripeByStatus[status]) {
        stripeByStatus[status] = { count: 0, amountPerMonth: 0 };
      }
      stripeByStatus[status].count++;

      // Calculate monthly amount
      if (sub.items && sub.items.data.length > 0) {
        const item = sub.items.data[0];
        if (item.price && item.price.recurring) {
          const amountCents = item.price.unit_amount;
          if (status === 'active') {
            totalMRRCents += amountCents;
          }
          stripeByStatus[status].amountPerMonth += amountCents;
        }
      }
    });

    Object.entries(stripeByStatus).forEach(([status, data]) => {
      console.log(
        `  ${status}: ${data.count} subscriptions (A$${(data.amountPerMonth / 100).toFixed(2)}/month combined)`
      );
    });

    console.log(
      `\nTotal MRR (Monthly Recurring Revenue - active subscriptions): A$${(totalMRRCents / 100).toFixed(2)}`
    );

    // 4. Comparison
    console.log('\n\n🔄 COMPARISON & DISCREPANCIES');
    console.log('==============================\n');

    const activeSubscriptionsInStripe = stripeByStatus.active?.count || 0;
    const activeSubscriptionsInFirestore =
      subscriptionsByStatus.active || 0;

    console.log('Subscription Count:');
    console.log(`  Firestore (active): ${activeSubscriptionsInFirestore}`);
    console.log(`  Stripe (active): ${activeSubscriptionsInStripe}`);

    if (activeSubscriptionsInFirestore !== activeSubscriptionsInStripe) {
      console.log(
        `  ⚠️  MISMATCH: ${Math.abs(
          activeSubscriptionsInFirestore - activeSubscriptionsInStripe
        )} difference`
      );
    } else {
      console.log(`  ✅ MATCH`);
    }

    console.log('\nMonthly Recurring Revenue:');
    const mrr = (totalMRRCents / 100).toFixed(2);
    console.log(`  Stripe MRR: A$${mrr}`);
    console.log(`  Dashboard shows: A$${(totalRevenueCents / 100).toFixed(2)}`);
    console.log(
      `  Note: Dashboard revenue includes all paid transactions, not just subscriptions`
    );

    // 5. Detailed invoice check
    console.log('\n\n📋 RECENT INVOICES (last 10)');
    console.log('============================\n');

    const invoices = await stripe.invoices.list({ limit: 10, status: 'paid' });

    console.log(`Found ${invoices.data.length} recent paid invoices:\n`);

    invoices.data.forEach((invoice, idx) => {
      const subscription = allSubscriptions.find(
        (s) => s.id === invoice.subscription
      );
      const metadata = subscription?.metadata || {};
      console.log(`${idx + 1}. Invoice ${invoice.id}`);
      console.log(
        `   Amount: A$${(invoice.amount_paid / 100).toFixed(2)} | Status: ${invoice.status}`
      );
      console.log(
        `   Owner: ${metadata.ownerId || 'unknown'} | Business: ${metadata.businessId || 'none'}`
      );
      console.log(
        `   Date: ${new Date(invoice.created * 1000).toISOString().split('T')[0]}`
      );
      console.log('');
    });

    console.log('\n✅ Report complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error checking revenue and subscriptions:', error);
    process.exit(1);
  }
}

checkRevenueAndSubscriptions();
