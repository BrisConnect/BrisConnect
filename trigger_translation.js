#!/usr/bin/env node

/**
 * Script to trigger bulk translation of all 14 languages
 * Run: node trigger_translation.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountKey = require(path.join(__dirname, 'service-account-key.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountKey),
  projectId: 'brisconnect-68b78',
});

const functions = admin.functions('australia-southeast1');

async function triggerTranslation() {
  try {
    console.log('🌍 Starting bulk translation for all 14 languages...');
    console.log('Languages: en, es, fr, de, zh, ar, hi, it, ja, ko, pt, ru, vi, el, pa\n');

    // Call the bulkTranslateLanguages Cloud Function
    const bulkTranslate = functions.httpsCallable('bulkTranslateLanguages');
    const result = await bulkTranslate({ projectId: 'brisconnect-68b78' });

    console.log('\n✅ Translation Complete!\n');
    console.log('Result:', JSON.stringify(result.data, null, 2));

    // Print summary
    if (result.data.results) {
      console.log('\n📊 Translation Summary:');
      result.data.results.forEach((langResult) => {
        console.log(
          `   ${langResult.language.toUpperCase()}: ${langResult.messagesTranslated} strings translated`,
        );
      });
    }

    console.log('\n✨ All languages have been translated!');
    console.log('📱 Rebuild and redeploy the web app to see changes in production.');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error triggering translation:', error.message);
    if (error.details) {
      console.error('Details:', error.details);
    }
    process.exit(1);
  }
}

triggerTranslation();
