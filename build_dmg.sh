#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PaglaMLX"
RELEASE_BIN="$PROJECT_DIR/.build/release/$APP_NAME"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_FILE="$PROJECT_DIR/$APP_NAME.dmg"

echo "=== Building $APP_NAME (release) ==="
swift build -c release --product "$APP_NAME"

echo "=== Creating .app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/PaglaMLX-Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "=== Signing bundle ==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "=== Creating .dmg ==="
rm -f "$DMG_FILE"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_FILE"

echo "=== Done ==="
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_FILE"
echo ""
echo "To open in Xcode: open $PROJECT_DIR/Package.swift"
