# BrisConnect SMS Worker (Local)

This worker consumes Firestore `sms_queue` documents and sends SMS.

## Modes

- `SMS_PROVIDER=mock`: logs SMS and marks job as `sent`.
- `SMS_PROVIDER=twilio`: sends real SMS with Twilio.

## Setup

1. Use Node 18+.
2. Install deps (if needed):
   - `npm install`
3. Set Firebase auth:
   - Preferred: `GOOGLE_APPLICATION_CREDENTIALS` env var pointing to a service account file.
   - Alternative: `FIREBASE_SERVICE_ACCOUNT_JSON` env var with inline JSON.
4. Copy variables from `.env.example` into your shell env.

## Run

- One pass (good for testing):
  - `npm run start:once`
- Continuous worker:
  - `npm start`

## Firestore Job Format

Expected fields in `sms_queue`:

- `to` (string)
- `message` (string)
- `meta` (object, optional)

The worker updates each job with status fields:

- `status`: `processing`, `sent`, or `failed`
- `attempts`
- `provider`
- `providerResponse` or `error`

## Quick End-to-End Test (Mock)

1. In app, queue an SMS from admin SMS screen.
2. Run worker with `SMS_PROVIDER=mock`.
3. Confirm document in `sms_queue` changes to `status: sent`.

## Quick End-to-End Test (Twilio)

1. Set:
   - `SMS_PROVIDER=twilio`
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_FROM_NUMBER`
2. Queue SMS from app.
3. Run worker and verify:
   - Firestore status becomes `sent`.
   - Twilio Console shows delivered/queued message.
   - Destination phone receives SMS.

## Firebase Auth Cleanup (Registration Reset)

If you deleted `local_users` / `visitor_users` in Firestore but still get
"email already in use", you also need to delete Firebase Authentication users.

### Dry run (safe)

- `npm run auth:purge:dry`

### Delete all Auth users

- `npm run auth:purge:all`

### Delete selected users by email

- `node purge_auth_users.js --emails user1@example.com,user2@example.com --yes`

### Delete users by domain

- `node purge_auth_users.js --domain example.com --yes`

This script requires Firebase Admin credentials:

- `GOOGLE_APPLICATION_CREDENTIALS` (recommended)
- or `FIREBASE_SERVICE_ACCOUNT_JSON`
- optional `FIREBASE_PROJECT_ID`
