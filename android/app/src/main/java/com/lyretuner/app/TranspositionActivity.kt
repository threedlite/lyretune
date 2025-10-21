package com.lyretuner.app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.lyretuner.app.ui.theme.LyreTuneTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.sin

class TranspositionActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    TranspositionScreen(
                        onBackPressed = { finish() }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranspositionScreen(onBackPressed: () -> Unit) {
    // Epitaph of Seikilos - actual notes from Wikipedia transcription
    // Modern notation shows these pitches (originally a fourth lower in Iastian)
    val seikilosNotes = "A3 E4 E4 C#4 D4 E4 D4 C#4 D4 E4 D4 C#4 B3 A3 B3 G3 A3 C#4 E4 D4 C#4 D4 C#4 A3 B3 G3 A3 C#4 B3 D4 E4 C#4 A3 A3 A3 F#3 E3"
    
    var inputText by remember { mutableStateOf(seikilosNotes) }
    var transpositionAmount by remember { mutableStateOf(0f) }
    var outputText by remember { mutableStateOf(seikilosNotes) }
    var uniqueNotesText by remember { mutableStateOf(getUniqueNotesSortedByFrequency(seikilosNotes)) }
    var isPlaying by remember { mutableStateOf(false) }
    var audioTrack by remember { mutableStateOf<AudioTrack?>(null) }
    
    val coroutineScope = rememberCoroutineScope()
    
    // Update output whenever input or transposition changes
    LaunchedEffect(inputText, transpositionAmount) {
        try {
            outputText = transposeNotes(inputText, transpositionAmount.toInt())
            // Calculate unique notes sorted by frequency
            uniqueNotesText = getUniqueNotesSortedByFrequency(outputText)
        } catch (e: Exception) {
            outputText = "Error: Invalid note format"
            uniqueNotesText = ""
            e.printStackTrace()
        }
    }
    
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
    
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = { Text("Transposition Tool") },
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
            // Input text field
            OutlinedTextField(
                value = inputText,
                onValueChange = { inputText = it },
                label = { Text("Input Notes") },
                placeholder = { Text("Enter notes like: A3 Bb3 C#4 D4\nChords like: C4-E4-G4 F3-A3-C4") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace),
                singleLine = false
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Transposition slider
            Column {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Transpose:",
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Text(
                        text = when {
                            transpositionAmount > 0 -> "+${transpositionAmount.toInt()} semitones"
                            transpositionAmount < 0 -> "${transpositionAmount.toInt()} semitones"
                            else -> "0 semitones (no change)"
                        },
                        style = MaterialTheme.typography.bodyLarge,
                        color = when {
                            transpositionAmount != 0f -> MaterialTheme.colorScheme.primary
                            else -> MaterialTheme.colorScheme.onSurface
                        }
                    )
                }
                
                Slider(
                    value = transpositionAmount,
                    onValueChange = { 
                        transpositionAmount = kotlin.math.round(it).toFloat()
                    },
                    valueRange = -12f..12f,
                    steps = 23, // 24 total positions (-12 to +12)
                    modifier = Modifier.fillMaxWidth(),
                    colors = SliderDefaults.colors(
                        thumbColor = Color.Gray,
                        activeTrackColor = Color.Gray,
                        inactiveTrackColor = Color.LightGray
                    )
                )
                
                // Helper text
                Text(
                    text = "Slide to transpose up or down by semitones (half steps)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // Output text field
            OutlinedTextField(
                value = outputText,
                onValueChange = { /* Read-only */ },
                label = { Text("Transposed Notes") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                readOnly = true,
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline
                ),
                singleLine = false
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Unique notes display
            OutlinedTextField(
                value = uniqueNotesText,
                onValueChange = { /* Read-only */ },
                label = { Text("Unique Notes (sorted by frequency)") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp),
                readOnly = true,
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline
                ),
                singleLine = false
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Play button
            Button(
                onClick = {
                    try {
                        if (isPlaying) {
                            // Stop playback
                            audioTrack?.stop()
                            audioTrack?.release()
                            audioTrack = null
                            isPlaying = false
                        } else {
                            // Start playback
                            coroutineScope.launch {
                                try {
                                    isPlaying = true
                                    playNotes(outputText) { track ->
                                        audioTrack = track
                                    }
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                } finally {
                                    isPlaying = false
                                }
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        isPlaying = false
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isPlaying) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                )
            ) {
                if (!isPlaying) {
                    Icon(
                        imageVector = Icons.Filled.PlayArrow,
                        contentDescription = "Play",
                        modifier = Modifier.padding(end = 8.dp)
                    )
                }
                Text(if (isPlaying) "Stop Playback" else "Play Transposed Notes")
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Reset button
            OutlinedButton(
                onClick = {
                    transpositionAmount = 0f
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = transpositionAmount != 0f
            ) {
                Text("Reset Transposition")
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Clear button
            OutlinedButton(
                onClick = {
                    inputText = ""
                    outputText = ""
                    transpositionAmount = 0f
                    // Stop playback if running
                    if (isPlaying) {
                        audioTrack?.stop()
                        audioTrack?.release()
                        audioTrack = null
                        isPlaying = false
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Clear All")
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Restore Seikilos button
            OutlinedButton(
                onClick = {
                    inputText = seikilosNotes
                    transpositionAmount = 0f
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Restore Epitaph of Seikilos")
            }
            
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

// Transposition logic
fun transposeNotes(input: String, semitones: Int): String {
    if (semitones == 0) return input
    
    val notes = input.trim().split(Regex("\\s+"))
    return notes.joinToString(" ") { note ->
        transposeNote(note, semitones)
    }
}

fun transposeNote(note: String, semitones: Int): String {
    if (note.isBlank()) return note

    // Check if this is a chord (contains hyphens)
    if (note.contains("-")) {
        // Split chord into individual notes, transpose each, and rejoin
        val notes = note.split("-")
        return notes.joinToString("-") { singleNote ->
            transposeSingleNote(singleNote, semitones)
        }
    }

    // Single note - transpose normally
    return transposeSingleNote(note, semitones)
}

fun transposeSingleNote(note: String, semitones: Int): String {
    if (note.isBlank()) return note

    // Parse the note
    val parsed = parseNote(note)
    if (parsed == null) return note // Return unchanged if parsing fails

    val (noteName, accidental, octave) = parsed

    // Convert to MIDI note number
    val baseNotes = mapOf(
        'C' to 0, 'D' to 2, 'E' to 4, 'F' to 5,
        'G' to 7, 'A' to 9, 'B' to 11
    )

    val baseMidi = baseNotes[noteName] ?: return note
    val accidentalOffset = when (accidental) {
        "#" -> 1
        "##" -> 2
        "b" -> -1
        "bb" -> -2
        else -> 0
    }

    // Calculate MIDI note number (C4 = 60)
    var midiNote = (octave + 1) * 12 + baseMidi + accidentalOffset

    // Apply transposition
    midiNote += semitones

    // Convert back to note name
    return midiToNote(midiNote)
}

fun parseNote(note: String): Triple<Char, String, Int>? {
    // Match note pattern: letter + optional accidentals + octave number
    val pattern = Regex("^([A-Ga-g])([#b]{0,2})([-]?\\d+)$")
    val match = pattern.find(note.trim()) ?: return null
    
    val (letter, accidental, octaveStr) = match.destructured
    val octave = octaveStr.toIntOrNull() ?: return null
    
    return Triple(letter.uppercase()[0], accidental, octave)
}

fun midiToNote(midi: Int): String {
    val noteNames = arrayOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    val octave = (midi / 12) - 1
    val noteIndex = midi % 12
    
    // Handle negative MIDI numbers
    val adjustedNoteIndex = if (noteIndex < 0) noteIndex + 12 else noteIndex
    val adjustedOctave = if (noteIndex < 0) octave - 1 else octave
    
    return "${noteNames[adjustedNoteIndex]}$adjustedOctave"
}

// Audio playback functions
suspend fun playNotes(notesString: String, onTrackCreated: (AudioTrack) -> Unit) = withContext(Dispatchers.IO) {
    try {
        val notes = notesString.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        if (notes.isEmpty()) return@withContext
        
        val sampleRate = 44100
        val noteDuration = 0.4 // seconds per note
        val pauseDuration = 0.05 // small pause between notes
        
        // Create audio track with error handling
        val bufferSize = try {
            AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(sampleRate * 2) // Ensure minimum buffer size
        } catch (e: Exception) {
            e.printStackTrace()
            return@withContext
        }
        
        val audioTrack = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (e: Exception) {
            e.printStackTrace()
            return@withContext
        }
        
        onTrackCreated(audioTrack)
        
        try {
            audioTrack.play()
            
            // Play each note or chord
            for (note in notes) {
                try {
                    // Check if this is a chord (contains hyphens)
                    if (note.contains("-")) {
                        // Parse chord into individual notes
                        val chordNotes = note.split("-").filter { it.isNotBlank() }
                        val frequencies = chordNotes.mapNotNull { singleNote ->
                            val freq = noteToFrequency(singleNote)
                            if (freq > 0 && freq < 20000) freq else null
                        }

                        if (frequencies.isNotEmpty()) {
                            // Generate and play chord (mixed tones)
                            val samples = generateChord(frequencies, noteDuration, sampleRate)
                            audioTrack.write(samples, 0, samples.size)

                            // Add pause between notes/chords
                            val pauseSamples = ShortArray((pauseDuration * sampleRate).toInt())
                            audioTrack.write(pauseSamples, 0, pauseSamples.size)
                        }
                    } else {
                        // Single note
                        val frequency = noteToFrequency(note)
                        if (frequency > 0 && frequency < 20000) { // Sanity check frequency
                            // Generate and play tone
                            val samples = generateTone(frequency, noteDuration, sampleRate)
                            audioTrack.write(samples, 0, samples.size)

                            // Add pause between notes
                            val pauseSamples = ShortArray((pauseDuration * sampleRate).toInt())
                            audioTrack.write(pauseSamples, 0, pauseSamples.size)
                        }
                    }
                } catch (e: Exception) {
                    // Skip invalid note and continue
                    e.printStackTrace()
                }
            }

            // Wait for the last note to finish playing
            // Calculate total time for last note + pause
            val finalWaitTime = ((noteDuration + pauseDuration) * 1000).toLong()
            Thread.sleep(finalWaitTime)
        } finally {
            try {
                audioTrack.stop()
                audioTrack.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    } catch (e: Exception) {
        e.printStackTrace()
    }
}

fun noteToFrequency(note: String): Double {
    val parsed = parseNote(note) ?: return 0.0
    val (noteName, accidental, octave) = parsed
    
    // Convert to MIDI note number
    val baseNotes = mapOf(
        'C' to 0, 'D' to 2, 'E' to 4, 'F' to 5,
        'G' to 7, 'A' to 9, 'B' to 11
    )
    
    val baseMidi = baseNotes[noteName] ?: return 0.0
    val accidentalOffset = when (accidental) {
        "#" -> 1
        "##" -> 2
        "b" -> -1
        "bb" -> -2
        else -> 0
    }
    
    // Calculate MIDI note number (C4 = 60)
    val midiNote = (octave + 1) * 12 + baseMidi + accidentalOffset
    
    // Convert MIDI to frequency (A4 = 440 Hz, MIDI 69)
    return 440.0 * 2.0.pow((midiNote - 69) / 12.0)
}

fun getUniqueNotesSortedByFrequency(notesString: String): String {
    val tokens = notesString.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    if (tokens.isEmpty()) return ""

    // Create a map of note to frequency for unique notes
    val noteFrequencyMap = mutableMapOf<String, Double>()

    for (token in tokens) {
        // Split by hyphen to handle chords
        val notes = token.split("-").filter { it.isNotBlank() }
        for (note in notes) {
            if (!noteFrequencyMap.containsKey(note)) {
                val frequency = noteToFrequency(note)
                if (frequency > 0) {
                    noteFrequencyMap[note] = frequency
                }
            }
        }
    }

    // Sort by frequency (ascending) and return as space-separated string
    return noteFrequencyMap.entries
        .sortedBy { it.value }
        .map { it.key }
        .joinToString(" ")
}

fun generateTone(frequency: Double, duration: Double, sampleRate: Int): ShortArray {
    val numSamples = (duration * sampleRate).toInt()
    val samples = ShortArray(numSamples)
    val amplitude = 0.7 // Reduce amplitude to avoid clipping
    val fadeInSamples = (0.01 * sampleRate).toInt() // 10ms fade in
    val fadeOutSamples = (0.05 * sampleRate).toInt() // 50ms fade out

    for (i in 0 until numSamples) {
        val angle = 2.0 * PI * i * frequency / sampleRate
        var sample = sin(angle) * amplitude

        // Apply fade in
        if (i < fadeInSamples) {
            sample *= i.toDouble() / fadeInSamples
        }
        // Apply fade out
        else if (i >= numSamples - fadeOutSamples) {
            sample *= (numSamples - i).toDouble() / fadeOutSamples
        }

        samples[i] = (sample * Short.MAX_VALUE).toInt().toShort()
    }

    return samples
}

fun generateChord(frequencies: List<Double>, duration: Double, sampleRate: Int): ShortArray {
    if (frequencies.isEmpty()) return ShortArray(0)
    if (frequencies.size == 1) return generateTone(frequencies[0], duration, sampleRate)

    val numSamples = (duration * sampleRate).toInt()
    val samples = ShortArray(numSamples)
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

        samples[i] = (mixedSample * Short.MAX_VALUE).toInt().toShort()
    }

    return samples
}