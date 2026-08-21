#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-brisconnect-68b78}"
SERVICE_ACCOUNT="brisconnect-mail-worker@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Setting up service account for Cloud Run worker..."
echo "Project: ${PROJECT_ID}"

if ! command -v gcloud &> /dev/null; then
  echo "Error: gcloud CLI is not installed. Install from https://cloud.google.com/sdk/docs/install"
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

# Create service account if it doesn't exist
if gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" &>/dev/null; then
  echo "Service account already exists: ${SERVICE_ACCOUNT}"
else
  echo "Creating service account..."
  gcloud iam service-accounts create brisconnect-mail-worker \
    --display-name="BrisConnect Mail Worker"
fi

# Grant Firestore read/write access
echo "Granting Firestore access..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/datastore.user" \
  --condition=None

echo ""
echo "Service account ready: ${SERVICE_ACCOUNT}"
