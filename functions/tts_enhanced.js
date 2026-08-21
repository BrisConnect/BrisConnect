const textToSpeech = require('@google-cloud/text-to-speech').v1;

/**
 * Map of short language codes to Google Cloud TTS voice configurations.
 * Uses the best available high-quality voices (Chirp3 HD, Neural2, or Wavenet).
 */
const PREMIUM_TTS_VOICES = {
  'en': { languageCode: 'en-AU', name: 'en-AU-Chirp3-HD-Achernar' },
  'es': { languageCode: 'es-ES', name: 'es-ES-Chirp3-HD-Achernar' },
  'fr': { languageCode: 'fr-FR', name: 'fr-FR-Chirp3-HD-Achernar' },
  'de': { languageCode: 'de-DE', name: 'de-DE-Chirp3-HD-Achernar' },
  'zh': { languageCode: 'cmn-CN', name: 'cmn-CN-Chirp3-HD-Achernar' },
  'zh-CN': { languageCode: 'cmn-CN', name: 'cmn-CN-Chirp3-HD-Achernar' },
  'ar': { languageCode: 'ar-XA', name: 'ar-XA-Chirp3-HD-Achernar' },
  'hi': { languageCode: 'hi-IN', name: 'hi-IN-Chirp3-HD-Achernar' },
  'it': { languageCode: 'it-IT', name: 'it-IT-Chirp3-HD-Achernar' },
  'ja': { languageCode: 'ja-JP', name: 'ja-JP-Chirp3-HD-Achernar' },
  'ko': { languageCode: 'ko-KR', name: 'ko-KR-Chirp3-HD-Achernar' },
  'pt': { languageCode: 'pt-BR', name: 'pt-BR-Chirp3-HD-Achernar' },
  'ru': { languageCode: 'ru-RU', name: 'ru-RU-Chirp3-HD-Aoede' },
  'vi': { languageCode: 'vi-VN', name: 'vi-VN-Chirp3-HD-Achernar' },
  'el': { languageCode: 'el-GR', name: 'el-GR-Chirp3-HD-Achernar' },
  'pa': { languageCode: 'pa-IN', name: 'pa-IN-Chirp3-HD-Achernar' },
};

/**
 * Get optimized voice configuration for TTS
 * @param {string} languageCode - 2-letter language code (e.g., 'pa', 'hi')
 * @returns {Object} Voice configuration for Google Cloud TTS
 */
function getOptimalVoiceConfig(languageCode) {
  const normalized = String(languageCode || '').trim().toLowerCase();
  return PREMIUM_TTS_VOICES[normalized] || PREMIUM_TTS_VOICES['en'];
}

/**
 * Synthesize speech with improved quality for regional languages
 * Uses Google Cloud Text-to-Speech SDK with Cloud Functions default service account
 * @param {string} text - Text to synthesize
 * @param {string} languageCode - Language code
 * @param {Object} options - Additional options (ignored for Chirp3 HD voices)
 * @returns {Promise<Buffer>} MP3 audio buffer
 */
async function synthesizeSpeechEnhanced(text, languageCode, options = {}) {
  try {
    // Use Cloud Functions' default service account credentials.
    // No API key is required; the runtime provides automatic authentication.
    const client = new textToSpeech.TextToSpeechClient();

    const voiceConfig = getOptimalVoiceConfig(languageCode);

    const request = {
      input: { text },
      voice: {
        languageCode: voiceConfig.languageCode,
        name: voiceConfig.name,
      },
      audioConfig: {
        audioEncoding: 'MP3',
      },
    };

    const [response] = await client.synthesizeSpeech(request);
    
    if (response.audioContent) {
      return response.audioContent;
    } else {
      throw new Error('No audio content in TTS response');
    }
  } catch (error) {
    console.error(`TTS synthesis failed for language ${languageCode}:`, error.message || error);
    throw new Error(`Text-to-Speech synthesis failed: ${error.message || String(error)}`);
  }
}

/**
 * Batch synthesize multiple texts for efficiency
 * @param {Array<{text: string, languageCode: string}>} items - Items to synthesize
 * @returns {Promise<Array<Buffer>>} Array of MP3 buffers
 */
async function synthesizeSpeechBatch(items) {
  const results = [];

  for (const item of items) {
    try {
      const audio = await synthesizeSpeechEnhanced(item.text, item.languageCode);
      results.push(audio);
    } catch (error) {
      console.error(`Error synthesizing text for language ${item.languageCode}:`, error);
      results.push(null);
    }
  }

  return results;
}

module.exports = {
  getOptimalVoiceConfig,
  synthesizeSpeechEnhanced,
  synthesizeSpeechBatch,
  PREMIUM_TTS_VOICES,
};
