import SwiftUI
import AVFoundation
import Accelerate
import UIKit

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
            // Ancient Hypolydios = Modern Lydian (F G A B C D E)
            return ["F", "G", "A", "B", "C", "D", "E"]
        case .hypophrygios:
            // Ancient Hypophrygios = Modern Mixolydian (G A B C D E F)
            return ["G", "A", "B", "C", "D", "E", "F"]
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

enum ChordReferenceMode: String, CaseIterable {
    case bass = "Bass"
    case middle = "Middle"
    case mese = "Mese"
}

// MARK: - Audio Manager

class AudioManager: ObservableObject {
    @Published var spectrum: [Float] = Array(repeating: 0, count: 100)
    @Published var fullSpectrum: [Float] = [] // Full FFT data - size = fftSize/2
    @Published var isRecording = false
    @Published var dominantFrequency: Double = 0
    @Published var detectedNote: String = "--"
    @Published var cents: Double = 0
    @Published var sampleRate: Double = 48000
    @Published var isPlayingNotes = false

    private let audioEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var fftSize = 16384  // Default: "Very High"
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
        // Initialize fullSpectrum with correct size
        fullSpectrum = Array(repeating: 0, count: fftSize / 2)
    }

    func updateFftSize(_ newSize: Int) {
        guard newSize != fftSize else { return }
        fftSize = newSize
        // Resize fullSpectrum immediately since this is called from async context
        fullSpectrum = Array(repeating: 0, count: newSize / 2)
        setupFFT()
        setupAudio()
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

        // Update sample rate if it changed (only if valid)
        if sampleRate != format.sampleRate && format.sampleRate > 0 && format.sampleRate.isFinite {
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
        // Pad to fftSize like Android (AudioProcessor.kt:84)
        let channelCount = Int(buffer.format.channelCount)
        let sampleCount = min(frameLength, fftSize)
        var samples = [Float](repeating: 0, count: fftSize) // Pad with zeros

        if channelCount == 1 {
            // Mono - copy directly
            for i in 0..<sampleCount {
                samples[i] = channelData[0][i]
            }
        } else if channelCount > 1 {
            // Stereo or more - mix down to mono
            for i in 0..<sampleCount {
                var sum: Float = 0
                for channel in 0..<min(channelCount, 2) {
                    sum += channelData[channel][i]
                }
                samples[i] = sum / Float(min(channelCount, 2))
            }
        }
        // samples is now padded to fftSize with zeros if needed

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

                // Find fundamental frequency using harmonic analysis (like Android)
                let binToFreq = Float(self.sampleRate) / Float(fftSize)
                let fundamentalBin = self.findFundamentalFrequency(
                    magnitudes: magnitudes,
                    binToFreq: binToFreq,
                    maxMagnitude: maxMagnitude
                )

                // Apply normalized magnitude check (like Android lines 149-162)
                // Normalize to 0-1 range based on reasonable signal levels
                let normalizedMagnitude = maxMagnitude > 0 ? min(1.0, maxMagnitude / 100.0) : 0.0

                // Apply noise gate - if normalized magnitude is below threshold, return no signal
                if fundamentalBin > 0 && normalizedMagnitude >= self.noiseGate {
                    let freq = Double(fundamentalBin) * self.sampleRate / Double(self.fftSize)

                    DispatchQueue.main.async {
                        self.spectrum = normalizedMagnitudes
                        self.fullSpectrum = normalizedFullSpectrum
                        self.dominantFrequency = freq
                        self.updateDetectedNote(frequency: freq)
                    }
                } else {
                    // No valid frequency detected (below noise gate or no fundamental found)
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

    // Port of Android's findFundamentalFrequency - sophisticated harmonic analysis
    private func findFundamentalFrequency(magnitudes: [Float], binToFreq: Float, maxMagnitude: Float) -> Int {
        let minFreq = Double(self.highPassFilter) // Use high-pass filter setting
        let maxFreq = 2000.0 // Maximum frequency to consider (2000 Hz)
        let minBin = max(1, Int(minFreq / Double(binToFreq)))
        let maxBin = min(magnitudes.count - 1, Int(maxFreq / Double(binToFreq)))

        // First, find the peak magnitude in our frequency range
        var peakBin = minBin
        var peakMagnitude = magnitudes[minBin]
        for i in minBin...maxBin {
            if magnitudes[i] > peakMagnitude {
                peakMagnitude = magnitudes[i]
                peakBin = i
            }
        }

        // Strongly prefer the dominant peak if it's in a reasonable frequency range
        let peakFreq = Float(peakBin) * binToFreq
        if peakMagnitude > maxMagnitude * 0.6 && peakFreq >= 200.0 {
            // Check if there's an even stronger peak at exactly double this frequency
            let doubleBin = peakBin * 2
            let doubleFreqStrength = doubleBin < magnitudes.count ? magnitudes[doubleBin] : 0.0

            // If the double frequency isn't significantly stronger, use this peak
            if doubleFreqStrength < peakMagnitude * 1.5 {
                print("AudioManager: Using dominant peak as fundamental: \(peakFreq)Hz (peak: \(peakMagnitude), double: \(doubleFreqStrength))")
                return peakBin
            } else {
                print("AudioManager: Skipping peak at \(peakFreq)Hz - stronger double at \(Float(doubleBin) * binToFreq)Hz")
            }
        }

        var bestFundamental = 0
        var bestScore: Float = 0.0

        // Test each potential fundamental frequency
        for fundamentalBin in minBin...maxBin {
            let fundamentalMag = magnitudes[fundamentalBin]
            let testFreq = Float(fundamentalBin) * binToFreq

            // Skip if fundamental is too weak
            if fundamentalMag < maxMagnitude * 0.1 { continue }

            var harmonicScore = fundamentalMag
            var harmonicCount: Float = 1.0

            // Check if this frequency is itself a harmonic of a lower frequency
            var isLikelyHarmonic = false
            for subharmonic in 2...6 {  // Check more subharmonics
                let subharmonicBin = fundamentalBin / subharmonic
                if subharmonicBin >= minBin && magnitudes[subharmonicBin] > maxMagnitude * 0.2 {  // Much stronger threshold
                    isLikelyHarmonic = true
                    print("AudioManager: Frequency \(testFreq)Hz rejected as harmonic - found stronger subharmonic at \(Float(subharmonicBin) * binToFreq)Hz")
                    break
                }
            }

            // Penalize if this frequency appears to be a harmonic
            if isLikelyHarmonic {
                harmonicScore *= 0.7
            }

            // Check harmonics (2nd, 3rd, 4th, 5th)
            for harmonic in 2...5 {
                let harmonicBin = fundamentalBin * harmonic
                if harmonicBin < magnitudes.count {
                    let harmonicMag = magnitudes[harmonicBin]
                    // Weight harmonics less than fundamental
                    harmonicScore += harmonicMag * (0.8 / Float(harmonic))
                    harmonicCount += 1.0
                }
            }

            // Normalize score by number of harmonics found
            let avgScore = harmonicScore / harmonicCount

            // Give bonus to frequencies near the peak (likely the true fundamental)
            let distanceFromPeak = abs(Float(fundamentalBin - peakBin))
            let proximityBonus = 1.0 + (0.2 * exp(-distanceFromPeak / 50.0))
            let adjustedScore = avgScore * proximityBonus

            // Prefer lower frequencies when scores are similar (within 10%)
            // This helps avoid detecting harmonics as fundamentals
            let scoreThreshold = bestScore * 0.9

            if adjustedScore > bestScore || (adjustedScore > scoreThreshold && fundamentalBin < bestFundamental) {
                // Log when we find a new best candidate
                if testFreq > 400 && testFreq < 600 {
                    print("AudioManager: New best candidate: \(testFreq)Hz (bin \(fundamentalBin)) score=\(adjustedScore), was \(Float(bestFundamental) * binToFreq)Hz")
                }
                bestScore = adjustedScore
                bestFundamental = fundamentalBin
            }
        }

        return bestFundamental
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
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        do {
                            try self.audioEngine.start()
                            DispatchQueue.main.async {
                                self.isRecording = true
                            }
                        } catch {
                            print("Failed to start audio engine: \(error)")
                        }
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    if granted {
                        do {
                            try self.audioEngine.start()
                            DispatchQueue.main.async {
                                self.isRecording = true
                            }
                        } catch {
                            print("Failed to start audio engine: \(error)")
                        }
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
        DispatchQueue.main.async {
            self.isRecording = false
        }
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
        DispatchQueue.main.async {
            self.isPlayingNotes = false
        }
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

        // Now test Dorios mode starting at E4 with JUST ANCIENT temperament (default)
        print("\n=== DORIOS MODE TEST (E4 start, Just Ancient) ===")
        let doriosNotes = ["E", "F", "G", "A", "B", "C", "D"]
        for (index, note) in doriosNotes.enumerated() {
            let octave = (note == "C" || note == "D") ? 5 : 4  // C and D are in next octave
            let freqEqual = noteToFrequency(note: note, octave: octave, temperament: .equal)
            let freqJustAncient = noteToFrequency(note: note, octave: octave, temperament: .justAncient)
            print("String \(index): \(note)\(octave) = \(freqJustAncient) Hz (justAncient) vs \(freqEqual) Hz (equal)")
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

        // Match Android implementation exactly (ScaleCalculator.kt:295-298)
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

        // Match Android implementation exactly (ScaleCalculator.kt:310-316)
        let octaves = Int(floor(semitones / 12.0))
        let semitoneInOctave = (semitones.truncatingRemainder(dividingBy: 12.0) + 12.0).truncatingRemainder(dividingBy: 12.0)

        let quarterTonesFromA = Int(round(semitoneInOctave * 2.0))
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

        // Match Android implementation exactly (ScaleCalculator.kt:339-342)
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
    let fftSize: Int  // Actual FFT size from settings
    let highPassFilter: Int  // Add high pass filter value
    let noiseGate: Float  // Add noise gate value

    // Zoom and pan state
    @State private var zoomLevel: CGFloat = 1.0
    @State private var lastZoomLevel: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0.0
    @State private var lastPanOffset: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            // Safety check: ensure sampleRate is valid
            if sampleRate > 0 && sampleRate.isFinite && fftSize > 0 {
                let binToFreq = sampleRate / Double(fftSize)  // Each bin represents frequency per FFT bin

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

            // Safety check: ensure values are finite before converting to Int
            let minBin = displayMinFreq.isFinite && binToFreq > 0 ? Int(displayMinFreq / binToFreq) : 0
            let maxBin = displayMaxFreq.isFinite && binToFreq > 0 ? min(Int(displayMaxFreq / binToFreq), fullSpectrum.count - 1) : fullSpectrum.count - 1

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
            } else {
                // Show loading state while audio initializes
                ZStack {
                    Color.black
                    Text("Initializing audio...")
                        .foregroundColor(.white)
                }
            }
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
                        fftSize: settings.getFftSize(),
                        highPassFilter: settings.highPassFilter,
                        noiseGate: settings.noiseGate  // Already in 0.0-0.8 range
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
                        // Dispatch async to avoid "Publishing changes from within view updates"
                        DispatchQueue.main.async {
                            updateStringFrequencies()
                            updateAudioSettings()
                        }
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
        audioManager.updateFftSize(settings.getFftSize())
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

            // Check if this is a chord (contains hyphens)
            if note.contains("-") {
                // Parse chord into individual notes
                let chordNotes = note.split(separator: "-").map(String.init)
                let frequencies = chordNotes.compactMap { singleNote -> Double? in
                    let freq = noteToFrequency(singleNote)
                    return (freq > 0 && freq < 20000) ? freq : nil
                }

                if !frequencies.isEmpty {
                    playChord(frequencies: frequencies, duration: noteDuration, sampleRate: sampleRate)
                    try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))
                }
            } else {
                // Single note
                let frequency = noteToFrequency(note)
                if frequency > 0 && frequency < 20000 {  // Sanity check
                    playTone(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
                    try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))
                }
            }
        }

        // Wait for the last note to finish playing
        try? await Task.sleep(nanoseconds: UInt64((noteDuration + pauseDuration) * 1_000_000_000))

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

    private func playChord(frequencies: [Double], duration: Double, sampleRate: Double) {
        guard !frequencies.isEmpty else { return }

        // If only one frequency, just play a single tone
        if frequencies.count == 1 {
            playTone(frequency: frequencies[0], duration: duration, sampleRate: sampleRate)
            return
        }

        let numSamples = Int(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(numSamples)

        guard let channelData = buffer.floatChannelData else { return }

        // Reduce amplitude based on number of notes to avoid clipping
        let amplitude = 0.6 / Double(frequencies.count)

        // Generate mixed tones with envelope
        for frame in 0..<numSamples {
            let t = Double(frame) / sampleRate

            // Simple envelope for smoother sound
            let attack = min(t / 0.01, 1.0)  // 10ms attack
            let release = max(0, min(1.0, (duration - t) / 0.01))  // 10ms release
            let envelope = attack * release

            // Mix all frequencies together
            var mixedSample = 0.0
            for frequency in frequencies {
                mixedSample += sin(2.0 * .pi * frequency * t) * amplitude
            }

            channelData[0][frame] = Float(mixedSample * envelope)
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
        .onChange(of: inputText) {
            updateTransposition()
        }
        .onChange(of: transpositionAmount) {
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

        // Check if this is a chord (contains hyphens)
        if note.contains("-") {
            // Split chord into individual notes, transpose each, and rejoin
            let notes = note.split(separator: "-").map(String.init)
            return notes.map { transposeSingleNote($0, semitones: semitones) }.joined(separator: "-")
        }

        // Single note - transpose normally
        return transposeSingleNote(note, semitones: semitones)
    }

    private func transposeSingleNote(_ note: String, semitones: Int) -> String {
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
        let tokens = notes.split(separator: " ").map(String.init)
        var allNotes: [String] = []

        // Extract all notes from tokens (including notes within chords)
        for token in tokens {
            if token.contains("-") {
                // Split chord into individual notes
                let chordNotes = token.split(separator: "-").map(String.init)
                allNotes.append(contentsOf: chordNotes)
            } else {
                allNotes.append(token)
            }
        }

        let uniqueSet = Set(allNotes)

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

// MARK: - Chord Analysis

struct ChordResult {
    let strings: [Int]
    let notes: [String]
    let frequencies: [Float]
    let ratios: [Int]
    let complexity: Double
    let numStrings: Int
}

class LyreChordAnalyzer {
    let frequencies: [Float]
    let noteNames: [String]
    let numStrings: Int

    // Formula parameters (NUMERIC_EMPIRIC_20251018)
    let augmentedPenalty = 0.6
    let sus2invPenalty = 0.08
    let major1invBonus = 0.057
    let dominant7Bonus = 0.65
    let halfdim7Penalty = 0.65
    let alpha = 1.0
    let beta = 0.3
    let kappa = 1.0
    let delta = 0.15
    let psi = 1.6
    let omega = 3.3
    let nu = 0.0
    let chi = 0.5

    init(scaleData: SettingsManager.ScaleData) {
        self.noteNames = scaleData.notes
        self.frequencies = scaleData.frequencies.map { Float($0) }
        self.numStrings = scaleData.notes.count
    }

    func analyzeAllChords(minStrings: Int = 2, maxStrings: Int? = nil) -> [ChordResult] {
        var results: [ChordResult] = []
        let maxSize = maxStrings ?? numStrings

        for size in minStrings...maxSize {
            let combinations = generateCombinations(n: numStrings, k: size)
            for combo in combinations {
                let chordFreqs = combo.map { frequencies[$0] }
                let chordNotes = combo.map { noteNames[$0] }
                let stringIndices = combo.map { $0 + 1 } // 1-indexed

                let ratios = frequenciesToRatios(freqs: chordFreqs)
                let complexity = complexityWithFiveAdjustments(notes: ratios)

                results.append(ChordResult(
                    strings: stringIndices,
                    notes: chordNotes,
                    frequencies: chordFreqs,
                    ratios: ratios,
                    complexity: complexity,
                    numStrings: size
                ))
            }
        }

        // Sort by complexity (ascending - simplest first)
        return results.sorted { $0.complexity < $1.complexity }
    }

    private func generateCombinations(n: Int, k: Int) -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []

        func backtrack(start: Int) {
            if current.count == k {
                result.append(current)
                return
            }

            for i in start..<n {
                current.append(i)
                backtrack(start: i + 1)
                current.removeLast()
            }
        }

        backtrack(start: 0)
        return result
    }

    private func bankersRound(_ value: Float) -> Int {
        let floor = Int(value.rounded(.down))
        let fraction = value - Float(floor)

        if fraction < 0.5 {
            return floor
        } else if fraction > 0.5 {
            return floor + 1
        } else {
            // Exactly 0.5 - round to even
            return floor % 2 == 0 ? floor : floor + 1
        }
    }

    func frequenciesToRatios(freqs: [Float], referenceFrequency: Float? = nil) -> [Int] {
        guard !freqs.isEmpty else { return [] }

        // If reference_frequency is None, defaults to min(freqs) - backward compatible
        let refFreq: Float
        if let ref = referenceFrequency {
            refFreq = ref
        } else {
            guard let minFreq = freqs.min() else { return [] }
            refFreq = minFreq
        }

        let ratios = freqs.map { $0 / refFreq }
        let precision: Float = 10000
        let intRatios = ratios.map { bankersRound($0 * precision) }

        let g = intRatios.reduce(intRatios[0]) { gcd($0, $1) }
        return intRatios.map { $0 / g }
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return x
    }

    private func primeFactorization(_ n: Int) -> [Int] {
        var num = n
        var factors: [Int] = []
        var d = 2

        while d * d <= num {
            while num % d == 0 {
                factors.append(d)
                num /= d
            }
            d += 1
        }

        if num > 1 {
            factors.append(num)
        }
        return factors
    }

    private func largestPrimeFactor(_ n: Int) -> Int {
        if n <= 1 { return 1 }
        let factors = primeFactorization(n)
        return factors.max() ?? 1
    }

    private func oddPart(_ n: Int) -> Int {
        var num = n
        while num % 2 == 0 {
            num /= 2
        }
        return num
    }

    func complexityWithFiveAdjustments(notes: [Int]) -> Double {
        var intervalOls: [Int] = []
        var intervalLps: [Int] = []
        var intervalMinOddLps: [Int] = []
        var intervalComplexity = 0.0

        for i in 0..<notes.count - 1 {
            let p = notes[i + 1]
            let q = notes[i]
            let g = gcd(p, q)
            let pReduced = p / g
            let qReduced = q / g

            let oddP = oddPart(pReduced)
            let oddQ = oddPart(qReduced)

            let ol = max(oddP, oddQ)
            let lp = largestPrimeFactor(ol)
            intervalComplexity += alpha * log2(Double(ol)) + beta * log2(Double(lp))
            intervalOls.append(ol)
            intervalLps.append(lp)

            let minOdd = min(oddP, oddQ)
            let lpMinOdd = largestPrimeFactor(minOdd)
            intervalMinOddLps.append(lpMinOdd)
        }

        if notes.count >= 3 {
            let pSpan = notes.last!
            let qSpan = notes.first!
            let g = gcd(pSpan, qSpan)
            let pSpanReduced = pSpan / g
            let qSpanReduced = qSpan / g

            let oddPSpan = oddPart(pSpanReduced)
            let oddQSpan = oddPart(qSpanReduced)

            let spanOl = max(oddPSpan, oddQSpan)
            let spanLp = largestPrimeFactor(spanOl)

            let allSameOl = Set(intervalOls).count == 1
            let isHomogeneous = allSameOl && spanOl < intervalOls[0]

            let minNote = notes.min()!

            var targetedAdjustments = 0.0

            // Triad adjustments
            if notes.count == 3 {
                if minNote == 16 && !isHomogeneous {
                    targetedAdjustments += augmentedPenalty
                }
                if minNote == 9 && !isHomogeneous {
                    targetedAdjustments += sus2invPenalty
                }
                if minNote == 5 && !isHomogeneous {
                    targetedAdjustments -= major1invBonus
                }
            }

            // Tetrad adjustments
            if notes.count == 4 {
                if minNote == 4 {
                    targetedAdjustments -= dominant7Bonus
                }
                if minNote == 5 {
                    targetedAdjustments += halfdim7Penalty
                }
            }

            let homogeneityBonus: Double
            let chiPenalty: Double
            let psiPenalty: Double
            let omegaPenalty: Double

            if allSameOl {
                if spanOl < intervalOls[0] {
                    homogeneityBonus = 1.0

                    if spanOl > 0 {
                        let avgMinOddLp = Double(intervalMinOddLps.reduce(0, +)) / Double(intervalMinOddLps.count)
                        let lpScale = avgMinOddLp / 3.0
                        chiPenalty = chi * max(0.0, 1.0 - log2(Double(spanOl))) * lpScale
                    } else {
                        chiPenalty = chi
                    }
                } else {
                    homogeneityBonus = 0.0
                    chiPenalty = 0.0
                }

                if spanOl == intervalOls[0] * intervalOls[0] {
                    let avgIntervalMinOddLp = Double(intervalMinOddLps.reduce(0, +)) / Double(intervalMinOddLps.count)
                    psiPenalty = psi * avgIntervalMinOddLp
                } else {
                    psiPenalty = 0.0
                }

                omegaPenalty = 0.0
            } else {
                homogeneityBonus = 0.0
                psiPenalty = 0.0
                chiPenalty = 0.0
                omegaPenalty = omega * max(0.0, log2(Double(spanLp)) - log2(5.0))
            }

            let minIntervalOl = intervalOls.min()!
            let nuPenalty = nu * max(0.0, log2(Double(minIntervalOl)) - log2(5.0))

            let compactnessPenalty = delta * (Double(notes.last! - notes.first!) / Double(notes.first!))

            return intervalComplexity - kappa * homogeneityBonus + compactnessPenalty +
                   psiPenalty + omegaPenalty + nuPenalty + chiPenalty + targetedAdjustments
        } else {
            return intervalComplexity
        }
    }

    // Helper function to pad strings
    private func pad(_ str: String, toLength length: Int) -> String {
        return str.padding(toLength: length, withPad: " ", startingAt: 0)
    }

    func formatResults(_ results: [ChordResult]) -> String {
        var sb = ""

        // Limit display to top 1000 chords for performance
        let displayLimit = 1000
        let displayResults = Array(results.prefix(displayLimit))
        let totalChords = results.count

        sb += String(repeating: "=", count: 100) + "\n"
        if totalChords > displayLimit {
            sb += "CHORD COMPLEXITY ANALYSIS - Showing top \(displayLimit) of \(totalChords) chords\n"
        } else {
            sb += "CHORD COMPLEXITY ANALYSIS - \(totalChords) chords shown\n"
        }
        sb += String(repeating: "=", count: 100) + "\n\n"

        sb += "LYRE TUNING\n"
        sb += String(repeating: "-", count: 100) + "\n"
        sb += "Number of strings: \(numStrings)\n\n"
        sb += "\(pad("String", toLength: 8))\(pad("Note", toLength: 12))\(pad("Frequency (Hz)", toLength: 15))\n"
        sb += String(repeating: "-", count: 100) + "\n"

        for i in 0..<numStrings {
            let stringNum = "\(i + 1)"
            let freq = String(format: "%.2f", frequencies[i])
            sb += "\(pad(stringNum, toLength: 8))\(pad(noteNames[i], toLength: 12))\(pad(freq, toLength: 15))\n"
        }

        sb += "\n" + String(repeating: "=", count: 100) + "\n"
        sb += "CHORD RANKINGS\n"
        sb += String(repeating: "=", count: 100) + "\n\n"
        sb += "\(pad("Rank", toLength: 6))\(pad("Strings", toLength: 15))\(pad("Notes", toLength: 30))\(pad("Ratio", toLength: 20))\(pad("Complexity", toLength: 12))\n"
        sb += String(repeating: "-", count: 100) + "\n"

        for (rank, result) in displayResults.enumerated() {
            let stringsStr = result.strings.map(String.init).joined(separator: ",")
            let notesStr = result.notes.joined(separator: " ")
            let ratioStr = result.ratios.map(String.init).joined(separator: ":")
            let rankStr = "\(rank + 1)"
            let complexityStr = String(format: "%.6f", result.complexity)

            sb += "\(pad(rankStr, toLength: 6))\(pad(stringsStr, toLength: 15))\(pad(notesStr, toLength: 30))\(pad(ratioStr, toLength: 20))\(pad(complexityStr, toLength: 12))\n"
        }

        sb += "\n" + String(repeating: "=", count: 100) + "\n"
        sb += "STATISTICS\n"
        sb += String(repeating: "=", count: 100) + "\n"
        sb += "Total chords analyzed: \(results.count)\n"

        if !results.isEmpty {
            sb += "Simplest chord: \(results[0].notes.joined(separator: " ")) "
            sb += "(complexity \(String(format: "%.6f", results[0].complexity)))\n"
            sb += "Most complex chord: \(results.last!.notes.joined(separator: " ")) "
            sb += "(complexity \(String(format: "%.6f", results.last!.complexity)))\n"
        }
        sb += "\n"

        sb += "Distribution by number of strings:\n"
        for size in 2...numStrings {
            let chordsOfSize = results.filter { $0.numStrings == size }
            if !chordsOfSize.isEmpty {
                let avgComplexity = chordsOfSize.reduce(0.0) { $0 + $1.complexity } / Double(chordsOfSize.count)
                sb += "  \(size) strings: \(chordsOfSize.count) chords, "
                sb += "avg complexity: \(String(format: "%.6f", avgComplexity))\n"
            }
        }
        sb += "\n"

        sb += String(repeating: "=", count: 100) + "\n"
        sb += "Note: Complexity is related to dissonance, so a lower complexity score is related to higher\n"
        sb += "consonance in this model.\n"
        sb += "Based on https://github.com/threedlite/lyretune/blob/main/analyze_lyre_chords.py\n"
        sb += String(repeating: "=", count: 100) + "\n"

        return sb
    }
}

// MARK: - Chord Progression Support

// Constants for chord progression analysis
let DYAD_SIZE = 2
let TRIAD_SIZE = 3
let TETRAD_SIZE = 4
let MIN_STRINGS_FOR_TRIADS = 4
let MAX_STRINGS_SUPPORTED = 9

let INVERSION_PENALTIES: [String: Double] = [
    "root": 0.0,
    "1st": 1.5,
    "2nd": 2.0,
    "3rd": 2.0,
    "unk": 3.0
]
let CROSSED_VOICES_PENALTY = 1.0
let VOICE_LEADING_WEIGHT = 0.5
let COMMON_TONE_BONUS = -0.5

let ROOT_MOVEMENT_STRENGTH: [Int: Double] = [
    0: 0.0,   // No movement
    3: -1.5,  // V→I (authentic cadence) - STRONGEST
    4: -0.3,  // IV→I (plagal) and I→V (half) - mixed
    5: -0.5,  // Ascending 5th
    2: 0.3,   // Stepwise
    6: 1.5,   // Tritone
    1: 0.8    // Half step
]

// Mode semitone patterns
let MODE_SEMITONES: [Mode: [Int]] = [
    .dorios: [0, 1, 3, 5, 7, 8, 10],      // Ancient Dorios = Modern Phrygian
    .phrygios: [0, 2, 3, 5, 7, 9, 10],    // Ancient Phrygios = Modern Dorian
    .lydios: [0, 2, 4, 5, 7, 9, 11],      // Ancient Lydios = Modern Ionian
    .mixolydios: [0, 1, 3, 5, 6, 8, 10],  // Ancient Mixolydios = Modern Locrian
    .hypodorios: [0, 2, 3, 5, 7, 8, 10],  // Ancient Hypodorios = Modern Aeolian
    .hypolydios: [0, 2, 4, 6, 7, 9, 11],  // Ancient Hypolydios = Modern Lydian
    .hypophrygios: [0, 2, 4, 5, 7, 9, 10] // Ancient Hypophrygios = Modern Mixolydian
]

let ANCIENT_TO_MODERN_MODE: [Mode: String] = [
    .dorios: "Phrygian",
    .phrygios: "Dorian",
    .lydios: "Ionian",
    .mixolydios: "Locrian",
    .hypodorios: "Aeolian",
    .hypolydios: "Lydian",
    .hypophrygios: "Mixolydian"
]

// Chord class
class LyreChord {
    let rootDegree: Int
    let scaleSemitones: [Int]
    let rootSemitone: Int
    let size: Int
    let mode: Mode?
    let degrees: [Int]
    let semitones: [Int]
    let quality: String

    init(rootDegree: Int, scaleSemitones: [Int], rootSemitone: Int, size: Int = 3, mode: Mode? = nil) {
        self.rootDegree = rootDegree
        self.scaleSemitones = scaleSemitones
        self.rootSemitone = rootSemitone
        self.size = size
        self.mode = mode

        // Build chord based on size
        let degreeOffsets: [Int]
        switch size {
        case DYAD_SIZE:
            degreeOffsets = [0, 2]
        case TRIAD_SIZE:
            degreeOffsets = [0, 2, 4]
        case TETRAD_SIZE:
            degreeOffsets = [0, 2, 4, 6]
        default:
            degreeOffsets = [0, 2, 4]
        }

        self.degrees = degreeOffsets.map { (rootDegree + $0) % 7 }
        self.semitones = LyreChord.getChordSemitones(degrees: degrees, rootDegree: rootDegree, scaleSemitones: scaleSemitones)

        // Determine quality
        self.quality = LyreChord.determineQuality(size: size, semitones: semitones)
    }

    static func getChordSemitones(degrees: [Int], rootDegree: Int, scaleSemitones: [Int]) -> [Int] {
        return degrees.map { deg in
            var st = scaleSemitones[deg]
            if deg < rootDegree {
                st += 12 // Next octave
            }
            return st
        }
    }

    static func determineQuality(size: Int, semitones: [Int]) -> String {
        switch size {
        case DYAD_SIZE:
            let interval = semitones[1] - semitones[0]
            return DYAD_QUALITIES[interval] ?? "\(interval)st"
        case TRIAD_SIZE:
            let third = semitones[1] - semitones[0]
            let fifth = semitones[2] - semitones[0]
            return TRIAD_QUALITIES["\(third),\(fifth)"] ?? "unk"
        case TETRAD_SIZE:
            let third = semitones[1] - semitones[0]
            let fifth = semitones[2] - semitones[0]
            let seventh = semitones[3] - semitones[0]
            return TETRAD_QUALITIES["\(third),\(fifth),\(seventh)"] ?? "unk"
        default:
            return "unk"
        }
    }

    func toRomanNumeral() -> String {
        // Use mode-aware Roman numerals if mode is provided
        let roman: String
        if size == DYAD_SIZE {
            // Dyads use simple Roman numeral with interval quality (like Android)
            let baseRoman = getSimpleRoman()
            roman = "\(baseRoman)-\(quality)"
        } else if let mode = mode, size == TRIAD_SIZE {
            let modeNumerals: [[String]] = [
                ["i°", "♭II", "♭iii", "iv", "♭V", "♭VI", "♭vii"],  // Mixolydios (Locrian)
                ["i", "ii°", "♭III", "iv", "v", "♭VI", "♭VII"],      // Hypodorios (Aeolian)
                ["I", "ii", "iii", "IV", "V", "vi", "vii°"],         // Lydios (Ionian)
                ["i", "ii", "♭III", "IV", "v", "vi°", "♭VII"],       // Phrygios (Dorian)
                ["i", "♭II", "♭III", "iv", "v°", "♭VI", "♭vii"],     // Dorios (Phrygian)
                ["I", "II", "iii", "♯iv°", "V", "vi", "vii"],        // Hypolydios (Lydian)
                ["I", "ii", "iii°", "IV", "v", "vi", "♭VII"]         // Hypophrygios (Mixolydian)
            ]
            let modeIndex = mode.toInt()
            roman = modeNumerals[modeIndex][rootDegree]
        } else if let mode = mode, size == TETRAD_SIZE {
            // For tetrads, use mode-aware base numeral but remove ° (like Android)
            let modeNumerals: [[String]] = [
                ["i°", "♭II", "♭iii", "iv", "♭V", "♭VI", "♭vii"],  // Mixolydios (Locrian)
                ["i", "ii°", "♭III", "iv", "v", "♭VI", "♭VII"],      // Hypodorios (Aeolian)
                ["I", "ii", "iii", "IV", "V", "vi", "vii°"],         // Lydios (Ionian)
                ["i", "ii", "♭III", "IV", "v", "vi°", "♭VII"],       // Phrygios (Dorian)
                ["i", "♭II", "♭III", "iv", "v°", "♭VI", "♭vii"],     // Dorios (Phrygian)
                ["I", "II", "iii", "♯iv°", "V", "vi", "vii"],        // Hypolydios (Lydian)
                ["I", "ii", "iii°", "IV", "v", "vi", "♭VII"]         // Hypophrygios (Mixolydian)
            ]
            let modeIndex = mode.toInt()
            let baseRoman = modeNumerals[modeIndex][rootDegree].replacingOccurrences(of: "°", with: "")
            // Use standard music theory notation for seventh chords
            switch quality {
            case "maj7":
                roman = "\(baseRoman)maj7"
            case "dom7":
                roman = "\(baseRoman)7"
            case "min7":
                roman = "\(baseRoman.lowercased())7"
            case "halfdim7":
                roman = "\(baseRoman.lowercased())ø7"
            case "dim7":
                roman = "\(baseRoman.lowercased())°7"
            default:
                roman = "\(baseRoman)?\(size)"
            }
        } else {
            roman = getSimpleRoman()
        }

        return roman
    }

    private func getSimpleRoman() -> String {
        let romans = ["I", "II", "III", "IV", "V", "VI", "VII"]
        return romans[rootDegree]
    }

    static let DYAD_QUALITIES: [Int: String] = [
        1: "m2", 2: "M2", 3: "m3", 4: "M3", 5: "P4",
        6: "TT", 7: "P5", 8: "m6", 9: "M6", 10: "m7", 11: "M7"
    ]

    static let TRIAD_QUALITIES: [String: String] = [
        "4,7": "maj",
        "3,7": "min",
        "3,6": "dim",
        "4,8": "aug"
    ]

    static let TETRAD_QUALITIES: [String: String] = [
        "4,7,11": "maj7",
        "4,7,10": "dom7",
        "3,7,10": "min7",
        "3,6,10": "halfdim7",
        "3,6,9": "dim7"
    ]
}

// Lyre Voicing class
class LyreVoicing {
    let chord: LyreChord
    let stringIndices: [Int]  // 1-indexed
    let semitones: [Int]
    let inversion: String
    let isAscending: Bool
    let useMultiChordMese: Bool
    let sortByCadence: Bool
    let meseDegree: Int
    let scaleSemitones: [Int]

    init(chord: LyreChord, stringIndices: [Int], semitones: [Int], useMultiChordMese: Bool = false, sortByCadence: Bool = false, meseDegree: Int = 0, scaleSemitones: [Int] = []) {
        self.chord = chord
        self.stringIndices = stringIndices
        self.semitones = semitones
        self.useMultiChordMese = useMultiChordMese
        self.sortByCadence = sortByCadence
        self.meseDegree = meseDegree
        self.scaleSemitones = scaleSemitones

        // Determine inversion
        // When useMultiChordMese is true, calculate inversions relative to mese-centered root
        let bassMod = semitones[0] % 12

        // Calculate expected chord tones for the re-centered chord
        let chordTones: [Int]
        if !sortByCadence && useMultiChordMese && !scaleSemitones.isEmpty {
            // Build chord tones from re-centered root
            let recenteredRootDegree = (chord.rootDegree - meseDegree + 7) % 7
            let degreeOffsets: [Int]
            switch chord.size {
            case DYAD_SIZE:
                degreeOffsets = [0, 2]
            case TRIAD_SIZE:
                degreeOffsets = [0, 2, 4]
            case TETRAD_SIZE:
                degreeOffsets = [0, 2, 4, 6]
            default:
                degreeOffsets = [0, 2, 4]
            }
            chordTones = degreeOffsets.map { offset in
                let deg = (recenteredRootDegree + offset) % 7
                return scaleSemitones[deg] % 12
            }
        } else {
            // Traditional: use chord's original semitones
            chordTones = chord.semitones.map { $0 % 12 }
        }

        switch chord.size {
        case DYAD_SIZE:
            self.inversion = (bassMod == chordTones[0]) ? "root" : "1st"
        case TRIAD_SIZE:
            if bassMod == chordTones[0] {
                self.inversion = "root"
            } else if bassMod == chordTones[1] {
                self.inversion = "1st"
            } else if bassMod == chordTones[2] {
                self.inversion = "2nd"
            } else {
                self.inversion = "unk"
            }
        case TETRAD_SIZE:
            if bassMod == chordTones[0] {
                self.inversion = "root"
            } else if bassMod == chordTones[1] {
                self.inversion = "1st"
            } else if bassMod == chordTones[2] {
                self.inversion = "2nd"
            } else if bassMod == chordTones[3] {
                self.inversion = "3rd"
            } else {
                self.inversion = "unk"
            }
        default:
            self.inversion = "unk"
        }

        // Check if ascending
        var ascending = true
        for i in 0..<semitones.count-1 {
            if semitones[i] >= semitones[i+1] {
                ascending = false
                break
            }
        }
        self.isAscending = ascending
    }

    func voicingPenalty() -> Double {
        let penalty: Double
        if chord.size == TETRAD_SIZE && inversion == "3rd" {
            penalty = INVERSION_PENALTIES["2nd"] ?? 2.0
        } else {
            penalty = INVERSION_PENALTIES[inversion] ?? 3.0
        }

        return penalty + (isAscending ? 0.0 : CROSSED_VOICES_PENALTY)
    }
}

// Progression class
class LyreProgression {
    let complexity: Double
    let voicings: [LyreVoicing]
    let chords: [LyreChord]
    var commonName: String?

    init(complexity: Double, voicings: [LyreVoicing], chords: [LyreChord], commonName: String? = nil) {
        self.complexity = complexity
        self.voicings = voicings
        self.chords = chords
        self.commonName = commonName
    }
}

// Lyre Progression Analyzer
class LyreProgressionAnalyzer {
    let mode: Mode
    let firstNote: String
    let numStrings: Int
    let temperament: Temperament
    let octaveOffset: Int
    let scaleSemitones: [Int]
    let frequencies: [Double]
    let noteNames: [String]
    let chordAnalyzer: LyreChordAnalyzer
    let chords: [LyreChord]
    let voicings: [String: [LyreVoicing]]  // Key: "degree,size"
    let useMultiChordMese: Bool
    let chordReferenceMode: ChordReferenceMode
    let sortByCadence: Bool

    // Middle string of the lyre (mese in Ancient Greek music theory)
    // For odd number: middle = (n+1)/2, for even: lower-middle = n/2
    let meseStringIndex: Int

    // Scale degree (0-6) of the mese string, used when useMultiChordMese is true
    let meseDegree: Int

    init(mode: Mode, firstNote: String, numStrings: Int, temperament: Temperament, octaveOffset: Int, scaleData: SettingsManager.ScaleData, chordAnalyzer: LyreChordAnalyzer, useMultiChordMese: Bool = false, chordReferenceMode: ChordReferenceMode = .bass, sortByCadence: Bool = false) {
        self.mode = mode
        self.firstNote = firstNote
        self.numStrings = numStrings
        self.temperament = temperament
        self.octaveOffset = octaveOffset
        self.useMultiChordMese = useMultiChordMese
        self.chordReferenceMode = chordReferenceMode
        self.sortByCadence = sortByCadence
        self.scaleSemitones = MODE_SEMITONES[mode] ?? [0, 2, 4, 5, 7, 9, 11]
        self.frequencies = scaleData.frequencies
        self.noteNames = scaleData.notes
        self.chordAnalyzer = chordAnalyzer
        self.meseStringIndex = (numStrings + 1) / 2
        self.meseDegree = (self.meseStringIndex - 1) % scaleSemitones.count

        // Debug logging to verify parameters
        print("=== LyreProgressionAnalyzer Init ===")
        print("useMultiChordMese: \(useMultiChordMese)")
        print("chordReferenceMode: \(chordReferenceMode.rawValue)")
        print("sortByCadence: \(sortByCadence)")
        print("numStrings: \(numStrings)")
        print("meseStringIndex (1-indexed): \(meseStringIndex)")
        print("meseDegree (0-indexed): \(meseDegree)")

        // Build chords
        var chordList: [LyreChord] = []
        let chordSizes = numStrings <= 4 ? [DYAD_SIZE] : (numStrings >= 7 ? [TRIAD_SIZE, TETRAD_SIZE, DYAD_SIZE] : [TRIAD_SIZE, DYAD_SIZE])

        for size in chordSizes {
            for degree in 0...6 {
                let chord = LyreChord(rootDegree: degree, scaleSemitones: scaleSemitones, rootSemitone: scaleSemitones[degree], size: size, mode: mode)
                chordList.append(chord)
            }
        }
        self.chords = chordList

        // Build voicings
        self.voicings = Self.buildVoicings(chords: chordList, numStrings: numStrings, scaleSemitones: scaleSemitones, useMultiChordMese: useMultiChordMese, sortByCadence: sortByCadence, meseDegree: meseDegree)
    }

    static func buildVoicings(chords: [LyreChord], numStrings: Int, scaleSemitones: [Int], useMultiChordMese: Bool = false, sortByCadence: Bool = false, meseDegree: Int = 0) -> [String: [LyreVoicing]] {
        var voicingsByChord: [String: [LyreVoicing]] = [:]

        for chord in chords {
            var voicingList: [LyreVoicing] = []

            // Try all combinations
            let combinations = generateCombinations(n: numStrings, k: chord.size)
            for strings in combinations {
                // Get semitones played
                let scaleLength = scaleSemitones.count
                let semitones = strings.map { s -> Int in
                    let degree = s % scaleLength
                    let octave = s / scaleLength
                    return scaleSemitones[degree] + (octave * 12)
                }

                // Check if valid voicing
                if isValidVoicing(semitones: semitones, chord: chord) {
                    let voicing = LyreVoicing(chord: chord, stringIndices: strings.map { $0 + 1 }, semitones: semitones, useMultiChordMese: useMultiChordMese, sortByCadence: sortByCadence, meseDegree: meseDegree, scaleSemitones: scaleSemitones)
                    voicingList.append(voicing)
                }
            }

            let key = "\(chord.rootDegree),\(chord.size)"
            voicingsByChord[key] = voicingList
        }

        return voicingsByChord
    }

    static func isValidVoicing(semitones: [Int], chord: LyreChord) -> Bool {
        let chordNotes = Set(chord.semitones.map { $0 % 12 })
        let playedNotes = Set(semitones.map { $0 % 12 })
        return playedNotes == chordNotes
    }

    static func generateCombinations(n: Int, k: Int) -> [[Int]] {
        var result: [[Int]] = []

        func backtrack(start: Int, current: [Int]) {
            if current.count == k {
                result.append(current)
                return
            }

            for i in start..<n {
                backtrack(start: i + 1, current: current + [i])
            }
        }

        backtrack(start: 0, current: [])
        return result
    }

    func generateProgressions(length: Int, chordSizes: Set<Int>, maxResults: Int = 100, timeoutSeconds: Double = 30.0, startTime: Date = Date()) -> (progressions: [LyreProgression], isPartial: Bool) {
        var progressionList: [LyreProgression] = []
        var isPartial = false

        // Filter chords by size
        let availableChords = chords.filter { chordSizes.contains($0.size) }.map { ($0.rootDegree, $0.size) }

        if availableChords.isEmpty {
            return ([], false)
        }

        // Generate all chord sequences (no limit to match Android behavior)
        let chordSequences = generateChordSequences(availableChords: availableChords, length: length)

        for chordSequence in chordSequences {
            // Skip consecutive identical chords
            var hasConsecutive = false
            for i in 0..<chordSequence.count-1 {
                if chordSequence[i] == chordSequence[i+1] {
                    hasConsecutive = true
                    break
                }
            }
            if hasConsecutive { continue }

            // For 4-chord sequences, skip if first pair equals second pair
            if length == 4 && chordSequence.count == 4 {
                if chordSequence[0] == chordSequence[2] && chordSequence[1] == chordSequence[3] {
                    continue
                }
            }

            // Get voicing options
            var voicingOptions: [[LyreVoicing]] = []
            var hasEmptyVoicing = false
            for (degree, size) in chordSequence {
                let key = "\(degree),\(size)"
                if let vList = voicings[key], !vList.isEmpty {
                    voicingOptions.append(vList)
                } else {
                    hasEmptyVoicing = true
                    break
                }
            }

            if hasEmptyVoicing { continue }

            // Try all voicing combinations (no limit to match Android behavior)
            let voicingCombos = generateVoicingCombinations(voicingOptions: voicingOptions)
            for voicingCombo in voicingCombos {
                // Check timeout periodically (every 100 progressions like Android)
                if progressionList.count % 100 == 0 {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > timeoutSeconds {
                        // Timeout reached - return partial results like Android does
                        isPartial = true
                        let sorted = progressionList.sorted { $0.complexity < $1.complexity }
                        return (Array(sorted.prefix(maxResults)), isPartial)
                    }
                }

                let complexity = calculateProgressionComplexity(voicingSequence: voicingCombo)
                let chordObjs = voicingCombo.map { $0.chord }
                progressionList.append(LyreProgression(complexity: complexity, voicings: voicingCombo, chords: chordObjs))
            }
        }

        // Sort and return top results (completed within timeout)
        let sorted = progressionList.sorted { $0.complexity < $1.complexity }
        return (Array(sorted.prefix(maxResults)), isPartial)
    }

    func generateChordSequences(availableChords: [(Int, Int)], length: Int) -> [[(Int, Int)]] {
        var result: [[(Int, Int)]] = []

        func backtrack(current: [(Int, Int)]) {
            if current.count == length {
                result.append(current)
                return
            }

            for chord in availableChords {
                backtrack(current: current + [chord])
            }
        }

        backtrack(current: [])
        return result
    }

    func generateVoicingCombinations(voicingOptions: [[LyreVoicing]]) -> [[LyreVoicing]] {
        if voicingOptions.isEmpty { return [] }
        if voicingOptions.count == 1 { return voicingOptions[0].map { [$0] } }

        var result: [[LyreVoicing]] = []

        func backtrack(index: Int, current: [LyreVoicing]) {
            if index == voicingOptions.count {
                result.append(current)
                return
            }

            for voicing in voicingOptions[index] {
                backtrack(index: index + 1, current: current + [voicing])
            }
        }

        backtrack(index: 0, current: [])
        return result
    }

    private func calculateChordComplexity(voicing: LyreVoicing, chord: LyreChord) -> Double {
        // Get frequencies for this voicing with bounds checking
        let freqs = voicing.stringIndices.compactMap { index -> Double? in
            let idx = index - 1
            guard idx >= 0 && idx < frequencies.count else { return nil }
            return frequencies[idx]
        }

        if freqs.count != voicing.stringIndices.count {
            // Some indices were invalid, return high complexity
            return 10.0
        }

        // Determine reference frequency based on chordReferenceMode
        // When prioritizing Western cadences, always use bass (traditional approach)
        let referenceFrequency: Float?
        if sortByCadence {
            referenceFrequency = nil  // Use default bass note for Western cadences
        } else {
            switch chordReferenceMode {
            case .bass:
                referenceFrequency = nil  // Use default (minimum)
            case .middle:
                // Use middle note of the chord (or lower-middle if even)
                let middleIdx = (freqs.count + 1) / 2 - 1  // Convert to 0-indexed
                referenceFrequency = middleIdx >= 0 && middleIdx < freqs.count ? Float(freqs[middleIdx]) : nil
            case .mese:
                // Use middle string of lyre (mese)
                let meseIdx = meseStringIndex - 1  // Convert to 0-indexed
                if meseIdx >= 0 && meseIdx < frequencies.count {
                    referenceFrequency = Float(frequencies[meseIdx])
                } else {
                    referenceFrequency = nil  // Fall back to default if invalid
                }
            }
        }

        // Convert to ratios
        let freqsFloat = freqs.map { Float($0) }
        let ratios = chordAnalyzer.frequenciesToRatios(freqs: freqsFloat, referenceFrequency: referenceFrequency)

        // Calculate chord complexity
        let chordComplexity = chordAnalyzer.complexityWithFiveAdjustments(notes: ratios)

        // Add voicing penalty
        return chordComplexity + voicing.voicingPenalty()
    }

    func calculateProgressionComplexity(voicingSequence: [LyreVoicing]) -> Double {
        var complexity = 0.0

        // Individual chord complexities
        for voicing in voicingSequence {
            complexity += calculateChordComplexity(voicing: voicing, chord: voicing.chord)
        }

        // Voice leading distances
        for i in 0..<voicingSequence.count-1 {
            let vlDistance = voiceLeadingDistance(voicing1: voicingSequence[i], voicing2: voicingSequence[i+1])
            complexity += vlDistance * VOICE_LEADING_WEIGHT
        }

        // Root movement
        for i in 0..<voicingSequence.count-1 {
            let rootComplexity = rootMovementComplexity(chord1: voicingSequence[i].chord, chord2: voicingSequence[i+1].chord)
            complexity += rootComplexity
        }

        return complexity
    }

    func voiceLeadingDistance(voicing1: LyreVoicing, voicing2: LyreVoicing) -> Double {
        let strings1 = Set(voicing1.stringIndices)
        let strings2 = Set(voicing2.stringIndices)

        let common = strings1.intersection(strings2)
        let voicesThatMove = (strings1.subtracting(common).count + strings2.subtracting(common).count)

        let commonToneBonus = Double(common.count) * COMMON_TONE_BONUS

        return Double(voicesThatMove) + commonToneBonus
    }

    func rootMovementComplexity(chord1: LyreChord, chord2: LyreChord) -> Double {
        // Calculate distance between chord root degrees
        // When sortByCadence is true (Western cadences), always use degree 0 as tonic
        // When sortByCadence is false and useMultiChordMese is true, use meseDegree as tonic
        let degreeDistance: Int
        if !sortByCadence && useMultiChordMese {
            // Re-center both chord degrees around mese as degree 0
            let degree1FromMese = (chord1.rootDegree - meseDegree + 7) % 7
            let degree2FromMese = (chord2.rootDegree - meseDegree + 7) % 7
            // Calculate distance between re-centered degrees
            let dist = (degree2FromMese - degree1FromMese + 7) % 7
            print("RootMovement: Using MESE: \(chord1.rootDegree)→\(chord2.rootDegree), re-centered: \(degree1FromMese)→\(degree2FromMese) (meseDegree=\(meseDegree)), distance=\(dist)")
            degreeDistance = dist
        } else {
            // Traditional: degree 0 is tonic (first string)
            let dist = (chord2.rootDegree - chord1.rootDegree + 7) % 7
            print("RootMovement: Traditional: \(chord1.rootDegree)→\(chord2.rootDegree), distance=\(dist)")
            degreeDistance = dist
        }
        return ROOT_MOVEMENT_STRENGTH[degreeDistance] ?? 1.0
    }

    func formatResultsForDisplay(progressions: [LyreProgression], sortByCadence: Bool) -> [ProgressionDisplay] {
        var displayList: [ProgressionDisplay] = []

        print("\n=== iOS PROGRESSION ANALYSIS DEBUG ===")
        print("Input progressions: \(progressions.count)")
        print("Sort by cadence: \(sortByCadence)")

        // Identify common progressions first
        let identified = identifyCommonProgressions(progressions: progressions)

        let withNames = identified.filter { $0.commonName != nil }.count
        print("Progressions with cadence names: \(withNames)")

        // Sort if requested
        let sorted = sortByCadence ? identified.sorted { a, b in
            if a.commonName == nil && b.commonName != nil { return false }
            if a.commonName != nil && b.commonName == nil { return true }
            if let aName = a.commonName, let bName = b.commonName, aName != bName {
                return aName < bName
            }
            return a.complexity < b.complexity
        } : identified

        print("After sorting: \(sorted.count)")
        print("\nFirst 10 progressions (before take/prefix):")

        for (rank, prog) in sorted.enumerated() {
            if rank >= 100 {
                break  // Only take first 100 like Android
            }
            let chordSymbols = prog.chords.map { $0.toRomanNumeral() }.joined(separator: " - ")

            if rank < 10 {
                print("  \(rank + 1). \(chordSymbols) | complexity: \(String(format: "%.6f", prog.complexity)) | cadence: \(prog.commonName ?? "none")")
            }

            let noteSequence = prog.voicings.map { voicingToNoteNames($0) }.joined(separator: "  ")

            // Get frequencies
            var allFrequencies: [Double] = []
            var notesPerChord: [Int] = []

            for voicing in prog.voicings {
                let freqs = voicing.stringIndices.compactMap { index -> Double? in
                    let idx = index - 1
                    guard idx >= 0 && idx < frequencies.count else { return nil }
                    return frequencies[idx]
                }
                allFrequencies.append(contentsOf: freqs)
                notesPerChord.append(freqs.count)
            }

            // Calculate cadence analysis for non-Western display
            let cadenceAnalysis = analyzeCadenceCharacteristics(progression: prog)

            displayList.append(ProgressionDisplay(
                rank: rank + 1,
                notes: noteSequence,
                chordSymbols: chordSymbols,
                commonName: prog.commonName,
                complexity: prog.complexity,
                frequencies: allFrequencies,
                notesPerChord: notesPerChord,
                cadenceAnalysis: cadenceAnalysis
            ))
        }

        print("\n=== Total results returned: \(displayList.count) ===\n")

        return displayList
    }

    // Analyze cadence characteristics for non-Western display
    func analyzeCadenceCharacteristics(progression: LyreProgression) -> CadenceAnalysis {
        // Analyze the final two chords for cadence characteristics
        let voicings = progression.voicings
        let chords = progression.chords

        if voicings.count < 2 {
            return CadenceAnalysis(motion: "Static", voiceLeading: "Smooth", harmonicDirection: "Neutral", closureStrength: "Continuous")
        }

        let penultimateVoicing = voicings[voicings.count - 2]
        let finalVoicing = voicings[voicings.count - 1]
        let penultimateChord = chords[chords.count - 2]
        let finalChord = chords[chords.count - 1]

        // 1. ROOT MOTION PATTERN
        // Re-center degrees around mese if using multi-chord mese mode
        let rootDegreeDistance: Int
        if !sortByCadence && useMultiChordMese {
            // Re-center both degrees around mese
            let penultimateDegreeFromMese = (penultimateChord.rootDegree - meseDegree + 7) % 7
            let finalDegreeFromMese = (finalChord.rootDegree - meseDegree + 7) % 7
            rootDegreeDistance = (finalDegreeFromMese - penultimateDegreeFromMese + 7) % 7
        } else {
            // Traditional: use original degrees
            rootDegreeDistance = (finalChord.rootDegree - penultimateChord.rootDegree + 7) % 7
        }

        // Compare actual bass notes (first notes) of voicings, not theoretical root pitch classes
        let penultimateBass = penultimateVoicing.semitones.first ?? penultimateChord.rootSemitone
        let finalBass = finalVoicing.semitones.first ?? finalChord.rootSemitone

        let motion: String
        if penultimateBass == finalBass {
            // Check if bass notes are the same first (handles inversions with same bass)
            motion = "Static"
        } else if rootDegreeDistance == 0 {
            motion = "Static"
        } else if rootDegreeDistance == 3 || rootDegreeDistance == 4 {
            // Distances 3-4 are fourths/fifths (strong intervals)
            motion = finalBass < penultimateBass ? "Strong Descent" : "Ascending Close"
        } else if rootDegreeDistance == 1 || rootDegreeDistance == 2 {
            // Distances 1-2 are seconds/thirds (weak intervals)
            motion = finalBass < penultimateBass ? "Weak Descent" : "Ascending Close"
        } else {
            // Distances 5-6 are sixths/sevenths
            motion = finalBass < penultimateBass ? "Weak Descent" : "Ascending Close"
        }

        // 2. VOICE LEADING CHARACTER
        // Count how many voices move between chords (using actual semitones, not pitch classes)
        let penultimateSemitones = Set(penultimateVoicing.semitones)
        let finalSemitones = Set(finalVoicing.semitones)
        let commonTones = penultimateSemitones.intersection(finalSemitones).count

        // Calculate voices moved from the perspective of the chord with more notes
        let totalVoices = max(penultimateVoicing.semitones.count, finalVoicing.semitones.count)
        let voicesMoved = totalVoices - commonTones

        let voiceLeading: String
        if voicesMoved <= 1 {
            voiceLeading = "Smooth"
        } else if voicesMoved == 2 {
            voiceLeading = "Moderate"
        } else {
            voiceLeading = "Active"
        }

        // 3. HARMONIC DIRECTION
        // Calculate individual chord complexities
        let penultimateComplexity = calculateChordComplexity(voicing: penultimateVoicing, chord: penultimateChord)
        let finalComplexity = calculateChordComplexity(voicing: finalVoicing, chord: finalChord)
        let complexityDelta = finalComplexity - penultimateComplexity

        let harmonicDirection: String
        if complexityDelta < -0.5 {
            harmonicDirection = "Resolving"
        } else if complexityDelta > 0.5 {
            harmonicDirection = "Tensing"
        } else {
            harmonicDirection = "Neutral"
        }

        // 4. CLOSURE STRENGTH
        let isStrongDescent = (motion == "Strong Descent")
        let isResolving = (harmonicDirection == "Resolving")
        let isRootPosition = finalVoicing.inversion == "root"

        let closureStrength: String
        if isStrongDescent && isResolving && isRootPosition {
            closureStrength = "Terminal"
        } else if motion == "Ascending Close" || harmonicDirection == "Tensing" || !isRootPosition {
            closureStrength = "Suspensive"
        } else {
            closureStrength = "Continuous"
        }

        return CadenceAnalysis(motion: motion, voiceLeading: voiceLeading, harmonicDirection: harmonicDirection, closureStrength: closureStrength)
    }

    func identifyCommonProgressions(progressions: [LyreProgression]) -> [LyreProgression] {
        // Two-chord cadence patterns (based on last two chords)
        let twoChordPatterns: [Mode: [[Int]: String]] = [
            .dorios: [  // Phrygian
                [0, 1]: "Phrygian Cadence (i-♭II)",
                [5, 0]: "Plagal Resolution (♭VI-i)",
                [6, 0]: "Subtonic Resolution (♭vii-i)",
                [1, 0]: "Descending Half-Step (♭II-i)",
                [3, 0]: "Subdominant Resolution (iv-i)",
                [2, 0]: "Mediant Resolution (♭III-i)",
                [4, 0]: "Diminished Resolution (v°-i)",
                [0, 5]: "Half Cadence (i-♭VI)",
                [0, 2]: "Rising Mediant (i-♭III)",
                [5, 6]: "Modal Motion (♭VI-♭vii)"
            ],
            .phrygios: [  // Dorian
                [4, 0]: "Minor Authentic (v-i)",
                [3, 0]: "Dorian Plagal (IV-i)",
                [6, 0]: "Dorian Subtonic (♭VII-i)",
                [0, 4]: "Minor Half Cadence (i-v)",
                [2, 0]: "Mediant Resolution (♭III-i)",
                [1, 0]: "Supertonic Resolution (ii-i)",
                [0, 6]: "Rising Subtonic (i-♭VII)",
                [0, 3]: "Subdominant Motion (i-IV)",
                [3, 4]: "Plagal to Dominant (IV-v)"
            ],
            .lydios: [  // Ionian/Major
                [4, 0]: "Authentic Cadence (V-I)",
                [3, 0]: "Plagal Cadence (IV-I)",
                [0, 4]: "Half Cadence (I-V)",
                [4, 5]: "Deceptive Cadence (V-vi)",
                [1, 0]: "Supertonic Resolution (ii-I)",
                [5, 0]: "Submediant Resolution (vi-I)",
                [6, 0]: "Leading Tone Resolution (vii°-I)",
                [0, 3]: "Tonic to Subdominant (I-IV)",
                [0, 5]: "Tonic to Submediant (I-vi)"
            ],
            .mixolydios: [  // Locrian
                [5, 0]: "Locrian Resolution (♭VI-i°)",
                [1, 0]: "Half-Step Descent (♭II-i°)",
                [6, 0]: "Subtonic Resolution (♭vii-i°)",
                [3, 0]: "Subdominant Resolution (iv-i°)",
                [2, 0]: "Mediant Resolution (♭iii-i°)"
            ],
            .hypodorios: [  // Aeolian/Minor
                [4, 0]: "Minor Authentic (v-i)",
                [3, 0]: "Minor Plagal (iv-i)",
                [0, 4]: "Minor Half Cadence (i-v)",
                [6, 0]: "Aeolian Subtonic (♭VII-i)",
                [5, 0]: "Submediant Resolution (♭VI-i)",
                [2, 0]: "Relative Major (♭III-i)",
                [0, 6]: "Rising Subtonic (i-♭VII)",
                [0, 5]: "Rising Submediant (i-♭VI)",
                [5, 6]: "Modal Progression (♭VI-♭VII)"
            ],
            .hypolydios: [  // Lydian
                [4, 0]: "Authentic Cadence (V-I)",
                [1, 0]: "Lydian Characteristic (II-I)",
                [0, 4]: "Half Cadence (I-V)",
                [3, 0]: "Plagal Cadence (IV-I)",
                [0, 1]: "Lydian Rising (I-II)",
                [4, 5]: "Deceptive Cadence (V-vi)"
            ],
            .hypophrygios: [  // Mixolydian
                [4, 0]: "Minor Dominant (v-I)",
                [6, 0]: "Mixolydian Cadence (♭VII-I)",
                [3, 0]: "Plagal Cadence (IV-I)",
                [0, 6]: "Mixolydian Half Cadence (I-♭VII)",
                [0, 4]: "Tonic to Dominant (I-v)",
                [0, 3]: "Tonic to Subdominant (I-IV)",
                [5, 0]: "Submediant Resolution (vi-I)",
                [1, 0]: "Supertonic Resolution (ii-I)"
            ]
        ]

        // Three-chord full progression patterns
        let threeChordPatterns: [Mode: [[Int]: String]] = [
            .dorios: [
                [0, 5, 6]: "Phrygian Descent (i-♭VI-♭vii)",
                [6, 5, 0]: "Descending Resolution (♭vii-♭VI-i)"
            ],
            .phrygios: [
                [0, 3, 4]: "Dorian Progression (i-IV-v)",
                [1, 4, 0]: "Minor Turnaround (ii-v-i)",
                [0, 6, 3]: "Dorian Color (i-♭VII-IV)"
            ],
            .lydios: [
                [0, 3, 4]: "Basic Progression (I-IV-V)",
                [0, 4, 0]: "Tonicization (I-V-I)",
                [1, 4, 0]: "Jazz Turnaround (ii-V-I)",
                [0, 5, 3]: "Descending Thirds (I-vi-IV)"
            ],
            .hypodorios: [
                [0, 3, 4]: "Minor Progression (i-iv-v)",
                [0, 5, 6]: "Aeolian Descent (i-♭VI-♭VII)",
                [0, 6, 3]: "Modal Color (i-♭VII-iv)"
            ],
            .hypolydios: [
                [0, 1, 4]: "Lydian Brightness (I-II-V)",
                [0, 3, 4]: "Basic Progression (I-IV-V)"
            ],
            .hypophrygios: [
                [0, 6, 3]: "Mixolydian Character (I-♭VII-IV)",
                [0, 3, 6]: "Modal Ascent (I-IV-♭VII)"
            ]
        ]

        // Four-chord full progression patterns
        let fourChordPatterns: [Mode: [[Int]: String]] = [
            .dorios: [
                [0, 5, 6, 0]: "Phrygian Loop (i-♭VI-♭vii-i)",
                [0, 1, 5, 0]: "Chromatic Circle (i-♭II-♭VI-i)",
                [6, 5, 0, 1]: "Modal Cycle (♭vii-♭VI-i-♭II)",
                [0, 5, 1, 0]: "Flat-Side Loop (i-♭VI-♭II-i)"
            ],
            .phrygios: [
                [0, 6, 3, 4]: "Dorian Cycle (i-♭VII-IV-v)",
                [0, 3, 6, 0]: "Dorian Loop (i-IV-♭VII-i)"
            ],
            .lydios: [
                [0, 4, 5, 3]: "Pop Progression (I-V-vi-IV)",
                [0, 5, 3, 4]: "50s Progression (I-vi-IV-V)",
                [5, 3, 0, 4]: "Sensitive Progression (vi-IV-I-V)",
                [0, 3, 4, 0]: "Circle of Fifths (I-IV-V-I)",
                [1, 4, 0, 0]: "Extended Turnaround (ii-V-I-I)"
            ],
            .mixolydios: [
                [0, 1, 5, 0]: "Locrian Cycle (i°-♭II-♭VI-i°)"
            ],
            .hypodorios: [
                [0, 5, 6, 3]: "Aeolian Progression (i-♭VI-♭VII-iv)",
                [0, 6, 3, 4]: "Minor Modal Cycle (i-♭VII-iv-v)",
                [0, 3, 6, 0]: "Minor Loop (i-iv-♭VII-i)"
            ],
            .hypolydios: [
                [0, 1, 4, 0]: "Lydian Resolution (I-II-V-I)"
            ],
            .hypophrygios: [
                [0, 6, 3, 6]: "Mixolydian Vamp (I-♭VII-IV-♭VII)",
                [0, 3, 6, 0]: "Mixolydian Loop (I-IV-♭VII-I)"
            ]
        ]

        return progressions.map { prog in
            let chordDegrees = prog.chords.map { $0.rootDegree }

            // Transform chord degrees if using mese as tonic
            // When sortByCadence is true (Western cadences), ignore useMultiChordMese
            let degreesForMatching: [Int]
            if !sortByCadence && useMultiChordMese {
                // Re-center degrees around mese as degree 0
                degreesForMatching = chordDegrees.map { ($0 - meseDegree + 7) % 7 }
            } else {
                // Use original degrees (degree 0 is tonic)
                degreesForMatching = chordDegrees
            }

            let allTriads = prog.chords.allSatisfy { $0.size == TRIAD_SIZE }

            if allTriads && degreesForMatching.count >= 2 {
                // Check full progression patterns first (for famous progressions)
                var name: String? = nil

                switch degreesForMatching.count {
                case 3:
                    name = threeChordPatterns[mode]?[degreesForMatching]
                case 4:
                    name = fourChordPatterns[mode]?[degreesForMatching]
                default:
                    break
                }

                // Fall back to cadence (last two chords)
                if name == nil {
                    let lastTwo = Array(degreesForMatching.suffix(2))
                    name = twoChordPatterns[mode]?[lastTwo]
                }

                if let foundName = name {
                    prog.commonName = foundName
                    let degreeInfo: String
                    if !sortByCadence && useMultiChordMese {
                        degreeInfo = "original degrees \(chordDegrees) (transformed to \(degreesForMatching) with mese=\(meseDegree))"
                    } else {
                        degreeInfo = "degrees \(chordDegrees)"
                    }
                    print("CadenceID: Found \(foundName) for \(degreeInfo) in mode \(mode.rawValue)")
                }
            }

            return prog
        }
    }

    func voicingToNoteNames(_ voicing: LyreVoicing) -> String {
        return voicing.semitones.map { semitoneToNoteName(semitone: $0) }.joined(separator: "-")
    }

    func semitoneToNoteName(semitone: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteOrder = ["C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11]

        guard let firstNoteIndex = noteOrder[firstNote] else { return "?" }

        let absoluteSemitone = firstNoteIndex + semitone
        let octave = 4 + (absoluteSemitone / 12)
        let noteIndex = absoluteSemitone % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// Data structures for chord progressions

// Non-Western cadence analysis
struct CadenceAnalysis {
    let motion: String           // Strong Descent, Weak Descent, Ascending Close, Static
    let voiceLeading: String     // Smooth, Moderate, Active
    let harmonicDirection: String // Resolving, Tensing, Neutral
    let closureStrength: String   // Terminal, Suspensive, Continuous
}

struct ProgressionDisplay: Identifiable {
    let id = UUID()
    let rank: Int
    let notes: String
    let chordSymbols: String
    let commonName: String?
    let complexity: Double
    let frequencies: [Double]
    let notesPerChord: [Int]
    let cadenceAnalysis: CadenceAnalysis?
}

// MARK: - Chord Progression View

struct ChordProgressionView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var progressions: [ProgressionDisplay] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String? = nil
    @State private var isPartialResults = false

    // Progression parameters
    @State private var selectedChordSizes: Set<Int> = [3]
    @State private var selectedProgressionLength = 4
    @State private var sortByCadence = false
    @State private var useMultiChordMese = false
    @State private var chordReferenceMode: ChordReferenceMode = .bass

    // Audio playback state
    @State private var audioManager: ChordProgressionAudioManager?
    @State private var currentlyPlaying: Int? = nil

    // Task management for cancellation
    @State private var analysisTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Current Settings Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Settings")
                                .font(.headline)
                                .padding(.bottom, 4)

                            Text("Scale Type: \(settings.scaleTypeCategory.rawValue)")
                            Text("Mode: \(settings.selectedMode.rawValue)")
                            Text("First Note: \(settings.firstNote)")
                            Text("Number of Strings: \(settings.numberOfStrings)")
                            Text("Temperament: \(settings.temperament.rawValue)")
                            Text("Octave Offset: \(settings.octaveOffset)")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        // Error message if invalid settings
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }

                        // Analysis options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analysis Options")
                                .font(.headline)

                            // Chord size selection
                            Text("Notes per chord (select multiple):")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                ForEach([2, 3, 4], id: \.self) { size in
                                    Button(action: {
                                        toggleChordSize(size)
                                    }) {
                                        Text("\(size) notes")
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedChordSizes.contains(size) ? Color.blue : Color.gray.opacity(0.3))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            // Progression length selection
                            Text("Chords in sequence:")
                                .font(.subheadline)
                                .padding(.top, 8)
                            HStack(spacing: 8) {
                                ForEach([2, 3, 4, 5], id: \.self) { length in
                                    Button(action: {
                                        selectedProgressionLength = length
                                    }) {
                                        Text("\(length)")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .background(selectedProgressionLength == length ? Color.blue : Color.gray.opacity(0.3))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            // Sort by cadence toggle
                            Toggle("Prioritize common modern Western cadences (Just)", isOn: $sortByCadence)
                                .padding(.top, 8)

                            // Multi-chord mese toggle
                            HStack {
                                Toggle("Multi-chord metrics: use mese (middle string) as tonic:", isOn: $useMultiChordMese)
                                    .disabled(sortByCadence)
                                    .foregroundColor(sortByCadence ? Color.gray : Color.primary)
                            }
                            .padding(.top, 8)

                            // Single chord reference frequency
                            Text("Single chord reference frequency:")
                                .font(.subheadline)
                                .foregroundColor(sortByCadence ? Color.gray : Color.primary)
                                .padding(.top, 8)
                            HStack(spacing: 8) {
                                ForEach([ChordReferenceMode.bass, ChordReferenceMode.middle, ChordReferenceMode.mese], id: \.self) { mode in
                                    Button(action: {
                                        if !sortByCadence {
                                            chordReferenceMode = mode
                                        }
                                    }) {
                                        Text(mode.rawValue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(chordReferenceMode == mode ? Color.blue : Color.gray.opacity(0.3))
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                            .opacity(sortByCadence ? 0.5 : 1.0)
                                    }
                                    .disabled(sortByCadence)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        // Analyze button
                        Button(action: analyzeProgressions) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 8)
                                }
                                Text(isAnalyzing ? "Analyzing..." : "Suggest Chord Progressions")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(errorMessage != nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isAnalyzing || errorMessage != nil)

                        // Partial results warning
                        if isPartialResults {
                            Text("⚠️ Analysis timed out after 30 seconds - showing partial results")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Results
                        if !progressions.isEmpty {
                            Text("Suggested Progressions (\(progressions.count))")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(progressions) { progression in
                                ProgressionRow(
                                    progression: progression,
                                    isPlaying: currentlyPlaying == (progression.rank - 1),
                                    showCadenceLabels: sortByCadence,
                                    onPlay: {
                                        playProgression(progression)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Chord Progression Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        // Stop any playing audio
                        audioManager?.stop()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            checkSettings()
            audioManager = ChordProgressionAudioManager()
        }
        .onDisappear {
            // Cancel any running analysis
            analysisTask?.cancel()
            // Stop audio playback
            audioManager?.stop()
        }
    }

    private func toggleChordSize(_ size: Int) {
        if selectedChordSizes.contains(size) {
            // Don't allow deselecting if it's the last one
            if selectedChordSizes.count > 1 {
                selectedChordSizes.remove(size)
            }
        } else {
            selectedChordSizes.insert(size)
        }
    }

    private func checkSettings() {
        if settings.scaleTypeCategory != .modes {
            errorMessage = "Chord progressions only available for Modes scale type"
        } else if settings.temperament == .equal {
            errorMessage = "Non-rational tunings not supported, try Just Intonation"
        } else if settings.numberOfStrings < 4 {
            errorMessage = "Minimum 4 strings required for chord progression analysis"
        } else if settings.numberOfStrings > 9 {
            errorMessage = "Maximum 9 strings supported for chord progression analysis"
        } else {
            errorMessage = nil
        }
    }

    private func analyzeProgressions() {
        guard errorMessage == nil else { return }

        // Cancel any existing analysis
        analysisTask?.cancel()

        isAnalyzing = true
        isPartialResults = false
        progressions = []

        // Create analysis task (timeout handled inside generateProgressions like Android)
        analysisTask = Task {
            do {
                let result = try await self.performAnalysis()

                await MainActor.run {
                    self.progressions = result
                    self.isAnalyzing = false
                    // isPartialResults is set inside performAnalysis if timeout occurred
                }
            } catch is CancellationError {
                // Manual cancellation
                await MainActor.run {
                    self.isAnalyzing = false
                }
            } catch {
                // Other errors
                await MainActor.run {
                    self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }

    private func performAnalysis() async throws -> [ProgressionDisplay] {
        return try await Task.detached(priority: .userInitiated) {
            // Check for cancellation before heavy work
            try Task.checkCancellation()

            let scaleData = await Task { @MainActor in
                self.settings.calculateScale()
            }.value

            try Task.checkCancellation()

            // Create chord analyzer
            let chordAnalyzer = LyreChordAnalyzer(scaleData: scaleData)

            try Task.checkCancellation()

            // Get current settings
            let mode = await MainActor.run { self.settings.selectedMode }
            let firstNote = await MainActor.run { self.settings.firstNote }
            let numStrings = await MainActor.run { self.settings.numberOfStrings }
            let temperament = await MainActor.run { self.settings.temperament }
            let octaveOffset = await MainActor.run { self.settings.octaveOffset }
            let progressionLength = await MainActor.run { self.selectedProgressionLength }
            let chordSizes = await MainActor.run { self.selectedChordSizes }
            let sortByCadence = await MainActor.run { self.sortByCadence }
            let useMultiChordMese = await MainActor.run { self.useMultiChordMese }
            let chordReferenceMode = await MainActor.run { self.chordReferenceMode }

            try Task.checkCancellation()

            // Create progression analyzer
            let analyzer = LyreProgressionAnalyzer(
                mode: mode,
                firstNote: firstNote,
                numStrings: numStrings,
                temperament: temperament,
                octaveOffset: octaveOffset,
                scaleData: scaleData,
                chordAnalyzer: chordAnalyzer,
                useMultiChordMese: useMultiChordMese,
                chordReferenceMode: chordReferenceMode,
                sortByCadence: sortByCadence
            )

            try Task.checkCancellation()

            // Generate progressions with timeout like Android (30 seconds)
            let startTime = Date()
            let maxResults = min(100, numStrings <= 5 ? 200 : 100)
            let (results, isPartial) = analyzer.generateProgressions(
                length: progressionLength,
                chordSizes: chordSizes,
                maxResults: maxResults,
                timeoutSeconds: 30.0,
                startTime: startTime
            )

            try Task.checkCancellation()

            // Update partial results flag on main actor
            if isPartial {
                await MainActor.run {
                    self.isPartialResults = true
                }
            }

            // Format for display
            let displayResults = analyzer.formatResultsForDisplay(
                progressions: results,
                sortByCadence: sortByCadence
            )

            return displayResults
        }.value
    }

    enum AnalysisError: Error {
        case invalidScaleData
        case analyzerCreationFailed
        case timeout
    }

    private func playProgression(_ progression: ProgressionDisplay) {
        guard let audio = audioManager else { return }

        currentlyPlaying = progression.rank - 1

        Task {
            do {
                try await audio.playProgression(
                    frequencies: progression.frequencies,
                    notesPerChord: progression.notesPerChord
                )
                currentlyPlaying = nil
            } catch {
                print("Error playing progression: \(error)")
                currentlyPlaying = nil
            }
        }
    }
}

// View that wraps chords properly - breaks only between chords, not within them
struct ChordSymbolsView: View {
    let text: String
    let isLarge: Bool

    var body: some View {
        // Chord symbols use " - " separator, notes use "  " separator
        let separator = isLarge ? " - " : "  "
        let chords = text.components(separatedBy: separator).filter { !$0.isEmpty }

        FlowLayout(spacing: isLarge ? 4 : 8) {
            ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                HStack(spacing: 4) {
                    Text(chord)
                        .font(.system(isLarge ? .body : .caption, design: .monospaced))
                        .foregroundColor(isLarge ? .blue : .gray)
                    // Add dash separator for roman numerals (but not after last one)
                    if isLarge && index < chords.count - 1 {
                        Text("-")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// FlowLayout that wraps items horizontally
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    // Start new line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct ProgressionRow: View {
    let progression: ProgressionDisplay
    let isPlaying: Bool
    let showCadenceLabels: Bool
    let onPlay: () -> Void

    @State private var showCopiedAlert = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Play button
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .frame(width: 40)

            // Rank
            Text("\(progression.rank)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 30, alignment: .leading)

            // Chord symbols and notes
            VStack(alignment: .leading, spacing: 2) {
                if showCadenceLabels {
                    // Western cadence mode
                    if let name = progression.commonName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    ChordSymbolsView(text: progression.chordSymbols, isLarge: true)
                } else {
                    // Non-Western cadence analysis mode
                    if let analysis = progression.cadenceAnalysis {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Text("Motion: ").foregroundColor(.gray)
                                Text(analysis.motion).foregroundColor(.blue)
                            }
                            .font(.system(.caption, design: .monospaced))

                            HStack(spacing: 0) {
                                Text("Voice: ").foregroundColor(.gray)
                                Text(analysis.voiceLeading).foregroundColor(.blue)
                            }
                            .font(.system(.caption, design: .monospaced))

                            HStack(spacing: 0) {
                                Text("Direction: ").foregroundColor(.gray)
                                Text(analysis.harmonicDirection).foregroundColor(.blue)
                            }
                            .font(.system(.caption, design: .monospaced))

                            HStack(spacing: 0) {
                                Text("Closure: ").foregroundColor(.gray)
                                Text(analysis.closureStrength).foregroundColor(.blue)
                            }
                            .font(.system(.caption, design: .monospaced))
                        }
                    }
                }

                // Display each chord on separate lines
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(progression.notes.components(separatedBy: "  ").enumerated()), id: \.offset) { index, chordNotes in
                        ChordSymbolsView(text: chordNotes, isLarge: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Complexity
            Text(String(format: "%.4f", progression.complexity))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onLongPressGesture {
            // Copy to clipboard
            let textToCopy = "\(progression.chordSymbols)\n\(progression.notes)"
            UIPasteboard.general.string = textToCopy
            showCopiedAlert = true

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Progression copied to clipboard")
        }
    }
}

// Audio manager for chord progression playback
class ChordProgressionAudioManager {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlaying = false
    private let audioFormat: AVAudioFormat

    init() {
        // Create a consistent audio format - stereo at 44100 Hz
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat)

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func playProgression(frequencies: [Double], notesPerChord: [Int]) async throws {
        // Validate input
        guard !frequencies.isEmpty, !notesPerChord.isEmpty else {
            throw AudioError.invalidInput
        }

        // Check that we have enough frequencies for all chords
        let totalNotes = notesPerChord.reduce(0, +)
        guard totalNotes == frequencies.count else {
            throw AudioError.mismatchedData
        }

        // Validate frequency values (must be positive and reasonable)
        guard frequencies.allSatisfy({ $0 > 0 && $0 < 20000 }) else {
            throw AudioError.invalidFrequency
        }

        stop()

        let sampleRate = 44100.0
        let noteDuration = 0.6 // seconds per chord
        let pauseDuration = 0.05 // seconds between chords

        // Generate audio for each chord
        var freqIndex = 0
        for (chordIdx, numNotes) in notesPerChord.enumerated() {
            // Safety check for array bounds
            guard freqIndex + numNotes <= frequencies.count else {
                print("Warning: Insufficient frequencies for chord \(chordIdx), stopping playback")
                break
            }

            let chordFreqs = Array(frequencies[freqIndex..<(freqIndex + numNotes)])
            freqIndex += numNotes

            // Generate chord audio
            let chordBuffer = generateChord(frequencies: chordFreqs, duration: noteDuration, sampleRate: sampleRate)

            // Play chord
            await MainActor.run {
                playerNode.scheduleBuffer(chordBuffer, at: nil, options: [])
                if !isPlaying {
                    playerNode.play()
                    isPlaying = true
                }
            }

            // Wait for chord to finish (check for cancellation)
            try await Task.sleep(nanoseconds: UInt64((noteDuration + pauseDuration) * 1_000_000_000))
        }
    }

    enum AudioError: Error {
        case invalidInput
        case mismatchedData
        case invalidFrequency
        case bufferCreationFailed
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
    }

    private func generateChord(frequencies: [Double], duration: Double, sampleRate: Double) -> AVAudioPCMBuffer {
        let numSamples = Int(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numSamples))!
        buffer.frameLength = AVAudioFrameCount(numSamples)

        guard let channelData = buffer.floatChannelData else { return buffer }

        let fadeInSamples = Int(0.01 * sampleRate)
        let fadeOutSamples = Int(0.05 * sampleRate)
        let amplitude = Float(0.7) / Float(frequencies.count)

        for i in 0..<numSamples {
            var mixedSample: Float = 0.0

            // Mix all frequencies
            for frequency in frequencies {
                let angle = 2.0 * Double.pi * Double(i) * frequency / sampleRate
                mixedSample += Float(sin(angle)) * amplitude
            }

            // Apply fade in
            if i < fadeInSamples {
                mixedSample *= Float(i) / Float(fadeInSamples)
            }
            // Apply fade out
            else if i >= numSamples - fadeOutSamples {
                mixedSample *= Float(numSamples - i) / Float(fadeOutSamples)
            }

            // Write to both channels (stereo)
            channelData[0][i] = mixedSample  // Left channel
            channelData[1][i] = mixedSample  // Right channel
        }

        return buffer
    }
}

// MARK: - Chord Analysis View

struct ChordAnalysisView: View {
    @ObservedObject var settings: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var analysisResult = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Current Settings Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Settings")
                                .font(.headline)
                                .padding(.bottom, 4)

                            Text("Scale Type: \(settings.scaleTypeCategory.rawValue)")
                            if settings.scaleTypeCategory == .modes {
                                Text("Mode: \(settings.selectedMode.rawValue)")
                            }
                            if settings.scaleTypeCategory == .genres {
                                Text("Genus: \(settings.selectedGenus.rawValue)")
                            }
                            Text("First Note: \(settings.firstNote)")
                            Text("Number of Strings: \(settings.numberOfStrings)")
                            Text("Temperament: \(settings.temperament.rawValue)")
                            Text("Octave Offset: \(settings.octaveOffset)")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                        // Error message for Equal temperament
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }

                        // Analyze button
                        Button(action: analyzeChords) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 8)
                                }
                                Text(isAnalyzing ? "Analyzing..." : "Analyze Chords")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background((settings.temperament == .equal || settings.numberOfStrings > 13) ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isAnalyzing || settings.temperament == .equal || settings.numberOfStrings > 13)

                        // Results
                        if !analysisResult.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Analysis Results")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: copyToClipboard) {
                                        HStack {
                                            Image(systemName: "doc.on.doc")
                                            Text("Copy")
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                }

                                ScrollView([.horizontal, .vertical]) {
                                    Text(analysisResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding()
                                }
                                .frame(maxHeight: 500)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)

                                Text("Long press to select text • Scroll horizontally and vertically")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Chord Analysis Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            checkTemperament()
        }
        .onChange(of: settings.numberOfStrings) {
            checkTemperament()
        }
    }

    private func checkTemperament() {
        if settings.temperament == .equal {
            errorMessage = "Non-rational tunings not supported, try Just Intonation"
        } else if settings.numberOfStrings > 13 {
            errorMessage = "Maximum 13 strings supported for chord analysis"
        } else {
            errorMessage = nil
        }
    }

    private func analyzeChords() {
        guard settings.temperament != .equal && settings.numberOfStrings <= 13 else { return }

        isAnalyzing = true
        errorMessage = nil

        // Run analysis on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let scaleData = settings.calculateScale()

            let analyzer = LyreChordAnalyzer(scaleData: scaleData)
            let results = analyzer.analyzeAllChords()
            let formatted = analyzer.formatResults(results)

            DispatchQueue.main.async {
                analysisResult = formatted
                isAnalyzing = false
            }
        }
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = analysisResult
        #endif
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
    @State private var showingChordAnalysis = false
    @State private var showingChordProgression = false

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

                // Chord Analysis Tool Button
                Button(action: {
                    showingChordAnalysis = true
                }) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 20))
                        Text("Chord Analysis Tool")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                }

                // Chord Progression Tool Button (only for Modes) - HIDDEN FOR NOW
                /*
                if settings.scaleTypeCategory == .modes {
                    Button(action: {
                        showingChordProgression = true
                    }) {
                        HStack {
                            Image(systemName: "music.quarternote.3")
                                .font(.system(size: 20))
                            Text("Suggest Chord Progressions (Beta)")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                    }
                }
                */

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
                        .onChange(of: settings.selectedProfileName) { oldValue, newValue in
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
                            set: { newValue in
                                Task { @MainActor in
                                    settings.numberOfStrings = Int(newValue)
                                }
                            }
                        ), in: 4...24, step: 1)
                    }

                    HStack {
                        Text("Octave Offset: \(settings.octaveOffset)")
                        Slider(value: Binding(
                            get: { Double(settings.octaveOffset) },
                            set: { newValue in
                                Task { @MainActor in
                                    settings.octaveOffset = Int(newValue)
                                }
                            }
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
                            set: { newValue in
                                Task { @MainActor in
                                    settings.tolerance = Int(newValue)
                                }
                            }
                        ), in: 1...10, step: 1)
                    }

                    HStack {
                        Text("High-pass Filter: \(settings.highPassFilter) Hz")
                        Slider(value: Binding(
                            get: { Double(settings.highPassFilter) },
                            set: { newValue in
                                Task { @MainActor in
                                    settings.highPassFilter = Int(newValue)
                                }
                            }
                        ), in: 0...500, step: 5)
                    }

                    HStack {
                        Text("Noise Gate: \(Int(settings.noiseGate * 100))%")
                        Slider(value: Binding(
                            get: { settings.noiseGate },
                            set: { newValue in
                                Task { @MainActor in
                                    settings.noiseGate = newValue
                                }
                            }
                        ), in: 0...0.8, step: 0.01)
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
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("\(version) (\(build))")
                                .foregroundColor(.secondary)
                        } else {
                            Text("3.0.10 (3)")
                                .foregroundColor(.secondary)
                        }
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
        .sheet(isPresented: $showingChordAnalysis) {
            ChordAnalysisView(settings: settings)
        }
        .sheet(isPresented: $showingChordProgression) {
            ChordProgressionView(settings: settings)
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
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
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