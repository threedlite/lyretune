#!/bin/bash

# Build release AAB for Google Play Store

echo "Building release AAB for LyreTune..."

# Check if keystore.properties exists
if [ ! -f "keystore.properties" ]; then
    echo "Error: keystore.properties not found!"
    echo "Please create keystore.properties from keystore.properties.template"
    echo "and generate a keystore using:"
    echo "  keytool -genkey -v -keystore keystore/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your-alias"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
./gradlew clean

# Build release AAB
echo "Building release AAB..."
./gradlew bundleRelease

if [ $? -eq 0 ]; then
    echo ""
    echo "Build successful!"
    echo "AAB file location: app/build/outputs/bundle/release/app-release.aab"
    echo ""
    echo "To test the AAB locally, use bundletool:"
    echo "  java -jar bundletool.jar build-apks --bundle=app/build/outputs/bundle/release/app-release.aab --output=app-release.apks"
    echo ""
    echo "Next steps for Google Play Store:"
    echo "1. Upload the AAB file to Google Play Console"
    echo "2. Fill in store listing details"
    echo "3. Set up pricing and distribution"
    echo "4. Complete content rating questionnaire"
    echo "5. Review and publish"
else
    echo "Build failed!"
    exit 1
fi