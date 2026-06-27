#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="VoxBox"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="build/dmg_staging"

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[DMG]${NC} $1"; }

log "Building Release configuration…"
xcodebuild -project VoxBox.xcodeproj -scheme VoxBox -configuration Release -derivedDataPath build build

APP_PATH=$(find build -name "VoxBox.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "❌ Could not find built .app bundle"
    exit 1
fi
log "✅ App built: $APP_PATH"

log "Preparing DMG staging…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

log "Creating DMG: $DMG_NAME"
if command -v create-dmg &>/dev/null; then
    create-dmg --volname "${APP_NAME} ${VERSION}" \
        --window-pos 200 120 --window-size 600 400 --icon-size 100 \
        --icon "${APP_NAME}.app" 150 190 --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 185 "$DMG_NAME" "$STAGING_DIR"
else
    log "create-dmg not found, using hdiutil…"
    hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
fi

rm -rf "$STAGING_DIR"
log "✅ DMG created: $DMG_NAME"
log "📦 Size: $(du -sh "$DMG_NAME" | awk '{print $1}')"
log "Next: xcrun notarytool submit $DMG_NAME --apple-id your@email.com --wait"
