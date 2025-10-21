package com.lyretuner.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.lyretuner.app.ui.theme.LyreTuneTheme
import org.json.JSONObject
import org.json.JSONArray

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
    
    // Trigger to force reload of all settings
    var settingsReloadTrigger by remember { mutableStateOf(0) }
    
    // Load all settings from SharedPreferences
    var scaleType by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("scale_type", 0)) }
    var mode by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("mode", 4)) } // Dorios
    var genus by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("genus", 0)) } // Diatonic
    var firstNote by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getString("first_note", "E") ?: "E") }
    var numStrings by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("num_strings", 7)) }
    var temperament by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("temperament", 2)) } // Just Ancient
    var octaveOffset by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("octave_offset", 0)) }
    var fftResolution by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("fft_resolution", 3)) } // Default to very high (16384)
    
    // Load magnitude scale from SharedPreferences
    var magnitudeScale by remember(settingsReloadTrigger) { 
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
            // Profile Management Section
            ProfileManagementCard(
                context = context,
                sharedPrefs = sharedPrefs,
                onProfileLoaded = {
                    // Trigger a recomposition to reload all settings from SharedPreferences
                    settingsReloadTrigger++
                }
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
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
                modifier = Modifier.fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = Color.Gray,
                    activeTrackColor = Color.Gray,
                    inactiveTrackColor = Color.LightGray
                )
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
                modifier = Modifier.fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = Color.Gray,
                    activeTrackColor = Color.Gray,
                    inactiveTrackColor = Color.LightGray
                )
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
            
            // Help text for FFT Resolution
            Text(
                text = "If the app response is too slow, try lowering the FFT Resolution",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)
            )
            
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
            var tolerance by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("tolerance", 3)) } // Default 3 Hz
            
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
                modifier = Modifier.fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = Color.Gray,
                    activeTrackColor = Color.Gray,
                    inactiveTrackColor = Color.LightGray
                )
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // High-pass Filter Setting (in Hz)
            var highPassFilter by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getInt("high_pass_filter", 150)) } // Default 150 Hz
            
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
                modifier = Modifier.fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = Color.Gray,
                    activeTrackColor = Color.Gray,
                    inactiveTrackColor = Color.LightGray
                )
            )
            
            Text(
                text = "Filters out sounds below this frequency to reduce low-frequency noise",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Noise Gate Setting (magnitude threshold)
            var noiseGate by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getFloat("noise_gate", 0.30f)) } // Default 30%
            
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
                modifier = Modifier.fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = Color.Gray,
                    activeTrackColor = Color.Gray,
                    inactiveTrackColor = Color.LightGray
                )
            )
            
            Text(
                text = "Filters out all audio below this volume level to reduce background noise",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp)
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Full Spectrum Display Option
            var showFullSpectrum by remember(settingsReloadTrigger) { mutableStateOf(sharedPrefs.getBoolean("show_full_spectrum", false)) }
            
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
            
            // Transposition Tool Button
            OutlinedButton(
                onClick = {
                    val intent = Intent(context, TranspositionActivity::class.java)
                    context.startActivity(intent)
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Open Transposition Tool")
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Chord Analysis Tool Button
            OutlinedButton(
                onClick = {
                    val intent = Intent(context, ChordAnalysisActivity::class.java)
                    context.startActivity(intent)
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Open Chord Analysis Tool")
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Chord Progression Tool Button (only for Modes)
            if (scaleType == 0) {
                OutlinedButton(
                    onClick = {
                        val intent = Intent(context, ChordProgressionActivity::class.java)
                        context.startActivity(intent)
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Suggest Chord Progressions (Beta)")
                }

                Spacer(modifier = Modifier.height(16.dp))
            }
            
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
                    fftResolution = 3  // 16384 (Very High)
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
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Version Info
            val packageInfo = try {
                context.packageManager.getPackageInfo(context.packageName, 0)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
            
            Text(
                text = "Version: ${packageInfo?.versionName ?: "Unknown"} (${packageInfo?.versionCode ?: "?"})",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 4.dp)
            )
            
            Text(
                text = "Built: ${BuildConfig.BUILD_TIMESTAMP}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            
            // License Link
            Text(
                text = "View License",
                style = MaterialTheme.typography.bodySmall.copy(
                    textDecoration = TextDecoration.Underline
                ),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .padding(bottom = 16.dp)
                    .clickable {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/threedlite/lyretune/blob/main/LICENSE.txt"))
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileManagementCard(
    context: Context, 
    sharedPrefs: android.content.SharedPreferences,
    onProfileLoaded: () -> Unit = {}
) {
    var profileName by remember { mutableStateOf("") }
    var showSaveDialog by remember { mutableStateOf(false) }
    val profiles = remember { mutableStateOf(loadProfileList(context)) }
    var selectedProfile by remember { mutableStateOf("") }
    var profileExpanded by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var profileToDelete by remember { mutableStateOf("") }
    
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
                text = "Settings Profiles",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = 12.dp)
            )
            
            // Save profile section
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = profileName,
                    onValueChange = { profileName = it },
                    label = { Text("Profile Name") },
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                Button(
                    onClick = {
                        if (profileName.isNotBlank()) {
                            saveProfile(context, profileName, sharedPrefs)
                            profileName = ""
                            showSaveDialog = true
                            profiles.value = loadProfileList(context)
                        }
                    },
                    enabled = profileName.isNotBlank()
                ) {
                    Text("Save")
                }
            }
            
            // Show save confirmation
            if (showSaveDialog) {
                LaunchedEffect(Unit) {
                    kotlinx.coroutines.delay(2000)
                    showSaveDialog = false
                }
                Text(
                    text = "Profile saved successfully!",
                    color = Color.Green,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
            
            // Load profile section
            if (profiles.value.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                
                Text(
                    text = "Load Profile:",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    ExposedDropdownMenuBox(
                        expanded = profileExpanded,
                        onExpandedChange = { profileExpanded = !profileExpanded },
                        modifier = Modifier.weight(1f)
                    ) {
                        TextField(
                            value = selectedProfile.ifEmpty { "Select a profile..." },
                            onValueChange = {},
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = profileExpanded) },
                            modifier = Modifier.menuAnchor().fillMaxWidth()
                        )
                        ExposedDropdownMenu(
                            expanded = profileExpanded,
                            onDismissRequest = { profileExpanded = false }
                        ) {
                            profiles.value.forEach { profile ->
                                DropdownMenuItem(
                                    text = { Text(profile) },
                                    onClick = {
                                        selectedProfile = profile
                                        profileExpanded = false
                                    },
                                    trailingIcon = {
                                        IconButton(
                                            onClick = {
                                                profileToDelete = profile
                                                showDeleteDialog = true
                                            }
                                        ) {
                                            Icon(
                                                Icons.Filled.Delete,
                                                contentDescription = "Delete",
                                                tint = MaterialTheme.colorScheme.error
                                            )
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Button(
                        onClick = {
                            if (selectedProfile.isNotBlank()) {
                                loadProfile(context, selectedProfile, sharedPrefs)
                                onProfileLoaded()
                            }
                        },
                        enabled = selectedProfile.isNotBlank()
                    ) {
                        Text("Load")
                    }
                }
            }
        }
    }
    
    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { 
                showDeleteDialog = false 
                profileToDelete = ""
            },
            title = { Text("Delete Profile") },
            text = { Text("Are you sure you want to delete the profile \"$profileToDelete\"?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        deleteProfile(context, profileToDelete)
                        profiles.value = loadProfileList(context)
                        if (selectedProfile == profileToDelete) {
                            selectedProfile = ""
                        }
                        showDeleteDialog = false
                        profileToDelete = ""
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        profileToDelete = ""
                    }
                ) {
                    Text("Cancel")
                }
            }
        )
    }
}

// Profile management helper functions
fun sanitizeProfileName(name: String): String {
    // Replace invalid characters with underscores
    return name.replace(Regex("[^a-zA-Z0-9_\\- ]"), "_").take(50)
}

fun saveProfile(context: Context, profileName: String, settingsPrefs: android.content.SharedPreferences) {
    try {
        val profilePrefs = context.getSharedPreferences("lyretune_profiles", Context.MODE_PRIVATE)
        val sanitizedName = sanitizeProfileName(profileName)
        
        // Create JSON object with all settings
        val profileData = JSONObject().apply {
            put("scale_type", settingsPrefs.getInt("scale_type", 0))
            put("mode", settingsPrefs.getInt("mode", 4))
            put("genus", settingsPrefs.getInt("genus", 0))
            put("first_note", settingsPrefs.getString("first_note", "E"))
            put("num_strings", settingsPrefs.getInt("num_strings", 7))
            put("temperament", settingsPrefs.getInt("temperament", 2))
            put("octave_offset", settingsPrefs.getInt("octave_offset", 0))
            put("fft_resolution", settingsPrefs.getInt("fft_resolution", 3))
            put("magnitude_scale", settingsPrefs.getInt("magnitude_scale", 1))
            put("tolerance", settingsPrefs.getInt("tolerance", 3))
            put("high_pass_filter", settingsPrefs.getInt("high_pass_filter", 150))
            put("noise_gate", settingsPrefs.getFloat("noise_gate", 0.30f).toDouble())
            put("show_full_spectrum", settingsPrefs.getBoolean("show_full_spectrum", false))
        }
        
        // Save profile
        profilePrefs.edit().putString(sanitizedName, profileData.toString()).apply()
        
        // Update profile list
        val profileList = profilePrefs.getStringSet("profile_list", mutableSetOf()) ?: mutableSetOf()
        profileList.add(sanitizedName)
        profilePrefs.edit().putStringSet("profile_list", profileList).apply()
    } catch (e: Exception) {
        e.printStackTrace()
    }
}

fun loadProfile(context: Context, profileName: String, settingsPrefs: android.content.SharedPreferences) {
    try {
        val profilePrefs = context.getSharedPreferences("lyretune_profiles", Context.MODE_PRIVATE)
        val profileDataString = profilePrefs.getString(profileName, null) ?: return
        val profileData = JSONObject(profileDataString)
        
        // Load all settings
        with(settingsPrefs.edit()) {
            putInt("scale_type", profileData.optInt("scale_type", 0))
            putInt("mode", profileData.optInt("mode", 4))
            putInt("genus", profileData.optInt("genus", 0))
            putString("first_note", profileData.optString("first_note", "E"))
            putInt("num_strings", profileData.optInt("num_strings", 7))
            putInt("temperament", profileData.optInt("temperament", 2))
            putInt("octave_offset", profileData.optInt("octave_offset", 0))
            putInt("fft_resolution", profileData.optInt("fft_resolution", 3))
            putInt("magnitude_scale", profileData.optInt("magnitude_scale", 1))
            putInt("tolerance", profileData.optInt("tolerance", 3))
            putInt("high_pass_filter", profileData.optInt("high_pass_filter", 150))
            putFloat("noise_gate", profileData.optDouble("noise_gate", 0.30).toFloat())
            putBoolean("show_full_spectrum", profileData.optBoolean("show_full_spectrum", false))
            apply()
        }
    } catch (e: Exception) {
        e.printStackTrace()
    }
}

fun deleteProfile(context: Context, profileName: String) {
    try {
        val profilePrefs = context.getSharedPreferences("lyretune_profiles", Context.MODE_PRIVATE)
        
        // Remove profile data
        profilePrefs.edit().remove(profileName).apply()
        
        // Update profile list
        val profileList = profilePrefs.getStringSet("profile_list", mutableSetOf()) ?: mutableSetOf()
        profileList.remove(profileName)
        profilePrefs.edit().putStringSet("profile_list", profileList).apply()
    } catch (e: Exception) {
        e.printStackTrace()
    }
}

fun loadProfileList(context: Context): List<String> {
    return try {
        val profilePrefs = context.getSharedPreferences("lyretune_profiles", Context.MODE_PRIVATE)
        val profileSet = profilePrefs.getStringSet("profile_list", emptySet()) ?: emptySet()
        profileSet.sorted()
    } catch (e: Exception) {
        e.printStackTrace()
        emptyList()
    }
}