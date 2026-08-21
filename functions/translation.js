const https = require('https');
const querystring = require('querystring');
const fs = require('fs');
const path = require('path');

// Language code mappings for Google Cloud Translation
const LANGUAGE_MAPPINGS = {
  'es': 'es',      // Spanish
  'fr': 'fr',      // French
  'de': 'de',      // German
  'zh': 'zh-CN',   // Simplified Chinese
  'ar': 'ar',      // Arabic
  'hi': 'hi',      // Hindi
  'it': 'it',      // Italian
  'ja': 'ja',      // Japanese
  'ko': 'ko',      // Korean
  'pt': 'pt',      // Portuguese
  'ru': 'ru',      // Russian
  'vi': 'vi',      // Vietnamese
  'el': 'el',      // Greek
  'pa': 'pa',      // Punjabi
};

const GOOGLE_TRANSLATE_API_URL = 'https://translation.googleapis.com/language/translate/v2';

/**
 * Translate text using Google Cloud Translation API (REST via HTTPS)
 * Requires GOOGLE_CLOUD_API_KEY environment variable
 * @param {string} text - Text to translate
 * @param {string} targetLanguage - Target language code
 * @returns {Promise<string>} Translated text
 */
async function translateText(text, targetLanguage) {
  return new Promise((resolve, reject) => {
    try {
      const apiKey = process.env.GOOGLE_CLOUD_API_KEY;
      if (!apiKey) {
        reject(new Error('GOOGLE_CLOUD_API_KEY environment variable is not set'));
        return;
      }

      const params = querystring.stringify({
        q: text,
        target: targetLanguage,
        source: 'en',
        key: apiKey,
      });

      const url = `${GOOGLE_TRANSLATE_API_URL}?${params}`;
      const parsedUrl = new URL(url);

      https
        .get(
          {
            hostname: parsedUrl.hostname,
            path: parsedUrl.pathname + parsedUrl.search,
            method: 'GET',
          },
          (response) => {
            let data = '';

            response.on('data', (chunk) => {
              data += chunk;
            });

            response.on('end', () => {
              try {
                const result = JSON.parse(data);
                if (result.data && result.data.translations && result.data.translations[0]) {
                  resolve(result.data.translations[0].translatedText);
                } else {
                  // Log for debugging
                  const preview = JSON.stringify(result).substring(0, 200);
                  reject(new Error(`Unexpected response format: ${preview}`));
                }
              } catch (error) {
                reject(new Error(`Failed to parse translation response: ${error.message}\nRaw data: ${data.substring(0, 200)}`));
              }
            });
          },
        )
        .on('error', (error) => {
          reject(new Error(`Translation API request failed: ${error.message}`));
        });
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Translates missing strings in language ARB files using Google Cloud Translation API
 * @param {string} targetLanguage - Language code (e.g., 'pa', 'hi')
 * @param {string} projectId - Google Cloud project ID
 * @returns {Promise<{success: boolean, messagesTranslated: number, language: string, errors: string[]}>}
 */
async function bulkTranslateArbFile(targetLanguage, projectId) {
  const errors = [];
  let messagesTranslated = 0;

  try {
    // Load English reference ARB
    const englishPath = path.join(__dirname, `../lib/l10n/app_en.arb`);
    if (!fs.existsSync(englishPath)) {
      return {
        success: false,
        messagesTranslated: 0,
        language: targetLanguage,
        errors: [`English ARB file not found at ${englishPath}`],
      };
    }

    const englishContent = fs.readFileSync(englishPath, 'utf-8');
    const englishData = JSON.parse(englishContent);

    // Load target language ARB
    const targetPath = path.join(__dirname, `../lib/l10n/app_${targetLanguage}.arb`);
    let targetData = {};
    
    if (fs.existsSync(targetPath)) {
      const targetContent = fs.readFileSync(targetPath, 'utf-8');
      targetData = JSON.parse(targetContent);
    } else {
      // Create new file if doesn't exist
      targetData = { '@@locale': targetLanguage };
    }

    // Find untranslated strings (identical to English)
    const untranslatedKeys = [];
    for (const [key, enValue] of Object.entries(englishData)) {
      if (!key.startsWith('@@') && typeof enValue === 'string') {
        const targetValue = targetData[key];
        // If missing or identical to English, it needs translation
        if (!targetValue || targetValue === enValue) {
          untranslatedKeys.push({ key, value: enValue });
        }
      }
    }

    if (untranslatedKeys.length === 0) {
      console.log(`✓ No untranslated strings for ${targetLanguage}`);
      return { success: true, messagesTranslated: 0, language: targetLanguage, errors: [] };
    }

    console.log(`Found ${untranslatedKeys.length} untranslated strings for language: ${targetLanguage}`);

    // Batch strings for translation (Google Cloud API has limits)
    const batchSize = 50;
    const googleLanguageCode = LANGUAGE_MAPPINGS[targetLanguage] || targetLanguage;

    for (let i = 0; i < untranslatedKeys.length; i += batchSize) {
      const batch = untranslatedKeys.slice(i, Math.min(i + batchSize, untranslatedKeys.length));

      try {
        // Translate each item in the batch
        const translations = [];
        for (const item of batch) {
          try {
            const translatedText = await translateText(item.value, googleLanguageCode);
            translations.push({ key: item.key, translation: translatedText });
            messagesTranslated++;
          } catch (itemError) {
            console.warn(`Failed to translate key "${item.key}":`, itemError.message);
          }
        }

        // Update target data with translations
        translations.forEach(({ key, translation }) => {
          targetData[key] = translation;
        });

        const batchNum = Math.floor(i / batchSize) + 1;
        const totalBatches = Math.ceil(untranslatedKeys.length / batchSize);
        console.log(`✓ Translated batch ${batchNum}/${totalBatches} for ${targetLanguage} (${translations.length}/${batch.length} successful)`);
      } catch (batchError) {
        const errorMsg = `Error translating batch for ${targetLanguage}: ${batchError.message}`;
        console.error(errorMsg);
        errors.push(errorMsg);
      }
    }

    // Ensure all metadata keys are present
    targetData['@@locale'] = targetLanguage;

    // Save updated ARB file
    fs.writeFileSync(targetPath, JSON.stringify(targetData, null, 2) + '\n', 'utf-8');
    console.log(`✓ Updated ${targetPath} with ${messagesTranslated} translations`);

    return {
      success: errors.length === 0,
      messagesTranslated,
      language: targetLanguage,
      errors,
    };
  } catch (error) {
    const errorMsg = `Fatal error in bulkTranslateArbFile for ${targetLanguage}: ${error.message}`;
    console.error(errorMsg);
    return {
      success: false,
      messagesTranslated: 0,
      language: targetLanguage,
      errors: [errorMsg],
    };
  }
}

/**
 * Translates all language ARB files
 * @param {string} projectId - Google Cloud project ID
 * @returns {Promise<Object>} Summary of all translation operations
 */
async function bulkTranslateAllLanguages(projectId) {
  const results = {};
  const languages = Object.keys(LANGUAGE_MAPPINGS);

  for (const lang of languages) {
    if (lang !== 'en') {
      console.log(`\n=== Processing ${lang.toUpperCase()} ===`);
      results[lang] = await bulkTranslateArbFile(lang, projectId);
    }
  }

  return results;
}

module.exports = {
  bulkTranslateArbFile,
  bulkTranslateAllLanguages,
};
