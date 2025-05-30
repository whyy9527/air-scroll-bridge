#!/bin/bash

# AirScrollBridge - DMG Creation Script
# This script creates a distributable DMG file for the macOS application

set -e

# Configuration
APP_NAME="AirScrollBridge"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
TEMP_DMG="$BUILD_DIR/temp_$APP_NAME.dmg"
FINAL_DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "📦 Creating DMG for $APP_NAME v$VERSION..."

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    echo "   Please run ./scripts/sign_and_notarize.sh first"
    exit 1
fi

# Clean previous DMG builds
echo "🧹 Cleaning previous DMG builds..."
rm -rf "$DMG_DIR"
rm -f "$TEMP_DMG"
rm -f "$FINAL_DMG"

# Create DMG staging directory
echo "📁 Creating DMG staging directory..."
mkdir -p "$DMG_DIR"

# Copy app bundle to staging directory
echo "📋 Copying app bundle..."
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create symbolic link to Applications folder
echo "🔗 Creating Applications folder link..."
ln -s /Applications "$DMG_DIR/Applications"

# Create a background image (using built-in system images)
echo "🎨 Creating DMG background..."
DMG_BACKGROUND="$DMG_DIR/.background"
mkdir -p "$DMG_BACKGROUND"

# Create a simple text-based background message
cat > "$DMG_DIR/.DS_Store_template" << 'EOF'
# This file helps set up the DMG appearance
# The actual .DS_Store will be created by the system
EOF

# Create README for the DMG
echo "📝 Creating README..."
cat > "$DMG_DIR/README.txt" << 'EOF'
AirScrollBridge v1.0.0

Installation Instructions:
1. Drag AirScrollBridge.app to the Applications folder
2. Launch AirScrollBridge from Applications
3. Grant motion permissions when prompted
4. Connect your AirPods and start using head gestures!

Requirements:
- macOS 14.0 or later
- AirPods (3rd generation) or AirPods Pro

Support:
For issues and documentation, visit: 
https://github.com/yourusername/air-scroll-bridge

Copyright © 2025. All rights reserved.
EOF

# Calculate DMG size (app size + padding)
echo "📏 Calculating DMG size..."
APP_SIZE=$(du -sm "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))  # Add 50MB padding

echo "   App size: ${APP_SIZE}MB"
echo "   DMG size: ${DMG_SIZE}MB"

# Create temporary DMG
echo "💿 Creating temporary DMG..."
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}m" \
    "$TEMP_DMG"

# Mount the temporary DMG
echo "🔧 Mounting temporary DMG for customization..."
MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach "$TEMP_DMG" -noautoopen -quiet

# Wait for mount
sleep 2

# Customize DMG appearance using AppleScript
echo "🎨 Customizing DMG appearance..."
cat > "$BUILD_DIR/dmg_setup.applescript" << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position items
        set position of item "$APP_NAME.app" of container window to {150, 150}
        set position of item "Applications" of container window to {350, 150}
        
        -- Hide README and background folder
        set position of item "README.txt" of container window to {150, 250}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Run AppleScript to customize appearance
osascript "$BUILD_DIR/dmg_setup.applescript" || echo "⚠️  Could not customize DMG appearance (continuing anyway)"

# Unmount the temporary DMG
echo "📤 Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR" -quiet || true

# Wait for unmount
sleep 2

# Convert to final compressed DMG
echo "🗜️ Creating final compressed DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG"

# Clean up temporary files
echo "🧹 Cleaning up..."
rm -f "$TEMP_DMG"
rm -f "$BUILD_DIR/dmg_setup.applescript"
rm -rf "$DMG_DIR"

# Verify the final DMG
echo "🔍 Verifying final DMG..."
hdiutil verify "$FINAL_DMG"

# Get file size
FINAL_SIZE=$(du -h "$FINAL_DMG" | cut -f1)

echo "✅ Successfully created DMG!"
echo "📍 Location: $FINAL_DMG"
echo "📊 Size: $FINAL_SIZE"
echo ""
echo "🚀 The DMG is ready for distribution!"
echo ""
echo "💡 Tips:"
echo "   - Test the DMG by mounting it and dragging the app to Applications"
echo "   - Upload to your distribution platform or website"
echo "   - Consider creating a checksum: shasum -a 256 '$FINAL_DMG'"
