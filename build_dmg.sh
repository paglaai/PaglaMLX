#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PaglaMLX"
RELEASE_BIN="$PROJECT_DIR/.build/release/$APP_NAME"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_FILE="$PROJECT_DIR/$APP_NAME.dmg"
STAGING_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$STAGING_DIR" "$APP_BUNDLE"
}
trap cleanup EXIT

echo "=== Building $APP_NAME (release) ==="
swift build -c release --product "$APP_NAME"

echo "=== Creating .app bundle ==="
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/PaglaMLX-Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "=== Signing bundle ==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "=== Staging DMG contents ==="
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "=== Creating .dmg ==="
rm -f "$DMG_FILE"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    -noanyowners \
    "$DMG_FILE"

echo "=== Done ==="
echo "  DMG:  $DMG_FILE"
