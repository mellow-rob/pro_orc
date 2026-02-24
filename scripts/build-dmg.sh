#!/bin/bash
set -euo pipefail

# Build Flutter macOS app and package as DMG
# Prerequisites: brew install create-dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$ROOT_DIR/pro_orc"
DIST_DIR="$ROOT_DIR/dist"
ICON_SRC="$ROOT_DIR/img/icon.icns"
ICON_PNG="$ROOT_DIR/img/dmg_icon.png"
APPICONSET="$APP_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset"

VERSION=$(grep 'version:' "$APP_DIR/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d'+' -f1)
DMG_NAME="ProOrc-${VERSION}-macOS.dmg"


echo "==> Building Pro Orc v${VERSION}..."

# Extract PNGs from icns and replace Xcode asset catalog icons BEFORE build
echo "==> Replacing Xcode AppIcon assets from icon.icns..."
ICONSET_TMP=$(mktemp -d)/icon.iconset
iconutil -c iconset -o "$ICONSET_TMP" "$ICON_SRC"
cp "$ICONSET_TMP/icon_16x16.png"      "$APPICONSET/app_icon_16.png"
cp "$ICONSET_TMP/icon_32x32.png"      "$APPICONSET/app_icon_32.png"
cp "$ICONSET_TMP/icon_32x32@2x.png"   "$APPICONSET/app_icon_64.png"
cp "$ICONSET_TMP/icon_128x128.png"    "$APPICONSET/app_icon_128.png"
cp "$ICONSET_TMP/icon_256x256.png"    "$APPICONSET/app_icon_256.png"
cp "$ICONSET_TMP/icon_512x512.png"    "$APPICONSET/app_icon_512.png"
cp "$ICONSET_TMP/icon_512x512@2x.png" "$APPICONSET/app_icon_1024.png"

# Build release (now compiles Assets.car with new icon)
cd "$APP_DIR"
flutter build macos --release

# Replace Xcode-generated icns with full-quality original for Finder display
echo "==> Replacing AppIcon.icns with full-quality icon.icns..."
cp "$ICON_SRC" "build/macos/Build/Products/Release/pro_orc.app/Contents/Resources/AppIcon.icns"

# Ad-hoc sign (after icon replacement)
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
  --volicon "$ICON_SRC" \
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
