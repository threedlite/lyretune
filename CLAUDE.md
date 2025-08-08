# LyreTune Build Instructions

## Prerequisites
- Android Studio
- Android SDK
- JDK 17 or higher
- ADB (Android Debug Bridge)

## Local WiFi Debug Build

### 1. Enable Developer Options on Android Device
- Go to Settings > About Phone
- Tap "Build Number" 7 times
- Go back to Settings > Developer Options
- Enable "USB Debugging"
- Enable "Wireless Debugging" (Android 11+)

### 2. Connect Device via WiFi
```bash
# First connect device via USB
adb devices

# Get device IP address
adb shell ip addr show wlan0

# Enable TCP/IP mode on port 5555
adb tcpip 5555

# Disconnect USB and connect via WiFi
adb connect <device-ip>:5555

# Verify connection
adb devices
```

### 3. Build and Install Debug APK
```bash
# Clean previous builds
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Install on connected device
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Or build and install in one command
./gradlew installDebug
```

### 4. Run and Debug
```bash
# View logs
adb logcat | grep -i lyretune

# Launch app
adb shell am start -n com.example.lyretune/.MainActivity
```

## Play Store Release Build

### 1. Generate Signing Key (First Time Only)
```bash
keytool -genkey -v -keystore lyretune-release.keystore -alias lyretune -keyalg RSA -keysize 2048 -validity 10000
```

### 2. Configure Signing in app/build.gradle
```gradle
android {
    signingConfigs {
        release {
            storeFile file('../lyretune-release.keystore')
            storePassword 'your-store-password'
            keyAlias 'lyretune'
            keyPassword 'your-key-password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 3. Build Release APK
```bash
# Clean build directory
./gradlew clean

# Build release APK
./gradlew assembleRelease

# Output location: app/build/outputs/apk/release/app-release.apk
```

### 4. Build App Bundle for Play Store
```bash
# Build AAB (Android App Bundle)
./gradlew bundleRelease

# Output location: app/build/outputs/bundle/release/app-release.aab
```

### 5. Test Release Build
```bash
# Install release APK for testing
adb install -r app/build/outputs/apk/release/app-release.apk

# Or use bundletool to test AAB
java -jar bundletool.jar build-apks --bundle=app/build/outputs/bundle/release/app-release.aab --output=test.apks --mode=universal
java -jar bundletool.jar install-apks --apks=test.apks
```

## Useful Commands

```bash
# Check build variants
./gradlew tasks

# Run lint checks
./gradlew lint

# Run tests
./gradlew test

# Check dependencies
./gradlew dependencies

# Build both debug and release
./gradlew assemble
```

## Troubleshooting

### WiFi Connection Issues
- Ensure device and computer are on same network
- Check firewall settings
- Try restarting ADB: `adb kill-server && adb start-server`

### Build Issues
- Clear Gradle cache: `./gradlew clean build --refresh-dependencies`
- Invalidate caches in Android Studio: File > Invalidate Caches
- Check SDK version compatibility in build.gradle

### Signing Issues
- Keep keystore file secure and backed up
- Never commit keystore or passwords to version control
- Use gradle.properties or environment variables for sensitive data