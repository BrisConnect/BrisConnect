# User Story: Real-Time Notifications

**As a** User, **I want** to receive real-time notifications **so that** I am immediately informed about important updates relevant to my role, without needing to manually check the app.

## Acceptance Criteria

- Users receive push notifications for events relevant to their role (owner, visitor, admin)
- Notification delivery respects per-user preferences and opt-outs
- Notifications include deep links so tapping opens the right screen
- In-app notification history is available for owners, visitors, and admins
- Failed or invalid FCM tokens are removed automatically
- Transient FCM errors are retried rather than dropped
- Account approval/rejection sends a real-time push notification to the owner
- Saved events trigger a reminder notification before the event starts
- Email copies are sent for important notifications so users see them without opening the app

## Status Summary

BrisConnect+ already has a comprehensive, role-aware notification pipeline:

- **FCM token lifecycle** is managed in [`lib/services/fcm_service.dart`](lib/services/fcm_service.dart): tokens are fetched on sign-in, refreshed automatically, and stored under the *currently active* role collection (`local_users` or `visitor_users`) so an owner/visitor dual account doesn't receive the wrong notifications. Stale tokens are removed from the opposite collection.
- **Cloud Function senders** for owners ([`functions/owner_notifications.js`](functions/owner_notifications.js)), visitors ([`functions/visitor_notifications.js`](functions/visitor_notifications.js)), and admins ([`functions/admin_notifications.js`](functions/admin_notifications.js)) all check preferences, persist in-app history, send FCM pushes, send email copies, and delete invalid tokens.
- **Triggers** exist for new reviews, promotion engagement spikes, expiring offers, review replies, saved-business profile updates, trending businesses, new business discovery, personalised recommendations, and visitor promotion expiry reminders.

Two real improvements were made in this session:

1. **Reliability:** a new shared [`functions/fcm_utils.js`](functions/fcm_utils.js) helper adds exponential-backoff retry for transient FCM failures and collects invalid tokens so callers can delete them. All three sender modules now use it.
2. **Account approval push:** a new `onLocalUserApprovalChanged` trigger sends an FCM push (plus in-app history) immediately when an owner's `approvalStatus` flips to `approved` or `rejected`. Previously only email/SMS were queued from the admin UI, leaving the app notification channel silent.

One honest gap remains: **saved-event reminders are device-local notifications only** ([`lib/services/visitor_notification_service.dart`](lib/services/visitor_notification_service.dart) schedules them with `flutter_local_notifications`). There is no server-side FCM push reminder before a saved event, so users who switch devices, use the web app, or uninstall/reinstall will not receive that reminder. This is documented at the end of this file.

## Component Map

```mermaid
graph LR
  A[FcmService] -->|store token| B[(local_users / visitor_users)]
  A -->|refresh| C[FirebaseMessaging]
  D[NotificationSettingsScreen] -->|persist| B
  E[Cloud Functions triggers] --> F[owner_notifications.js]
  E --> G[visitor_notifications.js]
  E --> H[admin_notifications.js]
  F --> I[fcm_utils.js<br/>NEW: retry + invalid-token cleanup]
  G --> I
  H --> I
  F --> J[user_notifications / local_users/{id}/notifications]
  G --> K[visitor_users/{email}/notifications]
  H --> L[admin_notifications]
  F --> M[FCM + Brevo email]
  G --> M
  H --> M
  N[onLocalUserApprovalChanged<br/>NEW] --> F
  O[onNewReviewNotifyOwner] --> F
  P[onPromotionEngagementSpike] --> F
  Q[notifyExpiringOffers] --> F
  R[onReviewReply / onCrowdReported] --> G
  S[notifyExpiringSavedPromotions] --> G
  T[onBusinessVerified] --> G
```

## AC 1: Role-Relevant Push Notifications

Already implemented across multiple Cloud Function triggers:

| Role | Trigger | What it notifies |
|---|---|---|
| Owner | `onNewReviewNotifyOwner` | New review on their business |
| Owner | `onPromotionEngagementSpike` | Promotion trending above engagement threshold |
| Owner | `notifyExpiringOffers` | Promotion expiring within 24h |
| Owner | `onLocalUserApprovalChanged` | Account approved/rejected |
| Visitor | `onReviewReply` | Business replied to their review |
| Visitor | `onCrowdReported` | Crowd/busyness updates for saved businesses |
| Visitor | `onPromotionNearby` | A saved/nearby promotion is available |
| Visitor | `onBusinessUpdated` | Saved business updated profile |
| Visitor | `onBusinessTrending` | Saved business is trending |
| Visitor | `notifyExpiringSavedPromotions` | Saved promotion expiring soon |
| Visitor | `onBusinessVerified` | New business matching interests joined |
| Admin | `_notifyAdmins` (via `sendAdminNotification`) | New reviews, crowd reports, review replies, etc. |

Each sender reads the user's FCM tokens from the appropriate subcollection (`local_users/{id}/fcmTokens`, `visitor_users/{email}/fcmTokens`, or `admins/{email}/fcmTokens`) and sends via `sendFcmWithRetry`.

## AC 2: Preference-Aware Delivery

**Visitor preferences** are stored on the `visitor_users` document and checked in [`functions/visitor_notifications.js`](functions/visitor_notifications.js):
```js
const PREFERENCE_FIELDS = {
  [VISITOR_NOTIFICATION_TYPES.NEARBY_PROMOTION]: 'nearbyPromotionsEnabled',
  [VISITOR_NOTIFICATION_TYPES.SAVED_BUSINESS_UPDATE]: 'savedBusinessUpdatesEnabled',
  ...
};
```

**Owner preferences** are stored on the `local_users` document and checked in [`functions/owner_notifications.js`](functions/owner_notifications.js) via `sendOwnerNotificationIfEnabled`:
```js
const prefs = await admin.firestore().collection('local_users').doc(ownerId).get();
if (prefs.exists && prefs.data()[preferenceField] === false) {
  return { success: false, sent: 0, error: 'Disabled by preference' };
}
```

The Flutter settings screen ([`lib/screens/notification_settings_screen.dart`](lib/screens/notification_settings_screen.dart)) lets users toggle these preferences and persists them through `LocalAuth`/`VisitorAuth`.

## AC 3: Deep Links and Actions

[`lib/services/fcm_service.dart`](lib/services/fcm_service.dart) handles notification taps:
- Parses `screen` from the FCM data payload and maps legacy screen names (`business_dashboard`, `reviews`, etc.) to current routes (`/local/portal`, `/admin/reports`, etc.).
- Parses `actions` JSON arrays from the payload and surfaces them as snackbar actions (e.g., "Extend offer" for promotions).
- Actionable FCM payloads include `apns.category` for iOS action buttons.

Owner/visitor/admin senders all normalize action routes before writing history/email so deep links don't break.

## AC 4: In-App Notification History

- **Owners:** [`lib/screens/owner_notifications_screen.dart`](lib/screens/owner_notifications_screen.dart) reads `local_users/{email}/notifications`; unread count shown in [`lib/widgets/owner_notification_bell.dart`](lib/widgets/owner_notification_bell.dart).
- **Visitors:** [`lib/screens/visitor_notifications_screen.dart`](lib/screens/visitor_notifications_screen.dart) reads `visitor_users/{email}/notifications`; unread count shown in [`lib/widgets/visitor_notification_bell.dart`](lib/widgets/visitor_notification_bell.dart).
- **Admins:** [`functions/admin_notifications.js`](functions/admin_notifications.js) writes to the top-level `admin_notifications` collection.

## AC 5: Automatic Invalid Token Cleanup

All three senders delete tokens that FCM reports as invalid or expired. With the new `sendFcmWithRetry` helper, the cleanup now happens after retries are exhausted:

```js
if (failedTokens.length > 0) {
  await Promise.all(
    failedTokens.map((token) =>
      db.collection(...).doc(token).delete().catch(() => {})
    )
  );
}
```

## AC 6: Retry on Transient FCM Errors

**Fixed/added.** [`functions/fcm_utils.js`](functions/fcm_utils.js) provides a shared multicast sender with exponential backoff:
```js
async function sendFcmWithRetry(messaging, tokens, payload, options = {}) {
  const maxRetries = options.maxRetries ?? 1;
  ...
}
```
It retries only on retryable codes (`messaging/server-unavailable`, `messaging/internal-error`, `messaging/unknown-error`, `ECONNRESET`, `ETIMEDOUT`, `ECONNREFUSED`, `429`, `Quota exceeded`) and returns failed tokens so callers can delete them.

## AC 7: Account Approval Push Notification

**Fixed/added.** [`functions/index.js`](functions/index.js) now exports `onLocalUserApprovalChanged`, a Firestore `onDocumentUpdated` trigger on `local_users/{ownerId}`:

```js
if (previousStatus === currentStatus) return;
if (currentStatus !== 'approved' && currentStatus !== 'rejected') return;
...
await sendOwnerNotification({ ownerId, title, body, data: { screen: '/local/portal' }, type: 'account_approved' });
```

This uses `sendOwnerNotification` (not the preference-gated variant) because approval status is an account-critical message that should not be silently disabled.

## AC 8: Email Copies

All senders call [`functions/email_notifications.js`](functions/email_notifications.js) (`sendNotificationEmail`) so users receive a Brevo email copy even if push fails or is disabled. This is gated by the user's `emailNotificationsEnabled` flag for visitors and always sent for owners/admins where appropriate.

## AC 9: Saved-Event Reminder

**Partially implemented — server-side push gap.** [`lib/services/visitor_notification_service.dart`](lib/services/visitor_notification_service.dart) schedules a *local* notification with `flutter_local_notifications` when a visitor marks an event as interested:

```dart
Future<void> scheduleEventReminder({ ... }) async {
  await _flutterLocalNotificationsPlugin.zonedSchedule(
    notificationId,
    'Event Reminder: $eventTitle',
    'Coming up on $eventDate at $eventLocation',
    tzReminderAt,
    notificationDetails,
    ...
  );
}
```

A Firestore record is also persisted via `NotificationRepository`, but **no Cloud Function reads that record to send an FCM push reminder**. This means:
- A user with multiple devices will only be reminded on the device where they saved the event.
- Web users (no `flutter_local_notifications` support) won't receive the reminder at all.
- Users who reinstall the app will lose scheduled reminders.

This is the one remaining real-time gap for this user story.

## Files Involved

| File | Role |
|---|---|
| `lib/services/fcm_service.dart` | Token lifecycle, permission handling, foreground snackbar, tap navigation |
| `lib/screens/notification_settings_screen.dart` | UI for toggling notification preferences |
| `lib/auth/local_auth.dart` | Owner notification preference getters/setters |
| `lib/auth/visitor_auth.dart` | Visitor notification preference getters/setters |
| `lib/services/visitor_notification_service.dart` | Local scheduled reminders for saved events |
| `lib/widgets/owner_notification_bell.dart` | Owner unread notification badge |
| `lib/widgets/visitor_notification_bell.dart` | Visitor unread notification badge |
| `lib/screens/owner_notifications_screen.dart` | Owner in-app notification history |
| `lib/screens/visitor_notifications_screen.dart` | Visitor in-app notification history |
| `functions/index.js` | Triggers (`onNewReviewNotifyOwner`, `onPromotionEngagementSpike`, `onLocalUserApprovalChanged`, visitor triggers, etc.) |
| `functions/owner_notifications.js` | Owner FCM/email/history sender; preference gate |
| `functions/visitor_notifications.js` | Visitor FCM/email/history sender; preference gate |
| `functions/admin_notifications.js` | Admin FCM/email/history sender |
| `functions/fcm_utils.js` | **New** — shared `sendFcmWithRetry` with exponential backoff and invalid-token reporting |
| `functions/email_notifications.js` | Brevo email copy sender |
| `functions/test/notifications.test.js` | Unit tests for promotion/extend/health notifications; **fixed** module-cache isolation |

## Noted (Not Fixed) Gap: Server-Side Saved-Event Push Reminder

The app schedules saved-event reminders locally, which satisfies "without manually checking the app" on a single mobile device but is not a true cross-device, real-time push. A complete implementation would:

1. Add a Cloud Scheduler job (e.g., every 15 minutes) that queries pending reminder records from Firestore.
2. For each reminder whose time has passed, call `sendVisitorNotification` with type `event_reminder`.
3. Mark the reminder as `sent` so it is not double-delivered.
4. Optionally delete the reminder record once the event has ended.

This is a larger feature than the focused fixes above and is left as a documented gap rather than a half-implemented push path.

## Status

- Added `functions/fcm_utils.js` and wired it into owner, visitor, and admin notification senders for retry + invalid-token cleanup.
- Added `onLocalUserApprovalChanged` Cloud Function trigger so account approval/rejection delivers a real-time push + in-app notification.
- Fixed `owner_notifications.js` to use inline `admin.firestore()` calls, avoiding module-level `db` capture issues in tests.
- Fixed test isolation in `functions/test/notifications.test.js` by clearing notification helper module caches in `beforeEach` and stubbing `change.after.ref.update` in `createCloudEventChange`.
- Verified `node --check` on all modified JS files.
- Verified `cd functions && npm test` — **10 passing**.
- Not yet deployed — ship via `firebase deploy --only functions` and `flutter build web --release && firebase deploy --only hosting`.
