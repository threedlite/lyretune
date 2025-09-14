#!/bin/bash

echo "Building LyreTune for iOS Simulator..."

# Clean up previous builds
rm -rf SimpleLyreTune.app

# Create app bundle structure
mkdir -p SimpleLyreTune.app

# Compile the Swift app for simulator (both architectures)
echo "Compiling for x86_64..."
xcrun -sdk iphonesimulator swiftc \
    -target x86_64-apple-ios14.0-simulator \
    -parse-as-library \
    LyreTuneApp.swift \
    -o SimpleLyreTune.app/SimpleLyreTune-x86_64

echo "Compiling for arm64..."
xcrun -sdk iphonesimulator swiftc \
    -target arm64-apple-ios14.0-simulator \
    -parse-as-library \
    LyreTuneApp.swift \
    -o SimpleLyreTune.app/SimpleLyreTune-arm64

# Create universal binary
echo "Creating universal binary..."
lipo -create \
    SimpleLyreTune.app/SimpleLyreTune-x86_64 \
    SimpleLyreTune.app/SimpleLyreTune-arm64 \
    -output SimpleLyreTune.app/SimpleLyreTune

# Clean up architecture-specific binaries
rm SimpleLyreTune.app/SimpleLyreTune-x86_64
rm SimpleLyreTune.app/SimpleLyreTune-arm64

# Create Info.plist
cat > SimpleLyreTune.app/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SimpleLyreTune</string>
    <key>CFBundleIdentifier</key>
    <string>com.lyretuner.simple</string>
    <key>CFBundleName</key>
    <string>LyreTune</string>
    <key>CFBundleDisplayName</key>
    <string>LyreTune</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneSimulator</string>
    </array>
    <key>DTPlatformName</key>
    <string>iphonesimulator</string>
    <key>DTSDKName</key>
    <string>iphonesimulator</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>LyreTune needs microphone access for tuning</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UIFileSharingEnabled</key>
    <false/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <false/>
    <key>UISupportsDocumentBrowser</key>
    <false/>
</dict>
</plist>
EOF

# Create _CodeSignature directory for ad-hoc signing
mkdir -p SimpleLyreTune.app/_CodeSignature

# Create a minimal CodeResources file
cat > SimpleLyreTune.app/_CodeSignature/CodeResources << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>files</key>
    <dict/>
    <key>files2</key>
    <dict/>
    <key>rules</key>
    <dict/>
    <key>rules2</key>
    <dict/>
</dict>
</plist>
EOF

echo "Build complete!"
echo "Installing to simulator..."

# Get simulator ID
DEVICE_ID="93B0574C-3ED9-47BA-9290-635452C29A19"

# Boot simulator if needed
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

# Uninstall previous version if exists
xcrun simctl uninstall "$DEVICE_ID" com.lyretuner.simple 2>/dev/null || true

# Install the app
xcrun simctl install "$DEVICE_ID" SimpleLyreTune.app

echo "Launching app..."
# Launch the app
xcrun simctl launch "$DEVICE_ID" com.lyretuner.simple

echo "✅ App deployed and launched in simulator!"