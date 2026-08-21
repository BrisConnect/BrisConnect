const logger = require('firebase-functions/logger');

/**
 * Sends an FCM multicast message with exponential-backoff retry for
 * transient failures. Failed tokens are collected and returned so callers
 * can decide whether to delete them.
 *
 * @param {admin.messaging.Messaging} messaging - Firebase Admin messaging instance.
 * @param {Array<string>} tokens - FCM registration tokens.
 * @param {Object} payload - FCM message payload (notification, data, apns, etc.).
 * @param {Object} [options]
 * @param {number} [options.maxRetries=1] - Number of retries after the first attempt.
 * @param {number} [options.initialDelayMs=1000] - Initial backoff delay.
 * @returns {Promise<{successCount:number, failedTokens:Array<string>, responses:Array<Object>}>}
 */
async function sendFcmWithRetry(messaging, tokens, payload, options = {}) {
  const maxRetries = options.maxRetries ?? 1;
  const initialDelayMs = options.initialDelayMs ?? 1000;

  let remainingTokens = [...tokens];
  let successCount = 0;
  const allFailedResponses = [];

  for (let attempt = 0; attempt <= maxRetries && remainingTokens.length > 0; attempt++) {
    if (attempt > 0) {
      const delay = initialDelayMs * 2 ** (attempt - 1);
      logger.info(`Retrying FCM send after ${delay}ms for ${remainingTokens.length} tokens (attempt ${attempt + 1}/${maxRetries + 1})`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }

    const response = await messaging.sendEachForMulticast({
      tokens: remainingTokens,
      ...payload,
    });

    successCount += response.successCount;

    const nextRetryTokens = [];
    response.responses.forEach((resp, idx) => {
      const token = remainingTokens[idx];
      if (resp.success) return;

      const error = resp.error;
      const code = error?.code || error?.message || 'unknown';
      // Retry only on transient errors. Invalid/expired tokens should not be retried.
      const isRetryable =
        code.includes('messaging/server-unavailable') ||
        code.includes('messaging/internal-error') ||
        code.includes('messaging/unknown-error') ||
        code.includes('ECONNRESET') ||
        code.includes('ETIMEDOUT') ||
        code.includes('ECONNREFUSED') ||
        code.includes('429') ||
        code.includes('Quota exceeded');

      if (isRetryable && attempt < maxRetries) {
        nextRetryTokens.push(token);
      } else {
        allFailedResponses.push({ token, error: error?.message || code });
      }
    });

    remainingTokens = nextRetryTokens;
  }

  return {
    successCount,
    failedTokens: allFailedResponses.map((r) => r.token),
    responses: allFailedResponses,
  };
}

module.exports = { sendFcmWithRetry };
