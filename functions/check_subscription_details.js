const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../service-account-key.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function checkSubscriptionDetails() {
  console.log('📱 DETAILED SUBSCRIPTION CHECK:\n');
  
  const subscriptions = await db.collection('business_subscriptions').get();
  
  subscriptions.forEach((doc, idx) => {
    const data = doc.data();
    console.log(`\n${idx + 1}. Owner ID: ${doc.id}`);
    console.log(`   Email: ${data.email}`);
    console.log(`   Status: ${data.status}`);
    console.log(`   Plan: ${data.planName}`);
    console.log(`   Stripe Subscription ID: ${data.stripeSubscriptionId}`);
    console.log(`   Stripe Customer ID: ${data.stripeCustomerId}`);
    console.log(`   Business ID: ${data.businessId}`);
    
    if (data.currentPeriodStart && data.currentPeriodEnd) {
      const start = data.currentPeriodStart.toDate();
      const end = data.currentPeriodEnd.toDate();
      console.log(`   Period: ${start.toISOString().split('T')[0]} to ${end.toISOString().split('T')[0]}`);
      
      const now = new Date();
      if (now >= end) {
        console.log(`   ⚠️  PERIOD EXPIRED (${Math.floor((now - end) / (1000 * 60 * 60 * 24))} days ago)`);
      } else {
        const daysLeft = Math.floor((end - now) / (1000 * 60 * 60 * 24));
        console.log(`   ✅ Period active (${daysLeft} days remaining)`);
      }
    }
    
    if (data.cancelAtPeriodEnd) {
      console.log(`   ⚠️  SCHEDULED FOR CANCELLATION`);
    }
    
    console.log(`   Created: ${data.createdAt ? data.createdAt.toDate().toISOString().split('T')[0] : 'N/A'}`);
    console.log(`   Updated: ${data.updatedAt ? data.updatedAt.toDate().toISOString().split('T')[0] : 'N/A'}`);
  });
  
  console.log('\n\n💰 PAYMENT HISTORY FOR THESE OWNERS:\n');
  
  subscriptions.forEach((subDoc) => {
    const ownerId = subDoc.id;
    const ownerData = subDoc.data();
  });
  
  // Check if there are any failed payments or other records
  console.log('\n📊 CHECKING ALL COLLECTIONS FOR THESE OWNERS:\n');
  
  subscriptions.forEach(async (subDoc) => {
    const ownerId = subDoc.id;
    const email = subDoc.data().email;
    const stripeSubId = subDoc.data().stripeSubscriptionId;
    
    // Check business_payments
    const payments = await db
      .collection('business_payments')
      .where('ownerId', '==', ownerId)
      .get();
    
    console.log(`Owner: ${ownerId} (${email})`);
    console.log(`  Stripe Subscription: ${stripeSubId}`);
    console.log(`  Payments recorded: ${payments.size}`);
    
    if (payments.size > 0) {
      payments.forEach(doc => {
        const data = doc.data();
        console.log(`    - ${data.type}: A$${(data.amountCents/100).toFixed(2)} [${data.status}]`);
      });
    } else {
      console.log(`    ⚠️  NO PAYMENTS RECORDED`);
    }
    
  });
  
  // Wait a bit then exit
  setTimeout(() => {
    process.exit(0);
  }, 2000);
}

checkSubscriptionDetails().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
