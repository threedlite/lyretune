# LyreTune - Ancient Greek Lyre Tuner

A Rust/egui application for tuning ancient Greek lyres using microphone input and frequency analysis.
Android and Mac versions also included.  Supported and maintained for US users only.


## Features

- Real-time frequency analysis using microphone input
- Support for Ancient Greek musical modes (Mixolydios, Hypodorios, Lydios, etc.)
- Support for Ancient Greek musical genres (Diatonic, Chromatic, Enharmonic)
- Multiple temperament options (Equal, Just, Meantone, Well)
- Visual frequency spectrum display
- Green indicators when strings are in tune
- Configurable for 7-24 string lyres

## Building

```bash
cargo build --release
```

## Running

```bash
cargo run --release
```

Make sure to grant microphone permissions when prompted.

## Usage

1. Select the number of strings on your lyre
2. Choose your first note (the lowest string)
3. Select the tuning system (Ancient Greek Modes, Genres, Pentatonic, or Double Harmonic)
4. Choose the specific mode or genus
5. Select the temperament (Just Intonation is recommended for ancient Greek music)
6. Play each string and tune until the corresponding note indicator turns green

## Dependencies

- egui/eframe for the GUI
- cpal for audio input
- rustfft for frequency analysis

## License

Based on the original JavaScript implementation by Dan Meany and Nikolaos Koumartzis (MIT License).
