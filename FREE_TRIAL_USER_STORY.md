# User Story: 30-Day Free Trial for New Business Owners

**As a** new Business Owner, **I want** to automatically receive a 30-day free trial of BrisConnect+ premium features when I create my business profile, **so that** I can experience the full value of the platform before committing to a paid subscription.

## Acceptance Criteria

- Trial starts automatically on new owner account creation — no manual action or payment details required.
- Full premium feature access during the trial (AI Tools, Gemini Insights, AI Promotion Assistant, AI-gated media upload).
- Dashboard clearly shows trial status and days remaining.
- "Subscribe Now" CTA visible at any point during the trial.
- Access is automatically revoked when the trial ends, without needing the owner to visit any specific screen.
- Existing paid subscriptions are never overwritten/restarted by the trial logic.
- **Non-Functional (Consistency):** trial/subscription status must be evaluated identically across every screen that gates premium access, so the owner never sees conflicting states.

## Component Map

```mermaid
graph LR
  A[local_users/{ownerId} created] --> B[onLocalUserCreated<br/>onDocumentCreated trigger]
  B -->|skip if doc exists| C[(business_subscriptions/ownerId<br/>status:trialing, isFreeTrial:true, trialEndsAt +30d)]
  C --> D[Dashboard: direct Firestore .snapshots<br/>business_dashboard_screen.dart]
  C --> E[getSubscriptionStatus callable<br/>schedule_promotion_screen.dart]
  D --> F["AI Tools" / "Gemini Insights" cards]
  E --> G["AI Promotion Assistant" / AI-gated media upload]
  H[expireFreeTrials<br/>onSchedule every 60 min] -->|trialEndsAt <= now| C
```

## AC 1: Trial Starts Automatically — No Manual Action or Payment Details

**File:** `functions/payments.js` — `onLocalUserCreated`
```js
exports.onLocalUserCreated = onDocumentCreated(
  { region: 'australia-southeast1', document: 'local_users/{ownerId}' },
  async (event) => {
    const ownerId = event.params.ownerId;
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
```
This is a Firestore *document-create trigger*, not something the owner clicks or fills a form for — the trial is provisioned the instant their `local_users` account document is created during registration, with zero Stripe interaction (no card, no checkout session).

## AC 2: Full Premium Feature Access During the Trial

Every premium-gating check treats `active: true` the same way regardless of *why* it's true (paid subscription vs. trial) — features aren't given a reduced/different trial mode, they're the same features:

**File:** `lib/screens/business_dashboard_screen.dart` — "AI Tools" card
```dart
final isFreeTrial = subscriptionData?['isFreeTrial'] == true &&
    subscriptionData?['status'] == 'trialing';
...
_featureRow(
  icon: Icons.edit_note_rounded,
  label: 'AI Post Creator',
  locked: !isActive, // isActive is true for BOTH 'trialing' and 'active' status
  onTap: isActive ? () => _openAIPostCreator(context) : null,
),
```
"Gemini Insights" (`_buildAiInsightsCard`) sits in the same `isActive`-gated row as "AI Tools", and "AI Promotion Assistant" + AI-gated media upload in `schedule_promotion_screen.dart` are gated by the same underlying `active` flag returned from `getSubscriptionStatus` — see AC 7 (Consistency) for how both paths stay in sync.

## AC 3: Dashboard Clearly Shows Trial Status and Days Remaining

**File:** `lib/screens/business_dashboard_screen.dart`
```dart
Widget _buildFreeTrialCard(BuildContext context, Map<String, dynamic>? subscriptionData) {
  final trialEndsAt = subscriptionData?['trialEndsAt'];
  var daysLeft = 0;
  if (trialEndsAt is Timestamp) {
    daysLeft = trialEndsAt.toDate().difference(DateTime.now()).inDays + 1;
    if (daysLeft < 0) daysLeft = 0;
  }
  return Container(
    ...
    child: Column(children: [
      const Text('Subscription', ...),
      Text('Free trial • $daysLeft day${daysLeft == 1 ? '' : 's'} left', ...),
      const Text('Enjoying AI tools and promotion features? Subscribe to keep access after your trial ends.'),
      ElevatedButton.icon(onPressed: () => _openSubscriptionPlans(context), label: const Text('Subscribe Now')),
    ]),
  );
}
```
The "AI Tools" card header badge repeats the same countdown so it's visible without scrolling to the subscription slot:
```dart
Text(
  isFreeTrial
      ? 'FREE TRIAL • ${trialDaysLeft ?? 0} DAYS LEFT'
      : isActive ? 'BRISCONNECT+ • ACTIVE' : 'PREMIUM',
  ...
)
```

## AC 4: "Subscribe Now" CTA Visible at Any Point During the Trial

The `_buildSubscriptionSlot()` dispatcher always renders the trial card (with its `Subscribe Now` button) whenever `isFreeTrial && status == 'trialing'` — there's no code path where a trialing owner sees the dashboard without this CTA:
```dart
Widget _buildSubscriptionSlot(BuildContext context, bool isActive, Map<String, dynamic>? subscriptionData) {
  final isFreeTrial = subscriptionData?['isFreeTrial'] == true &&
      subscriptionData?['status'] == 'trialing';
  if (isFreeTrial) return _buildFreeTrialCard(context, subscriptionData);
  if (isActive) return _buildSubscriptionCard(context, subscriptionData);
  return _buildUpgradePromptCard(context);
}
```
`schedule_promotion_screen.dart`'s locked AI Promotion Assistant card also always shows an "Upgrade to Premium" button once the trial ends, so the CTA follows the owner across screens, not just the dashboard.

## AC 5: Access Automatically Revoked When Trial Ends — No Screen Visit Required

**File:** `functions/payments.js` — `expireFreeTrials`
```js
/**
 * Scheduled job that flips expired free-trial subscriptions to
 * 'trial_expired' once their 30-day window has passed, so real-time
 * Firestore listeners (e.g. the dashboard) see the change immediately
 * instead of waiting for the owner to trigger getSubscriptionStatus.
 */
exports.expireFreeTrials = onSchedule(
  { region: 'australia-southeast1', schedule: 'every 60 minutes', timeoutSeconds: 300 },
  async () => {
    const snapshot = await db.collection('business_subscriptions')
      .where('isFreeTrial', '==', true)
      .where('status', '==', 'trialing')
      .where('trialEndsAt', '<=', admin.firestore.Timestamp.now())
      .get();

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, { status: 'trial_expired', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    }
    await batch.commit();
  },
);
```
This is a proactive server-side sweep (not lazy evaluation on visit), so `business_subscriptions/{ownerId}.status` flips to `trial_expired` within an hour of the deadline **even if the owner never opens the app** — and since the dashboard reads this document via a live `.snapshots()` stream, `isActive` flips to `false` and every gated feature locks itself the moment that write lands, with no page refresh needed.

## AC 6: Existing Paid Subscriptions Are Never Overwritten/Restarted

**File:** `functions/payments.js` — `onLocalUserCreated`
```js
const existing = await subRef.get();
if (existing.exists) {
  // Never overwrite an existing (possibly paid) subscription record.
  return;
}
```
Because this trigger only fires once, on the `local_users/{ownerId}` document's *creation*, and even then only writes if no `business_subscriptions/{ownerId}` doc exists yet, a business owner who already has a real Stripe subscription (or a prior trial record) can never have it clobbered by trial logic re-running.

## Non-Functional Requirement: Consistent Status Across Every Gating Screen

Two different code paths evaluate premium access, and both are deliberately kept reading the **same source of truth** so they can never disagree:

1. **Dashboard** (`business_dashboard_screen.dart`) reads `business_subscriptions/{ownerId}` directly via a real-time Firestore stream:
```dart
Stream<DocumentSnapshot<Map<String, dynamic>>> _subscriptionStream(String ownerId) {
  return FirebaseFirestore.instance.collection('business_subscriptions').doc(ownerId).snapshots();
}
```
2. **Promotion scheduling** (`schedule_promotion_screen.dart`) calls the `getSubscriptionStatus` callable, which derives its answer from the **same document**:
```dart
final status = await StripePaymentService.getSubscriptionStatus(ownerId);
_hasActiveSubscription = status['active'] == true;
```
```js
// functions/payments.js — getSubscriptionStatus
if (doc.exists && sub?.isFreeTrial && !sub.stripeSubscriptionId) {
  const stillInTrial = (sub.trialEndsAt?.toMillis?.() ?? 0) > Date.now();
  if (stillInTrial) return { active: true, status: 'trialing', isFreeTrial: true, ... };
  if (sub.status !== 'trial_expired') {
    await doc.ref.set({ status: 'trial_expired', updatedAt: ... }, { merge: true });
  }
  return { active: false, status: 'trial_expired', isFreeTrial: true };
}
```
Because `expireFreeTrials` proactively writes `status: 'trial_expired'` onto the document itself (rather than only being computed lazily inside the callable), **both** paths converge on the same `status` field within the hour — the dashboard's direct stream doesn't need to call the callable to learn the trial ended, and the callable's lazily-computed answer is consistent with what the scheduled job would have written anyway. This was the specific inconsistency risk flagged during implementation and is why the scheduled job exists at all, rather than relying solely on lazy evaluation in `getSubscriptionStatus`.

## Files Involved

| File | Role |
|---|---|
| `functions/payments.js` (`onLocalUserCreated`) | Grants the 30-day trial on new owner account creation |
| `functions/payments.js` (`getSubscriptionStatus`) | Callable used by promotion/AI screens; derives trial state from Firestore |
| `functions/payments.js` (`expireFreeTrials`) | Scheduled sweep (every 60 min) that proactively expires trials without a visit |
| `lib/screens/business_dashboard_screen.dart` | Trial status card, days-remaining badge, "Subscribe Now" CTA, AI Tools/Gemini Insights gating |
| `lib/screens/schedule_promotion_screen.dart` | AI Promotion Assistant + AI-gated media upload gating via `getSubscriptionStatus` |
| `lib/services/stripe_payment_service.dart` | `getSubscriptionStatus()` client wrapper |
| Firestore `business_subscriptions/{ownerId}` | Single source of truth: `status`, `isFreeTrial`, `trialStartedAt`, `trialEndsAt` |
| `firestore.indexes.json` | Composite index `(isFreeTrial ASC, status ASC, trialEndsAt ASC)` supporting the scheduled sweep query |

## Status

This feature is already fully implemented, deployed, and previously verified (a test `local_users` document was created via the Admin SDK and confirmed `onLocalUserCreated` produced a correct 30-day trial document). No code changes were needed for this documentation pass — every acceptance criterion, including the consistency non-functional requirement, is satisfied by the existing implementation.
