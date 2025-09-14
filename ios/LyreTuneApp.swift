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

    var intervals: [Double] {
        switch self {
        case .mixolydios:
            return [1.0, 9.0/8, 5.0/4, 4.0/3, 3.0/2, 5.0/3, 15.0/8]
        case .hypodorios:
            return [1.0, 9.0/8, 6.0/5, 4.0/3, 3.0/2, 8.0/5, 16.0/9]
        case .lydios:
            return [1.0, 9.0/8, 81.0/64, 4.0/3, 3.0/2, 27.0/16, 243.0/128]
        case .phrygios:
            return [1.0, 256.0/243, 32.0/27, 4.0/3, 3.0/2, 128.0/81, 16.0/9]
        case .dorios:
            return [1.0, 9.0/8, 32.0/27, 4.0/3, 3.0/2, 27.0/16, 16.0/9]
        case .hypolydios:
            return [1.0, 9.0/8, 5.0/4, 45.0/32, 3.0/2, 5.0/3, 15.0/8]
        case .hypophrygios:
            return [1.0, 16.0/15, 6.0/5, 4.0/3, 3.0/2, 8.0/5, 9.0/5]
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

    var intervals: [Double] {
        switch self {
        case .diatonic:
            return [1.0, 9.0/8, 32.0/27, 4.0/3, 3.0/2, 27.0/16, 16.0/9]
        case .chromatic:
            return [1.0, 256.0/243, 32.0/27, 4.0/3, 3.0/2, 128.0/81, 16.0/9]
        case .enharmonic:
            return [1.0, 256.0/243, 32.0/27, 4.0/3, 3.0/2, 128.0/81, 16.0/9]
        }
    }

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

    private let audioEngine = AVAudioEngine()
    private let fftSize = 16384  // Android default: "Very High"
    private var fftSetup: FFTSetup?
    private var window: [Float] = []

    init() {
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

                // Normalize full spectrum for display (like Android)
                var maxMagnitude: Float = 0
                for mag in magnitudes {
                    if mag > maxMagnitude {
                        maxMagnitude = mag
                    }
                }

                var normalizedFullSpectrum = [Float](repeating: 0, count: fftSize/2)
                if maxMagnitude > 0 {
                    let highPassBin = Int(150.0 * Double(fftSize) / self.sampleRate) // 150 Hz high-pass
                    for i in 0..<fftSize/2 {
                        // Apply high-pass filter
                        if i < highPassBin {
                            normalizedFullSpectrum[i] = 0
                        } else {
                            normalizedFullSpectrum[i] = magnitudes[i] / maxMagnitude
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

                // Find dominant frequency
                if let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset {
                    let freq = Double(maxIndex) * self.sampleRate / Double(self.fftSize)

                    DispatchQueue.main.async {
                        self.spectrum = normalizedMagnitudes
                        self.fullSpectrum = normalizedFullSpectrum
                        self.dominantFrequency = freq
                        self.updateDetectedNote(frequency: freq)
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

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency = 440.0

        let semitonesFromA4 = 12.0 * log2(frequency / a4Frequency)
        let nearestSemitone = round(semitonesFromA4)
        cents = (semitonesFromA4 - nearestSemitone) * 100.0

        let noteIndex = (Int(nearestSemitone) + 57) % 12
        let octave = 4 + Int(nearestSemitone + 0.5) / 12

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

        // Save to UserDefaults with iCloud sync explicitly disabled
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

        // Save to UserDefaults with iCloud sync explicitly disabled
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

    func calculateFrequencies() -> [Double] {
        let baseFrequency = 440.0
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        guard let noteIndex = noteNames.firstIndex(of: firstNote) else {
            return []
        }

        // Calculate base octave (E3 is default, like Android)
        let baseOctave = 3 + octaveOffset
        let semitonesFromA4 = (baseOctave - 4) * 12 + (noteIndex - 9)
        let rootFrequency = baseFrequency * pow(2.0, Double(semitonesFromA4) / 12.0)

        var frequencies: [Double] = []

        // Get intervals based on scale type
        let intervals: [Double]
        switch scaleTypeCategory {
        case .modes:
            intervals = selectedMode.intervals
        case .genres:
            intervals = selectedGenus.intervals
        case .pentatonic:
            intervals = [1.0, 9.0/8, 5.0/4, 3.0/2, 5.0/3] // Pentatonic scale
        case .doubleHarmonic:
            intervals = [1.0, 17.0/16, 5.0/4, 4.0/3, 3.0/2, 8.0/5, 15.0/8] // Double Harmonic
        case .phorminx:
            intervals = [1.0, 9.0/8, 5.0/4, 4.0/3] // Phorminx (4 strings)
        }

        for stringIndex in 0..<numberOfStrings {
            let octaveOffset = stringIndex / intervals.count
            let intervalIndex = stringIndex % intervals.count
            var frequency = rootFrequency * intervals[intervalIndex] * pow(2.0, Double(octaveOffset))

            // Apply temperament adjustment
            frequency = applyTemperament(frequency, stringIndex: stringIndex)

            frequencies.append(frequency)
        }

        return frequencies
    }

    private func applyTemperament(_ frequency: Double, stringIndex: Int) -> Double {
        switch temperament {
        case .equal:
            return frequency
        case .just:
            // Just intonation ratios
            let justRatios = [1.0, 25.0/24, 9.0/8, 6.0/5, 5.0/4, 4.0/3, 45.0/32, 3.0/2, 8.0/5, 5.0/3, 9.0/5, 15.0/8]
            let ratio = justRatios[stringIndex % 12]
            return frequency * ratio / pow(2.0, Double(stringIndex % 12) / 12.0)
        case .justAncient:
            // Ancient just intonation
            return frequency // Already applied in intervals
        case .meantone:
            // Meantone temperament
            let meantoneRatios = [1.0, 1.07, 1.118, 1.196, 1.25, 1.337, 1.398, 1.495, 1.6, 1.672, 1.789, 1.869]
            return frequency * meantoneRatios[stringIndex % 12]
        }
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // FFT Bars - Display full spectrum data at correct frequencies (like Android)
                let sampleRate = 48000.0
                let binToFreq = sampleRate / 16384.0  // Each bin represents ~2.93 Hz (4x better resolution!)
                let minBin = Int(50.0 / binToFreq)  // Start at 50 Hz
                let maxBin = min(Int(2000.0 / binToFreq), fullSpectrum.count - 1)  // End at 2000 Hz

                // Display ALL bins in the visible range (should be about 167 bars)
                ForEach(minBin...maxBin, id: \.self) { index in
                    let frequency = Double(index) * binToFreq
                    let yPos = frequencyToYPosition(frequency, height: geometry.size.height)

                    // Always show a bar, even if magnitude is very small
                    let magnitude = fullSpectrum[index]
                    let barWidth = max(CGFloat(magnitude) * geometry.size.width * 0.8,
                                      magnitude > 0 ? 2 : 0)  // Minimum 2 pixels if there's any signal

                    if barWidth > 0 {
                        Rectangle()
                            .fill(Color.blue.opacity(Double(magnitude) * 0.7 + 0.3))
                            .frame(width: barWidth, height: 1)  // Thin bars to see more detail
                            .position(x: barWidth / 2, y: yPos)
                    }
                }

                // String frequency lines with note labels
                ForEach(Array(stringFrequencies.enumerated()), id: \.offset) { index, freq in
                    if index < stringNotes.count {
                        let yPosition = frequencyToYPosition(freq, height: geometry.size.height)

                        ZStack {
                            // Frequency line
                            Rectangle()
                                .fill(isNearFrequency(freq, dominantFrequency) ? Color.green : Color.yellow.opacity(0.6))
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

        // Use logarithmic scaling for better visual distribution
        let logFreq = log10(frequency)
        let logMin = log10(finalMinFreq)
        let logMax = log10(finalMaxFreq)
        let normalized = (logFreq - logMin) / (logMax - logMin)

        // Invert so high frequencies are at the top
        return CGFloat(1.0 - normalized) * height
    }

    private func isNearFrequency(_ target: Double, _ current: Double) -> Bool {
        guard current > 0 else { return false }
        let cents = 1200.0 * log2(current / target)
        return abs(cents) < 10
    }
}

// MARK: - Main View

struct MainView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var settings = SettingsManager()
    @State private var showingSettings = false
    @State private var stringFrequencies: [Double] = []

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
                        stringNotes: getStringNotes(),
                        dominantFrequency: audioManager.dominantFrequency,
                        showFullSpectrum: settings.showFullSpectrum
                    )
                    .frame(height: 450)
                    .padding()

                    Spacer()

                    // Control button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(audioManager.isRecording ? Color.red : Color.green)
                                .frame(width: 80, height: 80)

                            Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                updateStringFrequencies()
                // Delay audio start to avoid initialization issues
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioManager.startRecording()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings)
                    .onDisappear {
                        updateStringFrequencies()
                    }
            }
        }
    }

    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
        } else {
            audioManager.startRecording()
        }
    }

    private func updateStringFrequencies() {
        stringFrequencies = settings.calculateFrequencies()
    }

    private func getSubtitleText() -> String {
        switch settings.scaleTypeCategory {
        case .modes:
            return "\(settings.selectedMode.rawValue) - \(settings.firstNote)\(3 + settings.octaveOffset)"
        case .genres:
            return "\(settings.selectedGenus.rawValue) - \(settings.firstNote)\(3 + settings.octaveOffset)"
        case .pentatonic:
            return "Pentatonic - \(settings.firstNote)\(3 + settings.octaveOffset)"
        case .doubleHarmonic:
            return "Double Harmonic - \(settings.firstNote)\(3 + settings.octaveOffset)"
        case .phorminx:
            return "Phorminx - \(settings.firstNote)\(3 + settings.octaveOffset)"
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

    private func getStringNotes() -> [String] {
        let frequencies = stringFrequencies
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4Frequency = 440.0

        return frequencies.map { freq in
            let semitonesFromA4 = 12.0 * log2(freq / a4Frequency)
            let nearestSemitone = Int(round(semitonesFromA4))

            let noteIndex = (nearestSemitone + 57) % 12
            let octave = 4 + (nearestSemitone + 9) / 12

            return "\(noteNames[noteIndex])\(octave)"
        }
    }
}


// MARK: - Transposition Tool View

struct TranspositionToolView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var inputText = "A3 E4 E4 C#4 D4 E4 D4 C#4 D4 E4 D4 C#4 B3 A3 B3 G3 A3 C#4 E4 D4 C#4 D4 C#4 A3 B3 G3 A3 C#4 B3 D4 E4 C#4 A3 A3 A3 F#3 E3"
    @State private var transpositionAmount: Double = 0
    @State private var outputText = ""
    @State private var uniqueNotes = ""

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

                // Tools Section
                Section(header: Text("Tools")) {
                    Button(action: {
                        showingTranspositionTool = true
                    }) {
                        HStack {
                            Image(systemName: "music.note.list")
                            Text("Transposition Tool")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // License Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("View License", destination: URL(string: "https://github.com/threedlite/lyretune/blob/main/LICENSE.txt")!)
                        .foregroundColor(.blue)
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
            try session.setCategory(.playAndRecord, mode: .measurement)
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