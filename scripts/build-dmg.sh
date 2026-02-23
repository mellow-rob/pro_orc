#!/bin/bash
set -euo pipefail

# Build Flutter macOS app and package as DMG
# Prerequisites: brew install create-dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$ROOT_DIR/pro_orc"
DIST_DIR="$ROOT_DIR/dist"
ICON_SRC="$ROOT_DIR/img/dmg_icon.png"
APPICONSET="$APP_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset"

VERSION=$(grep 'version:' "$APP_DIR/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d'+' -f1)
DMG_NAME="ProOrc-${VERSION}-macOS.dmg"

# Helper: generate full .icns from a PNG source
make_icns() {
  local src="$1" out="$2"
  local iconset_dir
  iconset_dir=$(mktemp -d)/icon.iconset
  mkdir -p "$iconset_dir"
  sips -z 16 16     "$src" --out "$iconset_dir/icon_16x16.png" > /dev/null
  sips -z 32 32     "$src" --out "$iconset_dir/icon_16x16@2x.png" > /dev/null
  sips -z 32 32     "$src" --out "$iconset_dir/icon_32x32.png" > /dev/null
  sips -z 64 64     "$src" --out "$iconset_dir/icon_32x32@2x.png" > /dev/null
  sips -z 128 128   "$src" --out "$iconset_dir/icon_128x128.png" > /dev/null
  sips -z 256 256   "$src" --out "$iconset_dir/icon_128x128@2x.png" > /dev/null
  sips -z 256 256   "$src" --out "$iconset_dir/icon_256x256.png" > /dev/null
  sips -z 512 512   "$src" --out "$iconset_dir/icon_256x256@2x.png" > /dev/null
  sips -z 512 512   "$src" --out "$iconset_dir/icon_512x512.png" > /dev/null
  sips -z 1024 1024 "$src" --out "$iconset_dir/icon_512x512@2x.png" > /dev/null
  iconutil -c icns "$iconset_dir" -o "$out"
}

echo "==> Building Pro Orc v${VERSION}..."

# Replace Xcode asset catalog icons BEFORE build so Assets.car gets the right icon
echo "==> Replacing Xcode AppIcon assets with icon_dmg.png..."
sips -z 16 16     "$ICON_SRC" --out "$APPICONSET/app_icon_16.png" > /dev/null
sips -z 32 32     "$ICON_SRC" --out "$APPICONSET/app_icon_32.png" > /dev/null
sips -z 64 64     "$ICON_SRC" --out "$APPICONSET/app_icon_64.png" > /dev/null
sips -z 128 128   "$ICON_SRC" --out "$APPICONSET/app_icon_128.png" > /dev/null
sips -z 256 256   "$ICON_SRC" --out "$APPICONSET/app_icon_256.png" > /dev/null
sips -z 512 512   "$ICON_SRC" --out "$APPICONSET/app_icon_512.png" > /dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$APPICONSET/app_icon_1024.png" > /dev/null

# Build release (now compiles Assets.car with new icon)
cd "$APP_DIR"
flutter build macos --release

# Convert icon PNG to icns for DMG volume icon
echo "==> Converting volume icon..."
make_icns "$ICON_SRC" "$ROOT_DIR/img/icon_dmg.icns"

# Ad-hoc sign
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
  --volicon "$ROOT_DIR/img/icon_dmg.icns" \
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
