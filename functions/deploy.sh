#!/bin/bash

# BrisConnect - Automated Firestore Rules & Food Business Seeding

PROJECT_ID="brisconnect-68b78"
RULES_FILE="/Users/ibrahim_ahhoa/Documents/BrisConnect/firestore.rules"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  BRISCONNECT - AUTOMATED DEPLOYMENT                            ║"
echo "║  Deploy Firestore Rules + Seed 27 Brisbane Food Businesses     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if service account exists
if [ ! -z "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "✓ Service account found: $GOOGLE_APPLICATION_CREDENTIALS"
  echo ""
  echo "⏳ Starting deployment..."
  cd /Users/ibrahim_ahhoa/Documents/BrisConnect/functions
  node deploy_fully_automated.js
  exit $?
fi

# Check if key exists in project
if [ -f "/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json" ]; then
  echo "✓ Service account found in project directory"
  export GOOGLE_APPLICATION_CREDENTIALS="/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json"
  cd /Users/ibrahim_ahhoa/Documents/BrisConnect/functions
  node deploy_fully_automated.js
  exit $?
fi

# No credentials found - guide user
echo "⚠️  No service account credentials found."
echo ""
echo "Quick Setup (2 minutes):"
echo "═════════════════════════════════════════════════════════════════"
echo ""
echo "1️⃣  Open this link:"
echo "    https://console.firebase.google.com/project/$PROJECT_ID/settings/serviceaccounts/adminsdk"
echo ""
echo "2️⃣  Click 'Generate New Private Key'"
echo ""
echo "3️⃣  Save the downloaded JSON file, then run:"
echo "    export GOOGLE_APPLICATION_CREDENTIALS=\"/path/to/your/key.json\""
echo "    /Users/ibrahim_ahhoa/Documents/BrisConnect/functions/deploy.sh"
echo ""
echo "OR copy the file to this project:"
echo "    cp /path/to/your/key.json /Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json"
echo "    /Users/ibrahim_ahhoa/Documents/BrisConnect/functions/deploy.sh"
echo ""
echo "═════════════════════════════════════════════════════════════════"
