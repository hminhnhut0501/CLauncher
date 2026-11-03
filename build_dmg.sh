#!/bin/bash
set -e

PROJECT_DIR="/Users/hminhnhut/.gemini/antigravity/scratch/TahoeLaunchpad"
APP_PATH="$PROJECT_DIR/Launchpad.app"
VOLUME_NAME="Launchpad"
DMG_NAME="Launchpad-2.0.0.dmg"
FINAL_DMG="$PROJECT_DIR/$DMG_NAME"
TEMP_DMG="/tmp/launchpad_temp.dmg"
STAGING_DIR="/tmp/launchpad_dmg_staging"

echo "💿 Packaging Launchpad into DMG..."

# 1. Clean previous artifacts
rm -rf "$STAGING_DIR" "$TEMP_DMG" "$FINAL_DMG"
mkdir -p "$STAGING_DIR"

# 2. Copy App and create Applications link
echo "📦 Copying Launchpad.app and creating /Applications symlink..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Create temporary writable DMG
echo "🛠️ Creating temporary DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TEMP_DMG"

# 4. Mount temporary DMG
echo "📂 Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | awk 'NR==1{print $1}')
sleep 1

# 5. Set Finder presentation properties via AppleScript
echo "🎨 Styling DMG window and icon positions..."
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 960, 560}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 128
        set arrangement of viewOptions to not arranged
        set position of item "Launchpad.app" of container window to {150, 180}
        set position of item "Applications" of container window to {410, 180}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

# 6. Unmount
echo "🔒 Unmounting temporary DMG..."
hdiutil detach "$DEVICE" || hdiutil detach "$DEVICE" -force
sleep 1

# 7. Convert to final read-only compressed DMG (UDZO)
echo "🗜️ Compressing to final DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

# 8. Clean temporary files
rm -rf "$STAGING_DIR" "$TEMP_DMG"

echo "✅ Successfully exported DMG at: $FINAL_DMG"
ls -lh "$FINAL_DMG"
