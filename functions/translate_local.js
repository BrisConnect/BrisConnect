#!/usr/bin/env node

/**
 * Local script to trigger bulk translation
 * Runs locally and has access to ARB files
 */

const path = require('path');
const { bulkTranslateAllLanguages } = require('./translation');

async function main() {
  try {
    console.log('🌍 Starting bulk translation for all 14 languages...\n');
    console.log('Languages: es, fr, de, zh, ar, hi, it, ja, ko, pt, ru, vi, el, pa\n');

    // Call the translation function (runs locally, has access to files)
    const results = await bulkTranslateAllLanguages('brisconnect-68b78');

    console.log('\n✅ Translation Complete!\n');

    // Print summary
    let successCount = 0;
    let totalTranslated = 0;

    Object.entries(results).forEach(([lang, result]) => {
      if (result.success) {
        successCount++;
        totalTranslated += result.messagesTranslated;
        console.log(`   ✓ ${lang.toUpperCase()}: ${result.messagesTranslated} strings translated`);
      } else {
        console.log(`   ✗ ${lang.toUpperCase()}: Failed - ${result.errors.join(', ')}`);
      }
    });

    console.log(`\n📊 Summary: ${totalTranslated} total strings translated across ${successCount} languages`);
    console.log('\n✨ All ARB files have been updated!');
    console.log('📱 Next: Rebuild and redeploy the web app to see changes in production.\n');

    process.exit(results && Object.values(results).some(r => r.success) ? 0 : 1);
  } catch (error) {
    console.error('❌ Error during translation:', error.message);
    if (error.stack) {
      console.error('\nStack:', error.stack);
    }
    process.exit(1);
  }
}

main();
