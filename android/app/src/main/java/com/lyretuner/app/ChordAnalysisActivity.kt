package com.lyretuner.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lyretuner.app.audio.ScaleCalculator
import com.lyretuner.app.audio.ScaleType
import com.lyretuner.app.audio.Mode
import com.lyretuner.app.audio.Genus
import com.lyretuner.app.audio.Temperament
import com.lyretuner.app.ui.theme.LyreTuneTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.*

class ChordAnalysisActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    ChordAnalysisScreen(
                        context = this@ChordAnalysisActivity,
                        onBackPressed = { finish() }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChordAnalysisScreen(context: Context, onBackPressed: () -> Unit) {
    val sharedPrefs = context.getSharedPreferences("lyretune_settings", Context.MODE_PRIVATE)
    var analysisResult by remember { mutableStateOf("") }
    var isAnalyzing by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val localContext = LocalContext.current

    val coroutineScope = rememberCoroutineScope()

    // Load current settings
    val scaleType = when(sharedPrefs.getInt("scale_type", 0)) {
        0 -> ScaleType.MODES
        1 -> ScaleType.GENRES
        2 -> ScaleType.PENTATONIC
        3 -> ScaleType.DOUBLE_HARMONIC
        4 -> ScaleType.PHORMINX
        else -> ScaleType.MODES
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

    val genus = when(sharedPrefs.getInt("genus", 0)) {
        0 -> Genus.DIATONIC
        1 -> Genus.CHROMATIC
        2 -> Genus.ENHARMONIC
        else -> Genus.DIATONIC
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

    // Check if temperament is EQUAL and show error
    LaunchedEffect(temperament, numStrings) {
        if (temperament == Temperament.EQUAL) {
            errorMessage = "Non-rational tunings not supported, try Just Intonation"
            analysisResult = ""
        } else if (numStrings > 13) {
            errorMessage = "Maximum 13 strings supported for chord analysis"
            analysisResult = ""
        } else {
            errorMessage = null
        }
    }

    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top App Bar
        TopAppBar(
            title = { Text("Chord Analysis Tool") },
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
                    if (scaleType == ScaleType.MODES) {
                        Text("Mode: ${mode.name}", style = MaterialTheme.typography.bodyMedium)
                    }
                    if (scaleType == ScaleType.GENRES) {
                        Text("Genus: ${genus.name}", style = MaterialTheme.typography.bodyMedium)
                    }
                    Text("First Note: $firstNote", style = MaterialTheme.typography.bodyMedium)
                    Text("Number of Strings: $numStrings", style = MaterialTheme.typography.bodyMedium)
                    Text("Temperament: ${temperament.name}", style = MaterialTheme.typography.bodyMedium)
                    Text("Octave Offset: $octaveOffset", style = MaterialTheme.typography.bodyMedium)
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Error message if Equal temperament
            if (errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    )
                ) {
                    Text(
                        text = errorMessage!!,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(16.dp)
                    )
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Analyze button
            Button(
                onClick = {
                    if (temperament != Temperament.EQUAL && numStrings <= 13) {
                        coroutineScope.launch {
                            isAnalyzing = true
                            try {
                                analysisResult = withContext(Dispatchers.Default) {
                                    analyzeChords(
                                        scaleType, mode, genus, firstNote,
                                        numStrings, temperament, octaveOffset
                                    )
                                }
                            } catch (e: Exception) {
                                analysisResult = "Error during analysis: ${e.message}"
                                e.printStackTrace()
                            } finally {
                                isAnalyzing = false
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isAnalyzing && temperament != Temperament.EQUAL && numStrings <= 13
            ) {
                Text(if (isAnalyzing) "Analyzing..." else "Analyze Chords")
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Progress indicator
            if (isAnalyzing) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Analysis results
            if (analysisResult.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                ) {
                    Text(
                        text = "Analysis Results",
                        style = MaterialTheme.typography.titleMedium
                    )

                    // Copy to clipboard button
                    OutlinedButton(
                        onClick = {
                            val clipboard = localContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val clip = ClipData.newPlainText("Chord Analysis", analysisResult)
                            clipboard.setPrimaryClip(clip)
                            Toast.makeText(localContext, "Copied to clipboard", Toast.LENGTH_SHORT).show()
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Share,
                            contentDescription = "Copy",
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Copy")
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    // Outer vertical scroll for the entire results
                    val verticalScrollState = rememberScrollState()
                    val horizontalScrollState = rememberScrollState()

                    SelectionContainer {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .verticalScroll(verticalScrollState)
                                .horizontalScroll(horizontalScrollState)
                                .padding(12.dp)
                        ) {
                            Text(
                                text = analysisResult,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 11.sp,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                Text(
                    text = "Long press to select text • Scroll horizontally and vertically",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

// Chord analysis logic
fun analyzeChords(
    scaleType: ScaleType,
    mode: Mode,
    genus: Genus,
    firstNote: String,
    numStrings: Int,
    temperament: Temperament,
    octaveOffset: Int
): String {
    val analyzer = LyreChordAnalyzer(
        scaleType, mode, genus, firstNote, numStrings, temperament, octaveOffset
    )

    val results = analyzer.analyzeAllChords(minStrings = 2, maxStrings = numStrings)

    return analyzer.formatResults(results, complexityThreshold = null)
}

data class ChordResult(
    val strings: List<Int>,
    val notes: List<String>,
    val frequencies: List<Float>,
    val ratios: List<Int>,
    val complexity: Double,
    val numStrings: Int
)

class LyreChordAnalyzer(
    scaleType: ScaleType,
    mode: Mode,
    genus: Genus,
    firstNote: String,
    val numStrings: Int,
    temperament: Temperament,
    octaveOffset: Int
) {
    val frequencies: List<Float>  // Made public for use by LyreProgressionAnalyzer
    val noteNames: List<String>   // Made public for use by LyreProgressionAnalyzer

    // Formula parameters (from NUMERIC_EMPIRIC_20251018)
    private val augmentedPenalty = 0.6
    private val sus2invPenalty = 0.08
    private val major1invBonus = 0.057
    private val dominant7Bonus = 0.65
    private val halfdim7Penalty = 0.65
    private val alpha = 1.0
    private val beta = 0.3
    private val kappa = 1.0
    private val delta = 0.15
    private val psi = 1.6
    private val omega = 3.3
    private val nu = 0.0
    private val chi = 0.5

    init {
        // Calculate tuning using ScaleCalculator
        val scaleData = ScaleCalculator.calculateScale(
            scaleType, mode, genus, firstNote, numStrings, temperament, octaveOffset
        )
        frequencies = scaleData.frequencies
        noteNames = scaleData.notes
    }

    fun analyzeAllChords(minStrings: Int = 2, maxStrings: Int = numStrings): List<ChordResult> {
        val results = mutableListOf<ChordResult>()

        // Generate all combinations
        for (size in minStrings..maxStrings) {
            val combinations = generateCombinations(numStrings, size)
            for (combo in combinations) {
                val chordFreqs = combo.map { frequencies[it] }
                val chordNotes = combo.map { noteNames[it] }
                val stringIndices = combo.map { it + 1 } // 1-indexed for display

                // Convert to ratios
                val ratios = frequenciesToRatios(chordFreqs)

                // Calculate complexity
                val complexity = complexityWithFiveAdjustments(ratios)

                results.add(
                    ChordResult(
                        strings = stringIndices,
                        notes = chordNotes,
                        frequencies = chordFreqs,
                        ratios = ratios,
                        complexity = complexity,
                        numStrings = size
                    )
                )
            }
        }

        // Sort by complexity (ascending - simplest first)
        return results.sortedWith(compareBy({ it.complexity }, { it.numStrings }))
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

    fun frequenciesToRatios(freqs: List<Float>): List<Int> {
        if (freqs.isEmpty()) return emptyList()

        val minFreq = freqs.minOrNull() ?: return emptyList()
        val ratios = freqs.map { it / minFreq }

        // Convert to integers by finding a common denominator
        val precision = 10000
        // Use banker's rounding (round half to even) to match Python behavior
        val intRatios = ratios.map { bankersRound(it * precision) }

        // Reduce by GCD
        val g = intRatios.reduce { a, b -> gcd(a, b) }
        return intRatios.map { it / g }
    }

    private fun bankersRound(value: Float): Int {
        // Banker's rounding: round half to even (matches Python's round())
        val floor = kotlin.math.floor(value).toInt()
        val fraction = value - floor

        return when {
            fraction < 0.5f -> floor
            fraction > 0.5f -> floor + 1
            floor % 2 == 0 -> floor  // Even: round down
            else -> floor + 1          // Odd: round up
        }
    }

    private fun gcd(a: Int, b: Int): Int {
        var x = abs(a)
        var y = abs(b)
        while (y != 0) {
            val temp = y
            y = x % y
            x = temp
        }
        return x
    }

    private fun primeFactorization(n: Int): List<Int> {
        var num = n
        val factors = mutableListOf<Int>()
        var d = 2
        while (d * d <= num) {
            while (num % d == 0) {
                factors.add(d)
                num /= d
            }
            d++
        }
        if (num > 1) {
            factors.add(num)
        }
        return factors
    }

    private fun largestPrimeFactor(n: Int): Int {
        if (n <= 1) return 1
        val factors = primeFactorization(n)
        return factors.maxOrNull() ?: 1
    }

    private fun oddPart(n: Int): Int {
        var num = n
        while (num % 2 == 0) {
            num /= 2
        }
        return num
    }

    fun complexityWithFiveAdjustments(notes: List<Int>): Double {
        val intervalOls = mutableListOf<Int>()
        val intervalLps = mutableListOf<Int>()
        val intervalMinOddLps = mutableListOf<Int>()
        var intervalComplexity = 0.0

        // Calculate interval complexity
        for (i in 0 until notes.size - 1) {
            val p = notes[i + 1]
            val q = notes[i]
            val g = gcd(p, q)
            val pReduced = p / g
            val qReduced = q / g

            val oddP = oddPart(pReduced)
            val oddQ = oddPart(qReduced)

            val ol = max(oddP, oddQ)
            val lp = largestPrimeFactor(ol)
            intervalComplexity += alpha * ln(ol.toDouble()) / ln(2.0) + beta * ln(lp.toDouble()) / ln(2.0)
            intervalOls.add(ol)
            intervalLps.add(lp)

            val minOdd = min(oddP, oddQ)
            val lpMinOdd = largestPrimeFactor(minOdd)
            intervalMinOddLps.add(lpMinOdd)
        }

        if (notes.size >= 3) {
            val pSpan = notes.last()
            val qSpan = notes.first()
            val g = gcd(pSpan, qSpan)
            val pSpanReduced = pSpan / g
            val qSpanReduced = qSpan / g

            val oddPSpan = oddPart(pSpanReduced)
            val oddQSpan = oddPart(qSpanReduced)

            val spanOl = max(oddPSpan, oddQSpan)
            val spanLp = largestPrimeFactor(spanOl)

            val allSameOl = intervalOls.toSet().size == 1
            val isHomogeneous = allSameOl && spanOl < intervalOls[0]

            val minNote = notes.minOrNull() ?: 1

            // Targeted adjustments
            var targetedAdjustments = 0.0

            // Triad adjustments (len==3)
            if (notes.size == 3) {
                // Augmented penalty: min=16 AND NOT homogeneous
                if (minNote == 16 && !isHomogeneous) {
                    targetedAdjustments += augmentedPenalty
                }

                // Sus2 1st inv penalty: min=9 AND NOT homogeneous
                if (minNote == 9 && !isHomogeneous) {
                    targetedAdjustments += sus2invPenalty
                }

                // Major 1st inv bonus: min=5 AND NOT homogeneous
                if (minNote == 5 && !isHomogeneous) {
                    targetedAdjustments -= major1invBonus
                }
            }

            // Tetrad adjustments (len==4)
            if (notes.size == 4) {
                // Dominant 7th bonus: min=4
                if (minNote == 4) {
                    targetedAdjustments -= dominant7Bonus
                }

                // Half-diminished 7th penalty: min=5
                if (minNote == 5) {
                    targetedAdjustments += halfdim7Penalty
                }
            }

            val homogeneityBonus: Double
            val chiPenalty: Double
            val psiPenalty: Double
            val omegaPenalty: Double

            if (allSameOl) {
                if (spanOl < intervalOls[0]) {
                    homogeneityBonus = 1.0

                    if (spanOl > 0) {
                        val avgMinOddLp = intervalMinOddLps.average()
                        val lpScale = avgMinOddLp / 3.0  // chi_lp_baseline
                        chiPenalty = chi * max(0.0, 1.0 - ln(spanOl.toDouble()) / ln(2.0)) * lpScale
                    } else {
                        chiPenalty = chi
                    }
                } else {
                    homogeneityBonus = 0.0
                    chiPenalty = 0.0
                }

                if (spanOl == intervalOls[0] * intervalOls[0]) {
                    val avgIntervalMinOddLp = intervalMinOddLps.average()
                    psiPenalty = psi * avgIntervalMinOddLp
                } else {
                    psiPenalty = 0.0
                }

                omegaPenalty = 0.0
            } else {
                homogeneityBonus = 0.0
                psiPenalty = 0.0
                chiPenalty = 0.0
                omegaPenalty = omega * max(0.0, ln(spanLp.toDouble()) / ln(2.0) - ln(5.0) / ln(2.0))  // span_lp_baseline = 5
            }

            val minIntervalOl = intervalOls.minOrNull() ?: 1
            val nuPenalty = nu * max(0.0, ln(minIntervalOl.toDouble()) / ln(2.0) - ln(5.0) / ln(2.0))  // interval_ol_baseline = 5

            val compactnessPenalty = delta * ((notes.last() - notes.first()).toDouble() / notes.first().toDouble())

            return intervalComplexity - kappa * homogeneityBonus + compactnessPenalty +
                   psiPenalty + omegaPenalty + nuPenalty + chiPenalty + targetedAdjustments
        } else {
            // Dyads - no additional complexity
            return intervalComplexity
        }
    }

    fun formatResults(results: List<ChordResult>, complexityThreshold: Double?): String {
        val filtered = if (complexityThreshold != null) {
            results.filter { it.complexity <= complexityThreshold }
        } else {
            results
        }

        val sb = StringBuilder()
        sb.appendLine("=" .repeat(100))
        sb.appendLine("CHORD COMPLEXITY ANALYSIS - ${filtered.size} chords shown")
        sb.appendLine("=" .repeat(100))
        sb.appendLine()
        sb.appendLine("LYRE TUNING")
        sb.appendLine("-" .repeat(100))
        sb.appendLine("Number of strings: $numStrings")
        sb.appendLine()
        sb.appendLine(String.format("%-8s %-12s %-15s", "String", "Note", "Frequency (Hz)"))
        sb.appendLine("-" .repeat(100))
        for (i in 0 until numStrings) {
            sb.appendLine(String.format("%-8d %-12s %-15.2f", i + 1, noteNames[i], frequencies[i]))
        }
        sb.appendLine()
        sb.appendLine("=" .repeat(100))
        sb.appendLine("CHORD RANKINGS")
        sb.appendLine("=" .repeat(100))
        sb.appendLine()
        sb.appendLine(String.format("%-6s %-15s %-30s %-20s %-12s",
            "Rank", "Strings", "Notes", "Ratio", "Complexity"))
        sb.appendLine("-" .repeat(100))

        for ((rank, result) in filtered.withIndex()) {
            val stringsStr = result.strings.joinToString(",")
            val notesStr = result.notes.joinToString(" ")
            val ratioStr = result.ratios.joinToString(":")

            sb.appendLine(String.format("%-6d %-15s %-30s %-20s %-12.6f",
                rank + 1, stringsStr, notesStr, ratioStr, result.complexity))
        }

        sb.appendLine()
        sb.appendLine("=" .repeat(100))
        sb.appendLine("STATISTICS")
        sb.appendLine("=" .repeat(100))
        sb.appendLine("Total chords analyzed: ${results.size}")
        if (filtered.isNotEmpty()) {
            sb.appendLine("Simplest chord: ${filtered[0].notes.joinToString(" ")} " +
                         "(complexity ${String.format("%.6f", filtered[0].complexity)})")
            sb.appendLine("Most complex chord: ${results.last().notes.joinToString(" ")} " +
                         "(complexity ${String.format("%.6f", results.last().complexity)})")
        }
        sb.appendLine()

        // Distribution by size
        sb.appendLine("Distribution by number of strings:")
        for (size in 2..numStrings) {
            val chordsOfSize = results.filter { it.numStrings == size }
            if (chordsOfSize.isNotEmpty()) {
                val avgComplexity = chordsOfSize.map { it.complexity }.average()
                sb.appendLine("  $size strings: ${chordsOfSize.size} chords, " +
                             "avg complexity: ${String.format("%.6f", avgComplexity)}")
            }
        }
        sb.appendLine()

        // Attribution
        sb.appendLine("=" .repeat(100))
        sb.appendLine("Note: Complexity is related to dissonance, so a lower complexity score is related to higher")
        sb.appendLine("consonance in this model.")
        sb.appendLine("Based on https://github.com/threedlite/lyretune/blob/main/analyze_lyre_chords.py")
        sb.appendLine("=" .repeat(100))

        return sb.toString()
    }
}
