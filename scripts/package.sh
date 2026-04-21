#!/bin/bash
set -euo pipefail

APP_NAME="ScreenShelf"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$PROJECT_DIR/$APP_NAME.app"

cd "$PROJECT_DIR"

echo "Building $APP_NAME..."
swift build -c release 2>&1

BIN_DIR=$(swift build -c release --show-bin-path 2>/dev/null)

echo "Packaging $APP_NAME.app..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$BUNDLE/Contents/MacOS/"
cp "Sources/$APP_NAME/Info.plist" "$BUNDLE/Contents/"
cp "Sources/$APP_NAME/Icons/AppIcon.icns" "$BUNDLE/Contents/Resources/"

codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || true

echo "Done. Opening $APP_NAME.app..."
open "$BUNDLE"
