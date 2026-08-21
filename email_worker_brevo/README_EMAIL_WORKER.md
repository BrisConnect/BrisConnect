# BrisConnect Email / SMS Worker

Polls the Firestore `mail` and `sms_queue` collections and sends messages via Brevo (email) and Twilio (SMS).

## Local testing

```bash
cd email_worker_brevo
npm install

# Mock mode (prints to console, does not send real email)
export EMAIL_PROVIDER=mock
export SMS_PROVIDER=mock
export FIREBASE_SERVICE_ACCOUNT_JSON=$(cat ../service-account-key.json)
npm start
```

## Production deployment to Cloud Run

### 1. Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated:
  ```bash
  gcloud auth login
  gcloud config set project brisconnect-68b78
  ```
- Brevo API key. Get it from **Brevo Console → Account → SMTP & API → API Keys**.

### 2. Store the Brevo API key in Secret Manager

```bash
gcloud secrets create brevo-api-key --data-file=- <<EOF
your-brevo-api-key-here
