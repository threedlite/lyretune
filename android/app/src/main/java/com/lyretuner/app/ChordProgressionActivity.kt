package com.lyretuner.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lyretuner.app.audio.ScaleCalculator
import com.lyretuner.app.audio.ScaleType
import com.lyretuner.app.audio.Mode
import com.lyretuner.app.audio.Temperament
import com.lyretuner.app.ui.theme.LyreTuneTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.*

// Chord reference frequency mode for complexity calculation
enum class ChordReferenceMode {
    BASS,        // Use bass note (lowest) - default/traditional
    MIDDLE,      // Use middle note of chord
    MESE         // Use middle string of lyre (mese/tonic)
}

// Data class for non-Western cadence analysis
data class CadenceAnalysis(
    val motion: String,           // Strong Descent, Weak Descent, Ascending Close, Static
    val voiceLeading: String,     // Smooth, Moderate, Active
    val harmonicDirection: String, // Resolving, Tensing, Neutral
    val closureStrength: String   // Terminal, Suspensive, Continuous
)

// Data class for displaying progressions
data class ProgressionDisplay(
    val rank: Int,
    val notes: String,
    val chordSymbols: String,  // Roman numeral chord symbols
    val commonName: String?,    // Common progression name (e.g., "Authentic Cadence (V-I)")
    val complexity: Double,
    val frequencies: List<Float>,
    val notesPerChord: List<Int>,  // How many notes in each chord
    val cadenceAnalysis: CadenceAnalysis? = null  // Non-Western cadence characterization
)

class ChordProgressionActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    ChordProgressionScreen(
                        context = this@ChordProgressionActivity,
                        onBackPressed = { finish() }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChordProgressionScreen(context: Context, onBackPressed: () -> Unit) {
    val sharedPrefs = context.getSharedPreferences("lyretune_settings", Context.MODE_PRIVATE)
    var progressions by remember { mutableStateOf<List<ProgressionDisplay>>(emptyList()) }
    var isAnalyzing by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isPartialResults by remember { mutableStateOf(false) }
    val localContext = LocalContext.current

    // Progression parameters
    var selectedChordSizes by remember { mutableStateOf(setOf(3)) }
    var selectedProgressionLength by remember { mutableStateOf(4) }
    var sortByCadence by remember { mutableStateOf(false) }

    // Complexity calculation options
    var useMultiChordMese by remember { mutableStateOf(false) }  // Multi-chord metrics: use mese as tonic
    var chordReferenceMode by remember { mutableStateOf(ChordReferenceMode.BASS) }  // Single chord reference

    // Audio playback state
    var audioTrack by remember { mutableStateOf<AudioTrack?>(null) }
    var currentlyPlaying by remember { mutableStateOf<Int?>(null) }

    val coroutineScope = rememberCoroutineScope()

    // Stop playback when leaving the screen
    DisposableEffect(Unit) {
        onDispose {
            try {
                audioTrack?.stop()
                audioTrack?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // Load current settings
    val scaleType = when(sharedPrefs.getInt("scale_type", 0)) {
        0 -> ScaleType.MODES
        else -> ScaleType.MODES // Should only be called for Modes
    }

    val mode = when(sharedPrefs.getInt("mode", 4)) {
        0 -> Mode.MIXOLYDIOS
        1 -> Mode.HYPODORIOS
        2 -> Mode.LYDIOS
        3 -> Mode.PHRYGIOS
        4 -> Mode.DORIOS
        5 -> Mode.HYPOLYDIOS
        6 -> Mode.HYPOPHRYGIOS
        else -> Mode.DORIOS
    }

    val firstNote = sharedPrefs.getString("first_note", "E") ?: "E"
    val numStrings = sharedPrefs.getInt("num_strings", 7)
    val temperament = when(sharedPrefs.getInt("temperament", 2)) {
        0 -> Temperament.EQUAL
        1 -> Temperament.JUST
        2 -> Temperament.JUST_ANCIENT
        3 -> Temperament.MEANTONE
        else -> Temperament.JUST
    }
    val octaveOffset = sharedPrefs.getInt("octave_offset", 0)

    // Check for valid settings
    LaunchedEffect(temperament, numStrings, scaleType) {
        if (scaleType != ScaleType.MODES) {
            errorMessage = "Chord progressions only available for Modes scale type"
            progressions = emptyList()
        } else if (temperament == Temperament.EQUAL) {
            errorMessage = "Non-rational tunings not supported, try Just Intonation"
            progressions = emptyList()
        } else if (numStrings < 4) {
            errorMessage = "Minimum 4 strings required for chord progression analysis"
            progressions = emptyList()
        } else if (numStrings > 9) {
            errorMessage = "Maximum 9 strings supported for chord progression analysis"
            progressions = emptyList()
        } else {
            errorMessage = null
        }
    }

    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = { Text("Chord Progression Tool") },
            navigationIcon = {
                IconButton(onClick = onBackPressed) {
                    Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                }
            }
        )

        // Scrollable content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Current settings display
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Text(
                        text = "Current Settings",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Text("Scale Type: ${scaleType.name}", style = MaterialTheme.typography.bodyMedium)
                    val modernModeName = ANCIENT_TO_MODERN_MODE[mode] ?: ""
                    Text("Mode: ${mode.name} (modern $modernModeName)", style = MaterialTheme.typography.bodyMedium)
                    Text("First Note: $firstNote", style = MaterialTheme.typography.bodyMedium)
                    Text("Number of Strings: $numStrings", style = MaterialTheme.typography.bodyMedium)
                    Text("Temperament: ${temperament.name}", style = MaterialTheme.typography.bodyMedium)
                    Text("Octave Offset: $octaveOffset", style = MaterialTheme.typography.bodyMedium)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Error message if invalid settings
            errorMessage?.let { message ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    )
                ) {
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(16.dp)
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Analysis options
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Text(
                        text = "Analysis Options",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )

                    // Chord size selection
                    Text(
                        text = "Notes per chord (select multiple):",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(2, 3, 4).forEach { size ->
                            FilterChip(
                                selected = selectedChordSizes.contains(size),
                                onClick = {
                                    selectedChordSizes = if (selectedChordSizes.contains(size)) {
                                        // Don't allow deselecting if it's the last one
                                        if (selectedChordSizes.size > 1) {
                                            selectedChordSizes - size
                                        } else {
                                            selectedChordSizes
                                        }
                                    } else {
                                        selectedChordSizes + size
                                    }
                                },
                                label = { Text("$size notes") },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Progression length selection
                    Text(
                        text = "Chords in sequence:",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(2, 3, 4, 5).forEach { length ->
                            FilterChip(
                                selected = selectedProgressionLength == length,
                                onClick = { selectedProgressionLength = length },
                                label = { Text("$length") },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Sort by cadence toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Prioritize Western cadences (Just):",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )
                        Switch(
                            checked = sortByCadence,
                            onCheckedChange = { sortByCadence = it }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Multi-chord metrics: use mese as tonic
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Multi-chord metrics: use mese (middle string) as tonic:",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                            color = if (sortByCadence) MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f) else MaterialTheme.colorScheme.onSurface
                        )
                        Switch(
                            checked = useMultiChordMese,
                            onCheckedChange = { useMultiChordMese = it },
                            enabled = !sortByCadence
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Chord reference frequency selection
                    Text(
                        text = "Single chord reference frequency:",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(bottom = 4.dp),
                        color = if (sortByCadence) MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f) else MaterialTheme.colorScheme.onSurface
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FilterChip(
                            selected = chordReferenceMode == ChordReferenceMode.BASS,
                            onClick = { chordReferenceMode = ChordReferenceMode.BASS },
                            label = { Text("Bass") },
                            modifier = Modifier.weight(1f),
                            enabled = !sortByCadence
                        )
                        FilterChip(
                            selected = chordReferenceMode == ChordReferenceMode.MIDDLE,
                            onClick = { chordReferenceMode = ChordReferenceMode.MIDDLE },
                            label = { Text("Middle") },
                            modifier = Modifier.weight(1f),
                            enabled = !sortByCadence
                        )
                        FilterChip(
                            selected = chordReferenceMode == ChordReferenceMode.MESE,
                            onClick = { chordReferenceMode = ChordReferenceMode.MESE },
                            label = { Text("Mese") },
                            modifier = Modifier.weight(1f),
                            enabled = !sortByCadence
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Analyze button
            Button(
                onClick = {
                    if (errorMessage == null) {
                        coroutineScope.launch {
                            isAnalyzing = true
                            isPartialResults = false
                            try {
                                val result = withContext(Dispatchers.Default) {
                                    analyzeChordProgressionsWithTimeout(
                                        mode, firstNote, numStrings, temperament, octaveOffset,
                                        selectedChordSizes, selectedProgressionLength,
                                        sortByCadence = sortByCadence,
                                        useMultiChordMese = useMultiChordMese,
                                        chordReferenceMode = chordReferenceMode,
                                        timeoutMillis = 30000L
                                    )
                                }
                                progressions = result.progressions
                                isPartialResults = result.isPartial

                                if (result.isPartial) {
                                    Toast.makeText(localContext, "Analysis timed out - showing partial results", Toast.LENGTH_LONG).show()
                                }
                            } catch (e: Exception) {
                                progressions = emptyList()
                                isPartialResults = false
                                Toast.makeText(localContext, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                                e.printStackTrace()
                            } finally {
                                isAnalyzing = false
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isAnalyzing && errorMessage == null
            ) {
                Text(if (isAnalyzing) "Analyzing..." else "Suggest Chord Progressions")
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Progress indicator
            if (isAnalyzing) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Analysis results
            if (progressions.isNotEmpty()) {
                Text(
                    text = "Suggested Progressions (${progressions.size})",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(bottom = 8.dp)
                )

                // Show partial results warning
                if (isPartialResults) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.tertiaryContainer
                        )
                    ) {
                        Text(
                            text = "⚠️ Analysis timed out after 30 seconds - showing partial results",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onTertiaryContainer,
                            modifier = Modifier.padding(12.dp)
                        )
                    }
                }

                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 500.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    items(progressions, key = { it.rank }) { prog ->
                        ProgressionRow(
                            progression = prog,
                            isPlaying = currentlyPlaying == prog.rank - 1,
                            showCadenceLabels = sortByCadence,
                            onPlay = {
                                coroutineScope.launch {
                                    try {
                                        // Stop any currently playing audio
                                        audioTrack?.stop()
                                        audioTrack?.release()
                                        audioTrack = null

                                        currentlyPlaying = prog.rank - 1
                                        playProgression(
                                            frequencies = prog.frequencies,
                                            notesPerChord = prog.notesPerChord,
                                            onTrackCreated = { track -> audioTrack = track }
                                        )
                                    } catch (e: Exception) {
                                        Toast.makeText(localContext, "Error playing: ${e.message}", Toast.LENGTH_SHORT).show()
                                        e.printStackTrace()
                                    } finally {
                                        currentlyPlaying = null
                                    }
                                }
                            },
                            context = localContext
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ProgressionRow(
    progression: ProgressionDisplay,
    isPlaying: Boolean,
    showCadenceLabels: Boolean,
    onPlay: () -> Unit,
    context: Context
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    onClick = {
                        Toast.makeText(context, "Long-press to copy to clipboard", Toast.LENGTH_SHORT).show()
                    },
                    onLongClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("Chord Progression", "${progression.chordSymbols}\n${progression.notes}")
                        clipboard.setPrimaryClip(clip)
                        Toast.makeText(context, "Progression copied to clipboard", Toast.LENGTH_SHORT).show()
                    }
                )
                .padding(8.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Play button
            IconButton(
                onClick = onPlay,
                modifier = Modifier.size(40.dp)
            ) {
                Icon(
                    imageVector = Icons.Filled.PlayArrow,
                    contentDescription = "Play",
                    tint = MaterialTheme.colorScheme.primary
                )
            }

            // Rank
            Text(
                text = "${progression.rank}",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.width(30.dp)
            )

            // Chord symbols and notes in a column
            Column(
                modifier = Modifier.weight(1f)
            ) {
                // Common name if available and enabled (highlighted)
                if (showCadenceLabels) {
                    progression.commonName?.let { name ->
                        Text(
                            text = name,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.tertiary
                        )
                    }
                    // Chord symbols (Roman numerals) - only when Western cadence is ON
                    Text(
                        text = progression.chordSymbols,
                        style = MaterialTheme.typography.bodyLarge,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.primary
                    )
                } else {
                    // Show cadence analysis when Western cadence is OFF
                    progression.cadenceAnalysis?.let { analysis ->
                        Text(
                            text = buildAnnotatedString {
                                // Motion
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurfaceVariant)) {
                                    append("Motion: ")
                                }
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.primary)) {
                                    append(analysis.motion)
                                }
                                append("\n")

                                // Voice Leading
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurfaceVariant)) {
                                    append("Voice: ")
                                }
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.primary)) {
                                    append(analysis.voiceLeading)
                                }
                                append("\n")

                                // Harmonic Direction
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurfaceVariant)) {
                                    append("Direction: ")
                                }
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.primary)) {
                                    append(analysis.harmonicDirection)
                                }
                                append("\n")

                                // Closure Strength
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurfaceVariant)) {
                                    append("Closure: ")
                                }
                                withStyle(SpanStyle(color = MaterialTheme.colorScheme.primary)) {
                                    append(analysis.closureStrength)
                                }
                            },
                            style = MaterialTheme.typography.bodySmall,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
                // Note names (smaller, secondary) - each chord on separate line
                Column {
                    progression.notes.split("  ").forEach { chordNotes ->
                        Text(
                            text = chordNotes,
                            style = MaterialTheme.typography.bodySmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Complexity
            Text(
                text = String.format("%.4f", progression.complexity),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.width(70.dp),
                fontFamily = FontFamily.Monospace
            )
        }
    }
}

// Result wrapper for timeout support
data class AnalysisResult(
    val progressions: List<ProgressionDisplay>,
    val isPartial: Boolean
)

// Chord progression analysis with timeout
suspend fun analyzeChordProgressionsWithTimeout(
    mode: Mode,
    firstNote: String,
    numStrings: Int,
    temperament: Temperament,
    octaveOffset: Int,
    chordSizes: Set<Int>,
    progressionLength: Int,
    sortByCadence: Boolean,
    useMultiChordMese: Boolean,
    chordReferenceMode: ChordReferenceMode,
    timeoutMillis: Long
): AnalysisResult = withContext(Dispatchers.Default) {
    val analyzer = LyreProgressionAnalyzer(
        mode, firstNote, numStrings, temperament, octaveOffset,
        useMultiChordMese, chordReferenceMode, sortByCadence
    )

    val startTime = System.currentTimeMillis()
    var isPartial = false

    try {
        val progressions = analyzer.generateProgressionsWithTimeout(
            minLength = progressionLength,
            maxLength = progressionLength,
            maxResults = 100,
            chordSizes = chordSizes,
            timeoutMillis = timeoutMillis,
            startTime = startTime,
            onTimeout = { isPartial = true }
        )

        val identified = analyzer.identifyCommonProgressions(progressions)
        val results = analyzer.formatResultsForDisplay(identified, progressionLength, sortByCadence)

        AnalysisResult(results, isPartial)
    } catch (e: Exception) {
        e.printStackTrace()
        AnalysisResult(emptyList(), false)
    }
}

// Audio playback functions
suspend fun playProgression(
    frequencies: List<Float>,
    notesPerChord: List<Int>,
    onTrackCreated: (AudioTrack) -> Unit
) {
    withContext(Dispatchers.IO) {
        try {
            val sampleRate = 44100
            val noteDuration = 0.6 // seconds per chord (50% longer than original 0.4s)
            val pauseDuration = 0.05 // seconds between chords

            // Create audio track with streaming mode for better quality
            val bufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(sampleRate * 2)

            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            onTrackCreated(audioTrack)
            audioTrack.play()

            // Validate frequency count matches notes per chord
            val expectedSize = notesPerChord.sum()
            if (frequencies.size != expectedSize) {
                throw IllegalArgumentException(
                    "Frequency count mismatch: expected $expectedSize (${notesPerChord.joinToString("+")}) but got ${frequencies.size}"
                )
            }

            // Play each chord in sequence using the actual notes per chord
            var freqIndex = 0
            for (numNotes in notesPerChord) {
                val chordFreqs = frequencies.subList(freqIndex, freqIndex + numNotes)
                freqIndex += numNotes

                // Generate and write chord
                val chordData = generateChord(chordFreqs, noteDuration, sampleRate)
                audioTrack.write(chordData, 0, chordData.size)

                // Add pause between chords
                val pauseSamples = ShortArray((pauseDuration * sampleRate).toInt())
                audioTrack.write(pauseSamples, 0, pauseSamples.size)
            }

            // Wait for audio to finish playing
            delay(((noteDuration + pauseDuration) * notesPerChord.size * 1000).toLong())
        } catch (e: Exception) {
            android.util.Log.e("ChordProgression", "Error playing progression", e)
        }
    }
}

fun generateChord(frequencies: List<Float>, duration: Double, sampleRate: Int): ShortArray {
    if (frequencies.isEmpty()) return ShortArray(0)

    val numSamples = (duration * sampleRate).toInt()
    val chord = ShortArray(numSamples)
    val fadeInSamples = (0.01 * sampleRate).toInt() // 10ms fade in
    val fadeOutSamples = (0.05 * sampleRate).toInt() // 50ms fade out

    // Reduce amplitude based on number of notes to avoid clipping
    val amplitude = 0.7 / frequencies.size

    for (i in 0 until numSamples) {
        var mixedSample = 0.0

        // Mix all frequencies together
        for (frequency in frequencies) {
            val angle = 2.0 * PI * i * frequency / sampleRate
            mixedSample += sin(angle) * amplitude
        }

        // Apply fade in
        if (i < fadeInSamples) {
            mixedSample *= i.toDouble() / fadeInSamples
        }
        // Apply fade out
        else if (i >= numSamples - fadeOutSamples) {
            mixedSample *= (numSamples - i).toDouble() / fadeOutSamples
        }

        chord[i] = (mixedSample * Short.MAX_VALUE).toInt().toShort()
    }

    return chord
}

// Constants
const val DYAD_SIZE = 2
const val TRIAD_SIZE = 3
const val TETRAD_SIZE = 4

const val MIN_STRINGS_FOR_TRIADS = 4
const val MAX_STRINGS_SUPPORTED = 9

// Voicing quality penalties
val INVERSION_PENALTIES = mapOf(
    "root" to 0.0,
    "1st" to 1.5,
    "2nd" to 2.0,
    "3rd" to 2.0,
    "unk" to 3.0
)
const val CROSSED_VOICES_PENALTY = 1.0

// Voice leading weights
const val VOICE_LEADING_WEIGHT = 0.5
const val COMMON_TONE_BONUS = -0.5

// Root movement strength
val ROOT_MOVEMENT_STRENGTH = mapOf(
    0 to 0.0,   // No movement
    3 to -1.5,  // V→I (authentic cadence) - STRONGEST
    4 to -0.3,  // IV→I (plagal) and I→V (half) - mixed
    5 to -0.5,  // Ascending 5th
    2 to 0.3,   // Stepwise
    6 to 1.5,   // Tritone
    1 to 0.8    // Half step
)

// Mode semitone patterns (from LyreChordAnalyzer.MODES in analyze_lyre_chords.py)
val MODE_SEMITONES = mapOf(
    Mode.DORIOS to listOf(0, 1, 3, 5, 7, 8, 10),      // Ancient Dorios = Modern Phrygian (E mode)
    Mode.PHRYGIOS to listOf(0, 2, 3, 5, 7, 9, 10),    // Ancient Phrygios = Modern Dorian (D mode)
    Mode.LYDIOS to listOf(0, 2, 4, 5, 7, 9, 11),      // Ancient Lydios = Modern Ionian (C mode)
    Mode.MIXOLYDIOS to listOf(0, 1, 3, 5, 6, 8, 10),  // Ancient Mixolydios = Modern Locrian (B mode)
    Mode.HYPODORIOS to listOf(0, 2, 3, 5, 7, 8, 10),  // Ancient Hypodorios = Modern Aeolian (A mode)
    Mode.HYPOLYDIOS to listOf(0, 2, 4, 6, 7, 9, 11),  // Ancient Hypolydios = Modern Lydian (F mode)
    Mode.HYPOPHRYGIOS to listOf(0, 2, 4, 5, 7, 9, 10) // Ancient Hypophrygios = Modern Mixolydian (G mode)
)

// Ancient to modern mode name mapping
val ANCIENT_TO_MODERN_MODE = mapOf(
    Mode.DORIOS to "Phrygian",
    Mode.PHRYGIOS to "Dorian",
    Mode.LYDIOS to "Ionian",
    Mode.MIXOLYDIOS to "Locrian",
    Mode.HYPODORIOS to "Aeolian",
    Mode.HYPOLYDIOS to "Lydian",
    Mode.HYPOPHRYGIOS to "Mixolydian"
)

// Expected chord qualities for each degree (0-6) in each mode
// Based on Roman numeral analysis: uppercase = major, lowercase = minor, ° = diminished
val MODE_CHORD_QUALITIES = mapOf(
    Mode.DORIOS to listOf("min", "maj", "maj", "min", "dim", "maj", "min"),       // i ♭II ♭III iv v° ♭VI ♭vii (Phrygian)
    Mode.PHRYGIOS to listOf("min", "min", "maj", "maj", "min", "dim", "maj"),     // i ii ♭III IV v vi° ♭VII (Dorian)
    Mode.LYDIOS to listOf("maj", "min", "min", "maj", "maj", "min", "dim"),       // I ii iii IV V vi vii° (Ionian/Major)
    Mode.MIXOLYDIOS to listOf("dim", "maj", "min", "min", "maj", "maj", "min"),   // i° ♭II ♭iii iv ♭V ♭VI ♭vii (Locrian)
    Mode.HYPODORIOS to listOf("min", "dim", "maj", "min", "min", "maj", "maj"),   // i ii° ♭III iv v ♭VI ♭VII (Aeolian/Natural Minor)
    Mode.HYPOLYDIOS to listOf("maj", "maj", "min", "dim", "maj", "min", "min"),   // I II iii ♯iv° V vi vii (Lydian)
    Mode.HYPOPHRYGIOS to listOf("maj", "min", "dim", "maj", "min", "min", "maj")  // I ii iii° IV v vi ♭VII (Mixolydian)
)

// Roman numerals with accidentals for each degree (0-6) in each mode
val MODE_ROMAN_NUMERALS = mapOf(
    Mode.DORIOS to listOf("i", "♭II", "♭III", "iv", "v°", "♭VI", "♭vii"),         // Phrygian
    Mode.PHRYGIOS to listOf("i", "ii", "♭III", "IV", "v", "vi°", "♭VII"),         // Dorian
    Mode.LYDIOS to listOf("I", "ii", "iii", "IV", "V", "vi", "vii°"),             // Ionian/Major
    Mode.MIXOLYDIOS to listOf("i°", "♭II", "♭iii", "iv", "♭V", "♭VI", "♭vii"),    // Locrian
    Mode.HYPODORIOS to listOf("i", "ii°", "♭III", "iv", "v", "♭VI", "♭VII"),      // Aeolian/Natural Minor
    Mode.HYPOLYDIOS to listOf("I", "II", "iii", "♯iv°", "V", "vi", "vii"),        // Lydian
    Mode.HYPOPHRYGIOS to listOf("I", "ii", "iii°", "IV", "v", "vi", "♭VII")       // Mixolydian
)

// Chord class - represents a chord with variable size
data class Chord(
    val rootDegree: Int,
    val scaleSemitones: List<Int>,
    val rootSemitone: Int,
    val size: Int = 3,
    val mode: Mode? = null
) {
    val degrees: List<Int>
    val semitones: List<Int>
    val quality: String

    init {
        // Build chord based on size
        val degreeOffsets = when (size) {
            DYAD_SIZE -> listOf(0, 2)
            TRIAD_SIZE -> listOf(0, 2, 4)
            TETRAD_SIZE -> listOf(0, 2, 4, 6)
            else -> listOf(0, 2, 4)
        }

        degrees = degreeOffsets.map { (rootDegree + it) % 7 }
        semitones = getChordSemitones(degrees, rootDegree, scaleSemitones)

        // Determine quality based on size
        quality = when (size) {
            DYAD_SIZE -> {
                val interval = semitones[1] - semitones[0]
                DYAD_QUALITIES[interval] ?: "${interval}st"
            }
            TRIAD_SIZE -> {
                val third = semitones[1] - semitones[0]
                val fifth = semitones[2] - semitones[0]
                TRIAD_QUALITIES[Pair(third, fifth)] ?: "unk"
            }
            TETRAD_SIZE -> {
                val third = semitones[1] - semitones[0]
                val fifth = semitones[2] - semitones[0]
                val seventh = semitones[3] - semitones[0]
                TETRAD_QUALITIES[Triple(third, fifth, seventh)] ?: "unk"
            }
            else -> "unk"
        }
    }

    // Check if this chord matches the expected quality for its degree in the mode
    fun isExpectedQuality(): Boolean {
        if (mode == null || size != TRIAD_SIZE) return true // Only validate triads with mode
        val expectedQualities = MODE_CHORD_QUALITIES[mode] ?: return true
        if (rootDegree !in 0..6) return true
        return quality == expectedQualities[rootDegree]
    }

    // Get validation indicator for display
    fun getValidationMarker(): String {
        return if (!isExpectedQuality()) "⚠" else ""
    }

    private fun getChordSemitones(degrees: List<Int>, rootDegree: Int, scaleSemitones: List<Int>): List<Int> {
        return degrees.map { deg ->
            var st = scaleSemitones[deg]
            if (deg < rootDegree) {
                st += 12 // Next octave
            }
            st
        }
    }

    override fun toString(): String {
        // Use mode-aware Roman numerals if mode is provided, otherwise fall back to simple numerals
        val roman = if (mode != null && size == TRIAD_SIZE) {
            // Use mode-specific Roman numeral with accidentals
            MODE_ROMAN_NUMERALS[mode]?.getOrNull(rootDegree) ?: getSimpleRoman()
        } else {
            getSimpleRoman()
        }

        val validationMarker = getValidationMarker()

        return when (size) {
            DYAD_SIZE -> "$roman-$quality$validationMarker"
            TRIAD_SIZE -> {
                // For mode-aware display, the quality is already in the Roman numeral
                if (mode != null) {
                    "$roman$validationMarker"
                } else {
                    // Fall back to old style
                    when (quality) {
                        "min" -> roman.lowercase() + validationMarker
                        "dim" -> roman.lowercase() + "°" + validationMarker
                        "aug" -> "$roman+$validationMarker"
                        else -> roman + validationMarker
                    }
                }
            }
            TETRAD_SIZE -> {
                val baseRoman = if (mode != null) {
                    MODE_ROMAN_NUMERALS[mode]?.getOrNull(rootDegree)?.replace("°", "") ?: getSimpleRoman()
                } else {
                    getSimpleRoman()
                }
                when (quality) {
                    "maj7" -> "${baseRoman}maj7$validationMarker"
                    "dom7" -> "${baseRoman}7$validationMarker"
                    "min7" -> "${baseRoman.lowercase()}7$validationMarker"
                    "halfdim7" -> "${baseRoman.lowercase()}ø7$validationMarker"
                    "dim7" -> "${baseRoman.lowercase()}°7$validationMarker"
                    else -> "$baseRoman?$size$validationMarker"
                }
            }
            else -> "$roman($size)$validationMarker"
        }
    }

    private fun getSimpleRoman(): String {
        val romans = listOf("I", "II", "III", "IV", "V", "VI", "VII")
        return romans[rootDegree]
    }

    companion object {
        val DYAD_QUALITIES = mapOf(
            1 to "m2", 2 to "M2", 3 to "m3", 4 to "M3", 5 to "P4",
            6 to "TT", 7 to "P5", 8 to "m6", 9 to "M6", 10 to "m7", 11 to "M7"
        )

        val TRIAD_QUALITIES = mapOf(
            Pair(4, 7) to "maj",
            Pair(3, 7) to "min",
            Pair(3, 6) to "dim",
            Pair(4, 8) to "aug"
        )

        val TETRAD_QUALITIES = mapOf(
            Triple(4, 7, 11) to "maj7",
            Triple(4, 7, 10) to "dom7",
            Triple(3, 7, 10) to "min7",
            Triple(3, 6, 10) to "halfdim7",
            Triple(3, 6, 9) to "dim7"
        )
    }
}

// LyreVoicing class
data class LyreVoicing(
    val chord: Chord,
    val stringIndices: List<Int>, // 1-indexed
    val semitones: List<Int>,
    val useMultiChordMese: Boolean = false,
    val sortByCadence: Boolean = false,
    val meseDegree: Int = 0,
    val scaleSemitones: List<Int> = emptyList()
) {
    val inversion: String
    val isAscending: Boolean

    init {
        // Determine inversion
        // When useMultiChordMese is true, calculate inversions relative to mese-centered root
        val rootMod = if (!sortByCadence && useMultiChordMese && scaleSemitones.isNotEmpty()) {
            // Re-center the chord's root degree around mese
            val recenteredRootDegree = (chord.rootDegree - meseDegree + 7) % 7
            // Get the semitone of the re-centered root
            scaleSemitones[recenteredRootDegree] % 12
        } else {
            // Traditional: use chord's original root
            chord.semitones[0] % 12
        }

        val bassMod = semitones[0] % 12

        // Calculate expected chord tones for the re-centered chord
        val chordTones = if (!sortByCadence && useMultiChordMese && scaleSemitones.isNotEmpty()) {
            // Build chord tones from re-centered root
            val recenteredRootDegree = (chord.rootDegree - meseDegree + 7) % 7
            val degreeOffsets = when (chord.size) {
                DYAD_SIZE -> listOf(0, 2)
                TRIAD_SIZE -> listOf(0, 2, 4)
                TETRAD_SIZE -> listOf(0, 2, 4, 6)
                else -> listOf(0, 2, 4)
            }
            degreeOffsets.map { offset ->
                val deg = (recenteredRootDegree + offset) % 7
                scaleSemitones[deg] % 12
            }
        } else {
            // Traditional: use chord's original semitones
            chord.semitones.map { it % 12 }
        }

        inversion = when (chord.size) {
            DYAD_SIZE -> if (bassMod == chordTones[0]) "root" else "1st"
            TRIAD_SIZE -> {
                when (bassMod) {
                    chordTones[0] -> "root"
                    chordTones[1] -> "1st"
                    chordTones[2] -> "2nd"
                    else -> "unk"
                }
            }
            TETRAD_SIZE -> {
                when (bassMod) {
                    chordTones[0] -> "root"
                    chordTones[1] -> "1st"
                    chordTones[2] -> "2nd"
                    chordTones[3] -> "3rd"
                    else -> "unk"
                }
            }
            else -> "unk"
        }

        // Check if ascending
        isAscending = semitones.zipWithNext().all { it.first < it.second }
    }

    override fun toString(): String {
        val invSymbols = when (chord.size) {
            DYAD_SIZE -> mapOf("root" to "", "1st" to "⁶")
            TRIAD_SIZE -> mapOf("root" to "", "1st" to "⁶", "2nd" to "⁶₄")
            TETRAD_SIZE -> mapOf("root" to "", "1st" to "⁶₅", "2nd" to "⁴₃", "3rd" to "²")
            else -> emptyMap()
        }

        val invSymbol = invSymbols[inversion] ?: "?"
        val asc = if (isAscending) "↑" else "↓"
        val strings = stringIndices.joinToString(",")
        return "$chord$invSymbol[$strings]$asc"
    }

    fun voicingPenalty(): Double {
        val penalty = if (chord.size == TETRAD_SIZE && inversion == "3rd") {
            INVERSION_PENALTIES["2nd"] ?: 2.0
        } else {
            INVERSION_PENALTIES[inversion] ?: 3.0
        }

        return penalty + if (!isAscending) CROSSED_VOICES_PENALTY else 0.0
    }
}

// Progression data class
data class Progression(
    val complexity: Double,
    val voicings: List<LyreVoicing>,
    val chords: List<Chord>,
    val description: String,
    val functional: String,
    var commonName: String? = null
)

// LyreProgressionAnalyzer class
class LyreProgressionAnalyzer(
    val mode: Mode,
    val firstNote: String,
    val numStrings: Int,
    temperament: Temperament,
    octaveOffset: Int,
    private val useMultiChordMese: Boolean = false,
    private val chordReferenceMode: ChordReferenceMode = ChordReferenceMode.BASS,
    private val sortByCadence: Boolean = false
) {
    private val scaleSemitones: List<Int>
    private val frequencies: List<Float>
    private val noteNames: List<String>
    private val chordSizes: List<Int>
    private val chords: List<Chord>
    private val voicings: Map<Pair<Int, Int>, List<LyreVoicing>>
    private val chordAnalyzer: LyreChordAnalyzer

    // Middle string index (1-indexed) for mese/tonic reference
    // For odd number: middle = (n+1)/2, for even: lower-middle = n/2
    private val meseStringIndex: Int = (numStrings + 1) / 2

    // Scale degree (0-6) of the mese string, used when useMultiChordMese is true
    // Lazy because it depends on scaleSemitones which is initialized in init block
    private val meseDegree: Int by lazy { (meseStringIndex - 1) % scaleSemitones.size }

    // Same parameters as chord analyzer
    private val params = mapOf(
        "augmented_penalty" to 0.6,
        "sus2inv_penalty" to 0.08,
        "major1inv_bonus" to 0.057,
        "dominant7_bonus" to 0.65,
        "halfdim7_penalty" to 0.65,
        "alpha" to 1.0,
        "beta" to 0.3,
        "kappa" to 1.0,
        "delta" to 0.15,
        "psi" to 1.6,
        "omega" to 3.3,
        "nu" to 0.0,
        "chi" to 0.5
    )

    init {
        require(numStrings >= MIN_STRINGS_FOR_TRIADS) {
            "Need at least $MIN_STRINGS_FOR_TRIADS strings for triad analysis, got $numStrings"
        }
        require(numStrings <= MAX_STRINGS_SUPPORTED) {
            "Maximum $MAX_STRINGS_SUPPORTED strings supported, got $numStrings"
        }

        // Debug logging to verify parameters
        android.util.Log.d("ProgAnalyzer", "=== LyreProgressionAnalyzer Init ===")
        android.util.Log.d("ProgAnalyzer", "useMultiChordMese: $useMultiChordMese")
        android.util.Log.d("ProgAnalyzer", "chordReferenceMode: $chordReferenceMode")
        android.util.Log.d("ProgAnalyzer", "sortByCadence: $sortByCadence")
        android.util.Log.d("ProgAnalyzer", "numStrings: $numStrings")
        android.util.Log.d("ProgAnalyzer", "meseStringIndex (1-indexed): $meseStringIndex")

        scaleSemitones = MODE_SEMITONES[mode] ?: listOf(0, 2, 4, 5, 7, 9, 11)

        android.util.Log.d("ProgAnalyzer", "meseDegree (0-indexed): ${(meseStringIndex - 1) % scaleSemitones.size}")

        // Create chord analyzer to get just intonation frequencies
        chordAnalyzer = LyreChordAnalyzer(
            ScaleType.MODES, mode, com.lyretuner.app.audio.Genus.DIATONIC,
            firstNote, numStrings, temperament, octaveOffset
        )

        // Use frequencies and note names from chord analyzer (just intonation)
        // This ensures complexity calculations match Python implementation
        frequencies = chordAnalyzer.frequencies
        noteNames = chordAnalyzer.noteNames

        // Determine chord sizes based on num_strings
        chordSizes = determineChordSizes()

        // Build all chords
        chords = buildChords()

        // Build all voicings
        voicings = buildVoicings()
    }

    private fun determineChordSizes(): List<Int> {
        return when {
            numStrings <= 4 -> listOf(DYAD_SIZE)
            numStrings <= 6 -> listOf(TRIAD_SIZE, DYAD_SIZE)
            numStrings >= 7 -> listOf(TRIAD_SIZE, TETRAD_SIZE, DYAD_SIZE)
            else -> listOf(TRIAD_SIZE, DYAD_SIZE)
        }
    }

    private fun buildChords(): List<Chord> {
        val chordList = mutableListOf<Chord>()
        for (size in chordSizes) {
            for (degree in 0..6) {
                val chord = Chord(degree, scaleSemitones, scaleSemitones[degree], size, mode)
                chordList.add(chord)
            }
        }
        return chordList
    }

    private fun isValidVoicing(semitones: List<Int>, chord: Chord): Boolean {
        val chordNotes = chord.semitones.map { it % 12 }.toSet()
        val playedNotes = semitones.map { it % 12 }.toSet()
        return playedNotes == chordNotes
    }

    private fun buildVoicings(): Map<Pair<Int, Int>, List<LyreVoicing>> {
        val voicingsByChord = mutableMapOf<Pair<Int, Int>, List<LyreVoicing>>()

        for (chord in chords) {
            val voicingList = mutableListOf<LyreVoicing>()

            // Try all combinations of chord.size strings
            val combinations = generateCombinations(numStrings, chord.size)
            for (strings in combinations) {
                // Get semitones played (considering octave wrapping)
                val scaleLength = scaleSemitones.size
                val semitones = strings.map { s ->
                    val degree = s % scaleLength
                    val octave = s / scaleLength
                    scaleSemitones[degree] + (octave * 12)
                }

                // Check if this forms the chord
                if (isValidVoicing(semitones, chord)) {
                    val voicing = LyreVoicing(
                        chord,
                        strings.map { it + 1 }, // 1-indexed
                        semitones,
                        useMultiChordMese,
                        sortByCadence,
                        meseDegree,
                        scaleSemitones
                    )
                    voicingList.add(voicing)
                }
            }

            val key = Pair(chord.rootDegree, chord.size)
            voicingsByChord[key] = voicingList
        }

        return voicingsByChord
    }

    private fun generateCombinations(n: Int, k: Int): List<List<Int>> {
        val result = mutableListOf<List<Int>>()

        fun backtrack(start: Int, current: MutableList<Int>) {
            if (current.size == k) {
                result.add(current.toList())
                return
            }

            for (i in start until n) {
                current.add(i)
                backtrack(i + 1, current)
                current.removeAt(current.size - 1)
            }
        }

        backtrack(0, mutableListOf())
        return result
    }

    /**
     * Get the middle index of a list (0-indexed).
     * For even-length lists, returns the lower-middle index.
     *
     * Examples:
     *   [a, b, c] -> 1 (middle)
     *   [a, b, c, d] -> 1 (lower-middle)
     */
    private fun <T> getMiddleIndex(list: List<T>): Int {
        return (list.size - 1) / 2
    }

    /**
     * Get the reference semitone for a voicing based on chordReferenceMode.
     * Used for motion detection in cadence analysis.
     *
     * When sortByCadence is true (prioritizing Western cadences), always uses bass note.
     * Otherwise, respects the chordReferenceMode setting.
     */
    private fun getReferenceNote(voicing: LyreVoicing): Int {
        // When prioritizing Western cadences, always use bass note (traditional)
        if (sortByCadence) {
            return voicing.semitones.firstOrNull() ?: 0
        }

        // Otherwise respect the user's reference mode selection
        return when (chordReferenceMode) {
            ChordReferenceMode.BASS -> {
                // Use bass note (lowest semitone)
                voicing.semitones.firstOrNull() ?: 0
            }
            ChordReferenceMode.MIDDLE -> {
                // Use middle note of the chord
                val middleIdx = getMiddleIndex(voicing.semitones)
                voicing.semitones.getOrNull(middleIdx) ?: voicing.semitones.firstOrNull() ?: 0
            }
            ChordReferenceMode.MESE -> {
                // Use mese (middle string of lyre)
                val meseIdx = meseStringIndex - 1  // Convert to 0-indexed
                if (meseIdx >= 0 && meseIdx < numStrings) {
                    // Calculate semitone with octave offset (same logic as buildVoicings)
                    val degree = meseIdx % scaleSemitones.size
                    val octave = meseIdx / scaleSemitones.size
                    scaleSemitones[degree] + (octave * 12)
                } else {
                    voicing.semitones.firstOrNull() ?: 0
                }
            }
        }
    }

    private fun voiceLeadingDistance(voicing1: LyreVoicing, voicing2: LyreVoicing): Double {
        val strings1 = voicing1.stringIndices.toSet()
        val strings2 = voicing2.stringIndices.toSet()

        val common = strings1.intersect(strings2)
        val voicesThatMove = (strings1 - common).size + (strings2 - common).size

        val commonToneBonus = common.size * COMMON_TONE_BONUS

        return voicesThatMove + commonToneBonus
    }

    private fun rootMovementComplexity(chord1: Chord, chord2: Chord): Double {
        // Calculate distance between chord root degrees
        // When sortByCadence is true (Western cadences), always use degree 0 as tonic
        // When sortByCadence is false and useMultiChordMese is true, use meseDegree as tonic
        val degreeDistance = if (!sortByCadence && useMultiChordMese) {
            // Re-center both chord degrees around mese as degree 0
            val degree1FromMese = (chord1.rootDegree - meseDegree + 7) % 7
            val degree2FromMese = (chord2.rootDegree - meseDegree + 7) % 7
            // Calculate distance between re-centered degrees
            val dist = (degree2FromMese - degree1FromMese + 7) % 7
            android.util.Log.d("RootMovement", "Using MESE: ${chord1.rootDegree}→${chord2.rootDegree}, re-centered: $degree1FromMese→$degree2FromMese (meseDegree=$meseDegree), distance=$dist")
            dist
        } else {
            // Traditional: degree 0 is tonic (first string)
            val dist = (chord2.rootDegree - chord1.rootDegree + 7) % 7
            android.util.Log.d("RootMovement", "Traditional: ${chord1.rootDegree}→${chord2.rootDegree}, distance=$dist")
            dist
        }
        return ROOT_MOVEMENT_STRENGTH[degreeDistance] ?: 1.0
    }

    private fun calculateChordComplexity(voicing: LyreVoicing, chord: Chord): Double {
        // Get frequencies for this voicing with bounds checking
        val freqs = voicing.stringIndices.mapNotNull {
            val index = it - 1
            if (index >= 0 && index < frequencies.size) {
                frequencies[index]
            } else {
                null
            }
        }

        if (freqs.size != voicing.stringIndices.size) {
            // Some indices were invalid, return high complexity
            return 10.0
        }

        // Determine reference frequency based on chordReferenceMode
        // When prioritizing Western cadences, always use bass (traditional approach)
        val referenceFrequency = if (sortByCadence) {
            null  // Use default bass note for Western cadences
        } else {
            when (chordReferenceMode) {
                ChordReferenceMode.BASS -> null  // Use default (minimum)
                ChordReferenceMode.MIDDLE -> {
                    // Use middle note of the chord (or lower-middle if even)
                    val middleIdx = getMiddleIndex(freqs)
                    freqs[middleIdx]
                }
                ChordReferenceMode.MESE -> {
                    // Use middle string of lyre (mese)
                    val meseIdx = meseStringIndex - 1  // Convert to 0-indexed
                    if (meseIdx >= 0 && meseIdx < frequencies.size) {
                        frequencies[meseIdx]
                    } else {
                        null  // Fall back to default if invalid
                    }
                }
            }
        }

        // Convert to ratios using the selected reference
        val ratios = chordAnalyzer.frequenciesToRatios(freqs, referenceFrequency)

        // Calculate chord complexity
        val chordComplexity = chordAnalyzer.complexityWithFiveAdjustments(ratios)

        // Add voicing penalty
        return chordComplexity + voicing.voicingPenalty()
    }

    private fun calculateProgressionComplexity(voicingSequence: List<LyreVoicing>): Double {
        var complexity = 0.0

        // Individual chord complexities
        for (voicing in voicingSequence) {
            complexity += calculateChordComplexity(voicing, voicing.chord)
        }

        // Voice leading distances
        for (i in 0 until voicingSequence.size - 1) {
            val vlDistance = voiceLeadingDistance(voicingSequence[i], voicingSequence[i + 1])
            complexity += vlDistance * VOICE_LEADING_WEIGHT
        }

        // Root movement
        for (i in 0 until voicingSequence.size - 1) {
            val rootComplexity = rootMovementComplexity(voicingSequence[i].chord, voicingSequence[i + 1].chord)
            complexity += rootComplexity
        }

        return complexity
    }

    fun generateProgressions(minLength: Int = 2, maxLength: Int = 4, maxResults: Int = 50, chordSizes: Set<Int>? = null): Map<Int, List<Progression>> {
        val resultsByLength = mutableMapOf<Int, List<Progression>>()

        for (length in minLength..maxLength) {
            val progressionList = mutableListOf<Progression>()

            // Generate all possible chord sequences
            // Filter chords by size if specified
            val availableChords = if (chordSizes != null && chordSizes.isNotEmpty()) {
                chords.filter { it.size in chordSizes }.map { Pair(it.rootDegree, it.size) }
            } else {
                chords.map { Pair(it.rootDegree, it.size) }
            }

            if (availableChords.isEmpty()) {
                // No chords of requested size available
                continue
            }

            val chordSequences = generateChordSequences(availableChords, length)

            for (chordSequence in chordSequences) {
                // Skip sequences with consecutive identical chords
                if (chordSequence.zipWithNext().any { it.first == it.second }) {
                    continue
                }

                // For 4-chord sequences, skip if first pair equals second pair
                if (length == 4 && chordSequence.size == 4) {
                    if (chordSequence[0] == chordSequence[2] && chordSequence[1] == chordSequence[3]) {
                        continue
                    }
                }

                // For each chord sequence, get voicing options
                val voicingOptions = chordSequence.map { voicings[it] ?: emptyList() }

                // Skip if any chord has no voicings
                if (voicingOptions.any { it.isEmpty() }) {
                    continue
                }

                // Try all combinations of voicings
                val voicingCombos = generateVoicingCombinations(voicingOptions)
                for (voicingCombo in voicingCombos) {
                    val complexity = calculateProgressionComplexity(voicingCombo)

                    val chordObjs = voicingCombo.map { it.chord }
                    val description = voicingCombo.joinToString(" - ")
                    val functional = chordObjs.joinToString(" - ")

                    progressionList.add(
                        Progression(complexity, voicingCombo, chordObjs, description, functional)
                    )
                }
            }

            // Sort by complexity and take top results
            resultsByLength[length] = progressionList.sortedBy { it.complexity }.take(maxResults)
        }

        return resultsByLength
    }

    fun generateProgressionsWithTimeout(
        minLength: Int = 2,
        maxLength: Int = 4,
        maxResults: Int = 50,
        chordSizes: Set<Int>? = null,
        timeoutMillis: Long,
        startTime: Long,
        onTimeout: () -> Unit
    ): Map<Int, List<Progression>> {
        val resultsByLength = mutableMapOf<Int, List<Progression>>()

        for (length in minLength..maxLength) {
            val progressionList = mutableListOf<Progression>()

            // Generate all possible chord sequences
            // Filter chords by size if specified
            val availableChords = if (chordSizes != null && chordSizes.isNotEmpty()) {
                chords.filter { it.size in chordSizes }.map { Pair(it.rootDegree, it.size) }
            } else {
                chords.map { Pair(it.rootDegree, it.size) }
            }

            if (availableChords.isEmpty()) {
                // No chords of requested size available
                continue
            }

            val chordSequences = generateChordSequences(availableChords, length)

            for (chordSequence in chordSequences) {
                // Check timeout
                if (System.currentTimeMillis() - startTime > timeoutMillis) {
                    onTimeout()
                    // Return what we have so far
                    if (progressionList.isNotEmpty()) {
                        resultsByLength[length] = progressionList.sortedBy { it.complexity }.take(maxResults)
                    }
                    return resultsByLength
                }

                // Skip sequences with consecutive identical chords
                if (chordSequence.zipWithNext().any { it.first == it.second }) {
                    continue
                }

                // For 4-chord sequences, skip if first pair equals second pair
                if (length == 4 && chordSequence.size == 4) {
                    if (chordSequence[0] == chordSequence[2] && chordSequence[1] == chordSequence[3]) {
                        continue
                    }
                }

                // For each chord sequence, get voicing options
                val voicingOptions = chordSequence.map { voicings[it] ?: emptyList() }

                // Skip if any chord has no voicings
                if (voicingOptions.any { it.isEmpty() }) {
                    continue
                }

                // Try all combinations of voicings
                val voicingCombos = generateVoicingCombinations(voicingOptions)
                for (voicingCombo in voicingCombos) {
                    // Check timeout periodically
                    if (progressionList.size % 100 == 0 && System.currentTimeMillis() - startTime > timeoutMillis) {
                        onTimeout()
                        // Return what we have so far
                        if (progressionList.isNotEmpty()) {
                            resultsByLength[length] = progressionList.sortedBy { it.complexity }.take(maxResults)
                        }
                        return resultsByLength
                    }

                    val complexity = calculateProgressionComplexity(voicingCombo)

                    val chordObjs = voicingCombo.map { it.chord }
                    val description = voicingCombo.joinToString(" - ")
                    val functional = chordObjs.joinToString(" - ")

                    progressionList.add(
                        Progression(complexity, voicingCombo, chordObjs, description, functional)
                    )
                }
            }

            // Sort by complexity and take top results
            resultsByLength[length] = progressionList.sortedBy { it.complexity }.take(maxResults)
        }

        return resultsByLength
    }

    private fun generateChordSequences(availableChords: List<Pair<Int, Int>>, length: Int): List<List<Pair<Int, Int>>> {
        val result = mutableListOf<List<Pair<Int, Int>>>()

        fun backtrack(current: MutableList<Pair<Int, Int>>) {
            if (current.size == length) {
                result.add(current.toList())
                return
            }

            for (chord in availableChords) {
                current.add(chord)
                backtrack(current)
                current.removeAt(current.size - 1)
            }
        }

        backtrack(mutableListOf())
        return result
    }

    private fun generateVoicingCombinations(voicingOptions: List<List<LyreVoicing>>): List<List<LyreVoicing>> {
        if (voicingOptions.isEmpty()) return emptyList()
        if (voicingOptions.size == 1) return voicingOptions[0].map { listOf(it) }

        val result = mutableListOf<List<LyreVoicing>>()

        fun backtrack(index: Int, current: MutableList<LyreVoicing>) {
            if (index == voicingOptions.size) {
                result.add(current.toList())
                return
            }

            for (voicing in voicingOptions[index]) {
                current.add(voicing)
                backtrack(index + 1, current)
                current.removeAt(current.size - 1)
            }
        }

        backtrack(0, mutableListOf())
        return result
    }

    // Analyze cadence characteristics for non-Western display
    fun analyzeCadenceCharacteristics(progression: Progression): CadenceAnalysis {
        // Analyze the final two chords for cadence characteristics
        val voicings = progression.voicings
        val chords = progression.chords

        if (voicings.size < 2) {
            return CadenceAnalysis("Static", "Smooth", "Neutral", "Continuous")
        }

        val penultimateVoicing = voicings[voicings.size - 2]
        val finalVoicing = voicings[voicings.size - 1]
        val penultimateChord = chords[chords.size - 2]
        val finalChord = chords[chords.size - 1]

        // 1. ROOT MOTION PATTERN
        // Re-center degrees around mese if using multi-chord mese mode
        val rootDegreeDistance = if (!sortByCadence && useMultiChordMese) {
            // Re-center both degrees around mese
            val penultimateDegreeFromMese = (penultimateChord.rootDegree - meseDegree + 7) % 7
            val finalDegreeFromMese = (finalChord.rootDegree - meseDegree + 7) % 7
            (finalDegreeFromMese - penultimateDegreeFromMese + 7) % 7
        } else {
            // Traditional: use original degrees
            (finalChord.rootDegree - penultimateChord.rootDegree + 7) % 7
        }

        // Get reference notes based on chordReferenceMode setting
        // (bass, middle, or mese depending on user selection)
        val penultimateRef = getReferenceNote(penultimateVoicing)
        val finalRef = getReferenceNote(finalVoicing)

        val motion = when {
            // Check if reference notes are the same first
            penultimateRef == finalRef -> "Static"
            rootDegreeDistance == 0 -> "Static"
            rootDegreeDistance in listOf(3, 4) -> {
                // Distances 3-4 are fourths/fifths (strong intervals)
                if (finalRef < penultimateRef) "Strong Descent" else "Ascending Close"
            }
            rootDegreeDistance in listOf(1, 2) -> {
                // Distances 1-2 are seconds/thirds (weak intervals)
                if (finalRef < penultimateRef) "Weak Descent" else "Ascending Close"
            }
            else -> {
                // Distances 5-6 are sixths/sevenths
                if (finalRef < penultimateRef) "Weak Descent" else "Ascending Close"
            }
        }

        // 2. VOICE LEADING CHARACTER
        // Count how many voices move between chords (using actual semitones, not pitch classes)
        val penultimateSemitones = penultimateVoicing.semitones.toSet()
        val finalSemitones = finalVoicing.semitones.toSet()
        val commonTones = penultimateSemitones.intersect(finalSemitones).size

        // Calculate voices moved from the perspective of the chord with more notes
        val totalVoices = maxOf(penultimateVoicing.semitones.size, finalVoicing.semitones.size)
        val voicesMoved = totalVoices - commonTones

        val voiceLeading = when (voicesMoved) {
            0, 1 -> "Smooth"
            2 -> "Moderate"
            else -> "Active"
        }

        // 3. HARMONIC DIRECTION
        // Calculate individual chord complexities
        val penultimateComplexity = calculateChordComplexity(penultimateVoicing, penultimateChord)
        val finalComplexity = calculateChordComplexity(finalVoicing, finalChord)
        val complexityDelta = finalComplexity - penultimateComplexity

        val harmonicDirection = when {
            complexityDelta < -0.5 -> "Resolving"
            complexityDelta > 0.5 -> "Tensing"
            else -> "Neutral"
        }

        // 4. CLOSURE STRENGTH
        val isStrongDescent = (motion == "Strong Descent")
        val isResolving = (harmonicDirection == "Resolving")
        val isRootPosition = finalVoicing.inversion == "root"

        val closureStrength = when {
            isStrongDescent && isResolving && isRootPosition -> "Terminal"
            motion == "Ascending Close" || harmonicDirection == "Tensing" || !isRootPosition -> "Suspensive"
            else -> "Continuous"
        }

        return CadenceAnalysis(motion, voiceLeading, harmonicDirection, closureStrength)
    }

    fun identifyCommonProgressions(progressionsByLength: Map<Int, List<Progression>>): Map<Int, List<Progression>> {
        val identified = mutableMapOf<Int, List<Progression>>()

        // Mode-specific common patterns
        // For each mode, define patterns based on their characteristic progressions
        val twoChordPatternsByMode = mapOf(
            // DORIOS (Phrygian): i ♭II ♭III iv v° ♭VI ♭vii
            Mode.DORIOS to mapOf(
                listOf(0, 1) to "Phrygian Cadence (i-♭II)",
                listOf(5, 0) to "Plagal Resolution (♭VI-i)",
                listOf(6, 0) to "Subtonic Resolution (♭vii-i)",
                listOf(1, 0) to "Descending Half-Step (♭II-i)",
                listOf(3, 0) to "Subdominant Resolution (iv-i)",
                listOf(2, 0) to "Mediant Resolution (♭III-i)",
                listOf(4, 0) to "Diminished Resolution (v°-i)",
                listOf(0, 5) to "Half Cadence (i-♭VI)",
                listOf(0, 2) to "Rising Mediant (i-♭III)",
                listOf(5, 6) to "Modal Motion (♭VI-♭vii)"
            ),
            // PHRYGIOS (Dorian): i ii ♭III IV v vi° ♭VII
            Mode.PHRYGIOS to mapOf(
                listOf(4, 0) to "Minor Authentic (v-i)",
                listOf(3, 0) to "Dorian Plagal (IV-i)",
                listOf(6, 0) to "Dorian Subtonic (♭VII-i)",
                listOf(0, 4) to "Minor Half Cadence (i-v)",
                listOf(2, 0) to "Mediant Resolution (♭III-i)",
                listOf(1, 0) to "Supertonic Resolution (ii-i)",
                listOf(0, 6) to "Rising Subtonic (i-♭VII)",
                listOf(0, 3) to "Subdominant Motion (i-IV)",
                listOf(3, 4) to "Plagal to Dominant (IV-v)"
            ),
            // LYDIOS (Ionian/Major): I ii iii IV V vi vii°
            Mode.LYDIOS to mapOf(
                listOf(4, 0) to "Authentic Cadence (V-I)",
                listOf(3, 0) to "Plagal Cadence (IV-I)",
                listOf(0, 4) to "Half Cadence (I-V)",
                listOf(4, 5) to "Deceptive Cadence (V-vi)",
                listOf(1, 0) to "Supertonic Resolution (ii-I)",
                listOf(5, 0) to "Submediant Resolution (vi-I)",
                listOf(6, 0) to "Leading Tone Resolution (vii°-I)",
                listOf(0, 3) to "Tonic to Subdominant (I-IV)",
                listOf(0, 5) to "Tonic to Submediant (I-vi)"
            ),
            // MIXOLYDIOS (Locrian): i° ♭II ♭iii iv ♭V ♭VI ♭vii
            Mode.MIXOLYDIOS to mapOf(
                listOf(5, 0) to "Locrian Resolution (♭VI-i°)",
                listOf(1, 0) to "Half-Step Descent (♭II-i°)",
                listOf(6, 0) to "Subtonic Resolution (♭vii-i°)",
                listOf(3, 0) to "Subdominant Resolution (iv-i°)",
                listOf(2, 0) to "Mediant Resolution (♭iii-i°)"
            ),
            // HYPODORIOS (Aeolian/Minor): i ii° ♭III iv v ♭VI ♭VII
            Mode.HYPODORIOS to mapOf(
                listOf(4, 0) to "Minor Authentic (v-i)",
                listOf(3, 0) to "Minor Plagal (iv-i)",
                listOf(0, 4) to "Minor Half Cadence (i-v)",
                listOf(6, 0) to "Aeolian Subtonic (♭VII-i)",
                listOf(5, 0) to "Submediant Resolution (♭VI-i)",
                listOf(2, 0) to "Relative Major (♭III-i)",
                listOf(0, 6) to "Rising Subtonic (i-♭VII)",
                listOf(0, 5) to "Rising Submediant (i-♭VI)",
                listOf(5, 6) to "Modal Progression (♭VI-♭VII)"
            ),
            // HYPOLYDIOS (Lydian): I II iii ♯iv° V vi vii
            Mode.HYPOLYDIOS to mapOf(
                listOf(4, 0) to "Authentic Cadence (V-I)",
                listOf(1, 0) to "Lydian Characteristic (II-I)",
                listOf(0, 4) to "Half Cadence (I-V)",
                listOf(3, 0) to "Plagal Cadence (IV-I)",
                listOf(0, 1) to "Lydian Rising (I-II)",
                listOf(4, 5) to "Deceptive Cadence (V-vi)"
            ),
            // HYPOPHRYGIOS (Mixolydian): I ii iii° IV v vi ♭VII
            Mode.HYPOPHRYGIOS to mapOf(
                listOf(4, 0) to "Minor Dominant (v-I)",
                listOf(6, 0) to "Mixolydian Cadence (♭VII-I)",
                listOf(3, 0) to "Plagal Cadence (IV-I)",
                listOf(0, 6) to "Mixolydian Half Cadence (I-♭VII)",
                listOf(0, 4) to "Tonic to Dominant (I-v)",
                listOf(0, 3) to "Tonic to Subdominant (I-IV)",
                listOf(5, 0) to "Submediant Resolution (vi-I)",
                listOf(1, 0) to "Supertonic Resolution (ii-I)"
            )
        )

        val threeChordPatternsByMode = mapOf(
            Mode.DORIOS to mapOf(
                listOf(0, 5, 6) to "Phrygian Descent (i-♭VI-♭vii)",
                listOf(6, 5, 0) to "Descending Resolution (♭vii-♭VI-i)"
            ),
            Mode.PHRYGIOS to mapOf(
                listOf(0, 3, 4) to "Dorian Progression (i-IV-v)",
                listOf(1, 4, 0) to "Minor Turnaround (ii-v-i)",
                listOf(0, 6, 3) to "Dorian Color (i-♭VII-IV)"
            ),
            Mode.LYDIOS to mapOf(
                listOf(0, 3, 4) to "Basic Progression (I-IV-V)",
                listOf(0, 4, 0) to "Tonicization (I-V-I)",
                listOf(1, 4, 0) to "Jazz Turnaround (ii-V-I)",
                listOf(0, 5, 3) to "Descending Thirds (I-vi-IV)"
            ),
            Mode.HYPODORIOS to mapOf(
                listOf(0, 3, 4) to "Minor Progression (i-iv-v)",
                listOf(0, 5, 6) to "Aeolian Descent (i-♭VI-♭VII)",
                listOf(0, 6, 3) to "Modal Color (i-♭VII-iv)"
            ),
            Mode.HYPOLYDIOS to mapOf(
                listOf(0, 1, 4) to "Lydian Brightness (I-II-V)",
                listOf(0, 3, 4) to "Basic Progression (I-IV-V)"
            ),
            Mode.HYPOPHRYGIOS to mapOf(
                listOf(0, 6, 3) to "Mixolydian Character (I-♭VII-IV)",
                listOf(0, 3, 6) to "Modal Ascent (I-IV-♭VII)"
            )
        )

        val fourChordPatternsByMode = mapOf(
            Mode.DORIOS to mapOf(
                listOf(0, 5, 6, 0) to "Phrygian Loop (i-♭VI-♭vii-i)",
                listOf(0, 1, 5, 0) to "Chromatic Circle (i-♭II-♭VI-i)",
                listOf(6, 5, 0, 1) to "Modal Cycle (♭vii-♭VI-i-♭II)",
                listOf(0, 5, 1, 0) to "Flat-Side Loop (i-♭VI-♭II-i)"
            ),
            Mode.PHRYGIOS to mapOf(
                listOf(0, 6, 3, 4) to "Dorian Cycle (i-♭VII-IV-v)",
                listOf(0, 3, 6, 0) to "Dorian Loop (i-IV-♭VII-i)"
            ),
            Mode.LYDIOS to mapOf(
                listOf(0, 4, 5, 3) to "Pop Progression (I-V-vi-IV)",
                listOf(0, 5, 3, 4) to "50s Progression (I-vi-IV-V)",
                listOf(5, 3, 0, 4) to "Sensitive Progression (vi-IV-I-V)",
                listOf(0, 3, 4, 0) to "Circle of Fifths (I-IV-V-I)",
                listOf(1, 4, 0, 0) to "Extended Turnaround (ii-V-I-I)"
            ),
            Mode.MIXOLYDIOS to mapOf(
                listOf(0, 1, 5, 0) to "Locrian Cycle (i°-♭II-♭VI-i°)"
            ),
            Mode.HYPODORIOS to mapOf(
                listOf(0, 5, 6, 3) to "Aeolian Progression (i-♭VI-♭VII-iv)",
                listOf(0, 6, 3, 4) to "Minor Modal Cycle (i-♭VII-iv-v)",
                listOf(0, 3, 6, 0) to "Minor Loop (i-iv-♭VII-i)"
            ),
            Mode.HYPOLYDIOS to mapOf(
                listOf(0, 1, 4, 0) to "Lydian Resolution (I-II-V-I)"
            ),
            Mode.HYPOPHRYGIOS to mapOf(
                listOf(0, 6, 3, 6) to "Mixolydian Vamp (I-♭VII-IV-♭VII)",
                listOf(0, 3, 6, 0) to "Mixolydian Loop (I-IV-♭VII-I)"
            )
        )

        for ((length, progressions) in progressionsByLength) {
            val identifiedList = progressions.map { prog ->
                val chordDegrees = prog.chords.map { it.rootDegree }

                // Transform chord degrees if using mese as tonic
                // When sortByCadence is true (Western cadences), ignore useMultiChordMese
                val degreesForMatching = if (!sortByCadence && useMultiChordMese) {
                    // Re-center degrees around mese as degree 0
                    chordDegrees.map { (it - meseDegree + 7) % 7 }
                } else {
                    // Use original degrees (degree 0 is tonic)
                    chordDegrees
                }

                // Only identify patterns for triads
                val allTriads = prog.chords.all { it.size == TRIAD_SIZE }
                val name = if (allTriads && degreesForMatching.size >= 2) {
                    // A cadence is defined by the LAST TWO CHORDS
                    val lastTwo = degreesForMatching.takeLast(2)
                    val cadenceName = twoChordPatternsByMode[mode]?.get(lastTwo)

                    // Also check for full progression patterns (for famous progressions like I-V-vi-IV)
                    val fullPattern = when (length) {
                        3 -> threeChordPatternsByMode[mode]?.get(degreesForMatching)
                        4 -> fourChordPatternsByMode[mode]?.get(degreesForMatching)
                        else -> null
                    }

                    // Prefer full pattern name, but fall back to cadence name
                    fullPattern ?: cadenceName
                } else {
                    null
                }

                // Debug logging
                if (name != null) {
                    val degreeInfo = if (!sortByCadence && useMultiChordMese) {
                        "original degrees $chordDegrees (transformed to $degreesForMatching with mese=$meseDegree)"
                    } else {
                        "degrees $chordDegrees"
                    }
                    android.util.Log.d("CadenceID", "Found: $name for $degreeInfo in mode $mode")
                }

                prog.copy(commonName = name)
            }

            val namedCount = identifiedList.count { it.commonName != null }
            android.util.Log.d("CadenceID", "Mode: $mode, Length: $length, Total: ${identifiedList.size}, Named: $namedCount")

            identified[length] = identifiedList
        }

        return identified
    }

    private fun semitoneToNoteName(semitone: Int): String {
        val noteNames = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
        val firstNoteIndex = noteNames.indexOf(firstNote)
        if (firstNoteIndex == -1) return "?"

        val absoluteSemitone = firstNoteIndex + semitone
        val octave = 4 + (absoluteSemitone / 12)
        val noteIndex = absoluteSemitone % 12
        return "${noteNames[noteIndex]}$octave"
    }

    private fun voicingToNoteNames(voicing: LyreVoicing): String {
        return voicing.semitones.joinToString("-") { semitoneToNoteName(it) }
    }

    fun formatResults(identified: Map<Int, List<Progression>>, selectedLength: Int? = null): String {
        val sb = StringBuilder()
        val width = 100

        sb.appendLine("=".repeat(width))
        sb.appendLine("LYRE CHORD PROGRESSION ANALYSIS - ${mode.name}")
        sb.appendLine("=".repeat(width))
        sb.appendLine()
        sb.appendLine("Number of strings: $numStrings")
        sb.appendLine()

        // Print top progressions for selected length or all lengths
        val lengthsToShow = if (selectedLength != null) {
            listOf(selectedLength)
        } else {
            listOf(2, 3, 4)
        }

        for (length in lengthsToShow) {
            val progressions = identified[length] ?: emptyList()
            if (progressions.isEmpty()) {
                sb.appendLine("No $length-chord progressions found")
                sb.appendLine()
                continue
            }

            sb.appendLine("=".repeat(width))
            sb.appendLine("$length-CHORD PROGRESSIONS (Top 100)")
            sb.appendLine("=".repeat(width))
            sb.appendLine()
            sb.appendLine(String.format("%-5s %-70s %-12s",
                "Rank", "Notes", "Complexity"))
            sb.appendLine("-".repeat(width))

            for ((rank, prog) in progressions.take(100).withIndex()) {
                val noteSequence = prog.voicings.joinToString("  ") { voicingToNoteNames(it) }

                sb.appendLine(String.format("%-5d %-70s %-12.4f",
                    rank + 1, noteSequence.take(70), prog.complexity))
            }

            sb.appendLine()
        }

        sb.appendLine("=".repeat(width))
        sb.appendLine("Based on analyze_lyre_progressions.py")
        sb.appendLine("=".repeat(width))

        return sb.toString()
    }

    fun formatResultsForDisplay(identified: Map<Int, List<Progression>>, selectedLength: Int? = null, sortByCadence: Boolean = false): List<ProgressionDisplay> {
        val displayList = mutableListOf<ProgressionDisplay>()

        android.util.Log.d("ProgDebug", "=== ANDROID PROGRESSION ANALYSIS DEBUG ===")
        android.util.Log.d("ProgDebug", "Selected length: $selectedLength")
        android.util.Log.d("ProgDebug", "Sort by cadence: $sortByCadence")

        // Get progressions for selected length or all lengths
        val lengthsToShow = if (selectedLength != null) {
            listOf(selectedLength)
        } else {
            listOf(2, 3, 4)
        }

        for (length in lengthsToShow) {
            val progressionsList = identified[length] ?: emptyList()

            android.util.Log.d("ProgDebug", "Length $length: Input progressions: ${progressionsList.size}")

            val withNames = progressionsList.count { it.commonName != null }
            android.util.Log.d("ProgDebug", "Progressions with cadence names: $withNames")

            // Sort by cadence if requested
            val progressions = if (sortByCadence) {
                progressionsList.sortedWith(compareBy(
                    // First sort by whether it has a common name (nulls last)
                    { it.commonName == null },
                    // Then group by the actual cadence name (so all "Phrygian Cadence" together, etc.)
                    { it.commonName ?: "" },
                    // Finally by complexity within each cadence group
                    { it.complexity }
                ))
            } else {
                progressionsList
            }

            android.util.Log.d("ProgDebug", "After sorting: ${progressions.size}")

            val top100 = progressions.take(100)
            android.util.Log.d("ProgDebug", "After take(100): ${top100.size}")
            android.util.Log.d("ProgDebug", "\nFirst 10 progressions:")

            for ((rank, prog) in top100.withIndex()) {
                if (rank < 10) {
                    val chordSymbols = prog.chords.joinToString(" - ")
                    android.util.Log.d("ProgDebug", "  ${rank + 1}. $chordSymbols | complexity: ${"%.6f".format(prog.complexity)} | cadence: ${prog.commonName ?: "none"}")
                }
                val noteSequence = prog.voicings.joinToString("  ") { voicingToNoteNames(it) }
                val chordSymbols = prog.chords.joinToString(" - ")

                // Debug: Log if this progression has a common name
                if (prog.commonName != null) {
                    android.util.Log.d("CadenceDisplay", "Rank ${rank + 1}: ${prog.commonName} - $chordSymbols")
                }

                // Get frequencies for all notes in the progression
                val allFrequencies = mutableListOf<Float>()
                val notesPerChord = mutableListOf<Int>()
                for (voicing in prog.voicings) {
                    val freqs = voicing.stringIndices.mapNotNull {
                        val index = it - 1
                        if (index >= 0 && index < frequencies.size) {
                            frequencies[index]
                        } else {
                            android.util.Log.e("ChordProgDisplay", "Invalid string index: $it (0-based: $index) for ${frequencies.size} strings")
                            null
                        }
                    }

                    if (freqs.size != voicing.stringIndices.size) {
                        // Some indices were invalid, log error but continue with valid frequencies
                        android.util.Log.w("ChordProgDisplay", "Some invalid indices in voicing")
                    }

                    allFrequencies.addAll(freqs)
                    notesPerChord.add(freqs.size)
                }

                android.util.Log.d("ChordProgDisplay", "Rank ${rank + 1}: ${prog.voicings.size} chords, notesPerChord=$notesPerChord, totalFreqs=${allFrequencies.size}")

                // Calculate cadence analysis for non-Western display
                val cadenceAnalysis = analyzeCadenceCharacteristics(prog)

                displayList.add(
                    ProgressionDisplay(
                        rank = rank + 1,
                        notes = noteSequence,
                        chordSymbols = chordSymbols,
                        commonName = prog.commonName,
                        complexity = prog.complexity,
                        frequencies = allFrequencies,
                        notesPerChord = notesPerChord,
                        cadenceAnalysis = cadenceAnalysis
                    )
                )
            }
        }

        android.util.Log.d("ProgDebug", "\n=== Total results returned: ${displayList.size} ===\n")

        return displayList
    }

    private fun buildIntervalPattern(): String {
        val pattern = mutableListOf<String>()
        for (i in scaleSemitones.indices) {
            val nextI = (i + 1) % scaleSemitones.size
            val interval = if (nextI == 0) {
                12 - scaleSemitones[i] + scaleSemitones[0]
            } else {
                scaleSemitones[nextI] - scaleSemitones[i]
            }

            pattern.add(when (interval) {
                1 -> "H"
                2 -> "W"
                else -> "$interval"
            })
        }
        return pattern.joinToString("-")
    }
}
