/**
 * test_google_monitoring.js
 * 
 * Test script to run Google listing monitoring on a small sample.
 * 
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="../service-account-key.json"
 *   node test_google_monitoring.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const { monitorAllGoogleListings } = require('./monitor_google_listings');
const { defineSecret } = require('firebase-functions/params');

// Load service account
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found at:', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

/**
 * Get Google Places API key from environment or secrets
 */
async function getApiKey() {
  // Try environment variable first
  if (process.env.GOOGLE_PLACES_API_KEY) {
    return process.env.GOOGLE_PLACES_API_KEY;
  }

  // Try alternate names
  if (process.env.GOOGLE_CLOUD_API_KEY) {
    return process.env.GOOGLE_CLOUD_API_KEY;
  }

  // Try to read from .env file
  const envPath = path.join(__dirname, '.env.brisconnect-68b78');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    
    // Try both possible key names
    let match = envContent.match(/GOOGLE_PLACES_API_KEY\s*=\s*(.+)/);
    if (match) {
      return match[1].trim();
    }
    
    match = envContent.match(/GOOGLE_CLOUD_API_KEY\s*=\s*(.+)/);
    if (match) {
      return match[1].trim();
    }
  }

  console.error('❌ Google Places API key not found');
  process.exit(1);
}

async function runTest() {
  try {
    console.log('\n🔍 Starting Google Listing Monitoring Test');
    console.log('==========================================\n');

    const apiKey = await getApiKey();
    console.log('✅ API Key loaded');

    // Run monitoring on 5 businesses as a test
    console.log('📊 Running monitoring on up to 5 sample businesses...\n');

    const results = await monitorAllGoogleListings(apiKey, 5);

    console.log('\n✅ Test Complete\n');
    console.log('Summary:');
    console.log(`├── Processed: ${results.processed}`);
    console.log(`├── Verified: ${results.verified}`);
    console.log(`├── Mismatches: ${results.mismatch}`);
    console.log(`├── Closed: ${results.closed}`);
    console.log(`└── Errors: ${results.errors}\n`);

    // Fetch and display the monitoring records created
    console.log('📋 Monitoring Records Created:\n');

    const monitoringSnap = await db
      .collection('google_listing_monitoring')
      .orderBy('checkTimestamp', 'desc')
      .limit(5)
      .get();

    for (const doc of monitoringSnap.docs) {
      const record = doc.data();
      console.log(`\n─── Record: ${doc.id}`);
      console.log(`    Business: ${record.businessName}`);
      console.log(`    Collection: ${record.businessCollection}`);
      console.log(`    Status: ${record.status}`);
      console.log(`    Severity: ${record.severity}`);
      console.log(`    Has Changes: ${record.hasChanges}`);

      if (record.hasChanges && record.changes) {
        console.log(`    Changes Detected:`);
        for (const [field, change] of Object.entries(record.changes)) {
          if (change.differs) {
            console.log(`      • ${field}:`);
            console.log(`        BrisConnect: ${change.brisconnect}`);
            console.log(`        Google: ${change.google}`);
            if (change.similarity !== undefined) {
              console.log(`        Similarity: ${(change.similarity * 100).toFixed(1)}%`);
            }
          }
        }
      }

      if (record.status === 'error') {
        console.log(`    Error: ${record.errorReason}`);
      }
    }

    console.log('\n\n✅ Test Results Available in Firestore');
    console.log('Collection: google_listing_monitoring\n');

    // Display sample record structure
    if (monitoringSnap.docs.length > 0) {
      const sampleRecord = monitoringSnap.docs[0].data();
      console.log('📌 Sample Record Structure:');
      console.log(JSON.stringify(sampleRecord, null, 2).substring(0, 500) + '...\n');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

runTest();
