#!/bin/bash
set -e

echo "Building BrisConnect web release..."
flutter build web --release

# Self-host CanvasKit from /canvaskit so Safari/iOS doesn't block it due to
# ITP/cross-origin restrictions when loaded from gstatic.com.
# Also disable the Flutter service worker to avoid stale caches causing
# blank-screen issues after reloads.
BOOTSTRAP="build/web/flutter_bootstrap.js"
SW_VERSION=$(grep -o 'serviceWorkerVersion: "[0-9]*"' "$BOOTSTRAP" | head -1 | grep -o '[0-9]*')
if [ -n "$SW_VERSION" ]; then
  sed -i.bak \
    -e "s|_flutter.loader.load({|_flutter.loader.load({\n  config: {\n    canvasKitBaseUrl: '/canvaskit'\n  },|" \
    -e "s|serviceWorkerSettings: {[^}]*}|serviceWorkerSettings: null|" \
    "$BOOTSTRAP"
  rm -f "$BOOTSTRAP.bak"
  echo "Patched $BOOTSTRAP (service worker disabled, local CanvasKit, version: $SW_VERSION)."
else
  echo "WARNING: Could not find serviceWorkerVersion in $BOOTSTRAP"
fi

echo "Build complete. Run: firebase deploy --only hosting"
