package com.lyretune.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.AudioAttributes
import android.media.AudioManager
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.lyretune.app.ui.theme.LyreTuneTheme
import com.lyretune.app.ui.components.SpectrumVisualizer
import com.lyretune.app.audio.AudioProcessor
import com.lyretune.app.audio.ScaleCalculator
import com.lyretune.app.audio.ScaleType
import com.lyretune.app.audio.Mode
import com.lyretune.app.audio.Genus
import com.lyretune.app.audio.Temperament
import kotlin.math.abs
import kotlin.math.pow
import android.util.Log
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var isPlaying = mutableStateOf(false)
    private var recordingThread: Thread? = null
    private var playbackThread: Thread? = null
    private var audioTrack: AudioTrack? = null
    private var settingsUpdateTrigger = mutableStateOf(0)
    
    // New Kotlin audio processor
    private val kotlinAudioProcessor = AudioProcessor()
    
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            startAudioProcessing()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    LyreTuneApp()
                }
            }
        }
        
        checkAudioPermission()
    }
    
    private fun checkAudioPermission() {
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED -> {
                startAudioProcessing()
            }
            else -> {
                requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        }
    }
    
    private fun startAudioProcessing() {
        // Start recording automatically for continuous tuning
        startAudioRecording()
    }
    
    private fun startAudioRecording() {
        val sampleRate = 48000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
        
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord?.startRecording()
                isRecording = true
                
                // Start audio processing in a background thread
                recordingThread = Thread {
                    val buffer = ShortArray(2048) // Back to original size
                    val floatBuffer = FloatArray(2048)
                    
                    while (isRecording && audioRecord != null) {
                        val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                        if (bytesRead > 0) {
                            // Convert short samples to float
                            for (i in 0 until bytesRead) {
                                floatBuffer[i] = buffer[i] / 32768.0f
                            }
                            
                            // Feed to Kotlin audio processor
                            kotlinAudioProcessor.feedAudioSamples(floatBuffer.copyOf(bytesRead))
                        }
                    }
                }
                recordingThread?.start()
            }
        } catch (e: SecurityException) {
            // Handle permission error
        } catch (e: Exception) {
            // Handle other errors
        }
    }
    
    private fun stopAudioRecording() {
        isRecording = false
        audioRecord?.stop()
        recordingThread?.join(1000) // Wait up to 1 second for thread to finish
        recordingThread = null
    }
    
    private fun playStringTones() {
        
        // Stop any existing playback
        stopPlayback()
        
        isPlaying.value = true
        
        playbackThread = Thread {
            val sampleRate = 48000
            val bufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .build()
                
            audioTrack?.play()
            
            // Get number of strings from shared preferences
            val numStrings = getSharedPreferences("lyretune_settings", MODE_PRIVATE)
                .getInt("num_strings", 7)
            
            // Play each string frequency in descending order (highest to lowest)
            for (i in (numStrings - 1) downTo 0) {
                if (!isPlaying.value) break
                
                val frequency = kotlinAudioProcessor.getScaleFrequency(i)
                if (frequency > 0) {
                    val noteName = kotlinAudioProcessor.getScaleNote(i)
                    android.util.Log.d("LyreTune", "Playing string $i: $noteName at $frequency Hz")
                    playLyreTone(frequency, 1200) // Play for 1.2 seconds
                    Thread.sleep(150) // Short pause between notes
                }
            }
            
            isPlaying.value = false
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        }
        
        playbackThread?.start()
    }
    
    private fun playLyreTone(frequency: Float, durationMs: Int) {
        val sampleRate = 48000
        val numSamples = sampleRate * durationMs / 1000
        val buffer = ShortArray(numSamples)
        
        // Generate lyre-like tone with harmonics and decay
        for (i in 0 until numSamples) {
            val t = i.toFloat() / sampleRate
            val decayFactor = Math.exp(-t * 0.8).toFloat() // Exponential decay
            
            // Fundamental frequency
            val fundamental = Math.sin(2.0 * Math.PI * frequency * t)
            
            // Add harmonics to create lyre-like timbre
            val harmonic2 = 0.6 * Math.sin(2.0 * Math.PI * frequency * 2 * t) // Second harmonic
            val harmonic3 = 0.4 * Math.sin(2.0 * Math.PI * frequency * 3 * t) // Third harmonic
            val harmonic4 = 0.2 * Math.sin(2.0 * Math.PI * frequency * 4 * t) // Fourth harmonic
            val harmonic5 = 0.1 * Math.sin(2.0 * Math.PI * frequency * 5 * t) // Fifth harmonic
            
            // Combine all harmonics
            val sample = (fundamental + harmonic2 + harmonic3 + harmonic4 + harmonic5) * decayFactor
            
            // Apply amplitude envelope and convert to short
            val amplitude = 0.3 * sample // Reduce overall volume
            buffer[i] = (amplitude * 32767).coerceIn(-32767.0, 32767.0).toInt().toShort()
        }
        
        audioTrack?.write(buffer, 0, buffer.size)
    }
    
    private fun stopPlayback() {
        isPlaying.value = false
        playbackThread?.join(1000)
        playbackThread = null
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }
    
    private fun togglePlayPause() {
        if (isPlaying.value) {
            stopPlayback()
        } else {
            playStringTones()
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Trigger settings reload
        settingsUpdateTrigger.value = settingsUpdateTrigger.value + 1
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopPlayback()
        stopAudioRecording()
        audioRecord?.release()
        audioRecord = null
        
        // Stop Kotlin audio processor
        kotlinAudioProcessor.stopProcessing()
    }
    
    @OptIn(ExperimentalMaterial3Api::class)
    @Composable
    fun LyreTuneApp() {
        var frequency by remember { mutableStateOf(0f) }
        var magnitude by remember { mutableStateOf(0f) }
        var closestNoteIndex by remember { mutableStateOf(-1) }
        var centsDifference by remember { mutableStateOf(0f) }
        var spectrumData by remember { mutableStateOf(listOf<Float>()) }
        
        // String highlighting persistence state
        var persistentInTuneIndex by remember { mutableStateOf(-1) }
        var lastInTuneTime by remember { mutableStateOf(0L) }
        
        // Card persistence state - for stable display
        var cardIsGreen by remember { mutableStateOf(false) }
        var lastGreenTime by remember { mutableStateOf(0L) }
        var lastDetectedNote by remember { mutableStateOf("") }
        var lastNoteChangeTime by remember { mutableStateOf(0L) }
        var persistentFrequency by remember { mutableStateOf(0f) }
        var persistentNote by remember { mutableStateOf("") }
        var persistentCents by remember { mutableStateOf(0f) }
        
        // Load magnitude scale from SharedPreferences
        val sharedPrefs = getSharedPreferences("lyretune_settings", MODE_PRIVATE)
        val updateTrigger by settingsUpdateTrigger
        val magnitudeValues = listOf(1f, 5f, 10f, 20f, 50f, 100f)
        var magnitudeScaleIndex by remember { 
            mutableStateOf(
                try {
                    sharedPrefs.getInt("magnitude_scale", 1) // Default to 5 (index 1)
                } catch (e: ClassCastException) {
                    // Handle case where it was stored as Float - clear and use default
                    sharedPrefs.edit().remove("magnitude_scale").apply()
                    1
                }
            )
        }
        val magnitudeScale = magnitudeValues[magnitudeScaleIndex.coerceIn(0, magnitudeValues.size - 1)]
        
        // Update magnitude scale when settings change
        LaunchedEffect(updateTrigger) {
            magnitudeScaleIndex = try {
                sharedPrefs.getInt("magnitude_scale", 1)
            } catch (e: ClassCastException) {
                sharedPrefs.edit().remove("magnitude_scale").apply()
                1
            }
        }
        
        // Make magnitude scale reactive to changes
        val currentMagnitudeScale = if (updateTrigger >= 0) {
            magnitudeValues[magnitudeScaleIndex.coerceIn(0, magnitudeValues.size - 1)]
        } else {
            magnitudeScale
        }
        
        // Load all settings from SharedPreferences
        val scaleType = remember(updateTrigger) { sharedPrefs.getInt("scale_type", 0) } // Modes
        val mode = remember(updateTrigger) { sharedPrefs.getInt("mode", 4) } // Dorios
        val genus = remember(updateTrigger) { sharedPrefs.getInt("genus", 0) } // Diatonic
        val firstNote = remember(updateTrigger) { sharedPrefs.getString("first_note", "E") ?: "E" }
        val numStrings = remember(updateTrigger) { sharedPrefs.getInt("num_strings", 7) }
        val temperament = remember(updateTrigger) { sharedPrefs.getInt("temperament", 2) } // Just Ancient
        val octaveOffset = remember(updateTrigger) { sharedPrefs.getInt("octave_offset", 0) }
        val fftResolution = remember(updateTrigger) { 
            val fftIndex = sharedPrefs.getInt("fft_resolution", 5) // Default to maximum resolution
            when(fftIndex) {
                0 -> 2048
                1 -> 4096 
                2 -> 8192
                3 -> 16384
                4 -> 32768
                5 -> 65536
                else -> 65536
            }
        }
        val showFullSpectrum = remember(updateTrigger) { sharedPrefs.getBoolean("show_full_spectrum", false) }
        val tolerance = remember(updateTrigger) { sharedPrefs.getInt("tolerance", 3) }
        val highPassFilter = remember(updateTrigger) { sharedPrefs.getInt("high_pass_filter", 150) }
        val noiseGate = remember(updateTrigger) { sharedPrefs.getFloat("noise_gate", 0.30f) }
        
        // Update scale when needed
        LaunchedEffect(scaleType, mode, genus, firstNote, numStrings, temperament, octaveOffset, fftResolution, noiseGate, highPassFilter) {
            // Update Kotlin audio processor
            val kotlinScaleType = when (scaleType) {
                0 -> ScaleType.MODES
                1 -> ScaleType.GENRES
                2 -> ScaleType.PENTATONIC
                3 -> ScaleType.DOUBLE_HARMONIC
                4 -> ScaleType.PHORMINX
                else -> ScaleType.MODES
            }
            
            val kotlinMode = when (mode) {
                0 -> Mode.MIXOLYDIOS
                1 -> Mode.HYPODORIOS
                2 -> Mode.LYDIOS
                3 -> Mode.PHRYGIOS
                4 -> Mode.DORIOS
                5 -> Mode.HYPOLYDIOS
                6 -> Mode.HYPOPHRYGIOS
                else -> Mode.DORIOS
            }
            
            val kotlinGenus = when (genus) {
                0 -> Genus.DIATONIC
                1 -> Genus.CHROMATIC
                2 -> Genus.ENHARMONIC
                else -> Genus.DIATONIC
            }
            
            val kotlinTemperament = when (temperament) {
                0 -> Temperament.EQUAL
                1 -> Temperament.JUST
                2 -> Temperament.JUST_ANCIENT
                3 -> Temperament.MEANTONE
                else -> Temperament.JUST
            }
            
            val scaleData = ScaleCalculator.calculateScale(
                kotlinScaleType,
                if (kotlinScaleType == ScaleType.MODES) kotlinMode else null,
                if (kotlinScaleType == ScaleType.GENRES) kotlinGenus else null,
                firstNote,
                numStrings,
                kotlinTemperament,
                octaveOffset
            )
            
            kotlinAudioProcessor.updateScale(scaleData)
            kotlinAudioProcessor.setFftSize(fftResolution)
            kotlinAudioProcessor.setHighPassFilter(highPassFilter)
            kotlinAudioProcessor.setNoiseGate(noiseGate)
            
            // Debug: Log all scale frequencies
            for (i in 0 until numStrings) {
                val freq = kotlinAudioProcessor.getScaleFrequency(i)
                val note = kotlinAudioProcessor.getScaleNote(i)
                android.util.Log.d("LyreTune", "Scale[$i]: $note = $freq Hz")
            }
        }
        
        // Get audio data from Kotlin processor
        val audioData by kotlinAudioProcessor.audioData.collectAsStateWithLifecycle()
        
        // Update state based on audio data
        LaunchedEffect(audioData) {
            val currentFreq = audioData.frequency
            magnitude = audioData.magnitude
            
            // Only update frequency display if magnitude is above noise gate and threshold
            if (magnitude > noiseGate && currentFreq > 20f) {
                frequency = currentFreq
                closestNoteIndex = kotlinAudioProcessor.getClosestNoteIndex(frequency)
                if (closestNoteIndex >= 0) {
                    centsDifference = kotlinAudioProcessor.getCentsDifference(frequency, closestNoteIndex)
                    
                    // Debug logging for all note detection
                    val noteName = kotlinAudioProcessor.getScaleNote(closestNoteIndex)
                    android.util.Log.d("LyreTune", "Detected $noteName: freq=$frequency Hz, index=$closestNoteIndex, cents=$centsDifference, magnitude=$magnitude")
                    
                    // Special logging when detecting wrong note
                    if (frequency > 500 && frequency < 540 && noteName == "E4") {
                        android.util.Log.e("LyreTune", "ERROR: Detecting E4 when freq is ${frequency}Hz (should be C5!)")
                    }
                    
                    // Log all scale frequencies for debugging
                    val allStringFreqs = (0 until numStrings).map { kotlinAudioProcessor.getScaleFrequency(it) }
                    val distances = allStringFreqs.map { kotlin.math.abs(frequency - it) }
                    val minDistance = distances.minOrNull() ?: Float.MAX_VALUE
                    val calculatedIndex = distances.indexOf(minDistance)
                    android.util.Log.d("LyreTune", "Frequency distances: ${distances.joinToString(", ")} | Min: $minDistance at index $calculatedIndex (reported: $closestNoteIndex)")
                    
                    // Update persistent display values
                    persistentFrequency = frequency
                    persistentNote = noteName
                    persistentCents = centsDifference
                    
                    // Check if note changed
                    if (noteName != lastDetectedNote && noteName.isNotEmpty()) {
                        val currentTime = System.currentTimeMillis()
                        val timeSinceGreen = currentTime - lastGreenTime
                        
                        // NEVER reset green state if we're within 3 seconds of going green
                        // Just update the note being displayed but keep it green
                        if (timeSinceGreen < 3000 && cardIsGreen) {
                            android.util.Log.d("LyreTune", "Note changed from $lastDetectedNote to $noteName during green period - keeping green")
                            // Don't reset cardIsGreen, just update the note
                        } else if (timeSinceGreen >= 3000) {
                            // Only after 3 seconds can we reset green state for note changes
                            android.util.Log.d("LyreTune", "Note changed from $lastDetectedNote to $noteName after green period - can reset")
                            cardIsGreen = false
                        }
                        lastDetectedNote = noteName
                    }
                    
                    // Green box state is now controlled by SpectrumVisualizer callback
                    // No need for duplicate peak-finding logic here
                    
                    // Check if string is in tune and set persistent highlighting  
                    val stringFreqs = (0 until numStrings).map { kotlinAudioProcessor.getScaleFrequency(it) }
                    if (closestNoteIndex < stringFreqs.size) {
                        val targetFreq = stringFreqs[closestNoteIndex]
                        val frequencyDifference = abs(frequency - targetFreq)
                        if (frequencyDifference < tolerance) {
                            persistentInTuneIndex = closestNoteIndex
                            lastInTuneTime = System.currentTimeMillis()
                        }
                    }
                }
            } else {
                // Clear display when signal is too weak
                frequency = 0f
                closestNoteIndex = -1
                centsDifference = 0f
                
                // Don't immediately clear persistent display values or green state
                // This prevents flickering when signal momentarily drops
            }
            
            // Update spectrum data
            spectrumData = audioData.spectrum // Use full spectrum resolution
        }
        
        // Clear persistent highlighting after 1 second
        LaunchedEffect(lastInTuneTime) {
            if (lastInTuneTime > 0) {
                delay(1000)
                if (System.currentTimeMillis() - lastInTuneTime >= 1000) {
                    persistentInTuneIndex = -1
                }
            }
        }
        
        // Clear green card state after 3 seconds
        LaunchedEffect(lastGreenTime) {
            if (lastGreenTime > 0 && cardIsGreen) {
                android.util.Log.d("LyreTune", "Green timer started, will clear in 3 seconds")
                delay(3000)
                if (System.currentTimeMillis() - lastGreenTime >= 3000) {
                    android.util.Log.d("LyreTune", "Clearing green state after 3 seconds")
                    cardIsGreen = false
                }
            }
        }
        
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top bar with title, play button, and settings
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "LyreTune",
                    style = MaterialTheme.typography.headlineMedium
                )
                
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Play/Pause Button
                    FilledIconButton(
                        onClick = { togglePlayPause() },
                        modifier = Modifier.size(48.dp),
                        colors = IconButtonDefaults.filledIconButtonColors(
                            containerColor = if (isPlaying.value) Color(0xFF4CAF50) else MaterialTheme.colorScheme.primaryContainer
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Filled.PlayArrow,
                            contentDescription = if (isPlaying.value) "Stop" else "Play",
                            tint = if (isPlaying.value) Color.White else MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                    
                    // Settings Button
                    IconButton(
                        onClick = {
                            val intent = Intent(this@MainActivity, SettingsActivity::class.java)
                            startActivity(intent)
                        }
                    ) {
                        Icon(
                            Icons.Filled.Settings,
                            contentDescription = "Settings"
                        )
                    }
                    
                    // Exit Button
                    IconButton(
                        onClick = {
                            finish()
                        }
                    ) {
                        Icon(
                            Icons.Filled.Close,
                            contentDescription = "Exit",
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }
            
            // Frequency Display - Always visible to prevent flickering
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (cardIsGreen) 
                        Color(0xFF4CAF50) else MaterialTheme.colorScheme.surface
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = if (persistentFrequency > 0f) "%.1f Hz".format(persistentFrequency) else "--- Hz",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold
                        )
                        LinearProgressIndicator(
                            progress = if (frequency > 0f) magnitude.coerceIn(0f, 1f) else 0f,
                            modifier = Modifier.width(120.dp)
                        )
                    }
                    
                    Column(
                        horizontalAlignment = Alignment.End
                    ) {
                        if (persistentFrequency > 0f && persistentNote.isNotEmpty()) {
                            Text(
                                text = persistentNote,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold
                            )
                        } else {
                            Text(
                                text = "---",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = "Listening...",
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Spectrum Visualizer - Takes full width now
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 16.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                ) {
                    Text(
                        text = "Frequency Spectrum",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    // Collect string frequencies and notes from Kotlin processor
                    val stringFrequencies = (0 until numStrings).map { 
                        kotlinAudioProcessor.getScaleFrequency(it) 
                    }
                    val stringNotes = (0 until numStrings).map { 
                        kotlinAudioProcessor.getScaleNote(it) 
                    }
                    
                    SpectrumVisualizer(
                        spectrumData = spectrumData,
                        modifier = Modifier.fillMaxSize(),
                        magnitudeScale = currentMagnitudeScale,
                        stringFrequencies = stringFrequencies,
                        stringNotes = stringNotes,
                        detectedFrequency = frequency,
                        closestNoteIndex = closestNoteIndex,
                        centsDifference = centsDifference,
                        fftSize = fftResolution,
                        showFullSpectrum = showFullSpectrum,
                        tolerance = tolerance,
                        persistentInTuneIndex = persistentInTuneIndex,
                        magnitude = magnitude,
                        noiseGate = noiseGate,
                        highPassFilter = highPassFilter,
                        onStringInTune = { isInTune, stringIndex, peakFrequency ->
                            if (isInTune && stringIndex >= 0) {
                                // Always update green state and reset timer when any string is in tune
                                cardIsGreen = true
                                lastGreenTime = System.currentTimeMillis()
                                
                                // Update frequency display with the detected string
                                val noteName = kotlinAudioProcessor.getScaleNote(stringIndex)
                                persistentFrequency = peakFrequency
                                persistentNote = noteName
                                
                                android.util.Log.d("LyreTune", "Card GREEN: $noteName at ${peakFrequency}Hz (string $stringIndex)")
                            }
                        }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}