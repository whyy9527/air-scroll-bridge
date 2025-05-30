#!/bin/bash

# AirScrollBridge - Code Signing and Notarization Script
# This script builds, signs, and notarizes the macOS application

set -e

# Configuration
APP_NAME="AirScrollBridge"
BUNDLE_ID="com.example.airscrollbridge"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS_FILE="$APP_NAME.entitlements"

# Developer credentials (set these as environment variables)
DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARIZATION_APPLE_ID="${NOTARIZATION_APPLE_ID:-}"
NOTARIZATION_PASSWORD="${NOTARIZATION_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"

echo "🚀 Building and signing $APP_NAME..."

# Check if developer credentials are set
if [[ -z "$DEVELOPER_ID" || -z "$NOTARIZATION_APPLE_ID" || -z "$NOTARIZATION_PASSWORD" || -z "$TEAM_ID" ]]; then
    echo "⚠️  Warning: Developer credentials not set. Skipping code signing and notarization."
    echo "   To enable signing, set the following environment variables:"
    echo "   - DEVELOPER_ID: Your Developer ID Application certificate name"
    echo "   - NOTARIZATION_APPLE_ID: Your Apple ID for notarization"
    echo "   - NOTARIZATION_PASSWORD: App-specific password for notarization"
    echo "   - TEAM_ID: Your Apple Developer Team ID"
    echo ""
    echo "   Building unsigned binary only..."
    
    # Build the release binary
    swift build --configuration release
    
    echo "✅ Unsigned binary built successfully at $BUILD_DIR/$APP_NAME"
    exit 0
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the release binary
echo "🔨 Building release binary..."
swift build --configuration release

# Create app bundle structure
echo "📦 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
echo "📄 Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>AirScrollBridge</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>NSMotionUsageDescription</key>
    <string>AirScrollBridge needs access to headphone motion data to provide scroll gestures.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create entitlements file
echo "🔐 Creating entitlements file..."
cat > "$ENTITLEMENTS_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <false/>
    <key>com.apple.security.device.microphone</key>
    <false/>
    <key>com.apple.security.device.usb</key>
    <false/>
    <key>com.apple.security.personal-information.location</key>
    <false/>
    <key>com.apple.security.assets.movies.read-only</key>
    <false/>
    <key>com.apple.security.assets.music.read-only</key>
    <false/>
    <key>com.apple.security.assets.pictures.read-only</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <false/>
    <key>com.apple.security.files.downloads.read-write</key>
    <false/>
</dict>
</plist>
EOF

# Sign the app bundle
echo "✍️  Signing app bundle..."
codesign --force --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign "$DEVELOPER_ID" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
codesign --force --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign "$DEVELOPER_ID" "$APP_BUNDLE"

# Verify signature
echo "🔍 Verifying signature..."
codesign --verify --verbose "$APP_BUNDLE"
spctl --assess --verbose "$APP_BUNDLE"

# Create a zip archive for notarization
echo "📦 Creating archive for notarization..."
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.zip"
cd "$BUILD_DIR"
zip -r "$APP_NAME.zip" "$APP_NAME.app"
cd ..

# Submit for notarization
echo "🏃 Submitting for notarization..."
SUBMISSION_ID=$(xcrun notarytool submit "$ARCHIVE_PATH" \
    --apple-id "$NOTARIZATION_APPLE_ID" \
    --password "$NOTARIZATION_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait \
    --output-format json | jq -r '.id')

if [ -z "$SUBMISSION_ID" ] || [ "$SUBMISSION_ID" = "null" ]; then
    echo "❌ Failed to submit for notarization"
    exit 1
fi

echo "📋 Submission ID: $SUBMISSION_ID"

# Check notarization status
echo "⏳ Waiting for notarization to complete..."
xcrun notarytool wait "$SUBMISSION_ID" \
    --apple-id "$NOTARIZATION_APPLE_ID" \
    --password "$NOTARIZATION_PASSWORD" \
    --team-id "$TEAM_ID"

# Get notarization info
echo "📊 Getting notarization info..."
xcrun notarytool info "$SUBMISSION_ID" \
    --apple-id "$NOTARIZATION_APPLE_ID" \
    --password "$NOTARIZATION_PASSWORD" \
    --team-id "$TEAM_ID"

# Staple the notarization
echo "📎 Stapling notarization..."
xcrun stapler staple "$APP_BUNDLE"

# Verify stapling
echo "🔍 Verifying stapling..."
xcrun stapler validate "$APP_BUNDLE"

# Clean up
rm -f "$ENTITLEMENTS_FILE"

echo "✅ Successfully built, signed, and notarized $APP_NAME!"
echo "📍 Location: $APP_BUNDLE"
echo ""
echo "🚀 You can now distribute this application or create a DMG using:"
echo "   ./scripts/make_dmg.sh"
