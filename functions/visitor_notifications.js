const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { sendNotificationEmail } = require('./email_notifications');
const { sendFcmWithRetry } = require('./fcm_utils');

const VISITOR_NOTIFICATION_TYPES = {
  NEARBY_PROMOTION: 'nearby_promotion',
  SAVED_BUSINESS_UPDATE: 'saved_business_update',
  TRENDING_BUSINESS: 'trending_business',
  PROMOTION_EXPIRY_REMINDER: 'promotion_expiry_reminder',
  NEW_BUSINESS_DISCOVERY: 'new_business_discovery',
  PERSONALISED_RECOMMENDATION: 'personalised_recommendation',
  REVIEW_REPLY: 'review_reply',
};

const PREFERENCE_FIELDS = {
  [VISITOR_NOTIFICATION_TYPES.NEARBY_PROMOTION]: 'nearbyPromotionsEnabled',
  [VISITOR_NOTIFICATION_TYPES.SAVED_BUSINESS_UPDATE]: 'savedBusinessUpdatesEnabled',
  [VISITOR_NOTIFICATION_TYPES.TRENDING_BUSINESS]: 'trendingBusinessesEnabled',
  [VISITOR_NOTIFICATION_TYPES.PROMOTION_EXPIRY_REMINDER]: 'promotionExpiryRemindersEnabled',
  [VISITOR_NOTIFICATION_TYPES.NEW_BUSINESS_DISCOVERY]: 'newBusinessDiscoveryEnabled',
  [VISITOR_NOTIFICATION_TYPES.PERSONALISED_RECOMMENDATION]: 'personalisedRecommendationsEnabled',
  [VISITOR_NOTIFICATION_TYPES.REVIEW_REPLY]: 'savedBusinessUpdatesEnabled',
};

/**
 * Sends an FCM message to all tokens registered for a visitor, persists a
 * record in `visitor_users/{email}/notifications`, and logs the outcome.
 *
 * @param {Object} options
 * @param {string} options.userEmail
 * @param {string} options.title
 * @param {string} options.body
 * @param {string} options.type - One of VISITOR_NOTIFICATION_TYPES.
 * @param {Object} [options.data={}]
 * @param {string} [options.relatedItemId]
 * @param {string} [options.relatedItemType]
 * @param {string} [options.actionRoute]
 * @returns {Promise<{success:boolean, sent:number, error?:string}>}
 */
async function sendVisitorNotification({
  userEmail,
  title,
  body,
  emailSubject,
  type,
  data = {},
  relatedItemId,
  relatedItemType,
  actionRoute,
  actionLabel,
}) {
  const db = admin.firestore();
  const messaging = admin.messaging();
  const normalizedEmail = String(userEmail || '').trim().toLowerCase();

  if (!normalizedEmail) {
    logger.warn('sendVisitorNotification called without userEmail.', { type });
    return { success: false, sent: 0, error: 'Missing userEmail' };
  }

  const visitorDoc = await db.collection('visitor_users').doc(normalizedEmail).get();
  if (!visitorDoc.exists) {
    logger.info('Visitor profile not found; skipping notification.', { normalizedEmail, type });
    return { success: false, sent: 0, error: 'Visitor not found' };
  }

  const visitor = visitorDoc.data() || {};
  const notificationsEnabled = visitor.notificationsEnabled !== false;
  const typePreferenceField = PREFERENCE_FIELDS[type];
  const typeEnabled = typePreferenceField ? visitor[typePreferenceField] !== false : true;

  if (!notificationsEnabled || !typeEnabled) {
    logger.info('Visitor disabled this notification type.', {
      normalizedEmail,
      type,
      notificationsEnabled,
      typeEnabled,
    });
    return { success: false, sent: 0, error: 'Disabled by visitor' };
  }

  const tokensSnap = await db
    .collection('visitor_users')
    .doc(normalizedEmail)
    .collection('fcmTokens')
    .get();

  const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);

  const notificationId = db
    .collection('visitor_users')
    .doc(normalizedEmail)
    .collection('notifications')
    .doc().id;

  const record = {
    id: notificationId,
    userEmail: normalizedEmail,
    title,
    message: body,
    type,
    data,
    relatedItemId: relatedItemId || data.relatedItemId || null,
    relatedItemType: relatedItemType || data.relatedItemType || null,
    actionRoute: actionRoute || data.screen || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };

  await db
    .collection('visitor_users')
    .doc(normalizedEmail)
    .collection('notifications')
    .doc(notificationId)
    .set(record);

  // Also send an email copy synchronously so the visitor sees it without opening the app.
  const emailEnabled = visitor.emailNotificationsEnabled !== false;
  if (emailEnabled) {
    await sendNotificationEmail({
      recipientEmail: normalizedEmail,
      title,
      body,
      emailSubject,
      type,
      actionRoute: actionRoute || data.screen || null,
      actionLabel,
      meta: { userType: 'visitor', relatedItemId, relatedItemType },
    });
  }

  if (tokens.length === 0) {
    logger.info('No FCM tokens for visitor; notification persisted only.', {
      normalizedEmail,
      type,
    });
    return { success: true, sent: 0, persisted: true };
  }

  const dataPayload = {
    type: type || 'visitor',
    ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v ?? '')])),
  };

  const payload = {
    notification: { title, body },
    data: dataPayload,
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          badge: 1,
          sound: 'default',
        },
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
        logger.warn('Visitor FCM send failed.', {
          normalizedEmail,
          token: token?.substring(0, 16),
          error,
        });
      });
    }
  }

  if (failedTokens.length > 0) {
    await Promise.all(
      failedTokens.map((token) =>
        db
          .collection('visitor_users')
          .doc(normalizedEmail)
          .collection('fcmTokens')
          .doc(token)
          .delete()
          .catch(() => {}),
      ),
    );
  }

  logger.info('Visitor notification processed.', {
    normalizedEmail,
    type,
    sentCount,
    failedCount: failedTokens.length,
  });

  return { success: true, sent: sentCount, persisted: true, failed: failedTokens.length };
}

module.exports = {
  sendVisitorNotification,
  VISITOR_NOTIFICATION_TYPES,
};
