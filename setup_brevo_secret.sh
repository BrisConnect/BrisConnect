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

read -rsp "Paste Brevo API v3 key (input hidden): " BREVO_API_KEY
echo ""

# Validate that the user pasted an API v3 key, not an SMTP relay key.
if [[ -z "$BREVO_API_KEY" ]]; then
  echo "✗ No key provided. Aborting."
  exit 1
fi
if [[ "$BREVO_API_KEY" == xsmtpsib-* ]]; then
  echo "✗ This is a Brevo SMTP relay key (starts with xsmtpsib-)."
  echo "   The Cloud Function needs a Brevo API v3 key (starts with xkeysib-)."
  echo "   Get one from app.brevo.com → Account → SMTP & API → API Keys."
  exit 1
fi
if [[ "$BREVO_API_KEY" != xkeysib-* ]]; then
  echo "✗ Unexpected key format. Brevo API v3 keys start with 'xkeysib-'."
  echo "   Please paste the correct key and try again."
  exit 1
fi

echo "$BREVO_API_KEY" | firebase --project "$PROJECT" functions:secrets:set BREVO_API_KEY
echo "✓ BREVO_API_KEY set"

echo ""
echo "Deploying functions to pick up the new secret..."
firebase deploy --only functions:sendEmailLoginCode,functions:sendVisitorWelcomeEmail,functions:processMailQueue --project "$PROJECT"
echo ""
echo "=== Done! Login-code, welcome, and admin broadcast emails will now be sent via Brevo. ==="
echo ""
echo "NOTE: The Firebase 'Trigger Email' extension is also watching the 'mail' collection."
echo "To avoid duplicate sends, either:"
echo "  1) Disable/uninstall the extension in the Firebase console, OR"
echo "  2) Reconfigure it with valid Brevo SMTP credentials. See README_EMAIL_WORKER.md."
