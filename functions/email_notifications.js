const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { defineSecret } = require('firebase-functions/params');

const brevoApiKey = defineSecret('BREVO_API_KEY');

const BREVO_SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'noreply@brisconnect.app';
const BREVO_SENDER_NAME = process.env.BREVO_SENDER_NAME || 'BrisConnect+';

function escapeHtml(input) {
  return String(input || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function wrapEmail({ bodyHtml, preheader }) {
  return `
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>BrisConnect+</title>
      </head>
      <body style="margin:0;padding:0;background-color:#f4f4f4;">
        <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">${escapeHtml(preheader)}</div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#f4f4f4;">
          <tr>
            <td align="center" style="padding:24px 16px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;">
                <tr>
                  <td style="background-color:#E8820C;padding:24px 32px;text-align:center;">
                    <span style="font-size:26px;font-weight:800;color:#ffffff;letter-spacing:0.5px;">BrisConnect+</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:32px;color:#333333;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.6;">
                    ${bodyHtml}
                  </td>
                </tr>
                <tr>
                  <td style="background-color:#fafafa;padding:24px 32px;text-align:center;color:#888888;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.5;">
                    <p style="margin:0 0 8px 0;">&copy; 2026 BrisConnect+. All rights reserved.</p>
                    <p style="margin:0;">You're receiving this because you have notifications enabled in your BrisConnect+ account.</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
  `;
}

function buildNotificationEmail({ title, body, actionRoute, actionLabel = 'Open in app' }) {
  const actionHtml = actionRoute
    ? `<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin-top:28px;">
        <tr>
          <td style="border-radius:6px;background-color:#E8820C;text-align:center;">
            <a href="https://brisconnect-68b78.web.app${actionRoute.startsWith('/') ? actionRoute : '/' + actionRoute}"
               style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:6px;">
              ${escapeHtml(actionLabel)}
            </a>
          </td>
        </tr>
      </table>`
    : '';

  const fallbackLink = actionRoute
    ? `https://brisconnect-68b78.web.app${actionRoute.startsWith('/') ? actionRoute : '/' + actionRoute}`
    : '';
  const fallbackHtml = fallbackLink
    ? `<p style="margin:28px 0 0 0;font-size:14px;color:#666666;">If the button above doesn't work, copy and paste this link into your browser:<br/>
        <a href="${fallbackLink}" style="color:#E8820C;text-decoration:underline;">${fallbackLink}</a>
      </p>`
    : '';

  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:16px;color:#333333;">Hi there,</p>
    <p style="margin:0 0 16px 0;font-size:18px;font-weight:600;color:#111111;">${escapeHtml(title)}</p>
    <p style="margin:0 0 16px 0;font-size:16px;color:#333333;">${escapeHtml(body).replace(/\n/g, '<br/>')}</p>
    ${actionHtml}
    ${fallbackHtml}
  `;

  return wrapEmail({ bodyHtml, preheader: body });
}

function docId(prefix, email) {
  const normalized = String(email || '').trim().toLowerCase();
  const ts = Date.now();
  const rand = Math.random().toString(36).slice(2, 8);
  return `${prefix}-${normalized}-${ts}-${rand}`;
}

async function sendEmailViaBrevo({ apiKey, to, subject, html }) {
  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'api-key': apiKey,
    },
    body: JSON.stringify({
      sender: { email: BREVO_SENDER_EMAIL, name: BREVO_SENDER_NAME },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Brevo API error ${response.status}: ${text}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = { raw: text };
  }
  return parsed;
}

async function writeEmailAudit({ email, subject, type, status, providerResponse, error }) {
  try {
    await admin.firestore().collection('email_audit').doc(docId(type, email)).set({
      to: email,
      subject,
      meta: { type },
      status,
      provider: 'brevo',
      providerResponse: providerResponse || null,
      error: error || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn('Failed to write email audit.', { email, type, error: e.message });
  }
}

/**
 * Sends a transactional notification email synchronously via Brevo.
 * The goal is delivery in under 5 seconds, so this calls the Brevo API
 * directly instead of queueing. If Brevo is unavailable or the runtime
 * does not have the API key, it falls back to queueing in the `mail`
 * collection so no notification is lost.
 *
 * @param {Object} options
 * @param {string} options.recipientEmail
 * @param {string} options.title - Notification title used in the email body.
 * @param {string} options.body - Notification body text.
 * @param {string} [options.emailSubject] - Optional custom email subject (defaults to title).
 * @param {string} [options.type] - Meta type for auditing.
 * @param {string} [options.actionRoute] - Deep link path (e.g. /local/notifications).
 * @param {string} [options.actionLabel] - Label for the CTA button (defaults to 'Open in app').
 * @param {Object} [options.meta={}] - Extra meta fields stored on audit/queue docs.
 * @returns {Promise<{delivered:boolean, queued:boolean, error?:string}>}
 */
async function sendNotificationEmail({
  recipientEmail,
  title,
  body,
  emailSubject,
  type = 'notification',
  actionRoute,
  actionLabel,
  meta = {},
}) {
  const email = String(recipientEmail || '').trim().toLowerCase();
  if (!email || !email.includes('@')) {
    logger.warn('sendNotificationEmail: invalid recipient email.', { type });
    return { delivered: false, queued: false, error: 'Invalid recipient email' };
  }

  const subject = String(emailSubject || title || '').trim() || 'BrisConnect+ notification';
  const html = buildNotificationEmail({ title, body, actionRoute, actionLabel });

  let apiKey;
  try {
    apiKey = brevoApiKey.value();
  } catch (e) {
    logger.warn('sendNotificationEmail: BREVO_API_KEY not available; falling back to mail queue.', {
      email,
      type,
      error: e.message,
    });
  }

  if (apiKey && apiKey.length > 0) {
    try {
      const providerResponse = await sendEmailViaBrevo({ apiKey, to: email, subject, html });
      await writeEmailAudit({ email, subject, type, status: 'sent', providerResponse });
      logger.info('sendNotificationEmail: delivered via Brevo.', { email, type });
      return { delivered: true, queued: false };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logger.error('sendNotificationEmail: Brevo send failed; falling back to mail queue.', {
        email,
        type,
        error: errorMessage,
      });
    }
  }

  // Fallback: queue for the existing mail processor to retry.
  try {
    await admin.firestore().collection('mail').doc(docId(type, email)).set({
      to: email,
      message: { subject, html },
      meta: { type, ...meta },
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info('sendNotificationEmail: queued as fallback.', { email, type });
    return { delivered: false, queued: true };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('sendNotificationEmail: failed to queue fallback.', { email, type, error: errorMessage });
    return { delivered: false, queued: false, error: errorMessage };
  }
}

module.exports = { sendNotificationEmail };
