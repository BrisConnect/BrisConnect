#!/bin/bash
set -e

echo "Building BrisConnect web release..."
flutter build web --release

# Ensure the source index.html (with legal fallback, viewport meta, etc.) is used.
cp web/index.html build/web/index.html

# Self-host CanvasKit from /canvaskit so Safari/iOS doesn't block it due to
# ITP/cross-origin restrictions when loaded from gstatic.com.
BOOTSTRAP="build/web/flutter_bootstrap.js"
SW_VERSION=$(grep -o 'serviceWorkerVersion: "[0-9]*"' "$BOOTSTRAP" | head -1 | grep -o '[0-9]*')
if [ -n "$SW_VERSION" ]; then
  sed -i.bak "s|_flutter.loader.load({|_flutter.loader.load({\n  config: {\n    canvasKitBaseUrl: '/canvaskit'\n  },|" "$BOOTSTRAP"
  rm -f "$BOOTSTRAP.bak"
  echo "Patched $BOOTSTRAP to use local CanvasKit (service worker version: $SW_VERSION)."
else
  echo "WARNING: Could not find serviceWorkerVersion in $BOOTSTRAP"
fi

echo "Build complete. Run: firebase deploy --only hosting"
