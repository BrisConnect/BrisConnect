const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { sendNotificationEmail } = require('./email_notifications');
const { sendFcmWithRetry } = require('./fcm_utils');

/**
 * Sends a platform-level notification to every admin. Persists one record
 * per admin in `admin_notifications` for the admin notification panel, then
 * pushes an FCM message to each admin's registered tokens.
 *
 * @param {Object} options
 * @param {string} options.title
 * @param {string} options.body
 * @param {Object} [options.data={}]
 * @param {string} [options.type]
 * @param {string} [options.category]
 * @param {Array<{action:string,title:string}>} [options.actions]
 * @returns {Promise<{success:boolean, sent:number, persisted?:number, failed?:number}>}
 */
async function sendAdminNotification({ title, body, data = {}, type, category, actions }) {
  const db = admin.firestore();
  const messaging = admin.messaging();

  const adminDocs = await db.collection('admins').limit(100).get();
  if (adminDocs.empty) {
    logger.info('No admins configured; skipping admin notification.', { type });
    return { success: false, sent: 0, error: 'No admins' };
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const baseNotificationId = db.collection('admin_notifications').doc().id;

  const relatedItemId =
    data?.businessId || data?.eventId || data?.promotionId || data?.reportId || data?.reviewId || null;
  const relatedItemType = data?.relatedItemType || null;
  const actionRoute = data?.screen || null;

  const baseRecord = {
    title,
    message: body,
    type: type || 'admin',
    data,
    createdAt: now,
    read: false,
    relatedItemId: relatedItemId || null,
    relatedItemType: relatedItemType || null,
    actionRoute: actionRoute || null,
  };

  await Promise.all(
    adminDocs.docs.map((doc) =>
      db
        .collection('admin_notifications')
        .doc(`${baseNotificationId}_${doc.id}`)
        .set({
          ...baseRecord,
          adminEmail: doc.id,
        })
        .catch((e) =>
          logger.warn('Failed to write admin notification.', { adminEmail: doc.id, error: e.message }),
        ),
    ),
  );

  // Send each admin an email copy synchronously so they see it without opening the app.
  await Promise.all(
    adminDocs.docs.map((doc) =>
      sendNotificationEmail({
        recipientEmail: doc.id,
        title,
        body,
        type: type || 'admin',
        actionRoute,
        meta: { userType: 'admin', relatedItemId, relatedItemType },
      }).catch((e) =>
        logger.warn('Failed to send admin notification email.', { adminEmail: doc.id, error: e.message }),
      ),
    ),
  );

  const dataPayload = {
    type: type || 'admin',
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

  const tokenDocs = await Promise.all(
    adminDocs.docs.map((doc) =>
      db.collection('local_users').doc(doc.id).collection('fcmTokens').get(),
    ),
  );

  const allTokens = tokenDocs
    .flatMap((snap) => snap.docs.map((d) => d.id))
    .filter(Boolean);

  if (allTokens.length === 0) {
    logger.info('No admin FCM tokens; notification persisted only.', { type });
    return { success: true, sent: 0, persisted: adminDocs.size };
  }

  const batchSize = 500;
  let sentCount = 0;
  const failedTokens = [];

  for (let i = 0; i < allTokens.length; i += batchSize) {
    const batch = allTokens.slice(i, i + batchSize);
    const result = await sendFcmWithRetry(messaging, batch, payload, {
      maxRetries: 1,
      initialDelayMs: 1000,
    });

    sentCount += result.successCount;
    failedTokens.push(...result.failedTokens);

    if (result.responses.length > 0) {
      result.responses.forEach(({ token, error }) => {
        logger.warn('Admin FCM send failed.', {
          token: token?.substring(0, 16),
          error,
        });
      });
    }
  }

  if (failedTokens.length > 0) {
    const tokenOwners = new Map();
    tokenDocs.forEach((snap, adminIdx) => {
      snap.docs.forEach((d) => {
        tokenOwners.set(d.id, adminDocs.docs[adminIdx].id);
      });
    });

    await Promise.all(
      failedTokens.map((token) => {
        const ownerId = tokenOwners.get(token);
        if (!ownerId) return Promise.resolve();
        return db
          .collection('local_users')
          .doc(ownerId)
          .collection('fcmTokens')
          .doc(token)
          .delete()
          .catch(() => {});
      }),
    );
  }

  logger.info('Admin notification processed.', {
    type,
    admins: adminDocs.size,
    sentCount,
    failedCount: failedTokens.length,
  });

  return { success: true, sent: sentCount, persisted: adminDocs.size, failed: failedTokens.length };
}

module.exports = { sendAdminNotification };
