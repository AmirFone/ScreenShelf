#!/bin/bash
set -euo pipefail

APP_NAME="ScreenShelf"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$PROJECT_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"

cd "$PROJECT_DIR"

echo "Building $APP_NAME (release)..."
swift build -c release 2>&1

BIN_DIR=$(swift build -c release --show-bin-path 2>/dev/null)

echo "Creating $APP_NAME.app bundle..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$BUNDLE/Contents/MacOS/"
cp "Sources/$APP_NAME/Info.plist" "$BUNDLE/Contents/"
cp "Sources/$APP_NAME/Icons/AppIcon.icns" "$BUNDLE/Contents/Resources/"

echo "Signing..."
codesign --force --deep --sign - "$BUNDLE"

echo "Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$BUNDLE" "$INSTALL_DIR/"

echo "$APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
