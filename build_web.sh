#!/bin/bash
set -e

echo "Building BrisConnect web release..."
flutter build web --release

# Self-host CanvasKit from /canvaskit so Safari/iOS doesn't block it due to
# ITP/cross-origin restrictions when loaded from gstatic.com.
# Also disable Flutter's own service worker entirely. It previously
# registered at the root scope and conflicted with firebase-messaging-sw.js
# (also root scope), which silently broke background push notifications
# on web. Stale main.dart.js caching is solved via HTTP headers instead.
BOOTSTRAP="build/web/flutter_bootstrap.js"
SW_VERSION=$(grep -o 'serviceWorkerVersion: "[0-9]*"' "$BOOTSTRAP" | head -1 | grep -o '[0-9]*')
if [ -n "$SW_VERSION" ]; then
  node -e "
    const fs = require('fs');
    const path = '$BOOTSTRAP';
    let content = fs.readFileSync(path, 'utf8');
    content = content.replace(
      \"_flutter.loader.load({\",
      \"_flutter.loader.load({\n  config: {\n    canvasKitBaseUrl: '/canvaskit'\n  },\"
    );
    content = content.replace(/serviceWorkerSettings:\s*\{[\s\S]*?\}/, 'serviceWorkerSettings: null');
    fs.writeFileSync(path, content);
  "
  echo "Patched $BOOTSTRAP (Flutter service worker disabled, local CanvasKit, version: $SW_VERSION)."
else
  echo "WARNING: Could not find serviceWorkerVersion in $BOOTSTRAP"
fi

# New page loads never register a service worker (see serviceWorkerSettings
# patch above), leaving firebase-messaging-sw.js as the only one intended to
# run at the root scope going forward. However, browsers/phones that already
# installed the old, aggressively-caching Flutter service worker (from before
# this fix shipped) still have it active and it must be replaced, not just
# deleted: if this URL 404s or falls back to index.html, the browser's SW
# update check gets invalid content (wrong MIME/script), the update silently
# fails, and the stale service worker keeps serving cached old versions of
# the app forever. So we overwrite it with a minimal self-destructing script
# (web/flutter_service_worker.js) that old clients can fetch, activate, and
# have unregister itself + clear all caches.
cp "web/flutter_service_worker.js" "build/web/flutter_service_worker.js"

# Precompress key text assets so Firebase Hosting can serve Brotli/gzip
# versions without runtime CPU cost. This dramatically reduces transfer
# size for the main JS bundle and improves first-load speed.
echo "Precompressing JS assets..."
node compress_web_assets.js

echo "Build complete. Run: firebase deploy --only hosting"
