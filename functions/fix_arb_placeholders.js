#!/usr/bin/env node

/**
 * Fix ARB files by restoring English placeholders that got translated
 * Replaces placeholder translations back to English format
 */

const fs = require('fs');
const path = require('path');

// Map of placeholder keys and their original English format
const PLACEHOLDER_MAP = {
  // Common placeholders that should never be translated
  'title': ['{title}', '{ਸਿਰਲੇਖ}', '{标题}', '{titre}', '{Titel}', '{العنوان}', '{शीर्षक}', '{titolo}', '{タイトル}', '{제목}', '{título}', '{название}', '{tiêu đề}', '{τίτλος}'],
  'count': ['{count}', '{ਗਿਣਤੀ}', '{计数}', '{compte}', '{Anzahl}', '{عدد}', '{गिनती}', '{conteggio}', '{数}', '{세다}', '{contagem}', '{количество}', '{đếm}', '{αριθμός}'],
  'value': ['{value}', '{ਮੁੱਲ}', '{值}', '{valeur}', '{Wert}', '{قيمة}', '{कीमत}', '{valore}', '{値}', '{값}', '{valor}', '{значение}', '{giá trị}', '{αξία}'],
  'rating': ['{rating}', '{ਰੇਟਿੰਗ}', '{评分}', '{évaluation}', '{Bewertung}', '{تصنيف}', '{रेटिंग}', '{valutazione}', '{評価}', '{평가}', '{avaliação}', '{рейтинг}', '{xếp hạng}', '{αξιολόγηση}'],
};

const LANGUAGE_CODES = ['es', 'fr', 'de', 'zh', 'ar', 'hi', 'it', 'ja', 'ko', 'pt', 'ru', 'vi', 'el', 'pa'];
const L10N_DIR = path.join(__dirname, '../lib/l10n');

function fixArb(filePath, languageCode) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    let data = JSON.parse(content);
    let modified = false;

    // For each key in the English file
    Object.keys(data).forEach(key => {
      if (key.startsWith('@@')) return; // Skip metadata

      const value = data[key];
      if (typeof value !== 'string') return;

      // Check if this value contains any non-English placeholders
      Object.entries(PLACEHOLDER_MAP).forEach(([placeholderName, variants]) => {
        const englishVariant = variants[0]; // First is English
        
        // Look for any non-English variant in the value
        for (let i = 1; i < variants.length; i++) {
          const variant = variants[i];
          if (value.includes(variant)) {
            // Replace the translated placeholder with English one
            data[key] = value.replace(new RegExp(variant.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), englishVariant);
            modified = true;
          }
        }
      });
    });

    if (modified) {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
      console.log(`✓ Fixed ${languageCode}: Restored English placeholders`);
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
