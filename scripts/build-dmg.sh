#!/bin/bash
set -euo pipefail

# Build Flutter macOS app and package as DMG
# Prerequisites: brew install create-dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$ROOT_DIR/pro_orc"
DIST_DIR="$ROOT_DIR/dist"

VERSION=$(grep 'version:' "$APP_DIR/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d'+' -f1)
DMG_NAME="ProOrc-${VERSION}-macOS.dmg"

echo "==> Building Pro Orc v${VERSION}..."

# Build release
cd "$APP_DIR"
flutter build macos --release

# Ad-hoc sign (no Apple Developer Account)
echo "==> Ad-hoc signing..."
codesign --deep --force -s - "build/macos/Build/Products/Release/pro_orc.app"

# Create dist directory
mkdir -p "$DIST_DIR"

# Remove old DMG if exists
rm -f "$DIST_DIR/$DMG_NAME"

# Create DMG with drag-to-Applications layout
echo "==> Creating DMG..."
create-dmg \
  --volname "Pro Orc" \
  --volicon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "pro_orc.app" 175 190 \
  --app-drop-link 425 190 \
  --hide-extension "pro_orc.app" \
  "$DIST_DIR/$DMG_NAME" \
  "build/macos/Build/Products/Release/pro_orc.app"

echo "==> Done: dist/$DMG_NAME"
echo ""
echo "To create a GitHub release:"
echo "  gh release create v${VERSION} dist/${DMG_NAME} --title \"Pro Orc v${VERSION}\" --generate-notes"
