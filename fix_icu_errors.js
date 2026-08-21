#!/usr/bin/env node

/**
 * Remove ICU message format from translated ARB files to fix lexing errors
 * This temporarily replaces complex strings with English equivalents
 */

const fs = require('fs');
const path = require('path');

const LANGUAGE_CODES = ['es', 'fr', 'de', 'zh', 'ar', 'hi', 'it', 'ja', 'ko', 'pt', 'ru', 'vi', 'el', 'pa'];
const L10N_DIR = path.join(__dirname, 'lib/l10n');

// Keys that have ICU issues - we'll revert these to English only
const KEYS_TO_REVERT = [
  'textScalePercent',
  'categoryLabel',
  'severityLabel',
  'versionLabel',
  'foodDescriptionIntro',
  'foodDescriptionCategories',
  'foodDescriptionPrice',
  'foodNarrationWelcome',
  'foodNarrationBadge',
  'foodNarrationCuisine',
  'foodNarrationLocation',
  'foodNarrationDateTime',
  'foodNarrationDescription',
  'foodNarrationPriceFree',
  'foodNarrationPrice',
  'foodNarrationRating',
  'foodNarrationCategories',
];

// Read English file to get correct values
const englishPath = path.join(L10N_DIR, 'app_en.arb');
const englishData = JSON.parse(fs.readFileSync(englishPath, 'utf-8'));

function revertToEnglish(filePath, languageCode) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    let data = JSON.parse(content);
    let modified = false;

    KEYS_TO_REVERT.forEach(key => {
      if (data[key] && englishData[key]) {
        data[key] = englishData[key];
        modified = true;
      }
    });

    if (modified) {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
      console.log(`✓ Reverted ${languageCode.toUpperCase()}: ${KEYS_TO_REVERT.length} ICU keys to English`);
    }
  } catch (error) {
    console.error(`✗ Error reverting ${languageCode}:`, error.message);
  }
}

console.log('🔧 Fixing ICU lexing errors by reverting complex strings...\n');

LANGUAGE_CODES.forEach(lang => {
  const filePath = path.join(L10N_DIR, `app_${lang}.arb`);
  if (fs.existsSync(filePath)) {
    revertToEnglish(filePath, lang);
  }
});

console.log('\n✨ ICU issues fixed! Complex strings reverted to English.');
console.log('   Other simple translations are preserved.\n');
