# LyreTune iOS

iOS port of the LyreTune app for tuning ancient Greek lyres and other stringed instruments.

## Features

- Real-time pitch detection using FFT analysis
- Support for ancient Greek musical modes (Mixolydios, Dorios, Phrygios, etc.)
- Multiple temperaments (Equal, Just, Just Ancient, Meantone)
- Visual spectrum analyzer with 120Hz ProMotion support
- String-by-string tuning indicators
- Transposition tool for key changes
- Profile management for saving tuning configurations
- Optimized for iPhone 16 with iOS 18

## Requirements

- Xcode 16.0+
- iOS 18.0+
- Swift 5.9+
- iPhone with microphone access

## Building

1. Open `LyreTune.xcodeproj` in Xcode
2. Select your development team in signing settings
3. Build and run on your device or simulator

## Architecture

- **Audio Processing**: AVAudioEngine for real-time microphone input
- **FFT Analysis**: Accelerate framework (vDSP) for frequency analysis
- **UI**: SwiftUI with iOS 18 features
- **Data Persistence**: UserDefaults and @AppStorage

## Project Structure

```
ios/LyreTune/
├── LyreTune/
│   ├── App/           # App entry point and configuration
│   ├── Views/         # SwiftUI views
│   ├── Components/    # Reusable UI components
│   ├── Audio/         # Audio processing and FFT
│   ├── Models/        # Data models and music theory
│   └── Resources/     # Assets and resources
└── LyreTuneTests/     # Unit tests
```

## License

See main project LICENSE file.