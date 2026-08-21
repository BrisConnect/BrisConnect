# 🔧 Webhook Configuration Fix Summary

## What Was Done

I've fixed your webhook configuration to properly sync Stripe subscription payments to your admin dashboard. Here's what was implemented:

### 1. **Enhanced Webhook Handler** (functions/payments.js)
- ✅ Added comprehensive logging for all webhook events
- ✅ Better error handling and visibility
- ✅ Debug information for missing metadata

### 2. **New Subscription Reconciliation Function**
- ✅ `reconcileSubscriptionPayments` - runs every 30 minutes
- Automatically catches any missed `invoice.payment_succeeded` events
- Backtracks 3 hours to cover webhook delivery delays

### 3. **Manual Reconciliation Trigger**
- ✅ `manualReconcileSubscriptions` - admin-callable function
- Can backfill up to 90 days of missed payments
- Useful for immediate testing and recovery

## Current Status

### Deployed Functions
- `stripeWebhook` - Main webhook endpoint (updated with logging)
- `reconcileSubscriptionPayments` - Scheduled reconciliation (NEW)
- `manualReconcileSubscriptions` - Manual trigger (NEW)

### Active Subscriptions Waiting for Payment Recording
- **brisconnect0@gmail.com** - sub_1U1r2bFLCPHEu32PlZgjkpp3
- **brisconnect0** - sub_test_brisconnect0 (TEST - should be deleted)

## Next Steps - Follow These in Order

### Step 1: Verify Stripe Webhook Endpoint
Go to: https://dashboard.stripe.com/webhooks

**Look for:** Endpoint URL ending with `/stripeWebhook`

**If NOT found - CREATE IT:**
1. Click "Add Endpoint"
2. Paste: `https://australia-southeast1-brisconnect-68b78.cloudfunctions.net/stripeWebhook`
3. Select these events:
   - ✅ checkout.session.completed
   - ✅ invoice.payment_succeeded
   - ✅ invoice.payment_failed
   - ✅ customer.subscription.deleted
4. Click "Add Endpoint"

**If FOUND - VERIFY IT:**
1. Click the endpoint to view details
2. Scroll to "Events to send" - all 4 events above should be checked
3. Scroll down to "Recent deliveries" to see if events are being received
4. Look for any 5xx errors

### Step 2: Test Webhook Delivery
1. In Stripe Dashboard, go to your webhook endpoint details
2. Click "Send test event"
3. Select `invoice.payment_succeeded` as test event type
4. Observe if 2xx response is returned

### Step 3: Monitor Firebase Logs
Run this to watch webhook events in real-time:
```bash
firebase functions:log -r australia-southeast1 --follow
```

You should see logging like:
```
INFO: Stripe webhook received eventType=invoice.payment_succeeded
INFO: Processing invoice.payment_succeeded invoiceId=in_...
INFO: Recording subscription payment amount=999
INFO: Subscription payment processed successfully
```

### Step 4: Clean Up Test Data
Delete the test subscription record (has `sub_test_brisconnect0`):

In Firebase Console → Firestore:
1. Go to `business_subscriptions` collection
2. Find document with ID: `brisconnect0` (email: brisconnect0@example.com)
3. Delete it

### Step 5: Manually Reconcile Missed Payments
After configuring webhook, run:
```bash
firebase functions:call manualReconcileSubscriptions
```

Or use this to backfill last 90 days:
```bash
firebase functions:call manualReconcileSubscriptions --data='{"daysBack": 90}'
```

Expected output:
```
✅ message: "Subscription reconciliation complete"
✅ checked: 1
✅ reconciledCount: 1 (number of payments backfilled)
```

### Step 6: Verify in Admin Dashboard
Visit: https://brisconnect-68b78.web.app/admin/dashboard

Check the "Monthly Revenue" KPI card - it should now show:
- **Current:** A$4.99 (only promotion)
- **After webhook fix:** A$19.98+ (includes subscription payments)

## How the Fix Works

```
Stripe Payment Flow
       ↓
   Webhook Event
       ↓
   stripeWebhook Function ← Enhanced with logging
       ↓
   Firestore business_payments ← Records payment
       ↓
   Admin Dashboard KPI ← Shows revenue

Fallback Flow (if webhook fails)
       ↓
   reconcileSubscriptionPayments (every 30 min)
       ↓
   Queries Stripe for missed invoices
       ↓
   Records to Firestore
       ↓
   Dashboard automatically updates
```

## Troubleshooting

### "Webhook endpoint rejected with 4xx"
- Check Firebase Console → Functions → stripeWebhook
- Ensure function is deployed and accessible
- Check CORS configuration

### "No recent deliveries in Stripe Dashboard"
- Verify events are enabled in endpoint settings
- Test manual event send first
- Check Firebase logs for errors

### "Payment amount mismatch"
- Verify SUBSCRIPTION_PRICE_CENTS = 999 (A$9.99) in functions/payments.js
- Check if Stripe invoice.amount_paid matches expected

### "Payment not appearing after 1 hour"
- Run manual reconciliation
- Check Firebase function logs
- Verify ownerId is in subscription metadata

## Important Files Modified

- `functions/payments.js`
  - Enhanced webhook logging
  - Added `reconcileSubscriptionPayments` function
  - Added `manualReconcileSubscriptions` function

- `functions/webhook-diagnostic.js` (NEW)
  - Guides webhook configuration
  - Provides troubleshooting steps

## Timeline for Full Recovery

1. Webhook config: **5 mins**
2. Test webhook: **2 mins**
3. Manual reconciliation: **1 min**
4. Verification: **immediate**

**Total: ~10 minutes to full recovery**

---

Need help? Check the logs:
```bash
firebase functions:log -r australia-southeast1
```

Deployed and ready! 🚀
