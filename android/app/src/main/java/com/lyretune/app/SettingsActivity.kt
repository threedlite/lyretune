package com.lyretune.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyretune.app.ui.theme.LyreTuneTheme

class SettingsActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    SettingsScreen(
                        context = this@SettingsActivity,
                        onBackPressed = { finish() }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(context: Context, onBackPressed: () -> Unit) {
    val sharedPrefs = context.getSharedPreferences("lyretune_settings", Context.MODE_PRIVATE)
    
    // Load all settings from SharedPreferences
    var scaleType by remember { mutableStateOf(sharedPrefs.getInt("scale_type", 0)) }
    var mode by remember { mutableStateOf(sharedPrefs.getInt("mode", 4)) } // Dorios
    var genus by remember { mutableStateOf(sharedPrefs.getInt("genus", 0)) } // Diatonic
    var firstNote by remember { mutableStateOf(sharedPrefs.getString("first_note", "E") ?: "E") }
    var numStrings by remember { mutableStateOf(sharedPrefs.getInt("num_strings", 7)) }
    var temperament by remember { mutableStateOf(sharedPrefs.getInt("temperament", 2)) } // Just Ancient
    var octaveOffset by remember { mutableStateOf(sharedPrefs.getInt("octave_offset", 0)) }
    var fftResolution by remember { mutableStateOf(sharedPrefs.getInt("fft_resolution", 5)) } // Default to maximum resolution (65536)
    
    // Load magnitude scale from SharedPreferences
    var magnitudeScale by remember { 
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
    
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = { Text("Settings") },
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
            // Scale Type Selection
            var scaleTypeExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = scaleTypeExpanded,
                onExpandedChange = { scaleTypeExpanded = !scaleTypeExpanded }
            ) {
                TextField(
                    value = when(scaleType) {
                        0 -> "Modes"
                        1 -> "Genres"
                        2 -> "Pentatonic"
                        3 -> "Double Harmonic"
                        4 -> "Phorminx"
                        else -> "Modes"
                    },
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Scale Type") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = scaleTypeExpanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = scaleTypeExpanded,
                    onDismissRequest = { scaleTypeExpanded = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Modes") },
                        onClick = { 
                            scaleType = 0
                            scaleTypeExpanded = false
                            sharedPrefs.edit().putInt("scale_type", scaleType).apply()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Genres") },
                        onClick = { 
                            scaleType = 1
                            scaleTypeExpanded = false
                            sharedPrefs.edit().putInt("scale_type", scaleType).apply()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Pentatonic") },
                        onClick = { 
                            scaleType = 2
                            scaleTypeExpanded = false
                            sharedPrefs.edit().putInt("scale_type", scaleType).apply()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Double Harmonic") },
                        onClick = { 
                            scaleType = 3
                            scaleTypeExpanded = false
                            sharedPrefs.edit().putInt("scale_type", scaleType).apply()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Phorminx") },
                        onClick = { 
                            scaleType = 4
                            scaleTypeExpanded = false
                            sharedPrefs.edit().putInt("scale_type", scaleType).apply()
                        }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Mode Selection (only for Modes)
            if (scaleType == 0) {
                var modeExpanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(
                    expanded = modeExpanded,
                    onExpandedChange = { modeExpanded = !modeExpanded }
                ) {
                    TextField(
                        value = when(mode) {
                            0 -> "Mixolydios"
                            1 -> "Hypodorios"
                            2 -> "Lydios"
                            3 -> "Phrygios"
                            4 -> "Dorios"
                            5 -> "Hypolydios"
                            6 -> "Hypophrygios"
                            else -> "Dorios"
                        },
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Mode") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = modeExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(
                        expanded = modeExpanded,
                        onDismissRequest = { modeExpanded = false }
                    ) {
                        listOf(
                            "Mixolydios" to 0,
                            "Hypodorios" to 1,
                            "Lydios" to 2,
                            "Phrygios" to 3,
                            "Dorios" to 4,
                            "Hypolydios" to 5,
                            "Hypophrygios" to 6
                        ).forEach { (name, value) ->
                            DropdownMenuItem(
                                text = { Text(name) },
                                onClick = { 
                                    mode = value
                                    modeExpanded = false
                                    sharedPrefs.edit().putInt("mode", mode).apply()
                                }
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // Genus Selection (only for Genres)
            if (scaleType == 1) {
                var genusExpanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(
                    expanded = genusExpanded,
                    onExpandedChange = { genusExpanded = !genusExpanded }
                ) {
                    TextField(
                        value = when(genus) {
                            0 -> "Diatonic"
                            1 -> "Chromatic"
                            2 -> "Enharmonic"
                            else -> "Diatonic"
                        },
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Genus") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = genusExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(
                        expanded = genusExpanded,
                        onDismissRequest = { genusExpanded = false }
                    ) {
                        listOf(
                            "Diatonic" to 0,
                            "Chromatic" to 1,
                            "Enharmonic" to 2
                        ).forEach { (name, value) ->
                            DropdownMenuItem(
                                text = { Text(name) },
                                onClick = { 
                                    genus = value
                                    genusExpanded = false
                                    sharedPrefs.edit().putInt("genus", genus).apply()
                                }
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
            
            // First Note Selection
            var firstNoteExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = firstNoteExpanded,
                onExpandedChange = { firstNoteExpanded = !firstNoteExpanded }
            ) {
                TextField(
                    value = firstNote,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("First Note") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = firstNoteExpanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = firstNoteExpanded,
                    onDismissRequest = { firstNoteExpanded = false }
                ) {
                    listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B").forEach { note ->
                        DropdownMenuItem(
                            text = { Text(note) },
                            onClick = { 
                                firstNote = note
                                firstNoteExpanded = false
                                sharedPrefs.edit().putString("first_note", firstNote).apply()
                            }
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Temperament Selection
            var temperamentExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = temperamentExpanded,
                onExpandedChange = { temperamentExpanded = !temperamentExpanded }
            ) {
                TextField(
                    value = when(temperament) {
                        0 -> "Equal"
                        1 -> "Just"
                        2 -> "Just Ancient"
                        3 -> "Meantone"
                        else -> "Just"
                    },
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Temperament") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = temperamentExpanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = temperamentExpanded,
                    onDismissRequest = { temperamentExpanded = false }
                ) {
                    listOf(
                        "Equal" to 0,
                        "Just" to 1,
                        "Just Ancient" to 2,
                        "Meantone" to 3
                    ).forEach { (name, value) ->
                        DropdownMenuItem(
                            text = { Text(name) },
                            onClick = { 
                                temperament = value
                                temperamentExpanded = false
                                sharedPrefs.edit().putInt("temperament", temperament).apply()
                            }
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // String Count Slider
            Text("Number of Strings: $numStrings")
            Slider(
                value = numStrings.toFloat(),
                onValueChange = { 
                    numStrings = it.toInt()
                    // Save immediately
                    sharedPrefs.edit().putInt("num_strings", numStrings).apply()
                },
                valueRange = 4f..24f,
                steps = 19,
                modifier = Modifier.fillMaxWidth()
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Octave Offset Slider
            Text("Octave Offset: $octaveOffset")
            Slider(
                value = octaveOffset.toFloat(),
                onValueChange = { 
                    octaveOffset = it.toInt()
                    // Save immediately
                    sharedPrefs.edit().putInt("octave_offset", octaveOffset).apply()
                },
                valueRange = -2f..2f,
                steps = 3,
                modifier = Modifier.fillMaxWidth()
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // FFT Resolution Selection
            val fftResolutionOptions = listOf("2048 (Fast)", "4096 (Balanced)", "8192 (High Res)", "16384 (Very High)", "32768 (Ultra)", "65536 (Maximum)")
            val fftResolutionValues = listOf(2048, 4096, 8192, 16384, 32768, 65536)
            
            var fftResolutionExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = fftResolutionExpanded,
                onExpandedChange = { fftResolutionExpanded = !fftResolutionExpanded }
            ) {
                TextField(
                    value = fftResolutionOptions[fftResolution.coerceIn(0, fftResolutionOptions.size - 1)],
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("FFT Resolution") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = fftResolutionExpanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = fftResolutionExpanded,
                    onDismissRequest = { fftResolutionExpanded = false }
                ) {
                    fftResolutionOptions.forEachIndexed { index, option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = { 
                                fftResolution = index
                                fftResolutionExpanded = false
                                sharedPrefs.edit().putInt("fft_resolution", fftResolution).apply()
                            }
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Magnitude Scale Selection
            val magnitudeOptions = listOf("1", "5", "10", "20", "50", "100")
            val magnitudeValues = listOf(1f, 5f, 10f, 20f, 50f, 100f)
            
            var magnitudeExpanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = magnitudeExpanded,
                onExpandedChange = { magnitudeExpanded = !magnitudeExpanded }
            ) {
                TextField(
                    value = magnitudeOptions[magnitudeScale.coerceIn(0, magnitudeOptions.size - 1)],
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Magnitude Scale") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = magnitudeExpanded) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = magnitudeExpanded,
                    onDismissRequest = { magnitudeExpanded = false }
                ) {
                    magnitudeOptions.forEachIndexed { index, option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = { 
                                magnitudeScale = index
                                magnitudeExpanded = false
                                sharedPrefs.edit().putInt("magnitude_scale", magnitudeScale).apply()
                            }
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Tolerance Setting (in Hz)
            var tolerance by remember { mutableStateOf(sharedPrefs.getInt("tolerance", 3)) } // Default 3 Hz
            
            Text("Tolerance: $tolerance Hz")
            Slider(
                value = tolerance.toFloat(),
                onValueChange = { 
                    tolerance = it.toInt()
                    // Save immediately
                    sharedPrefs.edit().putInt("tolerance", tolerance).apply()
                },
                valueRange = 1f..10f,
                steps = 8, // 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
                modifier = Modifier.fillMaxWidth()
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // High-pass Filter Setting (in Hz)
            var highPassFilter by remember { mutableStateOf(sharedPrefs.getInt("high_pass_filter", 150)) } // Default 150 Hz
            
            Text("High-pass Filter: $highPassFilter Hz")
            Slider(
                value = highPassFilter.toFloat(),
                onValueChange = { 
                    highPassFilter = it.toInt()
                    // Save immediately
                    sharedPrefs.edit().putInt("high_pass_filter", highPassFilter).apply()
                },
                valueRange = 0f..500f,
                steps = 99, // 0, 5, 10, 15, ..., 495, 500 (100 steps total)
                modifier = Modifier.fillMaxWidth()
            )
            
            Text(
                text = "Filters out sounds below this frequency to reduce low-frequency noise",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Noise Gate Setting (magnitude threshold)
            var noiseGate by remember { mutableStateOf(sharedPrefs.getFloat("noise_gate", 0.30f)) } // Default 30%
            
            Text("Noise Gate: ${(noiseGate * 100).toInt()}%")
            Slider(
                value = noiseGate,
                onValueChange = { 
                    noiseGate = it
                    // Save immediately
                    sharedPrefs.edit().putFloat("noise_gate", noiseGate).apply()
                },
                valueRange = 0f..0.8f, // 0% to 80%
                steps = 79, // 1% increments
                modifier = Modifier.fillMaxWidth()
            )
            
            Text(
                text = "Filters out all audio below this volume level to reduce background noise",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Full Spectrum Display Option
            var showFullSpectrum by remember { mutableStateOf(sharedPrefs.getBoolean("show_full_spectrum", false)) }
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Show Full Spectrum",
                    style = MaterialTheme.typography.bodyLarge
                )
                Switch(
                    checked = showFullSpectrum,
                    onCheckedChange = { 
                        showFullSpectrum = it
                        sharedPrefs.edit().putBoolean("show_full_spectrum", showFullSpectrum).apply()
                    }
                )
            }
            
            Text(
                text = "Show the complete frequency spectrum from low to high frequencies",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
            )
            
            Spacer(modifier = Modifier.height(32.dp))
            
            // Version Info
            val packageInfo = try {
                context.packageManager.getPackageInfo(context.packageName, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
            
            Text(
                text = "Version: ${packageInfo?.versionName ?: "Unknown"} (${packageInfo?.versionCode ?: "?"})",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            // Reset to Defaults Button
            Button(
                onClick = {
                    // Reset all settings to defaults
                    scaleType = 0
                    mode = 4
                    genus = 0
                    firstNote = "E"
                    numStrings = 7
                    temperament = 2  // Just Ancient
                    octaveOffset = 0
                    fftResolution = 5  // 65536 (Maximum)
                    magnitudeScale = 1  // 5
                    tolerance = 3  // 3 Hz
                    highPassFilter = 150  // 150 Hz
                    noiseGate = 0.30f  // 30%
                    showFullSpectrum = false
                    
                    // Save defaults to SharedPreferences
                    with(sharedPrefs.edit()) {
                        putInt("scale_type", scaleType)
                        putInt("mode", mode)
                        putInt("genus", genus)
                        putString("first_note", firstNote)
                        putInt("num_strings", numStrings)
                        putInt("temperament", temperament)
                        putInt("octave_offset", octaveOffset)
                        putInt("fft_resolution", fftResolution)
                        putInt("magnitude_scale", magnitudeScale)
                        putInt("tolerance", tolerance)
                        putInt("high_pass_filter", highPassFilter)
                        putFloat("noise_gate", noiseGate)
                        putBoolean("show_full_spectrum", showFullSpectrum)
                        apply()
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Reset to Defaults")
            }
        }
    }
}