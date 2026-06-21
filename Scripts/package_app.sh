#!/usr/bin/env bash
# Assemble a menu-bar .app bundle from the SwiftPM build product.
# Usage: ./Scripts/package_app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="Aurora"
BUNDLE_ID="com.evgenypopov.aurora"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$ROOT/.build/$CONFIG/AuroraApp"
DIST="$ROOT/dist/$APP_NAME.app"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "✗ Build product not found at $BIN_PATH" >&2
  exit 1
fi

echo "▸ Packaging $APP_NAME.app…"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN_PATH" "$DIST/Contents/MacOS/$APP_NAME"
sed "s/__BUNDLE_ID__/$BUNDLE_ID/g" "$ROOT/Scripts/Info.plist.template" > "$DIST/Contents/Info.plist"

# Ad-hoc sign so TCC (screen/mic) permissions can attach to a stable identity.
codesign --force --deep --sign - "$DIST" 2>/dev/null || \
  echo "  (codesign skipped — install full Xcode/codesign for signed builds)"

echo "✓ Built $DIST"
echo "  Run with: open \"$DIST\""

# Optional: install into /Applications for a stable location + TCC identity.
#   ./Scripts/package_app.sh release install
if [[ "${2:-}" == "install" ]]; then
  APPS="/Applications/$APP_NAME.app"
  echo "▸ Installing to $APPS…"
  rm -rf "$APPS"
  cp -R "$DIST" "$APPS"
  codesign --force --deep --sign - "$APPS" 2>/dev/null || true
  echo "✓ Installed $APPS"
fi
