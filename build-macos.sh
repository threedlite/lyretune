#!/bin/bash

# Build script for macOS
set -e

APP_NAME="LyreTune"
BUNDLE_ID="com.lyretune.app"
VERSION="0.1.0"

echo "Building ${APP_NAME} for macOS..."

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Rust is not installed. Please install it from https://rustup.rs/"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf target/release
rm -rf target/universal
rm -rf "${APP_NAME}.app"
rm -f "${APP_NAME}.dmg"

# Build for native architecture
echo "Building for native architecture..."
cargo build --release

# Create universal binary directory
mkdir -p target/universal

# Copy binary to universal directory (for now just native arch)
cp target/release/lyretune target/universal/lyretune

# Create macOS app bundle
echo "Creating app bundle..."
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy binary
cp target/universal/lyretune "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Make binary executable
chmod +x "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Create Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>LyreTune needs access to your microphone for audio input.</string>
</dict>
</plist>
EOF

# Copy the actual icon
echo "Adding lyre icon..."
cp icon.icns "${APP_NAME}.app/Contents/Resources/icon.icns"

echo "App bundle created successfully!"

# Create DMG
echo "Creating DMG..."

# Create a temporary directory for DMG contents
DMG_DIR="dmg_temp"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
cp -r "${APP_NAME}.app" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "${APP_NAME}.dmg"

# Clean up
rm -rf "$DMG_DIR"

echo ""
echo "Build complete!"
echo "App bundle: ${APP_NAME}.app"
echo "DMG file: ${APP_NAME}.dmg"
echo ""
echo "To install: Open ${APP_NAME}.dmg and drag ${APP_NAME} to Applications folder"