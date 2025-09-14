# iOS LyreTune Project Plan

## Project Overview
Port the Android LyreTune app to iOS, maintaining feature parity while following iOS design guidelines and best practices.

## Core Features (Based on Android Analysis)

### 1. Audio Processing
- **Real-time microphone input** using AVAudioEngine
- **FFT analysis** using Accelerate framework (vDSP)
- **Sample rate**: 48000 Hz
- **FFT size**: (configurable)
- **High-pass filter**: 150 Hz default (configurable)
- **Noise gate**: 2% threshold (configurable)

### 2. Tuning Modes Support
- **Ancient Greek Modes**: Mixolydios, Hypodorios, Lydios, Phrygios, Dorios, Hypolydios, Hypophrygios
- **Ancient Greek Genres**: Diatonic, Chromatic, Enharmonic
- **Additional Scales**: Pentatonic, Double Harmonic, Phorminx
- **Temperaments**: Equal, Just, Just Ancient, Meantone

### 3. UI Components
- **Main tuning view** with spectrum visualizer
- **Settings screen** for configuration
- **Transposition tool** for key changes
- **String selector** (7-24 strings)
- **Note indicators** with green highlighting when in tune
- **Frequency spectrum display** with real-time updates

### 4. App Features
- **Settings persistence** using UserDefaults
- **Microphone permissions** handling
- **Background audio** support
- **Multiple color themes**
- **Profiles** for saving tuning configurations

## Technical Architecture

### Project Structure
```
ios/
├── LyreTune/
│   ├── LyreTune.xcodeproj
│   ├── LyreTune/
│   │   ├── App/
│   │   │   ├── LyreTuneApp.swift
│   │   │   └── Info.plist
│   │   ├── Views/
│   │   │   ├── MainView.swift
│   │   │   ├── SettingsView.swift
│   │   │   └── TranspositionView.swift
│   │   ├── Components/
│   │   │   ├── SpectrumVisualizer.swift
│   │   │   ├── NoteIndicator.swift
│   │   │   └── StringSelector.swift
│   │   ├── Audio/
│   │   │   ├── AudioProcessor.swift
│   │   │   ├── FFTAnalyzer.swift
│   │   │   └── ScaleCalculator.swift
│   │   ├── Models/
│   │   │   ├── ScaleType.swift
│   │   │   ├── Mode.swift
│   │   │   ├── Genus.swift
│   │   │   └── Temperament.swift
│   │   ├── Utilities/
│   │   │   └── FrequencyUtilities.swift
│   │   └── Resources/
│   │       └── Assets.xcassets
│   └── LyreTuneTests/
│       ├── AudioProcessorTests.swift
│       └── ScaleCalculatorTests.swift
└── README.md
```

### Key Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with iOS 18 features
- **Audio**: AVAudioEngine, AVAudioSession
- **DSP**: Accelerate framework (vDSP for FFT)
- **Data Storage**: UserDefaults, @AppStorage, SwiftData
- **Minimum iOS**: 18.0 (iPhone 16 optimized)
- **Target Devices**: iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max

## Implementation Phases

### Phase 1: Project Setup (Week 1)
- [ ] Create Xcode project with SwiftUI
- [ ] Set up project structure and folders
- [ ] Configure build settings and app capabilities
- [ ] Add Info.plist entries for microphone usage

### Phase 2: Audio Foundation (Week 1-2)
- [ ] Implement AudioProcessor with AVAudioEngine
- [ ] Set up microphone input tap
- [ ] Implement FFT analysis using vDSP
- [ ] Create frequency detection algorithm
- [ ] Add audio session configuration

### Phase 3: Music Theory (Week 2)
- [ ] Port ScaleCalculator from Kotlin to Swift
- [ ] Implement all scale types and modes
- [ ] Add temperament calculations
- [ ] Create note-to-frequency mappings
- [ ] Implement transposition logic

### Phase 4: UI Development (Week 3)
- [ ] Create main tuning interface optimized for iPhone 16 display
- [ ] Implement spectrum visualizer with 120Hz ProMotion support
- [ ] Add note indicators with smooth animations
- [ ] Create settings view with all options
- [ ] Implement transposition tool view
- [ ] Add Dynamic Island integration for live tuning status
- [ ] Configure Action Button shortcuts (iPhone 16 Pro)
- [ ] Implement Camera Control button gestures

### Phase 5: Features & Polish (Week 4)
- [ ] Add settings persistence with SwiftData
- [ ] Implement profiles system
- [ ] Create app icons optimized for iPhone 16

### Phase 7: Release Preparation (Week 5)
- [ ] App Store screenshots
- [ ] App description and metadata
- [ ] Privacy policy for microphone usage
- [ ] Code signing and provisioning
- [ ] App Store submission

## Key Differences from Android

### iOS-Specific Considerations
1. **Audio Session**: Must configure AVAudioSession for recording
2. **Permissions**: iOS requires explicit Info.plist entries
3. **Background Audio**: Requires specific capabilities
4. **UI Paradigm**: SwiftUI instead of Jetpack Compose
5. **FFT Library**: Accelerate framework instead of Apache Commons Math

### Technical Risks
1. **Audio Latency**: Use low-latency audio configuration
2. **Performance**: Optimize FFT for real-time processing
3. **Battery Usage**: Implement efficient audio processing
4. **Memory Management**: Proper cleanup of audio buffers

### Mitigation Strategies
- Implement proper error handling for audio interruptions
- Leverage iOS 18's improved audio session management
- Use iPhone 16's enhanced processing for lower latency


- Xcode 16.0+
- iOS 18.0+ SDK
- Swift Package Manager for any third-party libraries
- Apple Developer Account for distribution
- iPhone 16 device for testing hardware-specific features
