#!/bin/bash
# Run this in macOS Terminal:
#   cd ~/Documents/BrisConnect
#   bash setup_brevo_secret.sh

set -e
PROJECT="brisconnect-68b78"

echo ""
echo "=== BrisConnect Brevo Email Setup ==="
echo "Project: $PROJECT"
echo ""
echo "You'll need from app.brevo.com:"
echo "  • API v3 key (starts with xkeysib-...)"
echo ""

read -rs "?Paste Brevo API v3 key: " BREVO_API_KEY
echo ""
echo "$BREVO_API_KEY" | firebase --project "$PROJECT" functions:secrets:set BREVO_API_KEY
echo "✓ BREVO_API_KEY set"

echo ""
echo "Deploying functions to pick up the new secret..."
firebase deploy --only functions:sendEmailLoginCode,functions:sendVisitorWelcomeEmail --project "$PROJECT"
echo ""
echo "=== Done! Login-code and welcome emails will now be sent directly via Brevo. ==="
