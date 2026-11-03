#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Building Launchpad (Release)..."
swift build -c release

APP_NAME="TahoeLaunchpad"
OUTPUT_APP_NAME="Launchpad"
APP_BUNDLE="$DIR/$OUTPUT_APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "📦 Creating macOS App Bundle ($OUTPUT_APP_NAME.app)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp ".build/release/$APP_NAME" "$MACOS/$OUTPUT_APP_NAME"
cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"

cat <<EOF > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$OUTPUT_APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.gemini.TahoeLaunchpad</string>
    <key>CFBundleName</key>
    <string>Launchpad</string>
    <key>CFBundleDisplayName</key>
    <string>Launchpad</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    <key>CADisableMinimumFrameDuration</key>
    <true/>
</dict>
</plist>
EOF

# Refresh icon cache for the bundle
touch "$APP_BUNDLE"

echo "✅ App bundle created successfully at: $APP_BUNDLE"
