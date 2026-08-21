const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../service-account-key.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function check() {
  // Get all payments
  const payments = await db.collection('business_payments').get();
  
  console.log('📋 ALL PAYMENT RECORDS:\n');
  const byType = {};
  
  payments.forEach(doc => {
    const data = doc.data();
    const type = data.type || 'unknown';
    if (!byType[type]) byType[type] = [];
    byType[type].push({
      owner: data.ownerId,
      amount: data.amountCents,
      status: data.status,
      date: data.paidAt ? data.paidAt.toDate().toISOString().split('T')[0] : 'N/A'
    });
  });
  
  for (const [type, items] of Object.entries(byType)) {
    console.log(`${type.toUpperCase()} (${items.length} records):`);
    let total = 0;
    items.forEach(item => {
      console.log(`  • ${item.owner}: A$${(item.amount/100).toFixed(2)} [${item.status}] - ${item.date}`);
      total += item.amount;
    });
    console.log(`  TOTAL: A$${(total/100).toFixed(2)}\n`);
  }
  
  process.exit(0);
}

check().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
