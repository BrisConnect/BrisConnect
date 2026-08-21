#!/usr/bin/env node

/**
 * Fix ARB files by replacing translated placeholders with English equivalents
 * This is needed because Google Translate API translates the placeholder text too
 */

const fs = require('fs');
const path = require('path');

// Common placeholder translations across languages
const PLACEHOLDER_FIXES = {
  // Punjabi
  'ਸਿਰਲੇਖ': 'title',
  'ਗਿਣਤੀ': 'count',
  'ਮੁੱਲ': 'value',
  'ਰੇਟਿੰਗ': 'rating',
  
  // Hindi
  'शीर्षक': 'title',
  'गिनती': 'count',
  'कीमत': 'value',
  'रेटिंग': 'rating',
  
  // Arabic
  'العنوان': 'title',
  'عدد': 'count',
  'قيمة': 'value',
  'تصنيف': 'rating',
  
  // Chinese
  '标题': 'title',
  '计数': 'count',
  '值': 'value',
  '评分': 'rating',
  
  // Japanese
  'タイトル': 'title',
  '数': 'count',
  '値': 'value',
  '評価': 'rating',
  
  // Greek
  'τίτλος': 'title',
  'αριθμός': 'count',
  'αξία': 'value',
  'αξιολόγηση': 'rating',
};

const LANGUAGE_CODES = ['es', 'fr', 'de', 'zh', 'ar', 'hi', 'it', 'ja', 'ko', 'pt', 'ru', 'vi', 'el', 'pa'];
const L10N_DIR = path.join(__dirname, '../lib/l10n');

function fixArb(filePath, languageCode) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    let data = JSON.parse(content);
    let modified = false;
    let fixCount = 0;

    // For each key-value pair
    Object.keys(data).forEach(key => {
      if (key.startsWith('@') || key.startsWith('_')) return;

      const value = data[key];
      if (typeof value !== 'string') return;

      // Replace all translated placeholders with English ones
      let newValue = value;
      Object.entries(PLACEHOLDER_FIXES).forEach(([translated, english]) => {
        const pattern = `{${translated}}`;
        const replacement = `{${english}}`;
        if (newValue.includes(pattern)) {
          newValue = newValue.split(pattern).join(replacement);
          fixCount++;
          modified = true;
        }
      });

      if (modified && newValue !== value) {
        data[key] = newValue;
      }
    });

    if (modified) {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
      console.log(`✓ Fixed ${languageCode.toUpperCase()}: ${fixCount} placeholders restored`);
    }
  } catch (error) {
    console.error(`✗ Error fixing ${languageCode}:`, error.message);
  }
}

console.log('🔧 Fixing translated ARB files...\n');

LANGUAGE_CODES.forEach(lang => {
  const filePath = path.join(L10N_DIR, `app_${lang}.arb`);
  if (fs.existsSync(filePath)) {
    fixArb(filePath, lang);
  }
});

console.log('\n✨ All ARB files fixed! Placeholders restored to English format.');
