#!/bin/bash
set -euo pipefail

APP_NAME="ScreenShelf"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_DIR="$PROJECT_DIR/dist"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"
STAGING="$PROJECT_DIR/.dmg-staging"

cd "$PROJECT_DIR"

# Build if needed
if [ ! -d "$BUNDLE" ]; then
    echo "Building $APP_NAME first..."
    ./scripts/package.sh
fi

echo "Creating DMG..."
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING" "$DMG_DIR"

cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" 2>&1

rm -rf "$STAGING"

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
