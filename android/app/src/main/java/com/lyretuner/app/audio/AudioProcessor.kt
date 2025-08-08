package com.lyretuner.app.audio

import org.apache.commons.math3.transform.DftNormalization
import org.apache.commons.math3.transform.FastFourierTransformer
import org.apache.commons.math3.transform.TransformType
import org.apache.commons.math3.complex.Complex
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.*
import android.util.Log

data class AudioData(
    val frequency: Float = 0f,
    val magnitude: Float = 0f,
    val spectrum: List<Float> = emptyList()
)

class AudioProcessor {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val sampleChannel = Channel<FloatArray>(Channel.UNLIMITED)
    
    private val _audioData = MutableStateFlow(AudioData())
    val audioData: StateFlow<AudioData> = _audioData.asStateFlow()
    
    private var _scaleData: ScaleData? = null
    private var _fftSize = 4096
    private var _highPassFilter = 150 // Default 150 Hz
    private var _noiseGate = 0.02f // Default 2%
    private val fft = FastFourierTransformer(DftNormalization.STANDARD)
    
    private var isProcessing = false
    
    init {
        startProcessing()
    }
    
    fun updateScale(scaleData: ScaleData) {
        _scaleData = scaleData
    }
    
    fun setFftSize(size: Int) {
        _fftSize = size
    }
    
    fun setHighPassFilter(frequencyHz: Int) {
        _highPassFilter = frequencyHz
    }
    
    fun setNoiseGate(threshold: Float) {
        _noiseGate = threshold
    }
    
    fun feedAudioSamples(samples: FloatArray) {
        if (samples.size >= 2048) {
            sampleChannel.trySend(samples)
        }
    }
    
    fun startProcessing() {
        if (isProcessing) return
        isProcessing = true
        
        scope.launch {
            for (samples in sampleChannel) {
                processAudioSamples(samples)
            }
        }
    }
    
    fun stopProcessing() {
        isProcessing = false
        scope.cancel()
    }
    
    private suspend fun processAudioSamples(samples: FloatArray) {
        withContext(Dispatchers.Default) {
            try {
                // Ensure we have a power of 2 size for FFT
                val fftSize = nearestPowerOf2(_fftSize)
                val paddedSamples = DoubleArray(fftSize) { i ->
                    if (i < minOf(samples.size, 2048)) samples[i].toDouble() else 0.0
                }
                
                // Perform FFT
                val complexResult = fft.transform(paddedSamples, TransformType.FORWARD)
                
                // Calculate magnitude spectrum and find peak
                val (frequency, magnitude, spectrum) = findPeakFrequency(complexResult, 48000f, fftSize)
                
                // Update audio data
                _audioData.value = AudioData(frequency, magnitude, spectrum)
                
            } catch (e: Exception) {
                // Handle FFT errors gracefully
                _audioData.value = AudioData(0f, 0f, emptyList())
            }
        }
    }
    
    private fun nearestPowerOf2(n: Int): Int {
        var power = 1
        while (power < n) power *= 2
        return power
    }
    
    private fun findPeakFrequency(fftData: Array<Complex>, sampleRate: Float, fftSize: Int): Triple<Float, Float, List<Float>> {
        val binCount = fftSize / 2
        val spectrum = mutableListOf<Float>()
        val binToFreq = sampleRate / fftSize.toFloat()
        
        // Build magnitude spectrum
        val magnitudes = DoubleArray(binCount)
        var maxMagnitude = 0.0
        
        for (i in 0 until binCount) {
            val magnitude = fftData[i].abs()
            magnitudes[i] = magnitude
            if (magnitude > maxMagnitude) {
                maxMagnitude = magnitude
            }
        }
        
        // Normalize spectrum for visualization and apply high-pass filter
        val highPassBin = (_highPassFilter.toFloat() / binToFreq).toInt()
        for (i in 0 until binCount) {
            val normalizedMag = if (maxMagnitude > 0) {
                (magnitudes[i] / maxMagnitude).toFloat()
            } else {
                0f
            }
            // Apply high-pass filter: set magnitudes below filter frequency to zero
            val filteredMag = if (i < highPassBin) 0f else normalizedMag
            spectrum.add(filteredMag)
        }
        
        // Find fundamental frequency using harmonic analysis
        val fundamentalBin = findFundamentalFrequency(magnitudes, binToFreq, maxMagnitude)
        val frequency = fundamentalBin * binToFreq
        
        // Debug logging for frequency detection
        if (frequency > 400 && frequency < 600) { // C5 range
            android.util.Log.d("AudioProcessor", "Detected freq in C range: ${frequency}Hz from bin $fundamentalBin")
        }
        
        
        // Use relative magnitude threshold - normalize to reasonable scale
        val normalizedMagnitude = if (maxMagnitude > 0) {
            // Scale magnitude to a 0-1 range based on reasonable signal levels
            (maxMagnitude / 100.0).toFloat().coerceIn(0f, 1f)
        } else {
            0f
        }
        
        // Apply noise gate - if normalized magnitude is below threshold, return no signal
        if (normalizedMagnitude < _noiseGate) {
            return Triple(0f, 0f, spectrum)
        }
        
        return Triple(frequency, normalizedMagnitude, spectrum)
    }
    
    private fun findFundamentalFrequency(magnitudes: DoubleArray, binToFreq: Float, maxMagnitude: Double): Int {
        val minFreq = _highPassFilter.toDouble() // Use high-pass filter setting
        val maxFreq = 2000.0 // Maximum frequency to consider (2000 Hz) 
        val minBin = (minFreq / binToFreq).toInt().coerceAtLeast(1)
        val maxBin = (maxFreq / binToFreq).toInt().coerceAtMost(magnitudes.size - 1)
        
        // First, find the peak magnitude in our frequency range
        var peakBin = minBin
        var peakMagnitude = magnitudes[minBin]
        for (i in minBin..maxBin) {
            if (magnitudes[i] > peakMagnitude) {
                peakMagnitude = magnitudes[i]
                peakBin = i
            }
        }
        
        // Strongly prefer the dominant peak if it's in a reasonable frequency range
        val peakFreq = peakBin * binToFreq
        if (peakMagnitude > maxMagnitude * 0.6 && peakFreq >= 200f) {
            // Check if there's an even stronger peak at exactly double this frequency
            val doubleBin = peakBin * 2
            val doubleFreqStrength = if (doubleBin < magnitudes.size) magnitudes[doubleBin] else 0.0
            
            // If the double frequency isn't significantly stronger, use this peak
            if (doubleFreqStrength < peakMagnitude * 1.5) {
                android.util.Log.d("AudioProcessor", "Using dominant peak as fundamental: ${peakFreq}Hz (peak: $peakMagnitude, double: $doubleFreqStrength)")
                return peakBin
            } else {
                android.util.Log.d("AudioProcessor", "Skipping peak at ${peakFreq}Hz - stronger double at ${doubleBin * binToFreq}Hz")
            }
        }
        
        var bestFundamental = 0
        var bestScore = 0.0
        
        // Test each potential fundamental frequency
        for (fundamentalBin in minBin..maxBin) {
            val fundamentalMag = magnitudes[fundamentalBin]
            val testFreq = fundamentalBin * binToFreq
            
            // Skip if fundamental is too weak
            if (fundamentalMag < maxMagnitude * 0.1) continue
            
            var harmonicScore = fundamentalMag
            var harmonicCount = 1
            
            // Check harmonics (2nd, 3rd, 4th, 5th)
            // Also check if this frequency is itself a harmonic of a lower frequency
            var isLikelyHarmonic = false
            for (subharmonic in 2..6) {  // Check more subharmonics
                val subharmonicBin = fundamentalBin / subharmonic
                if (subharmonicBin >= minBin && magnitudes[subharmonicBin] > maxMagnitude * 0.2) {  // Much stronger threshold
                    isLikelyHarmonic = true
                    android.util.Log.d("AudioProcessor", "Frequency ${testFreq}Hz rejected as harmonic - found stronger subharmonic at ${subharmonicBin * binToFreq}Hz")
                    break
                }
            }
            
            // Penalize if this frequency appears to be a harmonic
            if (isLikelyHarmonic) {
                harmonicScore *= 0.7
            }
            
            for (harmonic in 2..5) {
                val harmonicBin = fundamentalBin * harmonic
                if (harmonicBin < magnitudes.size) {
                    val harmonicMag = magnitudes[harmonicBin]
                    // Weight harmonics less than fundamental
                    harmonicScore += harmonicMag * (0.8 / harmonic)
                    harmonicCount++
                }
            }
            
            // Normalize score by number of harmonics found
            val avgScore = harmonicScore / harmonicCount
            
            // Give bonus to frequencies near the peak (likely the true fundamental)
            val distanceFromPeak = kotlin.math.abs(fundamentalBin - peakBin).toFloat()
            val proximityBonus = 1.0f + (0.2f * kotlin.math.exp(-distanceFromPeak / 50f))
            val adjustedScore = avgScore * proximityBonus
            
            // Prefer lower frequencies when scores are similar (within 10%)
            // This helps avoid detecting harmonics as fundamentals
            val scoreThreshold = bestScore * 0.9
            
            if (adjustedScore > bestScore || (adjustedScore > scoreThreshold && fundamentalBin < bestFundamental)) {
                // Log when we find a new best candidate
                if (testFreq > 400 && testFreq < 600) {
                    android.util.Log.d("AudioProcessor", "New best candidate: ${testFreq}Hz (bin $fundamentalBin) score=$adjustedScore, was ${bestFundamental * binToFreq}Hz")
                }
                bestScore = adjustedScore
                bestFundamental = fundamentalBin
            }
        }
        
        return bestFundamental
    }
    
    fun getClosestNoteIndex(frequency: Float): Int {
        return _scaleData?.let { scaleData ->
            val result = ScaleCalculator.getClosestNoteIndex(frequency, scaleData)
            android.util.Log.d("AudioProcessor", "getClosestNoteIndex: freq=$frequency, scaleSize=${scaleData.frequencies.size}, result=$result")
            result
        } ?: -1
    }
    
    fun getCentsDifference(frequency: Float, noteIndex: Int): Float {
        return _scaleData?.let { scaleData ->
            if (noteIndex >= 0 && noteIndex < scaleData.frequencies.size) {
                val targetFreq = scaleData.frequencies[noteIndex]
                ScaleCalculator.getCentsDifference(frequency, targetFreq)
            } else 0f
        } ?: 0f
    }
    
    fun getScaleNote(index: Int): String {
        return _scaleData?.let { scaleData ->
            if (index >= 0 && index < scaleData.notes.size) {
                scaleData.notes[index]
            } else ""
        } ?: ""
    }
    
    fun getScaleFrequency(index: Int): Float {
        return _scaleData?.let { scaleData ->
            if (index >= 0 && index < scaleData.frequencies.size) {
                scaleData.frequencies[index]
            } else 0f
        } ?: 0f
    }
    
    fun getSpectrumSize(): Int {
        return _audioData.value.spectrum.size
    }
    
    fun getSpectrumValue(index: Int): Float {
        val spectrum = _audioData.value.spectrum
        return if (index >= 0 && index < spectrum.size) {
            spectrum[index] // Already normalized in findPeakFrequency
        } else 0f
    }
}