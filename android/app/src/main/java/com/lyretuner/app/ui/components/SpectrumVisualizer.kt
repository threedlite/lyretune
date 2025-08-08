package com.lyretuner.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import android.util.Log
import kotlinx.coroutines.delay

@Composable
fun SpectrumVisualizer(
    spectrumData: List<Float>,
    modifier: Modifier = Modifier,
    magnitudeScale: Float = 1.0f,
    stringFrequencies: List<Float> = emptyList(),
    stringNotes: List<String> = emptyList(),
    detectedFrequency: Float = 0f,
    closestNoteIndex: Int = -1,
    centsDifference: Float = 0f,
    fftSize: Int = 4096,
    showFullSpectrum: Boolean = false,
    tolerance: Int = 20,
    persistentInTuneIndex: Int = -1,
    magnitude: Float = 0f,
    noiseGate: Float = 0.02f,
    highPassFilter: Int = 150,
    onStringInTune: (Boolean, Int, Float) -> Unit = { _, _, _ -> }
) {
    // Zoom and pan state
    var zoomLevel by remember { mutableStateOf(1f) }
    var panOffset by remember { mutableStateOf(0f) }
    
    // Calculate if any string is in tune and which one
    val stringInTuneData = remember(spectrumData, stringFrequencies, magnitude, stringNotes) {
        if (spectrumData.isNotEmpty() && stringFrequencies.isNotEmpty()) {
            val sampleRate = 48000f
            val binToFreq = sampleRate / fftSize.toFloat()
            var bestPeakMagnitude = 0f
            var bestStringIndex = -1
            var bestPeakFrequency = 0f
            
            stringFrequencies.forEachIndexed { stringIndex, stringFreq ->
                if (stringFreq > 0f) {
                    val centsRange = 50f
                    val freqRangeLow = stringFreq * 2.0f.pow(-centsRange / 1200.0f)
                    val freqRangeHigh = stringFreq * 2.0f.pow(centsRange / 1200.0f)
                    
                    var maxMagnitudeInRange = 0f
                    var peakFreqInRange = 0f
                    spectrumData.forEachIndexed { binIndex, binMagnitude ->
                        val binFreq = binIndex.toFloat() * binToFreq
                        if (binFreq >= freqRangeLow && binFreq <= freqRangeHigh && binMagnitude.toFloat() > maxMagnitudeInRange) {
                            maxMagnitudeInRange = binMagnitude
                            peakFreqInRange = binFreq
                        }
                    }
                    
                    if (maxMagnitudeInRange > bestPeakMagnitude && maxMagnitudeInRange > noiseGate) {
                        bestPeakMagnitude = maxMagnitudeInRange
                        bestStringIndex = stringIndex
                        bestPeakFrequency = peakFreqInRange
                    }
                }
            }
            Triple(bestPeakMagnitude > 0f, bestStringIndex, bestPeakFrequency)
        } else {
            Triple(false, -1, 0f)
        }
    }
    
    // Notify parent about string in-tune state
    LaunchedEffect(stringInTuneData) {
        onStringInTune(stringInTuneData.first, stringInTuneData.second, stringInTuneData.third)
    }
    
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(120.dp)
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    try {
                        // Validate input values
                        val safeZoom = zoom.coerceIn(0.1f, 5f)
                        // Use vertical pan (pan.y) for frequency navigation since spectrum is vertical
                        val safePan = pan.y.coerceIn(-size.height.toFloat(), size.height.toFloat())
                        
                        // Update zoom level with constraints
                        zoomLevel = (zoomLevel * safeZoom).coerceIn(0.5f, 10f)
                        
                        // Update pan offset with generous constraints for full spectrum navigation
                        val safeSize = if (size.height > 0) size.height else 1
                        // Allow very generous pan range - zoom level squared gives more range when zoomed
                        val maxPan = safeSize * zoomLevel * zoomLevel
                        panOffset = (panOffset + safePan).coerceIn(-maxPan, maxPan)
                    } catch (e: Exception) {
                        // Reset to safe values if any calculation fails
                        zoomLevel = 1f
                        panOffset = 0f
                    }
                }
            }
    ) {
        if (spectrumData.isNotEmpty()) {
            drawSpectrum(
                data = spectrumData, 
                magnitudeScale = magnitudeScale, 
                stringFrequencies = stringFrequencies, 
                stringNotes = stringNotes, 
                detectedFrequency = detectedFrequency, 
                closestNoteIndex = closestNoteIndex, 
                centsDifference = centsDifference, 
                fftSize = fftSize, 
                showFullSpectrum = showFullSpectrum, 
                tolerance = tolerance,
                zoomLevel = zoomLevel,
                panOffset = panOffset,
                magnitude = magnitude,
                noiseGate = noiseGate,
                highPassFilter = highPassFilter
            )
        }
    }
}

private fun DrawScope.drawSpectrum(
    data: List<Float>, 
    magnitudeScale: Float = 1.0f,
    stringFrequencies: List<Float> = emptyList(),
    stringNotes: List<String> = emptyList(),
    detectedFrequency: Float = 0f,
    closestNoteIndex: Int = -1,
    centsDifference: Float = 0f,
    fftSize: Int = 4096,
    showFullSpectrum: Boolean = false,
    tolerance: Int = 20,
    zoomLevel: Float = 1f,
    panOffset: Float = 0f,
    magnitude: Float = 0f,
    noiseGate: Float = 0.02f,
    highPassFilter: Int = 150
) {
    val width = size.width
    val height = size.height
    
    // Calculate base frequency range based on display mode
    val (baseMinFreq, baseMaxFreq) = if (showFullSpectrum) {
        // Show full spectrum from 20Hz to 8kHz (similar to original program)
        20f to 8000f
    } else {
        // Focus on string frequencies ±20%
        val validFrequencies = stringFrequencies.filter { it > 0f }
        if (validFrequencies.isEmpty()) return
        
        val minStringFreq = validFrequencies.minOrNull() ?: 100f
        val maxStringFreq = validFrequencies.maxOrNull() ?: 1000f
        (minStringFreq * 0.8f) to (maxStringFreq * 1.2f)
    }
    
    // Apply zoom and pan to frequency range with safety checks
    val freqRange = (baseMaxFreq - baseMinFreq).coerceAtLeast(1f) // Prevent zero range
    val safeZoomLevel = zoomLevel.coerceIn(0.1f, 20f) // Prevent extreme zoom values
    val zoomedRange = freqRange / safeZoomLevel
    val centerFreq = baseMinFreq + freqRange * 0.5f
    
    // Calculate pan offset in frequency space - allow panning across entire range
    val safeHeight = if (height > 0) height else 1f
    val maxPanFreqRange = freqRange - zoomedRange // Maximum frequency range we can pan
    // Pan up = higher frequencies, pan down = lower frequencies  
    val panFreqOffset = (panOffset / (safeHeight * safeZoomLevel)) * maxPanFreqRange
    
    // Calculate display window with bounds checking
    val rawMinFreq = centerFreq - zoomedRange * 0.5f + panFreqOffset
    val rawMaxFreq = rawMinFreq + zoomedRange
    
    // Ensure we stay within the base frequency range
    val minFreq = rawMinFreq.coerceAtLeast(baseMinFreq)
    val maxFreq = rawMaxFreq.coerceAtMost(baseMaxFreq)
        
    // Ensure minFreq < maxFreq with minimum 1Hz difference
    val finalMinFreq = minFreq.coerceAtMost(baseMaxFreq - 1f)
    val finalMaxFreq = maxFreq.coerceAtLeast(finalMinFreq + 1f)
    
    // Draw spectrum bars horizontally (bars extend from left to right)
    // Map spectrum data to the same frequency range as the strings
    val sampleRate = 48000f
    val binToFreq = sampleRate / fftSize.toFloat()
    
    // Collect all frequency bins within display range
    val barsInRange = mutableListOf<Pair<Float, Float>>() // (y-position, magnitude)
    
    data.forEachIndexed { index, value ->  // Use all available data
        // Convert bin index to frequency
        val frequency = index * binToFreq
        
        // Only collect bars within our display range
        if (frequency >= finalMinFreq && frequency <= finalMaxFreq) {
            // Map frequency to y position using the same calculation as string lines
            val freqDiff = finalMaxFreq - finalMinFreq
            val normalizedFreq = if (freqDiff > 0) {
                ((frequency - finalMinFreq) / freqDiff).coerceIn(0f, 1f)
            } else {
                0.5f // Default to center if range is invalid
            }
            val y = height * (1f - normalizedFreq) // Invert so higher frequencies are at top
            barsInRange.add(y to value)
        }
    }
    
    // Calculate bar height to fill the display with no gaps
    val barHeight = if (barsInRange.size > 1) {
        (height / barsInRange.size.toFloat()).coerceAtLeast(1f)
    } else {
        3f // Fallback for single bar
    }
    
    // Draw bars with calculated height to eliminate gaps (only if we have bars)
    if (barsInRange.isNotEmpty()) {
        barsInRange.forEach { (y, value) ->
            try {
                val safeY = y.coerceIn(0f, height)
                val barWidth = (value * magnitudeScale * 0.1f).coerceIn(0f, 1f) * width * 0.8f
                val safeBarWidth = barWidth.coerceAtLeast(0f)
                
                if (safeBarWidth > 0 && barHeight > 0) {
                    // Calculate color intensity based on magnitude - lighter blue for higher values
                    val normalizedValue = (value * magnitudeScale * 0.1f).coerceIn(0f, 1f)
                    // Interpolate from dark blue (0xFF1565C0) to light blue (0xFF64B5F6)
                    val darkBlue = 0xFF1565C0
                    val lightBlue = 0xFF64B5F6
                    
                    val red = ((darkBlue shr 16) and 0xFF) + (normalizedValue * (((lightBlue shr 16) and 0xFF) - ((darkBlue shr 16) and 0xFF))).toInt()
                    val green = ((darkBlue shr 8) and 0xFF) + (normalizedValue * (((lightBlue shr 8) and 0xFF) - ((darkBlue shr 8) and 0xFF))).toInt()
                    val blue = (darkBlue and 0xFF) + (normalizedValue * ((lightBlue and 0xFF) - (darkBlue and 0xFF))).toInt()
                    
                    val interpolatedColor = Color((0xFF000000 or (red.toLong() shl 16) or (green.toLong() shl 8) or blue.toLong()).toInt())
                    
                    drawLine(
                        color = interpolatedColor,
                        start = Offset(0f, safeY),
                        end = Offset(safeBarWidth, safeY),
                        strokeWidth = barHeight
                    )
                }
            } catch (e: Exception) {
                // Skip this bar if drawing fails
            }
        }
    }
    
    // Find the highest peak within tolerance of any string
    var bestStringIndex = -1
    var bestPeakMagnitude = 0f
    var bestPeakFrequency = 0f
    var anyStringInTune = false
    
    if (data.isNotEmpty() && stringFrequencies.isNotEmpty()) {
        val sampleRate = 48000f
        val binToFreq = sampleRate / fftSize.toFloat()
        
        // For each string, find the highest peak within ±50 cents tolerance
        stringFrequencies.forEachIndexed { stringIndex, stringFreq ->
            if (stringFreq > 0f) {
                // Calculate frequency range for ±50 cents around this string
                val centsRange = 50f // ±50 cents tolerance
                val freqRangeLow = stringFreq * 2.0f.pow(-centsRange / 1200.0f)
                val freqRangeHigh = stringFreq * 2.0f.pow(centsRange / 1200.0f)
                
                // Find the highest peak in this frequency range
                var maxMagnitudeInRange = 0f
                var peakFreqInRange = 0f
                
                data.forEachIndexed { binIndex, binMagnitude ->
                    val binFreq = binIndex.toFloat() * binToFreq
                    if (binFreq >= freqRangeLow && binFreq <= freqRangeHigh && binMagnitude.toFloat() > maxMagnitudeInRange) {
                        maxMagnitudeInRange = binMagnitude
                        peakFreqInRange = binFreq
                    }
                }
                
                // Check if this is the best peak found so far
                if (maxMagnitudeInRange > bestPeakMagnitude && maxMagnitudeInRange > magnitude * 0.1f) { // Above noise threshold
                    bestPeakMagnitude = maxMagnitudeInRange
                    bestPeakFrequency = peakFreqInRange
                    bestStringIndex = stringIndex
                    anyStringInTune = true
                }
            }
        }
    }
    
    // Draw string frequency lines as horizontal lines across the spectrum
    if (stringFrequencies.isNotEmpty()) {
        stringFrequencies.forEachIndexed { index, frequency ->
            if (frequency > 0f && index < stringNotes.size && frequency >= finalMinFreq && frequency <= finalMaxFreq) {
                // Map frequency to y position using the calculated range
                val freqDiff = finalMaxFreq - finalMinFreq
                val normalizedFreq = if (freqDiff > 0) {
                    ((frequency - finalMinFreq) / freqDiff).coerceIn(0f, 1f)
                } else {
                    0.5f // Default to center if range is invalid
                }
                val y = height * (1f - normalizedFreq) // Invert so higher frequencies are at top
                
                // Only the string with the highest peak within tolerance turns green
                val isCurrentlyInTune = (index == bestStringIndex && bestPeakMagnitude > noiseGate)
                val isClosest = closestNoteIndex == index
                val isPersistentlyInTune = false // TODO: Fix persistence
                
                // Draw horizontal string line
                val lineColor = when {
                    isCurrentlyInTune || isPersistentlyInTune -> Color(0xFF4CAF50) // Bright green for highest peak within tolerance
                    isClosest -> Color(0xFF8BC34A) // Light green for closest match  
                    else -> Color.Yellow // Yellow for other strings
                }
                drawLine(
                    color = lineColor,
                    start = Offset(0f, y),
                    end = Offset(width, y),
                    strokeWidth = if (isCurrentlyInTune || isPersistentlyInTune) 5f else if (isClosest) 4f else 3f
                )
                
                // Draw note label with background for better readability
                val text = "${stringNotes[index]} ${frequency.toInt()}Hz"
                val paint = android.graphics.Paint().apply {
                    color = Color.Black.toArgb()
                    textSize = 72f  // 3x the original 24f
                    isAntiAlias = true
                    textAlign = android.graphics.Paint.Align.RIGHT
                }
                
                // Get text bounds
                val bounds = android.graphics.Rect()
                paint.getTextBounds(text, 0, text.length, bounds)
                
                // Draw black background rectangle for text (larger for 3x text)
                drawRect(
                    color = Color.Black,
                    topLeft = Offset(width - 300f, y - 40f),
                    size = androidx.compose.ui.geometry.Size(295f, 70f)
                )
                
                // Draw text in yellow on black background
                paint.color = Color.Yellow.toArgb()
                drawContext.canvas.nativeCanvas.drawText(
                    text,
                    width - 10f,
                    y + 15f,
                    paint
                )
            }
        }
    }
    
    // Draw grey vertical line for noise threshold
    val noiseThresholdX = (noiseGate * magnitudeScale * 0.1f).coerceIn(0f, 1f) * width * 0.8f
    if (noiseThresholdX > 0f) {
        drawLine(
            color = Color.Gray,
            start = Offset(noiseThresholdX, 0f),
            end = Offset(noiseThresholdX, height),
            strokeWidth = 2f
        )
    }
    
    // Draw grey horizontal line for high pass filter frequency
    val highPassFreq = highPassFilter.toFloat()
    if (highPassFreq >= finalMinFreq && highPassFreq <= finalMaxFreq) {
        // Map frequency to y position using the same calculation as string lines
        val freqDiff = finalMaxFreq - finalMinFreq
        val normalizedFreq = if (freqDiff > 0) {
            ((highPassFreq - finalMinFreq) / freqDiff).coerceIn(0f, 1f)
        } else {
            0.5f
        }
        val y = height * (1f - normalizedFreq) // Invert so higher frequencies are at top
        
        drawLine(
            color = Color.Gray,
            start = Offset(0f, y),
            end = Offset(width, y),
            strokeWidth = 2f
        )
    }
    
    // Removed red detected frequency line as requested
    
    // Removed gray grid lines as requested
}