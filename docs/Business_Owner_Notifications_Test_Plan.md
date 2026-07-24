# Business-Owner Push Notifications — Test Plan

## User Story

> **As a** business owner (local user)  
> **I want** to receive push notifications for trending promotions, expiring offers, new reviews, and business updates  
> **So that** I can respond quickly and keep my business profile active.

---

## Acceptance Criteria

1. A logged-in local user can enable/disable each notification category independently.
2. The app requests iOS notification permission on launch and forwards the APNs token to Firebase.
3. The device FCM token is stored under `local_users/{email}/fcmTokens` after login.
4. A new review on the owner’s business triggers a push notification if the owner has not disabled it.
5. A spike in promotion engagement (views + clicks) triggers a trending-promotion notification at most once per hour.
6. A promotion expiring within 24 hours triggers a reminder notification at most once per offer.
7. Failed/inactive FCM tokens are removed automatically.
8. All notifications are also logged in `local_users/{email}/notifications` and `user_notifications`.

---

## Implementation Components

| Layer | Files |
|-------|-------|
| Platform config | `ios/Runner/Runner.entitlements`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist` |
| Flutter service | `lib/services/fcm_service.dart` |
| Auth model | `lib/auth/local_auth.dart` |
| Settings UI | `lib/screens/business_notification_settings_screen.dart` |
| Navigation | `lib/screens/local_portal_screen.dart` |
| Cloud Functions | `functions/index.js` (`sendOwnerNotification`, `onPromotionEngagementSpike`, `notifyExpiringOffers`, `onNewReviewNotifyOwner`) |
| Security rules | `firestore.rules` |

---

## Automated Tests

### Unit Tests

| File | Test | What it verifies |
|------|------|------------------|
| `test/services/fcm_service_test.dart` | `navigatorKey exposes a valid GlobalKey<NavigatorState>` | The global navigator key is available for foreground snackbars. |
| `test/services/fcm_service_test.dart` | `singleton instance is accessible` | `FcmService.instance` returns a singleton. |
| `test/services/fcm_service_test.dart` | `token is null before initialization` | No token is cached before the service initializes. |
| `test/auth/local_auth_notification_preferences_test.dart` | `defaults all business notification preferences to true` | New local users receive all categories by default. |
| `test/auth/local_auth_notification_preferences_test.dart` | `copyWith updates only the requested preference` | Preference updates are isolated. |

### Widget Tests

| File | Test | What it verifies |
|------|------|------------------|
| `test/screens/business_notification_settings_screen_test.dart` | `renders all four notification toggles` | The settings screen exposes trending promotions, offer expiry, new reviews, and business updates toggles. |
| `test/screens/business_notification_settings_screen_test.dart` | `toggles reflect current local preferences` | The UI reads the current user’s preferences (e.g., new reviews disabled). |

### Running the automated tests

```bash
flutter test test/services/fcm_service_test.dart \
  test/auth/local_auth_notification_preferences_test.dart \
  test/screens/business_notification_settings_screen_test.dart
```

**Current result:** `00:01 +7: All tests passed!`

---

## Manual / End-to-End Test Cases

### TC-01: iOS permission prompt on first launch

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Delete the app from the iPhone. | App removed. |
| 2 | Run `flutter run -d 00008130-000131EC3E31001C`. | App installs and launches. |
| 3 | Observe the welcome screen. | System alert appears: “BrisConnect+ Would Like to Send You Notifications”. |
| 4 | Tap **Allow**. | Alert dismisses; app continues to welcome screen. |

### TC-02: FCM token stored after local login

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Log in as a local user on the iPhone. | Login succeeds and local portal opens. |
| 2 | In Firebase Console → Firestore → `local_users/{email}/fcmTokens`. | A document exists with the FCM token, `platform: ios`, `createdAt`, and `lastSeenAt`. |
| 3 | Log out and log in again. | `lastSeenAt` timestamp updates. |

### TC-03: Toggle notification preferences

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On the local portal, open the profile/settings tab. | “Business Notifications” row is visible. |
| 2 | Tap **Business Notifications**. | The BusinessNotificationSettingsScreen opens. |
| 3 | Turn off **New reviews**. | Switch animates to OFF; a save indicator appears briefly. |
| 4 | In Firestore, read `local_users/{email}`. | `notifyNewReview: false`; other preferences remain `true`. |
| 5 | Return and turn **New reviews** back on. | Firestore updates to `notifyNewReview: true`. |

### TC-04: New review notification

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Ensure the business owner is logged in and notifications are enabled. | FCM token is present in Firestore. |
| 2 | From a visitor account, leave a review on the owner’s business. | Review is saved to `reviews/{reviewId}`. |
| 3 | Wait for the Cloud Function `onNewReviewNotifyOwner` to execute. | A push notification appears: “⭐ New review received”. |
| 4 | Check `local_users/{email}/notifications`. | A notification log entry exists with type `new_review`. |
| 5 | Disable **New reviews** and repeat. | No push notification is received. |

### TC-05: Promotion engagement spike

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create an active promotion for the logged-in owner. | Promotion document exists with `ownerId`, `views`, `clicks`. |
| 2 | Increment `views` and `clicks` so the total delta exceeds the threshold (default 50) within one hour. | Cloud Function `onPromotionEngagementSpike` fires. |
| 3 | Observe the device. | Push notification appears: “🔥 Your promotion is trending!”. |
| 4 | Increment engagement again within the same hour. | No duplicate notification is sent (throttled by `lastSpikeNotifiedAt`). |
| 5 | Disable **Trending promotions** and repeat. | No push notification is received. |

### TC-06: Offer expiry reminder

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create a promotion with `status: active` and `endAt` between now and +24 hours. | Promotion document exists in the expiring window. |
| 2 | Wait for the scheduled `notifyExpiringOffers` function (runs every 60 minutes) or invoke it manually. | Owner receives push: “⏰ Offer expiring soon”. |
| 3 | Check the promotion document. | `expiryReminderSentAt` is set. |
| 4 | Wait for the next scheduled run. | No duplicate reminder is sent for the same promotion. |
| 5 | Disable **Offer expiry reminders** and create another expiring promotion. | No reminder is sent. |

### TC-07: Stale token cleanup

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Add an invalid token to `local_users/{email}/fcmTokens`. | Invalid token document exists. |
| 2 | Trigger any notification (e.g., new review). | FCM send fails for the invalid token. |
| 3 | Check `local_users/{email}/fcmTokens`. | The invalid token document is deleted; valid tokens remain. |

### TC-08: Foreground notification presentation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Keep the app in the foreground on the business dashboard. | App is active. |
| 2 | Trigger a new review from another device. | A floating SnackBar appears at the bottom with the notification title and body. |
| 3 | Verify accessibility. | The SnackBar content is wrapped in `Semantics(liveRegion: true)`. |

---

## Backend Function Tests (Node.js / Firebase emulators)

Use the Firebase emulator suite or manual callable triggers to validate the Cloud Functions.

### Test: `sendOwnerNotification`

```js
const admin = require('firebase-admin');
const { sendOwnerNotification } = require('./index.js');

await admin.firestore().collection('local_users').doc('owner@test.com').collection('fcmTokens')
  .doc('valid_test_token').set({ token: 'valid_test_token', platform: 'ios' });

const result = await sendOwnerNotification({
  ownerId: 'owner@test.com',
  title: 'Test',
  body: 'Body',
  type: 'test',
});

expect(result.sent).toBeGreaterThan(0);
```

### Test: `onPromotionEngagementSpike`

1. Create a promotion with `views: 0`, `clicks: 0`, `engagementSpikeThreshold: 10`.
2. Update `views` to 15.
3. Verify a notification log is created for the owner.

### Test: `notifyExpiringOffers`

1. Create a promotion with `status: 'active'` and `endAt` 12 hours from now.
2. Run the scheduled function.
3. Verify an `offer_expiry` notification is sent and `expiryReminderSentAt` is set.

### Test: `onNewReviewNotifyOwner`

1. Create a business with `ownerId: 'owner@test.com'`.
2. Create a review with `businessId` pointing to that business.
3. Verify a `new_review` notification is sent.

---

## Known Blockers

- `pod install` / `flutter run` on the physical iPhone currently fails because CocoaPods cannot complete the git clone of `firebase/firebase-ios-sdk.git` (branch `CocoaPods-12.9.0`) due to GitHub network timeouts. This blocks on-device testing until the network stabilizes or the repo is pre-cached.

---

## Sign-off Checklist

- [x] Dependency added (`firebase_messaging: ^16.1.3`).
- [x] iOS entitlements, AppDelegate, and Info.plist configured.
- [x] Flutter FCM service implemented and testable.
- [x] LocalAuth preference fields and update method added.
- [x] Settings screen built and linked from local portal.
- [x] Cloud Functions for trending, expiry, and new reviews implemented.
- [x] Firestore rules updated.
- [x] Automated unit/widget tests pass.
- [ ] Functions deployed to Firebase.
- [ ] End-to-end validation on physical iPhone completed.
