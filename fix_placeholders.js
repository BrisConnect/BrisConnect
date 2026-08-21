#!/usr/bin/env node

/**
 * Fix specific placeholder issues in all ARB files
 */

const fs = require('fs');
const path = require('path');

const LANGUAGE_CODES = ['es', 'fr', 'de', 'zh', 'ar', 'hi', 'it', 'ja', 'ko', 'pt', 'ru', 'vi', 'el', 'pa'];
const L10N_DIR = path.join(__dirname, 'lib/l10n');

// Map of placeholder replacements needed
const REPLACEMENTS = [
  // Punjabi replacements
  ['{ਸਿਰਲੇਖ}', '{title}'],
  ['{ਗਿਣਤੀ}', '{count}'],
  ['{ਮੁੱਲ}', '{value}'],
  ['{ਰੇਟਿੰਗ}', '{rating}'],
  ['{ਜਮਿਆ}', '{saved}'],
  ['{ਅਸਥਾਨ}', '{location}'],
  ['{ਖਾਣਾ}', '{cuisine}'],
  ['{ਕਿਸਮ}', '{type}'],
  
  // Hindi replacements
  ['{शीर्षक}', '{title}'],
  ['{गिनती}', '{count}'],
  ['{कीमत}', '{value}'],
  ['{रेटिंग}', '{rating}'],
  ['{बचाया}', '{saved}'],
  ['{स्थान}', '{location}'],
  ['{पकवान}', '{cuisine}'],
  
  // Arabic replacements
  ['{العنوان}', '{title}'],
  ['{عدد}', '{count}'],
  ['{قيمة}', '{value}'],
  ['{تصنيف}', '{rating}'],
  
  // Chinese replacements
  ['{标题}', '{title}'],
  ['{计数}', '{count}'],
  ['{值}', '{value}'],
  ['{评分}', '{rating}'],
  
  // Greek replacements
  ['{τίτλος}', '{title}'],
  ['{αριθμός}', '{count}'],
  ['{αξία}', '{value}'],
  ['{αξιολόγηση}', '{rating}'],
  
  // Japanese replacements
  ['{タイトル}', '{title}'],
  ['{数}', '{count}'],
  ['{値}', '{value}'],
  ['{評価}', '{rating}'],
];

function fixArb(filePath, languageCode) {
  try {
    let content = fs.readFileSync(filePath, 'utf-8');
    let modified = false;
    let fixCount = 0;

    REPLACEMENTS.forEach(([translated, english]) => {
      if (content.includes(translated)) {
        content = content.split(translated).join(english);
        fixCount++;
        modified = true;
      }
    });

    if (modified) {
      fs.writeFileSync(filePath, content, 'utf-8');
      console.log(`✓ Fixed ${languageCode.toUpperCase()}: ${fixCount} placeholders restored`);
    }
  } catch (error) {
    console.error(`✗ Error fixing ${languageCode}:`, error.message);
  }
}

console.log('🔧 Fixing placeholder issues in all ARB files...\n');

LANGUAGE_CODES.forEach(lang => {
  const filePath = path.join(L10N_DIR, `app_${lang}.arb`);
  if (fs.existsSync(filePath)) {
    fixArb(filePath, lang);
  }
});

console.log('\n✨ All ARB files fixed! Ready to build.');
