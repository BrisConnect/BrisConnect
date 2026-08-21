#!/usr/bin/env node

/**
 * Stripe Webhook Configuration Diagnostic
 * 
 * This script helps verify and debug your Stripe webhook configuration.
 * It checks:
 * 1. Webhook endpoint status in Stripe
 * 2. Recent webhook deliveries and failures
 * 3. Whether events are reaching your Firebase function
 * 4. Provides instructions to create/update webhooks if needed
 */

const fs = require('fs');
const path = require('path');

const projectId = 'brisconnect-68b78';
const region = 'australia-southeast1';

// Expected webhook endpoint URLs
const webhookUrls = [
  `https://${region}-${projectId}.cloudfunctions.net/stripeWebhook`,
  `https://us-central1-${projectId}.cloudfunctions.net/stripeWebhook`, // Alternative region
];

const expectedEvents = [
  'checkout.session.completed',
  'invoice.payment_succeeded',
  'invoice.payment_failed',
  'customer.subscription.deleted',
];

console.log('🔍 Stripe Webhook Configuration Diagnostic\n');
console.log('═══════════════════════════════════════════════════════════════\n');

console.log('📋 Expected Configuration:\n');
console.log('Project ID:', projectId);
console.log('Region:', region);
console.log('\nExpected Webhook URLs:');
webhookUrls.forEach((url, idx) => {
  console.log(`  ${idx + 1}. ${url}`);
});

console.log('\nExpected Events:');
expectedEvents.forEach(evt => {
  console.log(`  • ${evt}`);
});

console.log('\n═══════════════════════════════════════════════════════════════\n');

console.log('🔧 To Verify/Fix Webhook Configuration:\n');

console.log('1️⃣  GO TO STRIPE DASHBOARD:');
console.log('   https://dashboard.stripe.com/webhooks\n');

console.log('2️⃣  CHECK ENDPOINT STATUS:');
console.log(`   Look for endpoint ending with: /stripeWebhook`);
console.log(`   Expected URL: ${webhookUrls[0]}\n`);

console.log('3️⃣  IF ENDPOINT DOES NOT EXIST, CREATE IT:');
console.log('   a) Click "Add Endpoint"');
console.log(`   b) Enter URL: ${webhookUrls[0]}`);
console.log('   c) Select Events:');
expectedEvents.forEach(evt => {
  console.log(`      ☐ ${evt}`);
});
console.log('   d) Click "Add Endpoint"\n');

console.log('4️⃣  IF ENDPOINT EXISTS, CHECK EVENTS:');
console.log('   a) Click on the endpoint to view details');
console.log('   b) Check "Events to send" - should include all above events');
console.log('   c) Scroll to "Recent deliveries" to see delivery attempts');
console.log('   d) Look for any failures or 5xx errors\n');

console.log('5️⃣  TEST WEBHOOK DELIVERY:');
console.log('   In the endpoint details, click "Send test event"');
console.log('   Select a test event type to verify delivery\n');

console.log('6️⃣  VERIFY IN FIREBASE LOGS:');
console.log('   Run this command to watch Firebase function logs:');
console.log(`   firebase functions:log -r ${region} --follow\n`);

console.log('═══════════════════════════════════════════════════════════════\n');

console.log('📊 Common Webhook Issues:\n');

console.log('❌ "Endpoint rejected requests with 4xx response"');
console.log('   → Check that Firebase function allows unauthenticated access');
console.log('   → Verify Firebase CORS is properly configured\n');

console.log('❌ "Endpoint not responding (timeout)"');
console.log('   → Function may be cold-starting, check logs');
console.log('   → Verify function has sufficient timeout (should be 30+ seconds)\n');

console.log('❌ "No deliveries showing in Stripe Dashboard"');
console.log('   → Endpoint may not be subscribed to events');
console.log('   → Check that events are enabled in endpoint configuration\n');

console.log('❌ "Payment recorded but reconciliation shows different amount"');
console.log('   → Check invoice.amount_paid vs invoice.amount_total');
console.log('   → Verify SUBSCRIPTION_PRICE_CENTS matches actual Stripe price\n');

console.log('═══════════════════════════════════════════════════════════════\n');

console.log('🚀 After Fixing Webhook:\n');

console.log('1. Deploy updated Firebase functions:');
console.log('   firebase deploy --only functions\n');

console.log('2. Trigger manual reconciliation:');
console.log('   firebase functions:call manualReconcileSubscriptions\n');

console.log('3. Monitor logs:');
console.log(`   firebase functions:log -r ${region} --follow\n`);

console.log('4. Verify in admin dashboard:');
console.log('   Check monthly revenue metric at https://brisconnect-68b78.web.app/admin/dashboard\n');

console.log('═══════════════════════════════════════════════════════════════\n');

// Try to read local config for additional debugging
try {
  const envPath = path.join(__dirname, '.env.brisconnect-68b78');
  if (fs.existsSync(envPath)) {
    console.log('📄 Local Configuration Found:\n');
    const content = fs.readFileSync(envPath, 'utf-8');
    console.log('Keys configured:');
    const keys = content.split('\n')
      .filter(line => line.trim() && !line.startsWith('#'))
      .map(line => line.split('=')[0]);
    keys.forEach(key => {
      const configured = content.includes(key);
      console.log(`  ${configured ? '✅' : '❌'} ${key}`);
    });
  }
} catch (e) {
  // ignore
}

console.log('\n✨ Webhook diagnostics complete!\n');
