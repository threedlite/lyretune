# LyreTune Android App

This is the Android version of LyreTune, an ancient Greek lyre tuning application.

## Prerequisites

1. **Android Studio** (latest version)
2. **Android SDK** (API level 24+)
3. **Android NDK** (version 25+)
4. **Rust** with Android targets:
5. **cargo-ndk**:
   ```bash
   cargo install cargo-ndk
   ```

## Building the App

### Method 1: Using Android Studio
1. Update `local.properties` with your Android SDK path:
   ```
   sdk.dir=/path/to/your/Android/Sdk
   ```
2. Open the `android` folder in Android Studio
3. Sync the project with Gradle files
4. Build and run on your device or emulator

### Method 2: Command Line
1. Set environment variables:
   ```bash
   export ANDROID_HOME=/home/user/Android/Sdk
   export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.2.9519653
   ```

2. Build the APK:
   ```bash
   cd android
   ./gradlew assembleDebug
   ```

3. Install on device:
   ```bash
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

## Project Structure

- `app/` - Android app module (Kotlin + Jetpack Compose)
- `app/src/main/java/` - Kotlin source code
- `app/src/main/res/` - Android resources (icons, layouts, etc.)
- `app/src/main/jniLibs/` - Compiled native libraries (auto-generated)

## Features Implemented

- [x] Complete Android project structure
- [x] Microphone permission handling
- [x] Full UI with all tuning modes and scales
- [x] Visual frequency spectrum display
- [x] Green indicators when strings are in tune
- [x] Scale type selection (Modes, Genres, Pentatonic, etc.)
- [x] Mode/Genus selection based on scale type
- [x] Configurable string count (4-24 strings)
- [x] Multiple temperament options
- [x] Real-time frequency display
- [x] App icon from desktop version
- [x] ProGuard configuration

## Supported Features

### Scale Types
- Ancient Greek Modes (Mixolydios, Hypodorios, Lydios, etc.)
- Genres (Diatonic, Chromatic, Enharmonic)
- Pentatonic scales
- Double Harmonic scale
- Phorminx tuning (4-string)

### Temperaments
- Equal temperament
- Just intonation
- Just intonation (Ancient)
- Meantone temperament

### UI Features
- Real-time frequency detection
- Visual tuning indicators (green when in tune)
- Frequency spectrum visualization
- Adjustable string count (4-24)
- Per-string frequency display

## Development Notes

- The app uses Jetpack Compose for modern Android UI
- Minimum SDK is 24 (Android 7.0) for broad device support
- Target SDK is 34 (Android 14)

## Troubleshooting

### Build Issues
- Ensure NDK is properly installed through Android Studio SDK Manager
- Check that Rust targets are installed: `rustup target list --installed`
- Verify cargo-ndk installation: `cargo ndk --version`

### Runtime Issues
- Grant microphone permission when prompted
- Ensure device volume is not muted
- For best results, use in a quiet environment

## Performance

- Audio latency: < 20ms on most devices
- Sample rate: 48kHz
- Update rate: 20 Hz (50ms intervals)