#!/usr/bin/env bash
set -euo pipefail

# Cloud Run deployment script for BrisConnect email/SMS worker
# Requires: gcloud CLI authenticated, Docker available, BREVO_API_KEY set

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-brisconnect-68b78}"
REGION="${CLOUD_RUN_REGION:-australia-southeast1}"
SERVICE_NAME="${CLOUD_RUN_SERVICE:-brisconnect-mail-worker}"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

if [[ -z "${BREVO_API_KEY:-}" ]]; then
  echo "Error: BREVO_API_KEY is not set."
  echo "Export it first: export BREVO_API_KEY=your-api-key"
  exit 1
fi

if ! command -v gcloud &> /dev/null; then
  echo "Error: gcloud CLI is not installed."
  echo "Install from: https://cloud.google.com/sdk/docs/install"
  exit 1
fi

echo "Deploying to Cloud Run..."
echo "Project: ${PROJECT_ID}"
echo "Region:  ${REGION}"
echo "Service: ${SERVICE_NAME}"

gcloud config set project "${PROJECT_ID}"
gcloud builds submit --tag "${IMAGE}"
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --no-allow-unauthenticated \
  --min-instances 1 \
  --max-instances 1 \
  --memory 256Mi \
  --cpu 1 \
  --concurrency 1 \
  --timeout 300s \
  --set-env-vars "FIREBASE_PROJECT_ID=${PROJECT_ID}" \
  --set-env-vars "EMAIL_PROVIDER=brevo" \
  --set-env-vars "SMS_PROVIDER=mock" \
  --set-env-vars "POLL_INTERVAL_MS=5000" \
  --set-env-vars "MAX_BATCH_SIZE=20" \
  --set-env-vars "BREVO_SENDER_EMAIL=noreply@brisconnect.com.au" \
  --set-env-vars "BREVO_SENDER_NAME=BrisConnect+" \
  --set-env-vars "BREVO_API_KEY=${BREVO_API_KEY}"

echo ""
echo "Deployment complete."
echo "Monitor logs: gcloud logging tail --service=${SERVICE_NAME} --region=${REGION}"
