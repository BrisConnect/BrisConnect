const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { sendNotificationEmail } = require('./email_notifications');
const { sendFcmWithRetry } = require('./fcm_utils');

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Screen alias map for owner notification deep links.
 */
const SCREEN_ALIASES = {
  '/business-detail': '/business/view',
  '/business_detail': '/business/view',
  '/promotion-detail': '/promotion/detail',
  '/promotion_detail': '/promotion/detail',
  '/business-dashboard': '/local/portal',
  '/business_dashboard': '/local/portal',
  '/local-notifications': '/local/notifications',
  '/local_notifications': '/local/notifications',
  '/admin-businesses': '/admin/businesses',
  '/admin_businesses': '/admin/businesses',
  '/admin-reports': '/admin/reports',
  '/admin_reports': '/admin/reports',
  '/admin-subscriptions': '/admin/subscriptions',
  '/admin_subscriptions': '/admin/subscriptions',
};

function normalizeActionRoute(rawScreen) {
  if (!rawScreen) return null;
  const raw = String(rawScreen).trim();
  // Callers sometimes already pass a full path (e.g. "/local/portal"); avoid
  // prepending a second leading slash which would produce an unroutable
  // "//local/portal" and leave owners on a blank "page not found" screen.
  const normalized = raw.startsWith('/')
    ? raw.replace(/_/g, '-')
    : `/${raw.replace(/^_+/, '').replace(/_/g, '-')}`;
  return SCREEN_ALIASES[normalized] || normalized;
}

/**
 * Sends an FCM message to all tokens registered for a business owner,
 * logs the notification in the owner's `notifications` subcollection, and
 * records the outcome in `user_notifications` for admin observability.
 *
 * @param {Object} options
 * @param {string} options.ownerId
 * @param {string} options.title
 * @param {string} options.body
 * @param {Object} [options.data={}]
 * @param {string} [options.type]
 * @param {string} [options.category] - iOS notification category.
 * @param {Array<{action:string,title:string}>} [options.actions]
 */
async function sendOwnerNotification({ ownerId, title, body, emailSubject, data = {}, type, category, actions, actionLabel }) {
  const messaging = admin.messaging();

  if (!ownerId) {
    logger.warn('sendOwnerNotification called without ownerId.', { type });
    return { success: false, sent: 0, error: 'Missing ownerId' };
  }

  const tokensSnap = await admin
    .firestore()
    .collection('local_users')
    .doc(ownerId)
    .collection('fcmTokens')
    .get();

  const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
  if (tokens.length === 0) {
    logger.info('No FCM tokens for owner.', { ownerId, type });
    return { success: false, sent: 0, error: 'No tokens' };
  }

  const dataPayload = {
    type: type || 'business',
    ...Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v ?? '')]),
    ),
  };
  if (actions && actions.length > 0) {
    dataPayload.actions = JSON.stringify(actions);
  }

  const apsPayload = {
    alert: { title, body },
    badge: 1,
    sound: 'default',
  };
  if (category) {
    apsPayload.category = category;
  }

  const payload = {
    notification: { title, body },
    data: dataPayload,
    apns: {
      payload: {
        aps: apsPayload,
      },
    },
  };

  const batchSize = 500;
  let sentCount = 0;
  const failedTokens = [];

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    const result = await sendFcmWithRetry(messaging, batch, payload, {
      maxRetries: 1,
      initialDelayMs: 1000,
    });

    sentCount += result.successCount;
    failedTokens.push(...result.failedTokens);

    if (result.responses.length > 0) {
      result.responses.forEach(({ token, error }) => {
        logger.warn('FCM send failed.', {
          ownerId,
          token: token.substring(0, 16),
          error,
        });
      });
    }
  }

  if (failedTokens.length > 0) {
    await Promise.all(
      failedTokens.map((token) =>
        admin
          .firestore()
          .collection('local_users')
          .doc(ownerId)
          .collection('fcmTokens')
          .doc(token)
          .delete()
          .catch(() => {}),
      ),
    );
  }

  const notificationId = admin
    .firestore()
    .collection('local_users')
    .doc(ownerId)
    .collection('notifications')
    .doc().id;

  const actionRoute = normalizeActionRoute(data.screen);
  const relatedItemId = data.relatedItemId || data.promotionId || data.businessId || data.reviewId || data.reportId || null;
  const relatedItemType = data.relatedItemType || (data.promotionId ? 'promotion' : data.businessId ? 'business' : data.reviewId ? 'review' : data.reportId ? 'report' : null);

  const notificationRecord = {
    id: notificationId,
    userId: ownerId,
    ownerId,
    businessId: data.businessId || null,
    type: type || 'business',
    title,
    message: body,
    body,
    data,
    actionRoute,
    relatedItemId,
    relatedItemType,
    sentCount,
    failedCount: failedTokens.length,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
    isRead: false,
  };

  await admin
    .firestore()
    .collection('local_users')
    .doc(ownerId)
    .collection('notifications')
    .doc(notificationId)
    .set(notificationRecord);

  // Also send an email copy synchronously so the owner sees it without opening the app.
  await sendNotificationEmail({
    recipientEmail: ownerId,
    title,
    body,
    emailSubject,
    type: type || 'business',
    actionRoute,
    actionLabel,
    meta: { userType: 'local', relatedItemId, relatedItemType },
  });

  await admin.firestore().collection('user_notifications').add({
    ...notificationRecord,
    source: 'cloud-function',
  });

  logger.info('Owner notification processed.', {
    ownerId,
    type,
    sentCount,
    failedCount: failedTokens.length,
  });

  return { success: true, sent: sentCount, failed: failedTokens.length };
}

/**
 * Preference-aware helper that checks an owner preference field before
 * sending. Important account/payment/security/verification notifications
 * bypass the preference check when [force] is true.
 */
async function sendOwnerNotificationIfEnabled({
  ownerId,
  preferenceField,
  force = false,
  title,
  body,
  emailSubject,
  data = {},
  type,
  category,
  actions,
  actionLabel,
}) {
  if (!ownerId) {
    return { success: false, sent: 0, error: 'Missing ownerId' };
  }

  if (!force && preferenceField) {
    const prefs = await admin.firestore().collection('local_users').doc(ownerId).get();
    if (prefs.exists && prefs.data()[preferenceField] === false) {
      logger.info(`Owner disabled ${preferenceField} notifications.`, { ownerId, type });
      return { success: false, sent: 0, error: 'Disabled by preference' };
    }
  }

  return sendOwnerNotification({ ownerId, title, body, emailSubject, data, type, category, actions, actionLabel });
}

module.exports = { sendOwnerNotification, sendOwnerNotificationIfEnabled };
