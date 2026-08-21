#!/usr/bin/env node

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ service-account-key.json not found');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function getStripeSecretKey() {
  try {
    // Try to get from Firebase secret manager
    const config = await admin.firestore().collection('config').doc('stripe').get();
    if (config.exists) {
      return config.data().secretKey;
    }
  } catch (e) {
    // ignore
  }
  
  // Fallback to environment
  return process.env.STRIPE_SECRET_KEY;
}

async function checkStripeData() {
  console.log('🔍 Checking Stripe Data via Firebase Functions...\n');

  try {
    // Call Firebase function to get Stripe data
    const callable = admin.functions().httpsCallable('getStripeMetrics');
    
    console.log('Calling Firebase function: getStripeMetrics...\n');
    
    try {
      const result = await callable();
      console.log(JSON.stringify(result.data, null, 2));
    } catch (error) {
      if (error.code === 'not-found' || error.code === 'unavailable') {
        console.log('Function not available. Checking Firestore data instead...\n');
        
        // Check all payment records
        const allPayments = await db.collection('business_payments').get();
        console.log(`Total payment records: ${allPayments.size}\n`);
        
        const byStatus = {};
        const byType = {};
        
        allPayments.forEach(doc => {
          const data = doc.data();
          const status = data.status || 'unknown';
          const type = data.type || 'unknown';
          
          byStatus[status] = (byStatus[status] || 0) + 1;
          byType[type] = (byType[type] || 0) + 1;
        });
        
        console.log('By Status:', byStatus);
        console.log('By Type:', byType);
        console.log('\nPayments marked as "paid":');
        
        const paidPayments = await db
          .collection('business_payments')
          .where('status', '==', 'paid')
          .get();
        
        paidPayments.forEach((doc, idx) => {
          const data = doc.data();
          console.log(`\n${idx + 1}. ${data.type || 'unknown'}`);
          console.log(`   Owner: ${data.ownerId}`);
          console.log(`   Amount: A$${((data.amountCents || 0) / 100).toFixed(2)}`);
          console.log(`   Date: ${data.paidAt ? data.paidAt.toDate().toISOString().split('T')[0] : 'N/A'}`);
          console.log(`   Stripe ID: ${data.stripeInvoiceId || data.stripeSessionId || 'N/A'}`);
        });
        
      } else {
        console.error('Error calling function:', error.message);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  
  process.exit(0);
}

checkStripeData();
