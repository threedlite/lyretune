# Release Guide for LyreTune Android App

## Prerequisites

1. **Create a keystore** (only needed once):
   ```bash
   keytool -genkey -v -keystore keystore/release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lyretune
   ```

2. **Configure signing**:
   - Copy `keystore.properties.template` to `keystore.properties`
   - Fill in your keystore details:
     - `storePassword`: Your keystore password
     - `keyPassword`: Your key password
     - `keyAlias`: Your key alias (e.g., "lyretune")
     - `storeFile`: Path to keystore (default: ../keystore/release-keystore.jks)

## Building for Release

1. **Build the AAB**:
   ```bash
   ./build-release.sh
   ```

   This will create: `app/build/outputs/bundle/release/app-release.aab`

2. **Test the AAB locally** (optional):
   ```bash
   # Download bundletool from https://github.com/google/bundletool/releases
   java -jar bundletool.jar build-apks --bundle=app/build/outputs/bundle/release/app-release.aab --output=app-release.apks --mode=universal
   unzip app-release.apks
   adb install universal.apk
   ```

## Google Play Store Checklist

### Before First Upload
- [ ] Create Google Play Developer account ($25 one-time fee)
- [ ] Create app in Google Play Console
- [ ] Complete app information form
- [ ] Upload app icon (512x512 PNG)
- [ ] Upload feature graphic (1024x500 PNG)
- [ ] Add screenshots (min 2, recommended 8)
- [ ] Write short description (80 chars max)
- [ ] Write full description (4000 chars max)

### For Each Release
- [ ] Update versionCode and versionName in build.gradle
- [ ] Build AAB using `./build-release.sh`
- [ ] Upload AAB to Production or Testing track
- [ ] Write release notes
- [ ] Complete content rating questionnaire
- [ ] Set pricing and distribution
- [ ] Review and publish

## Version Management

Current version: 1.0.1 (versionCode: 2)

Version codes must always increase. Suggested scheme:
- Major releases: 1.0.0, 2.0.0, etc.
- Minor releases: 1.1.0, 1.2.0, etc.
- Patches: 1.0.1, 1.0.2, etc.

## Security Notes

- NEVER commit `keystore.properties` or keystore files to version control
- Keep keystore backups in a secure location
- Use strong passwords for keystore and key
- The same keystore must be used for all future updates