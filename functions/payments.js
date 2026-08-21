const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const Stripe = require('stripe');
const { sendAdminNotification } = require('./admin_notifications');
const { sendOwnerNotification } = require('./owner_notifications');

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const SUBSCRIPTION_PRICE_CENTS = 999; // A$9.99 / month
const PROMOTION_PRICE_CENTS = 499; // A$4.99 per promotion boost

/**
 * Verifies the caller has an admin record in Firestore.
 */
async function assertAdminCaller(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  const email = String(request.auth.token.email || '').trim().toLowerCase();
  if (!email) {
    throw new HttpsError('permission-denied', 'Email claim is missing.');
  }
  const adminDoc = await admin.firestore().collection('admins').doc(email).get();
  if (!adminDoc.exists) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
}

function getBaseUrl(origin) {
  if (origin) {
    try {
      const url = new URL(origin);
      return `${url.protocol}//${url.host}`;
    } catch (_) {
      // fall through
    }
  }
  return 'https://brisconnect-68b78.web.app';
}

function stripeInstance() {
  return new Stripe(stripeSecretKey.value(), { apiVersion: '2024-06-20' });
}

/**
 * Records a completed promotion checkout session: writes the business_payments
 * receipt and flips the linked business's featured/promoted flags. Shared by
 * the webhook handler and the reconciliation job so both stay in sync.
 */
async function recordPromotionPayment(db, session, paidAtValue) {
  const { ownerId, email, promotionTitle } = session.metadata || {};
  const businessId = session.metadata?.businessId || null;
  const planId = session.metadata?.planId || null;
  const planName = session.metadata?.promotionTitle || promotionTitle || 'Promotion Boost';
  const durationDays = Math.max(1, Number(session.metadata?.durationDays) || 7);
  const amountCents = session.amount_total || PROMOTION_PRICE_CENTS;
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + durationDays * 24 * 60 * 60 * 1000);

  await db.collection('business_payments').add({
    ownerId,
    email,
    businessId,
    type: 'promotion',
    planId,
    planName,
    promotionTitle: planName,
    durationDays,
    amountCents,
    currency: 'aud',
    stripeSessionId: session.id,
    stripeCustomerId: session.customer,
    receiptUrl: session.receipt_url || null,
    status: 'paid',
    paidAt: paidAtValue,
    expiresAt,
    createdAt: paidAtValue,
  });

  // If a business is linked, mark it promoted for discover visibility.
  if (businessId) {
    await db.collection('businesses').doc(businessId).set({
      isPromoted: true,
      isFeatured: true,
      promotionExpiresAt: expiresAt,
      updatedAt: paidAtValue,
    }, { merge: true });
  }

  logger.info('Promotion payment recorded', { ownerId, businessId, planId, sessionId: session.id });
}

exports.createSubscriptionCheckout = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async ({ data, auth }) => {
    if (!auth || !auth.token || !auth.token.email) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const email = auth.token.email;
    const ownerId = String(data?.ownerId || email).trim();
    const businessId = String(data?.businessId || '').trim() || null;
    const planId = String(data?.planId || '').trim() || null;
    const origin = data?.origin;

    if (!ownerId) {
      throw new HttpsError('invalid-argument', 'Owner ID is required.');
    }

    const db = admin.firestore();
    const stripe = stripeInstance();
    const baseUrl = getBaseUrl(origin);

    let unitAmount = SUBSCRIPTION_PRICE_CENTS;
    let planName = 'BrisConnect Business Subscription';
    let interval = 'month';
    let stripePriceId = null;

    if (planId) {
      let planDoc = await db.collection('subscription_plans').doc(planId).get();

      // Fallback: resolve by Stripe price ID when the app sends that instead
      // of the Firestore document ID.
      if (!planDoc.exists) {
        const byPrice = await db.collection('subscription_plans')
          .where('stripePriceId', '==', planId)
          .where('isActive', '==', true)
          .limit(1)
          .get();
        if (!byPrice.empty) {
          planDoc = byPrice.docs[0];
        }
      }

      if (!planDoc.exists) {
        throw new HttpsError('not-found', 'Subscription plan not found.');
      }
      const plan = planDoc.data();
      if (plan.isActive !== true) {
        throw new HttpsError('failed-precondition', 'This subscription plan is not active.');
      }
      unitAmount = Math.max(0, Number(plan.priceCents) || SUBSCRIPTION_PRICE_CENTS);
      planName = String(plan.name || planName).trim();
      interval = String(plan.interval || 'monthly').toLowerCase() === 'yearly' ? 'year' : 'month';
      stripePriceId = plan.stripePriceId || null;
    }

    try {
      const lineItem = stripePriceId
        ? { price: stripePriceId, quantity: 1 }
        : {
            price_data: {
              currency: 'aud',
              product_data: {
                name: planName,
                description: `${interval[0].toUpperCase() + interval.slice(1)}ly subscription for business owners on BrisConnect.`,
              },
              unit_amount: unitAmount,
              recurring: { interval },
            },
            quantity: 1,
          };

      const session = await stripe.checkout.sessions.create({
        mode: 'subscription',
        payment_method_types: ['card'],
        customer_email: email,
        line_items: [lineItem],
        success_url: `${baseUrl}/local/portal?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${baseUrl}/local/portal?checkout=cancel`,
        metadata: {
          ownerId,
          email,
          businessId,
          type: 'subscription',
          planId: planId || '',
          planName,
        },
        subscription_data: {
          metadata: {
            ownerId,
            email,
            businessId,
            type: 'subscription',
            planId: planId || '',
            planName,
          },
        },
      });

      logger.info('Created subscription checkout', { ownerId, businessId, planId, sessionId: session.id });
      return { url: session.url, sessionId: session.id, planId: planId || '' };
    } catch (error) {
      logger.error('Failed to create subscription checkout', { error: error.message });
      throw new HttpsError('internal', 'Could not create checkout session.');
    }
  },
);

exports.createPromotionCheckout = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async ({ data, auth }) => {
    if (!auth || !auth.token || !auth.token.email) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const email = auth.token.email;
    const ownerId = String(data?.ownerId || email).trim();
    const businessId = String(data?.businessId || '').trim();
    const promotionTitle = String(data?.promotionTitle || 'Promotion Boost').trim();
    const planId = String(data?.planId || '').trim() || null;
    const origin = data?.origin;

    if (!ownerId) {
      throw new HttpsError('invalid-argument', 'Owner ID is required.');
    }

    const db = admin.firestore();
    const stripe = stripeInstance();
    const baseUrl = getBaseUrl(origin);

    let unitAmount = PROMOTION_PRICE_CENTS;
    let durationDays = 7;
    let planName = promotionTitle;
    let stripePriceId = null;

    if (planId) {
      let planDoc = await db.collection('promotion_plans').doc(planId).get();

      // Fallback: the app may send the Stripe price ID when the Firestore doc
      // ID is not available. Resolve the plan document by stripePriceId.
      if (!planDoc.exists) {
        const byPrice = await db.collection('promotion_plans')
          .where('stripePriceId', '==', planId)
          .where('isActive', '==', true)
          .limit(1)
          .get();
        if (!byPrice.empty) {
          planDoc = byPrice.docs[0];
        }
      }

      // Fallback: resolve by plan type when a stable type token was passed.
      if (!planDoc.exists) {
        const byType = await db.collection('promotion_plans')
          .where('type', '==', planId)
          .where('isActive', '==', true)
          .limit(1)
          .get();
        if (!byType.empty) {
          planDoc = byType.docs[0];
        }
      }

      if (!planDoc.exists) {
        throw new HttpsError('not-found', 'Promotion plan not found.');
      }
      const plan = planDoc.data();
      if (plan.isActive !== true) {
        throw new HttpsError('failed-precondition', 'This promotion plan is not active.');
      }
      unitAmount = Math.max(0, Number(plan.priceCents) || PROMOTION_PRICE_CENTS);
      // Defense in depth: Promotion Day is always 24 hours.
      const planDuration = Math.max(1, Number(plan.durationDays) || 7);
      durationDays = String(plan.type).toLowerCase() === 'promotionday'
        ? 1
        : planDuration;
      planName = String(plan.name || promotionTitle).trim();
      stripePriceId = plan.stripePriceId || null;
    }

    try {
      const lineItem = stripePriceId
        ? { price: stripePriceId, quantity: 1 }
        : {
            price_data: {
              currency: 'aud',
              product_data: {
                name: 'BrisConnect Promotion Boost',
                description: `Boost: ${planName}`,
              },
              unit_amount: unitAmount,
            },
            quantity: 1,
          };

      const session = await stripe.checkout.sessions.create({
        mode: 'payment',
        payment_method_types: ['card'],
        customer_email: email,
        line_items: [lineItem],
        success_url: `${baseUrl}/local/portal?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${baseUrl}/local/portal?checkout=cancel`,
        metadata: {
          ownerId,
          email,
          businessId,
          type: 'promotion',
          promotionTitle: planName,
          planId: planId || '',
          durationDays: String(durationDays),
        },
      });

      logger.info('Created promotion checkout', { ownerId, businessId, planId, sessionId: session.id });
      return { url: session.url, sessionId: session.id, durationDays, planId: planId || '' };
    } catch (error) {
      logger.error('Failed to create promotion checkout', { error: error.message });
      throw new HttpsError('internal', 'Could not create checkout session.');
    }
  },
);

exports.getSubscriptionStatus = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async ({ data, auth }) => {
    if (!auth || !auth.token || !auth.token.email) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const ownerId = String(data?.ownerId || auth.token.email).trim();
    const db = admin.firestore();

    try {
      const doc = await db.collection('business_subscriptions').doc(ownerId).get();
      const sub = doc.data();

      // Free trial: granted automatically when the owner registered (see
      // onLocalUserCreated) and has no real Stripe subscription attached.
      if (doc.exists && sub?.isFreeTrial && !sub.stripeSubscriptionId) {
        const trialEndsAt = sub.trialEndsAt?.toMillis?.() ?? 0;
        const stillInTrial = trialEndsAt > Date.now();
        if (stillInTrial) {
          return {
            active: true,
            status: 'trialing',
            isFreeTrial: true,
            trialEndsAt: Math.floor(trialEndsAt / 1000),
          };
        }
        if (sub.status !== 'trial_expired') {
          await doc.ref.set(
            { status: 'trial_expired', updatedAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true },
          );
        }
        return { active: false, status: 'trial_expired', isFreeTrial: true };
      }

      if (!doc.exists || !sub?.stripeSubscriptionId) {
        return { active: false, status: 'none' };
      }

      const stripe = stripeInstance();
      const subscription = await stripe.subscriptions.retrieve(sub.stripeSubscriptionId);
      const status = subscription.status;
      const active = status === 'active' || status === 'trialing';

      await db.collection('business_subscriptions').doc(ownerId).set({
        status,
        currentPeriodStart: subscription.current_period_start
          ? admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000)
          : null,
        currentPeriodEnd: subscription.current_period_end
          ? admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000)
          : null,
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return {
        active,
        status,
        currentPeriodEnd: subscription.current_period_end || null,
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
      };
    } catch (error) {
      logger.error('Failed to get subscription status', { error: error.message });
      throw new HttpsError('internal', 'Could not retrieve subscription status.');
    }
  },
);

/**
 * Triggered when a new business-owner account is registered. Grants a
 * 30-day free trial of BrisConnect+ (AI tools, AI-assisted promotion media)
 * so new owners can try premium features before subscribing.
 */
exports.onLocalUserCreated = onDocumentCreated(
  {
    region: 'australia-southeast1',
    document: 'local_users/{ownerId}',
  },
  async (event) => {
    const ownerId = event.params.ownerId;
    const db = admin.firestore();
    const subRef = db.collection('business_subscriptions').doc(ownerId);

    const existing = await subRef.get();
    if (existing.exists) {
      // Never overwrite an existing (possibly paid) subscription record.
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const trialEndsAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 30 * 24 * 60 * 60 * 1000,
    );

    await subRef.set({
      status: 'trialing',
      isFreeTrial: true,
      trialStartedAt: now,
      trialEndsAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Free trial granted to new business owner.', { ownerId });
  },
);

/**
 * Scheduled job that flips expired free-trial subscriptions to
 * 'trial_expired' once their 30-day window has passed, so real-time
 * Firestore listeners (e.g. the dashboard) see the change immediately
 * instead of waiting for the owner to trigger getSubscriptionStatus.
 */
exports.expireFreeTrials = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 60 minutes',
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collection('business_subscriptions')
      .where('isFreeTrial', '==', true)
      .where('status', '==', 'trialing')
      .where('trialEndsAt', '<=', now)
      .get();

    if (snapshot.empty) return;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        status: 'trial_expired',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    logger.info('Expired free trials downgraded.', { count: snapshot.size });
  },
);

exports.createBillingPortalSession = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async ({ data, auth }) => {
    if (!auth || !auth.token || !auth.token.email) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const email = auth.token.email;
    const ownerId = String(data?.ownerId || email).trim();
    const origin = data?.origin;

    if (!ownerId) {
      throw new HttpsError('invalid-argument', 'Owner ID is required.');
    }

    const db = admin.firestore();
    const stripe = stripeInstance();
    const baseUrl = getBaseUrl(origin);

    const subDoc = await db.collection('business_subscriptions').doc(ownerId).get();
    const subData = subDoc.exists ? subDoc.data() : null;
    let customerId = subData?.stripeCustomerId || null;

    // If no customer is recorded yet, search Stripe by email as a fallback.
    if (!customerId) {
      const customers = await stripe.customers.list({ email, limit: 1 });
      if (customers.data.length > 0) {
        customerId = customers.data[0].id;
      }
    }

    if (!customerId) {
      throw new HttpsError('failed-precondition', 'No Stripe customer found. Subscribe first.');
    }

    try {
      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: `${baseUrl}/local/portal?portal=return`,
      });

      logger.info('Created billing portal session', { ownerId, customerId, sessionId: session.id });
      return { url: session.url };
    } catch (error) {
      logger.error('Failed to create billing portal session', { error: error.message, ownerId });
      throw new HttpsError('internal', 'Could not open billing portal.');
    }
  },
);

exports.stripeWebhook = onRequest(
  {
    secrets: [stripeSecretKey, stripeWebhookSecret],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const payload = req.rawBody;
    const stripe = stripeInstance();

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(payload, sig, stripeWebhookSecret.value());
    } catch (error) {
      logger.error('Webhook signature verification failed', { error: error.message });
      res.status(400).send(`Webhook Error: ${error.message}`);
      return;
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();

    try {
      logger.info('Stripe webhook received', { eventType: event.type, eventId: event.id });
      
      if (event.type === 'checkout.session.completed') {
        const session = event.data.object;
        const { ownerId, email, type, promotionTitle } = session.metadata || {};

        logger.info('Processing checkout.session.completed', {
          sessionId: session.id,
          ownerId,
          type,
          paymentStatus: session.payment_status,
        });

        if (!ownerId || !type) {
          logger.warn('Checkout session missing metadata', {
            sessionId: session.id,
            hasOwnerId: !!ownerId,
            hasType: !!type,
            metadataKeys: Object.keys(session.metadata || {}),
          });
          res.json({ received: true });
          return;
        }

        if (type === 'subscription' && session.subscription) {
          const subscription = await stripe.subscriptions.retrieve(session.subscription);
          const subscriptionPlanId = session.metadata?.planId || null;
          const subscriptionPlanName = session.metadata?.planName || null;
          const linkedBusinessId = session.metadata?.businessId || null;

          logger.info('Activating new subscription', {
            ownerId,
            subscriptionId: subscription.id,
            planName: subscriptionPlanName,
            status: subscription.status,
          });

          await db.collection('business_subscriptions').doc(ownerId).set({
            ownerId,
            email,
            status: subscription.status,
            stripeCustomerId: session.customer,
            stripeSubscriptionId: subscription.id,
            planId: subscriptionPlanId,
            planName: subscriptionPlanName,
            businessId: linkedBusinessId,
            currentPeriodStart: subscription.current_period_start
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000)
              : null,
            currentPeriodEnd: subscription.current_period_end
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000)
              : null,
            cancelAtPeriodEnd: subscription.cancel_at_period_end,
            updatedAt: now,
            createdAt: now,
          }, { merge: true });

          // Mark the linked business as premium so visibility features activate.
          if (linkedBusinessId) {
            await db.collection('businesses').doc(linkedBusinessId).set({
              isPremium: true,
              premiumSubscriptionId: subscription.id,
              premiumPlanId: subscriptionPlanId,
              premiumPlanName: subscriptionPlanName,
              premiumStartedAt: now,
              updatedAt: now,
            }, { merge: true });
          }

          logger.info('Subscription activated', { ownerId, businessId: linkedBusinessId, planId: subscriptionPlanId, subscriptionId: subscription.id });

          await sendOwnerNotification({
            ownerId,
            title: '💳 Subscription active',
            body: `You're now subscribed to ${subscriptionPlanName || 'BrisConnect Business'}. Welcome to BrisConnect+!`,
            data: {
              ownerId,
              businessId: linkedBusinessId || '',
              subscriptionId: subscription.id,
              screen: 'business_dashboard',
            },
            type: 'subscription_success',
          });

          await sendAdminNotification({
            title: '💳 New subscription',
            body: `${email || ownerId} subscribed to ${subscriptionPlanName || 'BrisConnect Business'}.`,
            data: {
              ownerId,
              businessId: linkedBusinessId || '',
              subscriptionId: subscription.id,
              screen: '/admin/subscriptions',
              relatedItemType: 'subscription',
            },
            type: 'new_subscription',
          });
        }

        if (type === 'promotion') {
          await recordPromotionPayment(db, session, now);
        }
      }

      if (event.type === 'invoice.payment_failed') {
        const invoice = event.data.object;
        const subscriptionId = invoice.subscription;
        const customerEmail = invoice.customer_email || invoice.customer_name || 'Unknown';

        let ownerId = invoice.subscription_details?.metadata?.ownerId || null;
        let businessId = invoice.subscription_details?.metadata?.businessId || null;

        if (subscriptionId && (!ownerId || !businessId)) {
          try {
            const subscription = await stripe.subscriptions.retrieve(subscriptionId);
            ownerId = subscription.metadata?.ownerId || ownerId;
            businessId = subscription.metadata?.businessId || businessId;
          } catch (e) {
            logger.warn('Could not retrieve subscription for failed invoice.', { subscriptionId, error: e.message });
          }
        }

        if (ownerId) {
          await sendOwnerNotification({
            ownerId,
            title: '💳 Subscription payment failed',
            body: `We couldn't process your subscription payment. Please update your payment method to keep your BrisConnect+ benefits.`,
            data: {
              ownerId,
              businessId: businessId || '',
              invoiceId: invoice.id,
              subscriptionId: subscriptionId || '',
              screen: 'business_dashboard',
            },
            type: 'subscription_payment_failed',
          });
        }

        await sendAdminNotification({
          title: '💳 Payment failed',
          body: `A subscription payment failed for ${customerEmail}.`,
          data: {
            ownerId: ownerId || '',
            businessId: businessId || '',
            invoiceId: invoice.id,
            subscriptionId: subscriptionId || '',
            screen: '/admin/subscriptions',
            relatedItemType: 'payment',
          },
          type: 'payment_failed',
        });

        res.json({ received: true });
        return;
      }

      if (event.type === 'invoice.payment_succeeded') {
        const invoice = event.data.object;
        const subscriptionId = invoice.subscription;
        
        logger.info('Processing invoice.payment_succeeded', {
          invoiceId: invoice.id,
          subscriptionId,
          amount: invoice.amount_paid,
          status: invoice.status,
        });
        
        if (!subscriptionId) {
          logger.warn('Invoice has no subscription ID', { invoiceId: invoice.id });
          res.json({ received: true });
          return;
        }

        const subscription = await stripe.subscriptions.retrieve(subscriptionId);
        const { ownerId, email, businessId, planId, planName } = subscription.metadata || {};
        
        logger.info('Retrieved subscription metadata', {
          subscriptionId,
          ownerId,
          email,
          businessId,
          planName,
        });
        
        if (!ownerId) {
          logger.warn('Subscription has no ownerId in metadata', {
            subscriptionId,
            metadataKeys: Object.keys(subscription.metadata || {}),
          });
          res.json({ received: true });
          return;
        }

        await db.collection('business_subscriptions').doc(ownerId).set({
          status: subscription.status,
          currentPeriodStart: subscription.current_period_start
            ? admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000)
            : null,
          currentPeriodEnd: subscription.current_period_end
            ? admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000)
            : null,
          cancelAtPeriodEnd: subscription.cancel_at_period_end,
          updatedAt: now,
        }, { merge: true });

        // Record a billing row for each successful subscription invoice so owners
        // can view their payment history.
        logger.info('Recording subscription payment', {
          ownerId,
          amount: invoice.amount_total,
          invoiceId: invoice.id,
          subscriptionId,
        });
        
        await db.collection('business_payments').add({
          ownerId,
          email,
          businessId: businessId || null,
          type: 'subscription',
          planId: planId || null,
          planName: planName || 'Subscription',
          amountCents: invoice.amount_total || SUBSCRIPTION_PRICE_CENTS,
          currency: invoice.currency || 'aud',
          stripeInvoiceId: invoice.id,
          stripeSubscriptionId: subscriptionId,
          receiptUrl: invoice.hosted_invoice_url || null,
          status: 'paid',
          paidAt: now,
          createdAt: now,
        });

        // Keep premium flag in sync on renewal.
        if (businessId && subscription.status === 'active') {
          await db.collection('businesses').doc(businessId).set({
            isPremium: true,
            premiumSubscriptionId: subscription.id,
            updatedAt: now,
          }, { merge: true });
        }

        logger.info('Subscription payment processed successfully', {
          ownerId,
          invoiceId: invoice.id,
          subscriptionId,
          amount: invoice.amount_total,
        });
        
        await sendOwnerNotification({
          ownerId,
          title: '💳 Subscription renewed',
          body: `Your BrisConnect+ subscription has been renewed. Thanks for staying with us!`,
          data: {
            ownerId,
            businessId: businessId || '',
            subscriptionId: subscriptionId,
            screen: 'business_dashboard',
          },
          type: 'subscription_renewal_success',
        });
      }

      if (event.type === 'customer.subscription.deleted') {
        const subscription = event.data.object;
        const { ownerId, businessId } = subscription.metadata || {};
        if (!ownerId) {
          res.json({ received: true });
          return;
        }

        await db.collection('business_subscriptions').doc(ownerId).set({
          status: subscription.status,
          cancelAtPeriodEnd: false,
          updatedAt: now,
        }, { merge: true });

        // Clear premium flag when the subscription ends.
        if (businessId) {
          await db.collection('businesses').doc(businessId).set({
            isPremium: false,
            premiumEndedAt: now,
            updatedAt: now,
          }, { merge: true });
        }

        await sendOwnerNotification({
          ownerId,
          title: '💳 Subscription canceled',
          body: `Your BrisConnect+ subscription has ended. You can resubscribe anytime to restore your benefits.`,
          data: {
            ownerId,
            businessId: businessId || '',
            subscriptionId: subscription.id,
            screen: 'business_dashboard',
          },
          type: 'subscription_cancelled',
        });

        await sendAdminNotification({
          title: '💳 Subscription canceled',
          body: `${subscription.metadata?.email || ownerId} canceled their subscription.`,
          data: {
            ownerId,
            businessId: businessId || '',
            subscriptionId: subscription.id,
            screen: '/admin/subscriptions',
            relatedItemType: 'subscription',
          },
          type: 'canceled_subscription',
        });
      }

      res.json({ received: true });
    } catch (error) {
      logger.error('Webhook handler error', { error: error.message, type: event.type });
      res.status(500).send('Webhook processing failed.');
    }
  },
);

// ── Admin promotion plan management ─────────────────────────────────────────

const PLAN_TYPE_FEATURES = {
  premium: ['Premium badge', 'Priority search ranking', 'Verified highlight'],
  featured: ['Featured badge', 'Homepage carousel', 'Map priority pin'],
  promotionDay: ['Day-long spotlight', 'Social share boost', 'Push notification'],
};

exports.savePromotionPlan = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request);

    const data = request.data || {};
    const id = String(data.id || '').trim() || null;
    const type = String(data.type || 'premium').toLowerCase();
    const name = String(data.name || '').trim();
    const description = String(data.description || '').trim();
    const priceCents = Math.max(0, Math.round(Number(data.priceCents) || 0));

    // Promotion Day plans are always 24 hours, regardless of the supplied value.
    const rawDurationDays = Math.max(1, Math.round(Number(data.durationDays) || 1));
    const durationDays = type === 'promotionday' ? 1 : rawDurationDays;

    const features = Array.isArray(data.features)
      ? data.features.map((f) => String(f).trim()).filter(Boolean)
      : PLAN_TYPE_FEATURES[type] || [];
    const isActive = data.isActive !== false;

    if (!name) {
      throw new HttpsError('invalid-argument', 'Plan name is required.');
    }
    if (priceCents <= 0) {
      throw new HttpsError('invalid-argument', 'Price must be greater than zero.');
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const planRef = id ? db.collection('promotion_plans').doc(id) : db.collection('promotion_plans').doc();

    // Create or update Stripe Product + Price so the plan can be sold.
    const stripe = stripeInstance();
    let stripeProductId;
    let stripePriceId;

    try {
      const existing = id ? await planRef.get() : null;
      stripeProductId = existing?.data()?.stripeProductId;
      stripePriceId = existing?.data()?.stripePriceId;

      if (!stripeProductId) {
        const product = await stripe.products.create({
          name,
          description: description || `${type} promotion plan for BrisConnect`,
          metadata: { planId: planRef.id, type },
        });
        stripeProductId = product.id;
      } else {
        await stripe.products.update(stripeProductId, {
          name,
          description: description || `${type} promotion plan for BrisConnect`,
        });
      }

      // Stripe Prices are immutable, so create a new price whenever cost changes.
      const shouldCreateNewPrice = !stripePriceId ||
        (existing && existing.data().priceCents !== priceCents);
      if (shouldCreateNewPrice) {
        const price = await stripe.prices.create({
          product: stripeProductId,
          unit_amount: priceCents,
          currency: 'aud',
          metadata: { planId: planRef.id, type },
        });
        stripePriceId = price.id;
      }
    } catch (error) {
      logger.error('Stripe plan sync failed', { error: error.message, planId: planRef.id });
      throw new HttpsError('internal', 'Could not sync plan with Stripe.');
    }

    await planRef.set({
      type,
      name,
      description,
      priceCents,
      durationDays,
      features,
      stripeProductId,
      stripePriceId,
      isActive,
      updatedAt: now,
      createdAt: id ? (await planRef.get()).data()?.createdAt || now : now,
    }, { merge: true });

    logger.info('Promotion plan saved', { planId: planRef.id, name, priceCents });
    return { planId: planRef.id };
  },
);

exports.setPlanActive = onCall(
  {
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request);

    const planId = String(request.data?.planId || '').trim();
    const isActive = request.data?.isActive === true;
    if (!planId) {
      throw new HttpsError('invalid-argument', 'Plan ID is required.');
    }

    await admin.firestore().collection('promotion_plans').doc(planId).update({
      isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Promotion plan active state changed', { planId, isActive });
    return { success: true };
  },
);

exports.deactivatePromotion = onCall(
  {
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request);

    const paymentId = String(request.data?.paymentId || '').trim();
    if (!paymentId) {
      throw new HttpsError('invalid-argument', 'Payment ID is required.');
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const paymentRef = db.collection('business_payments').doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', 'Promotion payment not found.');
    }

    const payment = paymentDoc.data();
    await paymentRef.update({
      status: 'deactivated',
      deactivatedAt: now,
      deactivatedBy: request.auth.token.email,
    });

    // Remove featured visibility from the linked business.
    const businessId = payment?.businessId;
    if (businessId) {
      await db.collection('businesses').doc(businessId).update({
        isFeatured: false,
        isPromoted: false,
        promotionEndedAt: now,
      });
    }

    logger.info('Promotion manually deactivated', { paymentId, businessId });
    return { success: true };
  },
);

/**
 * Scheduled job that runs every 15 minutes to downgrade expired promotions.
 * Marks business_payments as expired and clears featured flags on businesses.
 */
exports.downgradeExpiredPromotions = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 15 minutes',
    timeoutSeconds: 300,
    secrets: [stripeSecretKey],
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    let expiredCount = 0;

    const snapshot = await db
      .collection('business_payments')
      .where('type', '==', 'promotion')
      .where('status', '==', 'paid')
      .where('expiresAt', '<=', now)
      .get();

    for (const doc of snapshot.docs) {
      const payment = doc.data();
      batch.update(doc.ref, {
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const businessId = payment?.businessId;
      if (businessId) {
        const businessRef = db.collection('businesses').doc(businessId);
        batch.update(businessRef, {
          isFeatured: false,
          isPromoted: false,
          promotionEndedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      expiredCount++;
    }

    if (expiredCount > 0) {
      await batch.commit();
    }

    logger.info('Expired promotion downgrade complete', {
      checked: snapshot.size,
      expired: expiredCount,
    });
  },
);

/**
 * Safety net for missed or delayed Stripe webhook deliveries. Periodically
 * re-checks recently completed promotion checkout sessions against Stripe
 * directly and records any payment the webhook failed to process, so
 * promotion status stays consistent with Stripe even if a webhook event is
 * lost (network blip, deploy-time cold start, etc.) rather than relying
 * solely on Stripe's own webhook retry policy.
 */
exports.reconcilePromotionPayments = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 30 minutes',
    timeoutSeconds: 300,
    secrets: [stripeSecretKey],
  },
  async () => {
    const db = admin.firestore();
    const stripe = stripeInstance();
    const lookbackSeconds = 3 * 60 * 60; // comfortably covers webhook delivery delays
    const createdAfter = Math.floor(Date.now() / 1000) - lookbackSeconds;

    const sessions = await stripe.checkout.sessions.list({
      created: { gte: createdAfter },
      limit: 100,
    });

    const promotionSessions = sessions.data.filter(
      (session) => session.metadata?.type === 'promotion'
        && session.payment_status === 'paid'
        && session.status === 'complete',
    );

    if (promotionSessions.length === 0) {
      logger.info('Promotion reconciliation: nothing to check.');
      return;
    }

    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - lookbackSeconds * 1000);
    const recentPaymentsSnap = await db.collection('business_payments')
      .where('type', '==', 'promotion')
      .where('paidAt', '>=', cutoff)
      .get();
    const knownSessionIds = new Set(
      recentPaymentsSnap.docs.map((doc) => doc.data().stripeSessionId).filter(Boolean),
    );

    const now = admin.firestore.FieldValue.serverTimestamp();
    let reconciledCount = 0;
    for (const session of promotionSessions) {
      if (knownSessionIds.has(session.id)) continue;
      await recordPromotionPayment(db, session, now);
      reconciledCount++;
    }

    if (reconciledCount > 0) {
      logger.warn('Reconciled promotion payments missed by webhook.', {
        checked: promotionSessions.length,
        reconciledCount,
      });
    } else {
      logger.info('Promotion reconciliation: all sessions already recorded.', {
        checked: promotionSessions.length,
      });
    }
  },
);

/**
 * Reconciles subscription invoice payments that were missed by webhook.
 * Runs every 30 minutes to catch any invoice.payment_succeeded events that failed.
 */
exports.reconcileSubscriptionPayments = onSchedule(
  {
    region: 'australia-southeast1',
    schedule: 'every 30 minutes',
    timeoutSeconds: 300,
    secrets: [stripeSecretKey],
  },
  async () => {
    const db = admin.firestore();
    const stripe = stripeInstance();
    const lookbackSeconds = 3 * 60 * 60; // comfortably covers webhook delivery delays
    const createdAfter = Math.floor(Date.now() / 1000) - lookbackSeconds;

    logger.info('Starting subscription payment reconciliation', { lookbackSeconds });

    try {
      // Get all invoices for subscriptions that were paid in the lookback window
      const invoices = await stripe.invoices.list({
        created: { gte: createdAfter },
        status: 'paid',
        limit: 100,
      });

      logger.info('Found invoices to reconcile', { count: invoices.data.length });

      const subscriptionInvoices = invoices.data.filter(
        (invoice) =>
          invoice.subscription && 
          invoice.status === 'paid' &&
          !invoice.draft
      );

      if (subscriptionInvoices.length === 0) {
        logger.info('Subscription reconciliation: nothing to check.');
        return;
      }

      const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - lookbackSeconds * 1000);
      const recentPaymentsSnap = await db.collection('business_payments')
        .where('type', '==', 'subscription')
        .where('paidAt', '>=', cutoff)
        .get();
      
      const knownInvoiceIds = new Set(
        recentPaymentsSnap.docs.map((doc) => doc.data().stripeInvoiceId).filter(Boolean),
      );

      logger.info('Reconciliation snapshot', {
        totalInvoices: subscriptionInvoices.length,
        recordedPayments: recentPaymentsSnap.size,
        knownInvoiceIds: knownInvoiceIds.size,
      });

      const now = admin.firestore.FieldValue.serverTimestamp();
      let reconciledCount = 0;
      let failedCount = 0;

      for (const invoice of subscriptionInvoices) {
        if (knownInvoiceIds.has(invoice.id)) {
          logger.debug('Invoice already recorded', { invoiceId: invoice.id });
          continue;
        }

        try {
          const subscriptionId = invoice.subscription;
          const subscription = await stripe.subscriptions.retrieve(subscriptionId);
          const { ownerId, email, businessId, planId, planName } = subscription.metadata || {};

          logger.info('Reconciling missed subscription invoice', {
            invoiceId: invoice.id,
            subscriptionId,
            ownerId,
            amount: invoice.amount_paid,
          });

          if (!ownerId) {
            logger.warn('Cannot reconcile: no ownerId in subscription metadata', {
              invoiceId: invoice.id,
              subscriptionId,
            });
            failedCount++;
            continue;
          }

          // Update subscription record
          await db.collection('business_subscriptions').doc(ownerId).set({
            status: subscription.status,
            currentPeriodStart: subscription.current_period_start
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000)
              : null,
            currentPeriodEnd: subscription.current_period_end
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000)
              : null,
            cancelAtPeriodEnd: subscription.cancel_at_period_end,
            updatedAt: now,
          }, { merge: true });

          // Record payment
          await db.collection('business_payments').add({
            ownerId,
            email,
            businessId: businessId || null,
            type: 'subscription',
            planId: planId || null,
            planName: planName || 'Subscription',
            amountCents: invoice.amount_paid || SUBSCRIPTION_PRICE_CENTS,
            currency: invoice.currency || 'aud',
            stripeInvoiceId: invoice.id,
            stripeSubscriptionId: subscriptionId,
            receiptUrl: invoice.hosted_invoice_url || null,
            status: 'paid',
            paidAt: now,
            createdAt: now,
            reconciledAt: now, // Mark as reconciled (not from webhook)
          });

          reconciledCount++;
          logger.info('Successfully reconciled subscription payment', {
            invoiceId: invoice.id,
            ownerId,
            amount: invoice.amount_paid,
          });
        } catch (error) {
          logger.error('Failed to reconcile subscription invoice', {
            invoiceId: invoice.id,
            error: error.message,
          });
          failedCount++;
        }
      }

      if (reconciledCount > 0 || failedCount > 0) {
        logger.warn('Subscription payment reconciliation complete', {
          checked: subscriptionInvoices.length,
          reconciledCount,
          failedCount,
        });
      } else {
        logger.info('Subscription reconciliation: all invoices already recorded', {
          checked: subscriptionInvoices.length,
        });
      }
    } catch (error) {
      logger.error('Subscription reconciliation failed', { error: error.message });
    }
  },
);

/**
 * Manual trigger to reconcile subscription payments.
 * Useful for backfilling missed payments or testing.
 * Usage: firebase functions:call manualReconcileSubscriptions
 */
exports.manualReconcileSubscriptions = onCall(
  {
    region: 'australia-southeast1',
    secrets: [stripeSecretKey],
    cors: true,
  },
  async (request) => {
    // Verify admin
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const email = String(request.auth.token.email || '').trim().toLowerCase();
    const db = admin.firestore();
    const adminDoc = await db.collection('admins').doc(email).get();

    if (!adminDoc.exists) {
      throw new HttpsError('permission-denied', 'Admin access required');
    }

    const stripe = stripeInstance();
    const daysBack = request.data?.daysBack || 90; // Default: last 90 days
    const createdAfter = Math.floor(Date.now() / 1000) - daysBack * 24 * 60 * 60;

    logger.info('Manual subscription reconciliation requested', {
      adminEmail: email,
      daysBack,
    });

    try {
      const invoices = await stripe.invoices.list({
        created: { gte: createdAfter },
        status: 'paid',
        limit: 100,
      });

      const subscriptionInvoices = invoices.data.filter(
        (invoice) =>
          invoice.subscription &&
          invoice.status === 'paid' &&
          !invoice.draft
      );

      logger.info('Found invoices for manual reconciliation', {
        total: invoices.data.length,
        subscriptionInvoices: subscriptionInvoices.length,
      });

      const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - daysBack * 24 * 60 * 60 * 1000);
      const recentPaymentsSnap = await db.collection('business_payments')
        .where('type', '==', 'subscription')
        .where('paidAt', '>=', cutoff)
        .get();

      const knownInvoiceIds = new Set(
        recentPaymentsSnap.docs.map((doc) => doc.data().stripeInvoiceId).filter(Boolean),
      );

      const now = admin.firestore.FieldValue.serverTimestamp();
      let reconciledCount = 0;
      const errors = [];

      for (const invoice of subscriptionInvoices) {
        if (knownInvoiceIds.has(invoice.id)) {
          logger.debug('Skipping already recorded invoice', { invoiceId: invoice.id });
          continue;
        }

        try {
          const subscription = await stripe.subscriptions.retrieve(invoice.subscription);
          const { ownerId, email: ownerEmail, businessId, planId, planName } = subscription.metadata || {};

          if (!ownerId) {
            logger.warn('Cannot reconcile: missing ownerId', {
              invoiceId: invoice.id,
              subscriptionId: subscription.id,
            });
            errors.push({
              invoiceId: invoice.id,
              reason: 'Missing ownerId in metadata',
            });
            continue;
          }

          // Update subscription
          await db.collection('business_subscriptions').doc(ownerId).set({
            status: subscription.status,
            currentPeriodStart: subscription.current_period_start
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000)
              : null,
            currentPeriodEnd: subscription.current_period_end
              ? admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000)
              : null,
            cancelAtPeriodEnd: subscription.cancel_at_period_end,
            updatedAt: now,
          }, { merge: true });

          // Record payment
          await db.collection('business_payments').add({
            ownerId,
            email: ownerEmail || ownerId,
            businessId: businessId || null,
            type: 'subscription',
            planId: planId || null,
            planName: planName || 'Subscription',
            amountCents: invoice.amount_paid,
            currency: invoice.currency || 'aud',
            stripeInvoiceId: invoice.id,
            stripeSubscriptionId: subscription.id,
            receiptUrl: invoice.hosted_invoice_url || null,
            status: 'paid',
            paidAt: now,
            createdAt: now,
            reconciledAt: now,
            reconcileSource: 'manual',
          });

          reconciledCount++;
          logger.info('Reconciled subscription payment', {
            invoiceId: invoice.id,
            ownerId,
            amount: invoice.amount_paid,
          });
        } catch (error) {
          logger.error('Failed to reconcile invoice', {
            invoiceId: invoice.id,
            error: error.message,
          });
          errors.push({
            invoiceId: invoice.id,
            error: error.message,
          });
        }
      }

      const result = {
        message: 'Subscription reconciliation complete',
        checked: subscriptionInvoices.length,
        reconciledCount,
        errors: errors.length > 0 ? errors : undefined,
      };

      logger.info('Manual reconciliation complete', result);
      return result;
    } catch (error) {
      logger.error('Manual reconciliation failed', { error: error.message });
      throw new HttpsError('internal', error.message);
    }
  },
);

// ── Admin subscription plan management ──────────────────────────────────────

exports.saveSubscriptionPlan = onCall(
  {
    secrets: [stripeSecretKey],
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request);

    const data = request.data || {};
    const id = String(data.id || '').trim() || null;
    const name = String(data.name || '').trim();
    const description = String(data.description || '').trim();
    const priceCents = Math.max(0, Math.round(Number(data.priceCents) || 0));
    const interval = String(data.interval || 'monthly').toLowerCase();
    const features = Array.isArray(data.features)
      ? data.features.map((f) => String(f).trim()).filter(Boolean)
      : [];
    const isActive = data.isActive !== false;

    if (!name) {
      throw new HttpsError('invalid-argument', 'Plan name is required.');
    }
    if (priceCents <= 0) {
      throw new HttpsError('invalid-argument', 'Price must be greater than zero.');
    }
    if (!['monthly', 'yearly'].includes(interval)) {
      throw new HttpsError('invalid-argument', 'Interval must be monthly or yearly.');
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const planRef = id
      ? db.collection('subscription_plans').doc(id)
      : db.collection('subscription_plans').doc();

    const stripe = stripeInstance();
    let stripeProductId;
    let stripePriceId;

    try {
      const existing = id ? await planRef.get() : null;
      stripeProductId = existing?.data()?.stripeProductId;
      stripePriceId = existing?.data()?.stripePriceId;

      if (!stripeProductId) {
        const product = await stripe.products.create({
          name,
          description: description || `${name} subscription plan for BrisConnect`,
          metadata: { planId: planRef.id, interval },
        });
        stripeProductId = product.id;
      } else {
        await stripe.products.update(stripeProductId, {
          name,
          description: description || `${name} subscription plan for BrisConnect`,
        });
      }

      const shouldCreateNewPrice = !stripePriceId ||
        (existing && existing.data().priceCents !== priceCents) ||
        (existing && existing.data().interval !== interval);
      if (shouldCreateNewPrice) {
        const price = await stripe.prices.create({
          product: stripeProductId,
          unit_amount: priceCents,
          currency: 'aud',
          recurring: { interval: interval === 'yearly' ? 'year' : 'month' },
          metadata: { planId: planRef.id, interval },
        });
        stripePriceId = price.id;
      }
    } catch (error) {
      logger.error('Stripe subscription plan sync failed', { error: error.message, planId: planRef.id });
      throw new HttpsError('internal', 'Could not sync plan with Stripe.');
    }

    await planRef.set({
      name,
      description,
      priceCents,
      interval,
      features,
      stripeProductId,
      stripePriceId,
      isActive,
      updatedAt: now,
      createdAt: id ? (await planRef.get()).data()?.createdAt || now : now,
    }, { merge: true });

    logger.info('Subscription plan saved', { planId: planRef.id, name, priceCents, interval });
    return { planId: planRef.id };
  },
);

exports.setSubscriptionPlanActive = onCall(
  {
    region: 'australia-southeast1',
    cors: true,
    maxInstances: 10,
  },
  async (request) => {
    await assertAdminCaller(request);

    const planId = String(request.data?.planId || '').trim();
    const isActive = request.data?.isActive === true;
    if (!planId) {
      throw new HttpsError('invalid-argument', 'Plan ID is required.');
    }

    await admin.firestore().collection('subscription_plans').doc(planId).update({
      isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Subscription plan active state changed', { planId, isActive });
    return { success: true };
  },
);
