import SwiftUI
import AVFoundation
import Accelerate

// MARK: - Models

enum ScaleTypeCategory: String, CaseIterable {
    case modes = "Modes"
    case genres = "Genres"
    case pentatonic = "Pentatonic"
    case doubleHarmonic = "Double Harmonic"
    case phorminx = "Phorminx"

    func toInt() -> Int {
        switch self {
        case .modes: return 0
        case .genres: return 1
        case .pentatonic: return 2
        case .doubleHarmonic: return 3
        case .phorminx: return 4
        }
    }

    static func fromInt(_ value: Int) -> ScaleTypeCategory {
        switch value {
        case 0: return .modes
        case 1: return .genres
        case 2: return .pentatonic
        case 3: return .doubleHarmonic
        case 4: return .phorminx
        default: return .modes
        }
    }
}

enum Mode: String, CaseIterable {
    case mixolydios = "Mixolydios"
    case hypodorios = "Hypodorios"
    case lydios = "Lydios"
    case phrygios = "Phrygios"
    case dorios = "Dorios"
    case hypolydios = "Hypolydios"
    case hypophrygios = "Hypophrygios"

    // Ancient Greek modes mapped to their modern equivalents
    // The pattern represents the notes in the scale
    var notePattern: [String] {
        switch self {
        case .mixolydios:
            // Ancient Mixolydios = Modern Locrian (B C D E F G A)
            return ["B", "C", "D", "E", "F", "G", "A"]
        case .hypodorios:
            // Ancient Hypodorios = Modern Aeolian (A B C D E F G)
            return ["A", "B", "C", "D", "E", "F", "G"]
        case .lydios:
            // Ancient Lydios = Modern Ionian (C D E F G A B)
            return ["C", "D", "E", "F", "G", "A", "B"]
        case .phrygios:
            // Ancient Phrygios = Modern Dorian (D E F G A B C)
            return ["D", "E", "F", "G", "A", "B", "C"]
        case .dorios:
            // Ancient Dorios = Modern Phrygian (E F G A B C D)
            return ["E", "F", "G", "A", "B", "C", "D"]
        case .hypolydios:
            // Ancient Hypolydios = Modern Mixolydian (G A B C D E F)
            return ["G", "A", "B", "C", "D", "E", "F"]
        case .hypophrygios:
            // Ancient Hypophrygios = Modern Lydian (F G A B C D E)
            return ["F", "G", "A", "B", "C", "D", "E"]
        }
    }

    func toInt() -> Int {
        switch self {
        case .mixolydios: return 0
        case .hypodorios: return 1
        case .lydios: return 2
        case .phrygios: return 3
        case .dorios: return 4
        case .hypolydios: return 5
        case .hypophrygios: return 6
        }
    }

    static func fromInt(_ value: Int) -> Mode {
        switch value {
        case 0: return .mixolydios
        case 1: return .hypodorios
        case 2: return .lydios
        case 3: return .phrygios
        case 4: return .dorios
        case 5: return .hypolydios
        case 6: return .hypophrygios
        default: return .dorios
        }
    }
}

enum Genus: String, CaseIterable {
    case diatonic = "Diatonic"
    case chromatic = "Chromatic"
    case enharmonic = "Enharmonic"

    func toInt() -> Int {
        switch self {
        case .diatonic: return 0
        case .chromatic: return 1
        case .enharmonic: return 2
        }
    }

    static func fromInt(_ value: Int) -> Genus {
        switch value {
        case 0: return .diatonic
        case 1: return .chromatic
        case 2: return .enharmonic
        default: return .diatonic
        }
    }
}

enum Temperament: String, CaseIterable {
    case equal = "Equal"
    case just = "Just"
    case justAncient = "Just Ancient"
    case meantone = "Meantone"

    func toInt() -> Int {
        switch self {
        case .equal: return 0
        case .just: return 1
        case .justAncient: return 2
        case .meantone: return 3
        }
    }

    static func fromInt(_ value: Int) -> Temperament {
        switch value {
        case 0: return .equal
        case 1: return .just
        case 2: return .justAncient
        case 3: return .meantone
        default: return .justAncient
        }
    }
}

// MARK: - Audio Manager

class AudioManager: ObservableObject {
    @Published var spectrum: [Float] = Array(repeating: 0, count: 100)
    @Published var fullSpectrum: [Float] = Array(repeating: 0, count: 8192) // Full FFT data (16384/2)
    @Published var isRecording = false
    @Published var dominantFrequency: Double = 0
    @Published var detectedNote: String = "--"
    @Published var cents: Double = 0
    @Published var sampleRate: Double = 48000
    @Published var isPlayingNotes = false

    private let audioEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let fftSize = 16384  // Android default: "Very High"
    private var fftSetup: FFTSetup?
    private var window: [Float] = []

    // Settings from SettingsManager
    var highPassFilter: Int = 150
    var noiseGate: Float = 0.30
    var tolerance: Int = 3

    init() {
        setupFFT()
        setupAudio()
        setupPlaybackEngine()
    }

    private func setupFFT() {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Create Hann window
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    private func setupAudio() {
        let inputNode = audioEngine.inputNode

        // Try to use the input node's native format first
        var format = inputNode.outputFormat(forBus: 0)

        // If the format is invalid (common in simulator), create a default format
        if format.channelCount == 0 || format.sampleRate == 0 {
            print("Invalid input format, using default format for simulator")
            // Use a standard format that works in simulator
            format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 44100,
                                  channels: 1,
                                  interleaved: false) ?? AVAudioFormat()
        }

        // Ensure we have a valid format before proceeding
        guard format.channelCount > 0 && format.sampleRate > 0 else {
            print("Cannot create valid audio format")
            return
        }

        // Update sample rate if it changed
        if sampleRate != format.sampleRate {
            sampleRate = format.sampleRate
        }

        // Remove any existing tap first
        inputNode.removeTap(onBus: 0)

        // Install new tap with valid format
        inputNode.installTap(onBus: 0,
                           bufferSize: AVAudioFrameCount(fftSize),
                           format: nil) { [weak self] buffer, _ in  // Use nil to let system choose format
            self?.processAudioBuffer(buffer)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData,
              let fftSetup = fftSetup else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Use the first channel (or mix channels if stereo)
        let channelCount = Int(buffer.format.channelCount)
        var samples = [Float](repeating: 0, count: min(frameLength, fftSize))

        if channelCount == 1 {
            // Mono - copy directly
            for i in 0..<samples.count {
                samples[i] = channelData[0][i]
            }
        } else if channelCount > 1 {
            // Stereo or more - mix down to mono
            for i in 0..<samples.count {
                var sum: Float = 0
                for channel in 0..<min(channelCount, 2) {
                    sum += channelData[channel][i]
                }
                samples[i] = sum / Float(min(channelCount, 2))
            }
        }

        // Ensure we have enough samples
        guard samples.count >= fftSize else { return }

        // Apply window
        var windowedData = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedData, 1, vDSP_Length(fftSize))

        // Perform FFT
        var realPart = [Float](repeating: 0, count: fftSize/2)
        var imagPart = [Float](repeating: 0, count: fftSize/2)

        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                windowedData.withUnsafeBufferPointer { bufferPtr in
                    let complexPtr = UnsafeRawPointer(bufferPtr.baseAddress!).bindMemory(to: DSPComplex.self, capacity: fftSize/2)
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
                }

                let log2n = vDSP_Length(log2(Float(fftSize)))
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Calculate magnitudes
                var magnitudes = [Float](repeating: 0, count: fftSize/2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))

                // Find max magnitude for normalization
                var maxMagnitude: Float = 0
                for mag in magnitudes {
                    if mag > maxMagnitude {
                        maxMagnitude = mag
                    }
                }

                // Apply noise gate - if signal is too weak, ignore it
                let noiseThreshold = maxMagnitude * self.noiseGate

                var normalizedFullSpectrum = [Float](repeating: 0, count: fftSize/2)
                if maxMagnitude > 0 {
                    let highPassBin = Int(Double(self.highPassFilter) * Double(fftSize) / self.sampleRate) // Use settings high-pass
                    for i in 0..<fftSize/2 {
                        // Apply high-pass filter
                        if i < highPassBin {
                            normalizedFullSpectrum[i] = 0
                        } else {
                            // Apply noise gate
                            if magnitudes[i] < noiseThreshold {
                                normalizedFullSpectrum[i] = 0
                            } else {
                                normalizedFullSpectrum[i] = magnitudes[i] / maxMagnitude
                            }
                        }
                    }
                }

                // Also create downsampled spectrum for compatibility
                var normalizedMagnitudes = [Float](repeating: 0, count: 100)
                let scale = Float(1.0 / Float(fftSize))
                for i in 0..<100 {
                    let startIdx = i * (fftSize/2) / 100
                    let endIdx = min((i + 1) * (fftSize/2) / 100, fftSize/2)
                    if startIdx < endIdx {
                        var sum: Float = 0
                        for j in startIdx..<endIdx {
                            sum += magnitudes[j]
                        }
                        normalizedMagnitudes[i] = sqrt(sum / Float(endIdx - startIdx)) * scale * 100
                    }
                }

                // Find dominant frequency (considering high-pass filter and noise gate)
                let highPassBin = Int(Double(self.highPassFilter) * Double(fftSize) / self.sampleRate)
                var maxMagnitudeIndex = -1
                var maxMagnitudeValue: Float = 0

                for i in highPassBin..<magnitudes.count {
                    if magnitudes[i] > maxMagnitudeValue && magnitudes[i] >= noiseThreshold {
                        maxMagnitudeValue = magnitudes[i]
                        maxMagnitudeIndex = i
                    }
                }

                if maxMagnitudeIndex > 0 {
                    let freq = Double(maxMagnitudeIndex) * self.sampleRate / Double(self.fftSize)

                    DispatchQueue.main.async {
                        self.spectrum = normalizedMagnitudes
                        self.fullSpectrum = normalizedFullSpectrum
                        self.dominantFrequency = freq
                        self.updateDetectedNote(frequency: freq)
                    }
                } else {
                    // No valid frequency detected (below noise gate)
                    DispatchQueue.main.async {
                        self.spectrum = normalizedMagnitudes
                        self.fullSpectrum = normalizedFullSpectrum
                        self.dominantFrequency = 0
                        self.detectedNote = "--"
                        self.cents = 0
                    }
                }
            }
        }
    }

    private func updateDetectedNote(frequency: Double) {
        guard frequency > 0 else {
            detectedNote = "--"
            cents = 0
            return
        }

        // Note names in chromatic order starting from C
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency = 440.0

        // Calculate semitones from A4
        let semitonesFromA4 = 12.0 * log2(frequency / a4Frequency)
        let nearestSemitone = round(semitonesFromA4)
        cents = (semitonesFromA4 - nearestSemitone) * 100.0

        // A4 is the 9th note of octave 4 (C4=0, C#4=1...A4=9)
        // So A4 is 4*12 + 9 = 57 semitones from C0
        // Therefore, frequency is (57 + nearestSemitone) semitones from C0
        let semitonesFromC0 = 57 + Int(nearestSemitone)

        // Calculate octave and note index
        var octave = semitonesFromC0 / 12
        var noteIndex = semitonesFromC0 % 12

        // Handle negative values
        if semitonesFromC0 < 0 {
            octave = (semitonesFromC0 - 11) / 12
            noteIndex = ((semitonesFromC0 % 12) + 12) % 12
        }

        detectedNote = "\(noteNames[noteIndex])\(octave)"
    }

    func startRecording() {
        guard !isRecording else { return }

        do {
            // Request microphone permission first
            #if os(iOS)
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    do {
                        try self.audioEngine.start()
                        self.isRecording = true
                    } catch {
                        print("Failed to start audio engine: \(error)")
                    }
                }
            }
            #else
            try audioEngine.start()
            isRecording = true
            #endif
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        isRecording = false
    }

    // MARK: - Audio Playback

    private func setupPlaybackEngine() {
        // Attach the player node to the playback engine
        playbackEngine.attach(playerNode)

        // Get the output format (usually 2 channels at 48000 Hz)
        let outputFormat = playbackEngine.outputNode.outputFormat(forBus: 0)

        // Create a mono format for our generated tones
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate, channels: 1) else {
            print("Failed to create mono format")
            return
        }

        // Connect player to mixer with mono format
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: monoFormat)

        // Boost the output volume for physical device
        playbackEngine.mainMixerNode.outputVolume = 1.0

        // Start the playback engine
        do {
            try playbackEngine.start()
            print("Playback engine started successfully")
        } catch {
            print("Failed to start playback engine: \(error)")
        }
    }

    func playHighlightedNotes(stringFrequencies: [Double], stringNotes: [String]) {
        guard !isPlayingNotes else { return }

        // Reconfigure audio session for better playback on physical device
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for playback: \(error)")
        }
        #endif

        // Ensure playback engine is running
        if !playbackEngine.isRunning {
            do {
                try playbackEngine.start()
            } catch {
                print("Failed to restart playback engine: \(error)")
                return
            }
        }

        isPlayingNotes = true

        // Play notes in sequence
        DispatchQueue.global(qos: .userInitiated).async {
            // Start the player node
            self.playerNode.play()

            // Use the actual output format sample rate to ensure correct pitch
            let outputFormat = self.playbackEngine.outputNode.outputFormat(forBus: 0)
            let sampleRate = outputFormat.sampleRate
            print("Playback using sample rate: \(sampleRate) Hz")

            // Play each string frequency in descending order (highest to lowest)
            for (index, frequency) in stringFrequencies.enumerated().reversed() {
                guard self.isPlayingNotes else {
                    self.playerNode.stop()
                    break
                }

                if frequency > 0 {
                    // Make sure we're getting the right note for this index
                    let note = index < stringNotes.count ? stringNotes[index] : "?"
                    print("\n=== Playing String \(index) ===")
                    print("Display shows: \(note)")
                    print("Frequency: \(frequency) Hz")

                    // Verify what note this frequency should be
                    let a4 = 440.0
                    let semitones = 12.0 * log2(frequency / a4)
                    print("Semitones from A4: \(semitones)")

                    // Calculate what note this frequency actually represents
                    let testNote = self.testDetectedNote(frequency: frequency)
                    print("This frequency is actually: \(testNote)")

                    if testNote != note {
                        print("ERROR: Frequency doesn't match note!")
                        print("  Display shows \(note) but frequency \(frequency) Hz is \(testNote)")
                    }

                    self.playTone(frequency: frequency, duration: 1.0, sampleRate: sampleRate)
                    Thread.sleep(forTimeInterval: 0.12) // Short pause between notes
                }
            }

            self.playerNode.stop()

            DispatchQueue.main.async {
                self.isPlayingNotes = false
            }
        }
    }

    private func playTone(frequency: Double, duration: Double, sampleRate: Double) {
        let numSamples = Int(sampleRate * duration)

        // Create mono format
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("Failed to create audio format")
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            print("Failed to create audio buffer")
            return
        }

        buffer.frameLength = AVAudioFrameCount(numSamples)

        // Get the buffer's audio channel data (mono - single channel)
        guard let channelData = buffer.floatChannelData else {
            print("Failed to get channel data")
            return
        }

        // Generate lyre-like tone with harmonics and decay
        for frame in 0..<numSamples {
            let t = Double(frame) / sampleRate
            let decayFactor = exp(-t * 0.8) // Exponential decay

            // Fundamental frequency
            let fundamental = sin(2.0 * .pi * frequency * t)

            // Add harmonics to create lyre-like timbre
            let harmonic2 = 0.6 * sin(2.0 * .pi * frequency * 2 * t)
            let harmonic3 = 0.4 * sin(2.0 * .pi * frequency * 3 * t)
            let harmonic4 = 0.2 * sin(2.0 * .pi * frequency * 4 * t)
            let harmonic5 = 0.1 * sin(2.0 * .pi * frequency * 5 * t)

            // Combine all harmonics
            let sample = (fundamental + harmonic2 + harmonic3 + harmonic4 + harmonic5) * decayFactor

            // Apply amplitude envelope - write to mono channel (channel 0 only)
            let amplitude = Float(sample * 0.5) // Increased volume for physical device
            channelData[0][frame] = amplitude
        }

        // Use a semaphore to wait for buffer completion
        let semaphore = DispatchSemaphore(value: 0)

        // Schedule and play the buffer
        playerNode.scheduleBuffer(buffer, at: nil, options: []) {
            semaphore.signal()
        }

        // Wait for buffer to finish
        _ = semaphore.wait(timeout: .now() + duration + 0.1)
    }

    func stopPlayingNotes() {
        isPlayingNotes = false
        playerNode.stop()
    }

    // Test function to see what updateDetectedNote would produce
    private func testDetectedNote(frequency: Double) -> String {
        guard frequency > 0 else {
            return "--"
        }

        // Note names in chromatic order starting from C
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency = 440.0

        // Calculate semitones from A4
        let semitonesFromA4 = 12.0 * log2(frequency / a4Frequency)
        let nearestSemitone = round(semitonesFromA4)

        // A4 is the 9th note of octave 4 (C4=0, C#4=1...A4=9)
        // So A4 is 4*12 + 9 = 57 semitones from C0
        // Therefore, frequency is (57 + nearestSemitone) semitones from C0
        let semitonesFromC0 = 57 + Int(nearestSemitone)

        // Calculate octave and note index
        var octave = semitonesFromC0 / 12
        var noteIndex = semitonesFromC0 % 12

        // Handle negative values
        if semitonesFromC0 < 0 {
            octave = (semitonesFromC0 - 11) / 12
            noteIndex = ((semitonesFromC0 % 12) + 12) % 12
        }

        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Profile Management

struct Profile: Codable, Identifiable {
    var id: String { name }
    let name: String
    let scaleTypeCategory: Int
    let selectedMode: Int
    let selectedGenus: Int
    let firstNote: String
    let numberOfStrings: Int
    let temperament: Int
    let octaveOffset: Int
    let fftResolution: Int
    let magnitudeScale: Int
    let tolerance: Int
    let highPassFilter: Int
    let noiseGate: Float
    let showFullSpectrum: Bool
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    @Published var scaleTypeCategory: ScaleTypeCategory = .modes
    @Published var selectedMode: Mode = .dorios
    @Published var selectedGenus: Genus = .diatonic
    @Published var firstNote: String = "E"
    @Published var numberOfStrings: Int = 7
    @Published var temperament: Temperament = .justAncient
    @Published var octaveOffset: Int = 0
    @Published var fftResolution: Int = 3 // Default to 16384 (Very High)
    @Published var magnitudeScale: Int = 1 // Default to 5
    @Published var tolerance: Int = 3 // Hz
    @Published var highPassFilter: Int = 150 // Hz
    @Published var noiseGate: Float = 0.30 // 30%
    @Published var showFullSpectrum: Bool = false

    // Profile management
    @Published var profiles: [Profile] = []
    @Published var selectedProfileName: String = ""

    init() {
        loadProfiles()
        // Test frequency calculation
        testFrequencyCalculation()
    }

    private func testFrequencyCalculation() {
        // Test frequency calculation - these should match standard frequencies
        print("\n=== FREQUENCY CALCULATION TEST ===")

        // Test known frequencies
        let tests = [
            ("C4", "C", 4, 261.63),
            ("D4", "D", 4, 293.66),
            ("E4", "E", 4, 329.63),
            ("F4", "F", 4, 349.23),
            ("G4", "G", 4, 392.00),
            ("A4", "A", 4, 440.00),
            ("B4", "B", 4, 493.88)
        ]

        for (name, note, octave, expected) in tests {
            let calculated = noteToFrequency(note: note, octave: octave, temperament: .equal)
            let diff = abs(calculated - expected)
            if diff > 1.0 {
                print("ERROR: \(name) = \(calculated) Hz (expected \(expected) Hz, diff=\(diff))")
            } else {
                print("OK: \(name) = \(calculated) Hz")
            }
        }

        // Now test Dorios mode starting at E4
        print("\n=== DORIOS MODE TEST (E4 start) ===")
        let doriosNotes = ["E", "F", "G", "A", "B", "C", "D"]
        for (index, note) in doriosNotes.enumerated() {
            let octave = (note == "C" || note == "D") ? 5 : 4  // C and D are in next octave
            let freq = noteToFrequency(note: note, octave: octave, temperament: .equal)
            print("String \(index): \(note)\(octave) = \(freq) Hz")
        }
    }

    func saveProfile(name: String) {
        let profile = Profile(
            name: name,
            scaleTypeCategory: scaleTypeCategory.toInt(),
            selectedMode: selectedMode.toInt(),
            selectedGenus: selectedGenus.toInt(),
            firstNote: firstNote,
            numberOfStrings: numberOfStrings,
            temperament: temperament.toInt(),
            octaveOffset: octaveOffset,
            fftResolution: fftResolution,
            magnitudeScale: magnitudeScale,
            tolerance: tolerance,
            highPassFilter: highPassFilter,
            noiseGate: noiseGate,
            showFullSpectrum: showFullSpectrum
        )

        // Remove existing profile with same name if exists
        profiles.removeAll { $0.name == name }
        profiles.append(profile)

        // Save to local UserDefaults only
        if let encoded = try? JSONEncoder().encode(profiles) {
            let localDefaults = UserDefaults(suiteName: "com.lyretuner.local")!
            localDefaults.set(encoded, forKey: "lyretune_profiles_local")
            localDefaults.synchronize()
        }
    }

    func loadProfile(_ profile: Profile) {
        scaleTypeCategory = ScaleTypeCategory.fromInt(profile.scaleTypeCategory)
        selectedMode = Mode.fromInt(profile.selectedMode)
        selectedGenus = Genus.fromInt(profile.selectedGenus)
        firstNote = profile.firstNote
        numberOfStrings = profile.numberOfStrings
        temperament = Temperament.fromInt(profile.temperament)
        octaveOffset = profile.octaveOffset
        fftResolution = profile.fftResolution
        magnitudeScale = profile.magnitudeScale
        tolerance = profile.tolerance
        highPassFilter = profile.highPassFilter
        noiseGate = profile.noiseGate
        showFullSpectrum = profile.showFullSpectrum
        selectedProfileName = profile.name
    }

    func deleteProfile(name: String) {
        profiles.removeAll { $0.name == name }
        if selectedProfileName == name {
            selectedProfileName = ""
        }

        // Save to local UserDefaults only
        if let encoded = try? JSONEncoder().encode(profiles) {
            let localDefaults = UserDefaults(suiteName: "com.lyretuner.local")!
            localDefaults.set(encoded, forKey: "lyretune_profiles_local")
            localDefaults.synchronize()
        }
    }

    private func loadProfiles() {
        let localDefaults = UserDefaults(suiteName: "com.lyretuner.local")!
        if let data = localDefaults.data(forKey: "lyretune_profiles_local"),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = decoded
        }
    }

    // Structure to hold both notes and frequencies (like Android's ScaleData)
    struct ScaleData {
        let notes: [String]
        let frequencies: [Double]
    }

    func calculateScale() -> ScaleData {
        // Get the scale notes based on scale type
        let scaleNotes: [String]
        switch scaleTypeCategory {
        case .modes:
            // Get mode pattern and transpose to first note
            let basePattern = selectedMode.notePattern
            scaleNotes = transposeScale(basePattern, from: basePattern[0], to: firstNote)
        case .genres:
            scaleNotes = getGenusScale(selectedGenus, firstNote: firstNote)
        case .pentatonic:
            scaleNotes = getPentatonicScale(firstNote: firstNote)
        case .doubleHarmonic:
            scaleNotes = getDoubleHarmonicScale(firstNote: firstNote)
        case .phorminx:
            scaleNotes = getPhorminxScale(firstNote: firstNote)
        }

        // Calculate frequencies with octave handling (matching Android logic)
        var notesWithOctaves: [String] = []
        var frequencies: [Double] = []
        var lastFrequency: Double = 0

        for stringIndex in 0..<numberOfStrings {
            let noteIndex = stringIndex % scaleNotes.count
            let note = scaleNotes[noteIndex]

            // Calculate base octave from scale cycle position
            let baseCycleOctave = stringIndex / scaleNotes.count
            var stringOctave = octaveOffset + 4 + baseCycleOctave

            // Calculate frequency for this note
            var frequency = noteToFrequency(note: note, octave: stringOctave, temperament: temperament)

            // Ensure frequencies are ascending
            if stringIndex > 0 && frequency <= lastFrequency {
                while frequency <= lastFrequency && stringOctave < 10 {
                    stringOctave += 1
                    frequency = noteToFrequency(note: note, octave: stringOctave, temperament: temperament)
                }
            }

            // Store note with octave (like Android's noteWithOctave)
            let noteWithOctave = "\(note)\(stringOctave)"
            notesWithOctaves.append(noteWithOctave)
            frequencies.append(frequency)
            lastFrequency = frequency
        }

        return ScaleData(notes: notesWithOctaves, frequencies: frequencies)
    }

    // Helper function to transpose scale from one note to another
    private func transposeScale(_ scale: [String], from fromNote: String, to toNote: String) -> [String] {
        // If no transposition needed, return as is
        if fromNote == toNote {
            return scale
        }

        // Calculate semitone difference
        let noteOrder = ["C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
                        "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11]
        let chromatic = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        guard let fromIndex = noteOrder[fromNote],
              let toIndex = noteOrder[toNote] else {
            return scale
        }

        let interval = (toIndex - fromIndex + 12) % 12

        return scale.map { note in
            guard let noteIndex = noteOrder[note] else { return note }
            let newIndex = (noteIndex + interval) % 12
            return chromatic[newIndex]
        }
    }

    // Get genus scale for the given first note
    private func getGenusScale(_ genus: Genus, firstNote: String) -> [String] {
        // These are the predefined scales from Android
        let scales: [Genus: [String: String]] = [
            .diatonic: [
                "C": "C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A B C D",
                "D": "D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E",
                "E": "E F G A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F#",
                "F": "F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A B C D E F G",
                "G": "G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A",
                "A": "A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G A B",
                "B": "B C D E F G A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db"
            ],
            .chromatic: [
                "C": "C C# D F F# G Bb B C Eb E F Ab A Bb Db D D# F# G G# B C C#",
                "D": "D D# E G G# A C C# D F F# G Bb B C Eb E F Ab A Bb Db D D#",
                "E": "E F F# A Bb B D D# E G G# A C C# D F F# G Bb B C Eb E F",
                "F": "F F# G Bb B C Eb E F Ab A Bb B D D# E G G# A C C# D F F#",
                "G": "G G# A C C# D F F# G Bb B C Eb E F Ab A Bb Db D D# F# G G#",
                "A": "A Bb B D D# E G G# A C C# D F F# G Bb B C Eb E F Ab A Bb",
                "B": "B C C# E F F# A Bb B D D# E G G# A C C# D F F# G Bb B C"
            ],
            .enharmonic: [
                "C": "C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G B B* C",
                "D": "D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D",
                "E": "E E* F A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E",
                "F": "F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G B B* C E E* F",
                "G": "G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G",
                "A": "A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A",
                "B": "B B* C E E* F A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B"
            ]
        ]

        // Try exact match first
        if let scaleString = scales[genus]?[firstNote] {
            return scaleString.components(separatedBy: " ")
        }

        // If no exact match, transpose from C
        if let baseScaleString = scales[genus]?["C"] {
            let baseScale = baseScaleString.components(separatedBy: " ")
            return transposeScale(baseScale, from: "C", to: firstNote)
        }

        // Fallback to a simple scale
        return ["C", "D", "E", "F", "G", "A", "B"]
    }

    // Get pentatonic scale
    private func getPentatonicScale(firstNote: String) -> [String] {
        let scales: [String: String] = [
            "F": "F G Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C",
            "G": "G A C D E G A C D E G A C D E G A C D E G A C D",
            "A": "A C D E G A C D E G A C D E G A C D E G A C D E",
            "Bb": "Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C D F",
            "C": "C D E G A C D E G A C D E G A C D E G A C D E G",
            "D": "D E G A C D E G A C D E G A C D E G A C D E G A",
            "E": "E G A C D E G A C D E G A C D E G A C D E G A C"
        ]

        // Handle B note (becomes Bb)
        let lookupNote = firstNote == "B" ? "Bb" : firstNote

        if let scaleString = scales[lookupNote] {
            return scaleString.components(separatedBy: " ")
        }

        // Transpose from F if no match
        if let baseScaleString = scales["F"] {
            let baseScale = baseScaleString.components(separatedBy: " ")
            return transposeScale(baseScale, from: "F", to: lookupNote)
        }

        return ["C", "D", "E", "G", "A"]
    }

    // Get double harmonic scale
    private func getDoubleHarmonicScale(firstNote: String) -> [String] {
        let basePattern = ["C", "Db", "E", "F", "G", "Ab", "B"]
        return transposeScale(basePattern, from: "C", to: firstNote)
    }

    // Get phorminx scale
    private func getPhorminxScale(firstNote: String) -> [String] {
        let basePattern = ["A", "B", "C", "E"]
        return transposeScale(basePattern, from: "A", to: firstNote)
    }

    // Convert note to frequency using temperament
    private func noteToFrequency(note: String, octave: Int, temperament: Temperament) -> Double {
        let a4Freq: Double = 440.0

        // Calculate semitones from A4
        var semitones: Double = 0
        switch note.prefix(1) {
        case "C": semitones = -9
        case "D": semitones = -7
        case "E": semitones = -5
        case "F": semitones = -4
        case "G": semitones = -2
        case "A": semitones = 0
        case "B": semitones = 2
        default: semitones = 0
        }

        // Handle sharps, flats, and quarter-tones
        if note.contains("#") { semitones += 1 }
        if note.contains("b") { semitones -= 1 }
        if note.contains("*") { semitones += 0.5 }  // Quarter-tone

        // Add octave offset
        let totalSemitones = semitones + Double((octave - 4) * 12)

        // Apply temperament
        switch temperament {
        case .equal:
            return a4Freq * pow(2.0, totalSemitones / 12.0)
        case .just:
            return a4Freq * getJustRatio(totalSemitones)
        case .justAncient:
            return a4Freq * getJustAncientRatio(totalSemitones)
        case .meantone:
            return a4Freq * getMeantoneRatio(totalSemitones)
        }
    }

    // Just intonation ratios
    private func getJustRatio(_ semitones: Double) -> Double {
        // Handle quarter-tones with equal temperament
        if semitones.truncatingRemainder(dividingBy: 1.0) != 0 {
            return pow(2.0, semitones / 12.0)
        }

        let ratios: [Double] = [
            1.0,      // A
            16.0/15.0, // A#/Bb
            9.0/8.0,   // B
            6.0/5.0,   // C
            5.0/4.0,   // C#/Db
            4.0/3.0,   // D
            45.0/32.0, // D#/Eb
            3.0/2.0,   // E
            8.0/5.0,   // F
            5.0/3.0,   // F#/Gb
            9.0/5.0,   // G
            15.0/8.0   // G#/Ab
        ]

        let octaves = Int(floor(semitones / 12.0))
        let noteIndex = Int((semitones.truncatingRemainder(dividingBy: 12.0) + 12.0).truncatingRemainder(dividingBy: 12.0))

        return ratios[noteIndex] * pow(2.0, Double(octaves))
    }

    // Just Ancient temperament ratios (22 shruti system)
    private func getJustAncientRatio(_ semitones: Double) -> Double {
        let shrutiCents: [Double] = [
            0.0, 22.0, 90.0, 112.0, 182.0, 204.0, 294.0, 316.0, 386.0, 408.0,
            498.0, 520.0, 590.0, 612.0, 702.0, 722.0, 792.0, 814.0, 884.0, 906.0,
            996.0, 1018.0, 1088.0, 1110.0
        ]

        let ratios = shrutiCents.map { cents in pow(2.0, cents / 1200.0) }

        let octaves = Int(floor(semitones / 12.0))
        let semitoneInOctave = semitones.truncatingRemainder(dividingBy: 12.0) + 12.0
        let quarterTonesFromA = Int(round(semitoneInOctave.truncatingRemainder(dividingBy: 12.0) * 2.0))
        let quarterToneIndex = quarterTonesFromA % 24

        return ratios[quarterToneIndex] * pow(2.0, Double(octaves))
    }

    // Meantone temperament ratios
    private func getMeantoneRatio(_ semitones: Double) -> Double {
        // Handle quarter-tones with equal temperament
        if semitones.truncatingRemainder(dividingBy: 1.0) != 0 {
            return pow(2.0, semitones / 12.0)
        }

        let ratios: [Double] = [
            1.0,        // A
            1.0449,     // A#/Bb
            1.1180,     // B
            1.1963,     // C
            1.2500,     // C#/Db
            1.3375,     // D
            1.3975,     // D#/Eb
            1.4953,     // E
            1.5625,     // F
            1.6719,     // F#/Gb
            1.7889,     // G
            1.8692      // G#/Ab
        ]

        let octaves = Int(floor(semitones / 12.0))
        let noteIndex = Int((semitones.truncatingRemainder(dividingBy: 12.0) + 12.0).truncatingRemainder(dividingBy: 12.0))

        return ratios[noteIndex] * pow(2.0, Double(octaves))
    }

    func getFftSize() -> Int {
        let sizes = [2048, 4096, 8192, 16384, 32768, 65536]
        return sizes[min(fftResolution, sizes.count - 1)]
    }

    func getMagnitudeScaleValue() -> Float {
        let values: [Float] = [1, 5, 10, 20, 50, 100]
        return values[min(magnitudeScale, values.count - 1)]
    }
}

// MARK: - FFT Visualization View

struct FFTVisualizationView: View {
    let spectrum: [Float]
    let fullSpectrum: [Float]  // Add full spectrum data
    let stringFrequencies: [Double]
    let stringNotes: [String]
    let dominantFrequency: Double
    let showFullSpectrum: Bool
    let tolerance: Int
    let sampleRate: Double  // Add sample rate to ensure correct frequency calculation
    let highPassFilter: Int  // Add high pass filter value
    let noiseGate: Float  // Add noise gate value

    // Zoom and pan state
    @State private var zoomLevel: CGFloat = 1.0
    @State private var lastZoomLevel: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0.0
    @State private var lastPanOffset: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            let binToFreq = sampleRate / 16384.0  // Each bin represents frequency per FFT bin

            // Calculate BASE display range based on display mode
            let baseMinFreq: Double = {
                if showFullSpectrum {
                    // Show full spectrum from 20Hz to 8kHz (like Android)
                    return 20.0
                } else {
                    // Focus on string frequencies with padding
                    let sortedFreqs = stringFrequencies.sorted()
                    let minStringFreq = sortedFreqs.first ?? 100
                    let range = (sortedFreqs.last ?? 1000) - minStringFreq
                    let padding = range * 0.2
                    return max(50.0, minStringFreq - padding)
                }
            }()

            let baseMaxFreq: Double = {
                if showFullSpectrum {
                    // Show full spectrum from 20Hz to 8kHz (like Android)
                    return 8000.0
                } else {
                    // Focus on string frequencies with padding
                    let sortedFreqs = stringFrequencies.sorted()
                    let maxStringFreq = sortedFreqs.last ?? 1000
                    let range = maxStringFreq - (sortedFreqs.first ?? 100)
                    let padding = range * 0.2
                    return min(2000.0, maxStringFreq + padding)
                }
            }()

            // Apply zoom and pan to frequency range (like Android)
            let freqRange = max(baseMaxFreq - baseMinFreq, 1.0)
            let safeZoomLevel = min(max(Double(zoomLevel), 0.1), 20.0)
            let zoomedRange = freqRange / safeZoomLevel
            let centerFreq = baseMinFreq + freqRange * 0.5

            // Calculate pan offset in frequency space
            let maxPanFreqRange = freqRange - zoomedRange
            let panFreqOffset = (Double(panOffset) / (geometry.size.height * safeZoomLevel)) * maxPanFreqRange

            // Calculate display window with bounds checking
            let rawMinFreq = centerFreq - zoomedRange * 0.5 + panFreqOffset
            let rawMaxFreq = rawMinFreq + zoomedRange

            // Ensure we stay within the base frequency range
            let displayMinFreq = max(rawMinFreq, baseMinFreq)
            let displayMaxFreq = min(rawMaxFreq, baseMaxFreq)

            let minBin = Int(displayMinFreq / binToFreq)
            let maxBin = min(Int(displayMaxFreq / binToFreq), fullSpectrum.count - 1)

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Display ALL bins in the visible range (like Android)
                ForEach(minBin...maxBin, id: \.self) { index in
                    let frequency = Double(index) * binToFreq

                    // Map frequency to y position using LINEAR scaling (like Android)
                    let freqDiff = displayMaxFreq - displayMinFreq
                    let normalizedFreq = freqDiff > 0 ? (frequency - displayMinFreq) / freqDiff : 0.5
                    let yPos = CGFloat(1.0 - normalizedFreq) * geometry.size.height

                    // Calculate bar height to touch neighbors
                    let nextFrequency = Double(index + 1) * binToFreq
                    let nextNormalizedFreq = freqDiff > 0 ? (nextFrequency - displayMinFreq) / freqDiff : 0.5
                    let nextYPos = CGFloat(1.0 - nextNormalizedFreq) * geometry.size.height
                    let barHeight = abs(yPos - nextYPos) + 1  // +1 to ensure overlap

                    // Always show a bar, even if magnitude is very small
                    let magnitude = fullSpectrum[index]
                    let barWidth = max(CGFloat(magnitude) * geometry.size.width * 0.8,
                                      magnitude > 0 ? 2 : 0)  // Minimum 2 pixels if there's any signal

                    if barWidth > 0 {
                        Rectangle()
                            .fill(Color.blue.opacity(Double(magnitude) * 0.7 + 0.3))
                            .frame(width: barWidth, height: barHeight)  // Height based on distance to next bar
                            .position(x: barWidth / 2, y: yPos)
                    }
                }

                // Draw grey horizontal line for high pass filter frequency
                let highPassFreq = Double(highPassFilter)
                if highPassFreq >= displayMinFreq && highPassFreq <= displayMaxFreq {
                    let highPassY = frequencyToYPosition(highPassFreq, height: geometry.size.height,
                                                        minFreq: displayMinFreq, maxFreq: displayMaxFreq)
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width / 2, y: highPassY)
                }

                // Draw grey vertical line for noise gate threshold
                let noiseThresholdX = CGFloat(noiseGate) * geometry.size.width * 0.8
                if noiseThresholdX > 0 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1, height: geometry.size.height)
                        .position(x: noiseThresholdX, y: geometry.size.height / 2)
                }

                // String frequency lines with note labels
                ForEach(Array(stringFrequencies.enumerated()), id: \.offset) { index, freq in
                    if index < stringNotes.count {
                        let yPosition = frequencyToYPosition(freq, height: geometry.size.height,
                                                            minFreq: displayMinFreq, maxFreq: displayMaxFreq)

                        ZStack {
                            // Frequency line - use tolerance from settings
                            Rectangle()
                                .fill(isNearFrequency(freq, dominantFrequency, tolerance: tolerance) ? Color.green : Color.yellow.opacity(0.6))
                                .frame(width: geometry.size.width, height: 2)
                                .position(x: geometry.size.width / 2, y: yPosition)

                            // Note and frequency labels
                            HStack {
                                Text(stringNotes[index])
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)

                                Spacer()

                                Text(String(format: "%.1f Hz", freq))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 8)
                            .position(x: geometry.size.width / 2, y: yPosition)
                        }
                    }
                }

            }
            // Add double tap to reset FIRST (higher priority)
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoomLevel = 1.0
                    lastZoomLevel = 1.0
                    panOffset = 0.0
                    lastPanOffset = 0.0
                }
            }
            // Add combined gesture that handles both zoom and pan
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newZoom = lastZoomLevel * value
                            zoomLevel = min(max(newZoom, 0.5), 10.0) // Limit zoom between 0.5x and 10x
                        }
                        .onEnded { value in
                            lastZoomLevel = zoomLevel
                        },
                    DragGesture()
                        .onChanged { value in
                            // Use vertical translation for frequency navigation (like Android)
                            let translation = value.translation.height
                            panOffset = lastPanOffset + translation

                            // Limit pan based on zoom level (like Android)
                            let maxPan = geometry.size.height * zoomLevel * zoomLevel
                            panOffset = min(max(panOffset, -maxPan), maxPan)
                        }
                        .onEnded { value in
                            lastPanOffset = panOffset
                        }
                )
            )
        }
    }

    private func calculateStringFrequencyRange() -> (Double, Double) {
        let validFreqs = stringFrequencies.filter { $0 > 0 }
        if !validFreqs.isEmpty {
            let minStringFreq = validFreqs.min() ?? 100
            let maxStringFreq = validFreqs.max() ?? 1000
            return (minStringFreq * 0.8, maxStringFreq * 1.2)
        } else {
            return (100, 1000)
        }
    }

    private func frequencyToYPosition(_ frequency: Double, height: CGFloat,
                                     minFreq: Double? = nil, maxFreq: Double? = nil) -> CGFloat {
        let finalMinFreq: Double
        let finalMaxFreq: Double

        if let min = minFreq, let max = maxFreq {
            // Use provided min/max frequencies
            finalMinFreq = min
            finalMaxFreq = max
        } else {
            // Calculate the actual range from string frequencies with padding
            let sortedFreqs = stringFrequencies.sorted()
            guard !sortedFreqs.isEmpty else {
                return height / 2
            }

            let minStringFreq = sortedFreqs.first ?? 100
            let maxStringFreq = sortedFreqs.last ?? 1000

            // Add padding to spread out the display (20% on each side)
            let range = maxStringFreq - minStringFreq
            let padding = range * 0.2
            finalMinFreq = max(50.0, minStringFreq - padding)
            finalMaxFreq = min(2000.0, maxStringFreq + padding)
        }

        // Use LINEAR scaling like Android (not logarithmic)
        let freqDiff = finalMaxFreq - finalMinFreq
        let normalizedFreq = freqDiff > 0 ? (frequency - finalMinFreq) / freqDiff : 0.5
        let clampedFreq = min(max(normalizedFreq, 0.0), 1.0)

        // Invert so high frequencies are at the top
        return CGFloat(1.0 - clampedFreq) * height
    }

    private func isNearFrequency(_ target: Double, _ current: Double, tolerance: Int = 3) -> Bool {
        guard current > 0 else { return false }
        // Use Hz-based tolerance instead of cents for better precision at low frequencies
        return abs(current - target) <= Double(tolerance)
    }
}

// MARK: - Main View

struct MainView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var settings = SettingsManager()
    @State private var showingSettings = false
    @State private var stringFrequencies: [Double] = []
    @State private var stringNotes: [String] = []

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("LyreTune")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(getSubtitleText())
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Play button
                        Button(action: {
                            if audioManager.isPlayingNotes {
                                audioManager.stopPlayingNotes()
                            } else {
                                audioManager.playHighlightedNotes(stringFrequencies: stringFrequencies, stringNotes: stringNotes)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(audioManager.isPlayingNotes ? Color.orange : Color.blue)
                                    .frame(width: 50, height: 50)

                                Image(systemName: audioManager.isPlayingNotes ? "stop.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 8)

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()

                    // Note display - note left, frequency right
                    HStack {
                        Text(audioManager.detectedNote)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(abs(audioManager.cents) < 5 ? .green : .white)

                        Spacer()

                        Text(String(format: "%.1f Hz", audioManager.dominantFrequency))
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // FFT Visualization
                    FFTVisualizationView(
                        spectrum: audioManager.spectrum,
                        fullSpectrum: audioManager.fullSpectrum,
                        stringFrequencies: stringFrequencies,
                        stringNotes: stringNotes,
                        dominantFrequency: audioManager.dominantFrequency,
                        showFullSpectrum: settings.showFullSpectrum,
                        tolerance: settings.tolerance,
                        sampleRate: audioManager.sampleRate,
                        highPassFilter: settings.highPassFilter,
                        noiseGate: Float(settings.noiseGate) / 100.0
                    )
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                updateStringFrequencies()
                updateAudioSettings()
                // Delay audio start to avoid initialization issues
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioManager.startRecording()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings)
                    .onDisappear {
                        updateStringFrequencies()
                        updateAudioSettings()
                    }
            }
        }
    }


    private func updateStringFrequencies() {
        let scaleData = settings.calculateScale()
        stringFrequencies = scaleData.frequencies
        stringNotes = scaleData.notes
    }

    private func updateAudioSettings() {
        audioManager.highPassFilter = settings.highPassFilter
        audioManager.noiseGate = settings.noiseGate
        audioManager.tolerance = settings.tolerance
    }

    private func getSubtitleText() -> String {
        switch settings.scaleTypeCategory {
        case .modes:
            return "\(settings.selectedMode.rawValue) - \(settings.firstNote)\(4 + settings.octaveOffset)"
        case .genres:
            return "\(settings.selectedGenus.rawValue) - \(settings.firstNote)\(4 + settings.octaveOffset)"
        case .pentatonic:
            return "Pentatonic - \(settings.firstNote)\(4 + settings.octaveOffset)"
        case .doubleHarmonic:
            return "Double Harmonic - \(settings.firstNote)\(4 + settings.octaveOffset)"
        case .phorminx:
            return "Phorminx - \(settings.firstNote)\(4 + settings.octaveOffset)"
        }
    }

    private func centsColor(_ cents: Double) -> Color {
        let absCents = abs(cents)
        if absCents <= 5 {
            return .green
        } else if absCents <= 15 {
            return .yellow
        } else {
            return .red
        }
    }

}


// MARK: - Transposition Playback Manager

class TranspositionPlaybackManager: ObservableObject {
    @Published var isPlaying = false
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var playbackTask: Task<Void, Never>?

    init() {
        setupPlaybackEngine()
    }

    private func setupPlaybackEngine() {
        playbackEngine.attach(playerNode)

        let outputFormat = playbackEngine.outputNode.outputFormat(forBus: 0)
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate, channels: 1) else {
            print("Failed to create mono format")
            return
        }

        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: monoFormat)

        // Boost the output volume for physical device
        playbackEngine.mainMixerNode.outputVolume = 1.0

        do {
            try playbackEngine.start()
            print("Transposition playback engine started")
        } catch {
            print("Failed to start transposition playback engine: \(error)")
        }
    }

    func playNotes(_ notesString: String) {
        guard !isPlaying else { return }

        // Parse notes
        let notes = notesString.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !notes.isEmpty else { return }

        isPlaying = true

        // Cancel any existing playback
        playbackTask?.cancel()

        // Start new playback task
        playbackTask = Task {
            await playNotesAsync(notes)
        }
    }

    private func playNotesAsync(_ notes: [String]) async {
        // Ensure engine is running
        if !playbackEngine.isRunning {
            do {
                try playbackEngine.start()
            } catch {
                print("Failed to restart playback engine: \(error)")
                await MainActor.run { self.isPlaying = false }
                return
            }
        }

        playerNode.play()

        let sampleRate = 44100.0
        let noteDuration = 0.4  // 400ms per note
        let pauseDuration = 0.05  // 50ms pause between notes

        for note in notes {
            guard !Task.isCancelled else {
                playerNode.stop()
                await MainActor.run { self.isPlaying = false }
                return
            }

            let frequency = noteToFrequency(note)
            if frequency > 0 && frequency < 20000 {  // Sanity check
                playTone(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
                try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))
            }
        }

        playerNode.stop()
        await MainActor.run { self.isPlaying = false }
    }

    private func playTone(frequency: Double, duration: Double, sampleRate: Double) {
        let numSamples = Int(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(numSamples)

        guard let channelData = buffer.floatChannelData else { return }

        // Generate simple tone with envelope
        for frame in 0..<numSamples {
            let t = Double(frame) / sampleRate

            // Simple envelope for smoother sound
            let attack = min(t / 0.01, 1.0)  // 10ms attack
            let release = max(0, min(1.0, (duration - t) / 0.01))  // 10ms release
            let envelope = attack * release

            // Generate tone
            let sample = sin(2.0 * .pi * frequency * t) * envelope
            channelData[0][frame] = Float(sample * 0.6)  // Increased volume for physical device
        }

        let semaphore = DispatchSemaphore(value: 0)

        playerNode.scheduleBuffer(buffer, at: nil, options: []) {
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + duration + 0.1)
    }

    private func noteToFrequency(_ note: String) -> Double {
        // Parse note (e.g., "C#4", "Bb3", "F5")
        let pattern = "^([A-G])([#b]*)([0-9])$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) else {
            return 0
        }

        let noteNameRange = Range(match.range(at: 1), in: note)!
        let accidentalRange = Range(match.range(at: 2), in: note)!
        let octaveRange = Range(match.range(at: 3), in: note)!

        let noteName = String(note[noteNameRange])
        let accidental = String(note[accidentalRange])
        let octave = Int(note[octaveRange])!

        // Note to semitone mapping (C = 0)
        let noteValues = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var semitone = noteValues[noteName] else { return 0 }

        // Apply accidentals
        for char in accidental {
            if char == "#" { semitone += 1 }
            else if char == "b" { semitone -= 1 }
        }

        // Calculate MIDI note number (A4 = 69)
        let midiNote = (octave + 1) * 12 + semitone

        // Convert to frequency (A4 = 440 Hz)
        return 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playerNode.stop()
        isPlaying = false
    }
}

// MARK: - Transposition Tool View

struct TranspositionToolView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var inputText = "A3 E4 E4 C#4 D4 E4 D4 C#4 D4 E4 D4 C#4 B3 A3 B3 G3 A3 C#4 E4 D4 C#4 D4 C#4 A3 B3 G3 A3 C#4 B3 D4 E4 C#4 A3 A3 A3 F#3 E3"
    @State private var transpositionAmount: Double = 0
    @State private var outputText = ""
    @State private var uniqueNotes = ""
    @State private var isPlaying = false
    @StateObject private var playbackManager = TranspositionPlaybackManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input notes
                    VStack(alignment: .leading) {
                        Text("Input Notes")
                            .font(.headline)
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Transposition slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transpose:")
                                .font(.headline)
                            Spacer()
                            Text(transpositionAmount > 0 ? "+\(Int(transpositionAmount)) semitones" :
                                 transpositionAmount < 0 ? "\(Int(transpositionAmount)) semitones" :
                                 "0 semitones (no change)")
                                .foregroundColor(transpositionAmount != 0 ? .blue : .secondary)
                        }

                        Slider(value: $transpositionAmount, in: -12...12, step: 1)

                        Text("Slide to transpose up or down by semitones (half steps)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Output notes
                    VStack(alignment: .leading) {
                        Text("Transposed Notes")
                            .font(.headline)
                        Text(outputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Unique notes
                    VStack(alignment: .leading) {
                        Text("Unique Notes (sorted by frequency)")
                            .font(.headline)
                        Text(uniqueNotes)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            transpositionAmount = 0
                        }) {
                            Text("Reset Transposition")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(transpositionAmount == 0)

                        Button(action: {
                            inputText = ""
                            outputText = ""
                            uniqueNotes = ""
                            transpositionAmount = 0
                        }) {
                            Text("Clear All")
                                .frame(maxWidth: .infinity)
                        }

                        Button(action: {
                            inputText = "A3 E4 E4 C#4 D4 E4 D4 C#4 D4 E4 D4 C#4 B3 A3 B3 G3 A3 C#4 E4 D4 C#4 D4 C#4 A3 B3 G3 A3 C#4 B3 D4 E4 C#4 A3 A3 A3 F#3 E3"
                            transpositionAmount = 0
                        }) {
                            Text("Restore Epitaph of Seikilos")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Transposition Tool")
            .navigationBarItems(
                leading: Button(action: {
                    if playbackManager.isPlaying {
                        playbackManager.stopPlayback()
                    } else {
                        playbackManager.playNotes(outputText)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(playbackManager.isPlaying ? Color.orange : Color.blue)
                            .frame(width: 44, height: 44)

                        Image(systemName: playbackManager.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            updateTransposition()
        }
        .onChange(of: inputText) { _ in
            updateTransposition()
        }
        .onChange(of: transpositionAmount) { _ in
            updateTransposition()
        }
    }

    private func updateTransposition() {
        outputText = transposeNotes(inputText, semitones: Int(transpositionAmount))
        uniqueNotes = getUniqueNotes(from: outputText)
    }

    private func transposeNotes(_ input: String, semitones: Int) -> String {
        if semitones == 0 { return input }

        let notes = input.split(separator: " ").map(String.init)
        return notes.map { transposeNote($0, semitones: semitones) }.joined(separator: " ")
    }

    private func transposeNote(_ note: String, semitones: Int) -> String {
        if note.isEmpty { return note }

        // Parse note (e.g., "C#4", "Bb3", "F5")
        let pattern = "^([A-G])([#b]*)([0-9])$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) else {
            return note
        }

        guard let noteNameRange = Range(match.range(at: 1), in: note),
              let octaveRange = Range(match.range(at: 3), in: note) else {
            return note
        }

        let noteName = String(note[noteNameRange])
        let accidentalRange = Range(match.range(at: 2), in: note)
        let accidental = accidentalRange != nil ? String(note[accidentalRange!]) : ""
        let octave = Int(note[octaveRange]) ?? 4

        // Convert to MIDI note number
        let baseNotes: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let baseMidi = baseNotes[noteName] else { return note }

        let accidentalOffset = accidental == "#" ? 1 : accidental == "b" ? -1 : 0
        var midiNote = (octave + 1) * 12 + baseMidi + accidentalOffset

        // Apply transposition
        midiNote += semitones

        // Convert back to note
        let newOctave = (midiNote / 12) - 1
        let noteInOctave = midiNote % 12

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(noteNames[noteInOctave])\(newOctave)"
    }

    private func getUniqueNotes(from notes: String) -> String {
        let noteArray = notes.split(separator: " ").map(String.init)
        let uniqueSet = Set(noteArray)

        // Sort by frequency (MIDI note number)
        let sorted = uniqueSet.sorted { note1, note2 in
            getMidiNumber(from: note1) < getMidiNumber(from: note2)
        }

        return sorted.joined(separator: " ")
    }

    private func getMidiNumber(from note: String) -> Int {
        let pattern = "^([A-G])([#b]*)([0-9])$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) else {
            return 0
        }

        guard let noteNameRange = Range(match.range(at: 1), in: note),
              let octaveRange = Range(match.range(at: 3), in: note) else {
            return 0
        }

        let noteName = String(note[noteNameRange])
        let accidentalRange = Range(match.range(at: 2), in: note)
        let accidental = accidentalRange != nil ? String(note[accidentalRange!]) : ""
        let octave = Int(note[octaveRange]) ?? 4

        let baseNotes: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let baseMidi = baseNotes[noteName] else { return 0 }

        let accidentalOffset = accidental == "#" ? 1 : accidental == "b" ? -1 : 0
        return (octave + 1) * 12 + baseMidi + accidentalOffset
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var newProfileName = ""
    @State private var showingSaveAlert = false
    @State private var showingDeleteAlert = false
    @State private var profileToDelete = ""
    @State private var showingTranspositionTool = false

    private let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let fftResolutionOptions = ["2048 (Fast)", "4096 (Balanced)", "8192 (High Res)", "16384 (Very High)", "32768 (Ultra)", "65536 (Maximum)"]
    private let magnitudeOptions = ["1", "5", "10", "20", "50", "100"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Transposition Tool Button at top
                Button(action: {
                    showingTranspositionTool = true
                }) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                        Text("Transposition Tool")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                }

                Form {
                    // Profile Management Section
                Section(header: Text("Profile Management")) {
                    HStack {
                        TextField("Profile Name", text: $newProfileName)
                        Button("Save") {
                            if !newProfileName.isEmpty {
                                settings.saveProfile(name: newProfileName)
                                newProfileName = ""
                                showingSaveAlert = true
                            }
                        }
                        .disabled(newProfileName.isEmpty)
                    }

                    if !settings.profiles.isEmpty {
                        Picker("Load Profile", selection: $settings.selectedProfileName) {
                            Text("None").tag("")
                            ForEach(settings.profiles) { profile in
                                Text(profile.name).tag(profile.name)
                            }
                        }
                        .onChange(of: settings.selectedProfileName) { newValue in
                            if let profile = settings.profiles.first(where: { $0.name == newValue }) {
                                settings.loadProfile(profile)
                            }
                        }

                        if !settings.selectedProfileName.isEmpty {
                            Button(action: {
                                profileToDelete = settings.selectedProfileName
                                showingDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Current Profile")
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }

                // Scale Type Section
                Section(header: Text("Scale Type")) {
                    Picker("Scale Type", selection: $settings.scaleTypeCategory) {
                        ForEach(ScaleTypeCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    // Mode selection (only for Modes)
                    if settings.scaleTypeCategory == .modes {
                        Picker("Mode", selection: $settings.selectedMode) {
                            ForEach(Mode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }

                    // Genus selection (only for Genres)
                    if settings.scaleTypeCategory == .genres {
                        Picker("Genus", selection: $settings.selectedGenus) {
                            ForEach(Genus.allCases, id: \.self) { genus in
                                Text(genus.rawValue).tag(genus)
                            }
                        }
                    }
                }

                // Tuning Settings
                Section(header: Text("Tuning")) {
                    Picker("First Note", selection: $settings.firstNote) {
                        ForEach(notes, id: \.self) { note in
                            Text(note).tag(note)
                        }
                    }

                    Picker("Temperament", selection: $settings.temperament) {
                        ForEach(Temperament.allCases, id: \.self) { temp in
                            Text(temp.rawValue).tag(temp)
                        }
                    }

                    HStack {
                        Text("Number of Strings: \(settings.numberOfStrings)")
                        Slider(value: Binding(
                            get: { Double(settings.numberOfStrings) },
                            set: { settings.numberOfStrings = Int($0) }
                        ), in: 4...24, step: 1)
                    }

                    HStack {
                        Text("Octave Offset: \(settings.octaveOffset)")
                        Slider(value: Binding(
                            get: { Double(settings.octaveOffset) },
                            set: { settings.octaveOffset = Int($0) }
                        ), in: -2...2, step: 1)
                    }
                }

                // Audio Processing Settings
                Section(header: Text("Audio Processing")) {
                    Picker("FFT Resolution", selection: $settings.fftResolution) {
                        ForEach(0..<fftResolutionOptions.count, id: \.self) { index in
                            Text(fftResolutionOptions[index]).tag(index)
                        }
                    }

                    Picker("Magnitude Scale", selection: $settings.magnitudeScale) {
                        ForEach(0..<magnitudeOptions.count, id: \.self) { index in
                            Text(magnitudeOptions[index]).tag(index)
                        }
                    }

                    HStack {
                        Text("Tolerance: \(settings.tolerance) Hz")
                        Slider(value: Binding(
                            get: { Double(settings.tolerance) },
                            set: { settings.tolerance = Int($0) }
                        ), in: 1...10, step: 1)
                    }

                    HStack {
                        Text("High-pass Filter: \(settings.highPassFilter) Hz")
                        Slider(value: Binding(
                            get: { Double(settings.highPassFilter) },
                            set: { settings.highPassFilter = Int($0) }
                        ), in: 0...500, step: 5)
                    }

                    HStack {
                        Text("Noise Gate: \(Int(settings.noiseGate * 100))%")
                        Slider(value: $settings.noiseGate, in: 0...0.8, step: 0.01)
                    }

                    Toggle("Show Full Spectrum", isOn: $settings.showFullSpectrum)
                }

                // Reset Button
                Section {
                    Button(action: resetToDefaults) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                // License Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("3.0.8")
                            .foregroundColor(.secondary)
                    }

                    Link("View License", destination: URL(string: "https://github.com/threedlite/lyretune/blob/main/LICENSE.txt")!)
                        .foregroundColor(.blue)
                }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert(isPresented: $showingSaveAlert) {
            Alert(
                title: Text("Profile Saved"),
                message: Text("Profile has been saved successfully."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Profile"),
                message: Text("Are you sure you want to delete the profile \"\(profileToDelete)\"?"),
                primaryButton: .destructive(Text("Delete")) {
                    settings.deleteProfile(name: profileToDelete)
                    profileToDelete = ""
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingTranspositionTool) {
            TranspositionToolView()
        }
    }

    private func resetToDefaults() {
        settings.scaleTypeCategory = .modes
        settings.selectedMode = .dorios
        settings.selectedGenus = .diatonic
        settings.firstNote = "E"
        settings.numberOfStrings = 7
        settings.temperament = .justAncient
        settings.octaveOffset = 0
        settings.fftResolution = 3
        settings.magnitudeScale = 1
        settings.tolerance = 3
        settings.highPassFilter = 150
        settings.noiseGate = 0.30
        settings.showFullSpectrum = false
    }
}

// MARK: - App Entry Point

@main
struct LyreTuneApp: App {
    init() {
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .default mode instead of .measurement for better playback volume
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
    }
}