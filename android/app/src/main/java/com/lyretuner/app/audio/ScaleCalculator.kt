package com.lyretuner.app.audio

import kotlin.math.*

enum class ScaleType {
    MODES, GENRES, PENTATONIC, DOUBLE_HARMONIC, PHORMINX
}

enum class Mode {
    MIXOLYDIOS, HYPODORIOS, LYDIOS, PHRYGIOS, DORIOS, HYPOLYDIOS, HYPOPHRYGIOS
}

enum class Genus {
    DIATONIC, CHROMATIC, ENHARMONIC
}

enum class Temperament {
    EQUAL, JUST, JUST_ANCIENT, MEANTONE
}

data class ScaleData(
    val notes: List<String>,
    val frequencies: List<Float>
)

class ScaleCalculator {
    companion object {
        private const val A4_FREQ = 440.0f
        
        fun calculateScale(
            scaleType: ScaleType,
            mode: Mode?,
            genus: Genus?,
            firstNote: String,
            numStrings: Int,
            temperament: Temperament,
            octaveOffset: Int
        ): ScaleData {
            val baseNotes = when (scaleType) {
                ScaleType.MODES -> getModeScale(mode ?: Mode.DORIOS, firstNote)
                ScaleType.GENRES -> getGenusScale(genus ?: Genus.DIATONIC, firstNote)
                ScaleType.PENTATONIC -> getPentatonicScale(firstNote)
                ScaleType.DOUBLE_HARMONIC -> getDoubleHarmonicScale(firstNote)
                ScaleType.PHORMINX -> getPhorminxScale(firstNote)
            }
            
            return calculateFrequenciesWithOctaves(
                baseNotes, temperament, octaveOffset, numStrings
            )
        }
        
        private fun getModeScale(mode: Mode, firstNote: String): List<String> {
            // Ancient Greek modes (7-note patterns)
            val basePatterns = mapOf(
                // Ancient Mixolydios = Modern Locrian (B C D E F G A)
                Mode.MIXOLYDIOS to listOf("B", "C", "D", "E", "F", "G", "A"),
                // Ancient Hypodorios = Modern Aeolian (A B C D E F G) 
                Mode.HYPODORIOS to listOf("A", "B", "C", "D", "E", "F", "G"),
                // Ancient Lydios = Modern Ionian (C D E F G A B)
                Mode.LYDIOS to listOf("C", "D", "E", "F", "G", "A", "B"),
                // Ancient Phrygios = Modern Dorian (D E F G A B C)
                Mode.PHRYGIOS to listOf("D", "E", "F", "G", "A", "B", "C"),
                // Ancient Dorios = Modern Phrygian (E F G A B C D)
                Mode.DORIOS to listOf("E", "F", "G", "A", "B", "C", "D"),
                // Ancient Hypolydios = Modern Mixolydian (G A B C D E F)
                Mode.HYPOLYDIOS to listOf("G", "A", "B", "C", "D", "E", "F"),
                // Ancient Hypophrygios = Modern Lydian (F G A B C D E)
                Mode.HYPOPHRYGIOS to listOf("F", "G", "A", "B", "C", "D", "E")
            )
            val basePattern = basePatterns[mode]!!
            return transposeScale(basePattern, basePattern[0], firstNote)
        }
        
        private fun getGenusScale(genus: Genus, firstNote: String): List<String> {
            val scales = when (genus) {
                Genus.DIATONIC -> mapOf(
                    "C" to "C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A B C D",
                    "D" to "D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E",
                    "E" to "E F G A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F#",
                    "F" to "F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A B C D E F G",
                    "G" to "G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G# A B C# D E F# G A",
                    "A" to "A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db Eb E F# G A B",
                    "B" to "B C D E F G A Bb C D Eb F G Ab Bb C Db Eb F Gb Ab Bb B Db"
                )
                Genus.CHROMATIC -> mapOf(
                    "C" to "C C# D F F# G Bb B C Eb E F Ab A Bb Db D D# F# G G# B C C#",
                    "D" to "D D# E G G# A C C# D F F# G Bb B C Eb E F Ab A Bb Db D D#",
                    "E" to "E F F# A Bb B D D# E G G# A C C# D F F# G Bb B C Eb E F",
                    "F" to "F F# G Bb B C Eb E F Ab A Bb B D D# E G G# A C C# D F F#",
                    "G" to "G G# A C C# D F F# G Bb B C Eb E F Ab A Bb Db D D# F# G G#",
                    "A" to "A Bb B D D# E G G# A C C# D F F# G Bb B C Eb E F Ab A Bb",
                    "B" to "B C C# E F F# A Bb B D D# E G G# A C C# D F F# G Bb B C"
                )
                Genus.ENHARMONIC -> mapOf(
                    "C" to "C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G B B* C",
                    "D" to "D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D",
                    "E" to "E E* F A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E",
                    "F" to "F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G B B* C E E* F",
                    "G" to "G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A C# C#* D F# F#* G",
                    "A" to "A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B D# D#* E G# G#* A",
                    "B" to "B B* C E E* F A A* A# D D* D#* G G* G#* C C* C# F F* F# A# A#* B"
                )
            }
            
            // Try to find exact match
            scales[firstNote]?.let { scaleString ->
                return scaleString.split(" ")
            }
            
            // If no exact match, transpose from C
            val baseScale = scales["C"]!!.split(" ")
            return transposeScale(baseScale, "C", firstNote)
        }
        
        private fun getPentatonicScale(firstNote: String): List<String> {
            val scales = mapOf(
                "F" to "F G Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C",
                "G" to "G A C D E G A C D E G A C D E G A C D E G A C D",
                "A" to "A C D E G A C D E G A C D E G A C D E G A C D E",
                "Bb" to "Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C D F",
                "C" to "C D E G A C D E G A C D E G A C D E G A C D E G",
                "D" to "D E G A C D E G A C D E G A C D E G A C D E G A",
                "E" to "E G A C D E G A C D E G A C D E G A C D E G A C"
            )
            
            // Handle special case for B note (becomes Bb in original)
            val lookupNote = if (firstNote == "B") "Bb" else firstNote
            
            // Try to find exact match
            scales[lookupNote]?.let { scaleString ->
                return scaleString.split(" ")
            }
            
            // If no exact match, transpose from F
            val baseScale = scales["F"]!!.split(" ")
            return transposeScale(baseScale, "F", lookupNote)
        }
        
        private fun getDoubleHarmonicScale(firstNote: String): List<String> {
            val basePattern = listOf("C", "Db", "E", "F", "G", "Ab", "B")
            return transposeScale(basePattern, "C", firstNote)
        }
        
        private fun getPhorminxScale(firstNote: String): List<String> {
            val basePattern = listOf("A", "B", "C", "E")
            return transposeScale(basePattern, "A", firstNote)
        }
        
        private fun transposeScale(scale: List<String>, fromNote: String, toNote: String): List<String> {
            // For no transposition, return as is
            if (fromNote == toNote) {
                return scale
            }
            
            // Helper function to calculate quarter-tone distance
            fun noteToQuarterTones(note: String): Int {
                val base = when (note.first()) {
                    'C' -> 0
                    'D' -> 4
                    'E' -> 8
                    'F' -> 10
                    'G' -> 14
                    'A' -> 18
                    'B' -> 22
                    else -> 0
                }
                
                var adjustment = 0
                if (note.contains('#')) adjustment += 2
                if (note.contains('b')) adjustment -= 2
                if (note.contains('*')) adjustment += 1
                
                return (base + adjustment + 24) % 24
            }
            
            // Helper function to convert quarter-tones back to note name
            fun quarterTonesToNote(quarterTones: Int): String {
                val notes = listOf(
                    "C", "C*", "C#", "C#*", "D", "D*", "D#", "D#*", 
                    "E", "E*", "F", "F*", "F#", "F#*", "G", "G*", 
                    "G#", "G#*", "A", "A*", "Bb", "Bb*", "B", "B*"
                )
                return notes[quarterTones % 24]
            }
            
            val fromQuarterTones = noteToQuarterTones(fromNote)
            val toQuarterTones = noteToQuarterTones(toNote)
            val interval = (toQuarterTones - fromQuarterTones + 24) % 24
            
            return scale.map { note ->
                val noteQuarterTones = noteToQuarterTones(note)
                val newQuarterTones = (noteQuarterTones + interval) % 24
                quarterTonesToNote(newQuarterTones)
            }
        }
        
        private fun calculateFrequenciesWithOctaves(
            notes: List<String>,
            temperament: Temperament,
            octaveOffset: Int,
            numStrings: Int
        ): ScaleData {
            val notesWithOctaves = mutableListOf<String>()
            val frequencies = mutableListOf<Float>()
            var currentOctave = octaveOffset + 4
            var lastFrequency = 0f
            
            // Handle case where we need more strings than available notes by cycling through the scale
            for (i in 0 until numStrings) {
                val noteIndex = i % notes.size
                val note = notes[noteIndex]
                
                // Calculate base octave from scale cycle position
                val baseCycleOctave = i / notes.size
                var stringOctave = octaveOffset + 4 + baseCycleOctave
                
                // Calculate frequency for this note at the current octave
                var freq = noteToFrequency(note, temperament, stringOctave, A4_FREQ)
                
                // Ensure frequencies are ascending - if current frequency is lower than last, 
                // increase octave until it's higher
                if (i > 0 && freq <= lastFrequency) {
                    while (freq <= lastFrequency && stringOctave < 10) { // Safety limit
                        stringOctave += 1
                        freq = noteToFrequency(note, temperament, stringOctave, A4_FREQ)
                    }
                }
                
                val noteWithOctave = "$note$stringOctave"
                notesWithOctaves.add(noteWithOctave)
                frequencies.add(freq)
                lastFrequency = freq
                currentOctave = stringOctave
            }
            
            return ScaleData(notesWithOctaves, frequencies)
        }
        
        private fun noteToSemitone(noteBase: Char): Int {
            return when (noteBase) {
                'C' -> 0; 'D' -> 2; 'E' -> 4; 'F' -> 5; 'G' -> 7; 'A' -> 9; 'B' -> 11
                else -> 0
            }
        }
        
        private fun noteToFrequency(note: String, temperament: Temperament, octave: Int, a4Freq: Float): Float {
            // Calculate semitones from A4 (including quarter-tones)
            val semitones_from_a = when (note.first()) {
                'C' -> -9
                'D' -> -7
                'E' -> -5
                'F' -> -4
                'G' -> -2
                'A' -> 0
                'B' -> 2
                else -> 0
            }
            
            var adjustment = 0.0f
            if (note.contains('#')) adjustment += 1.0f
            if (note.contains('b')) adjustment -= 1.0f
            if (note.contains('*')) adjustment += 0.5f // Quarter-tone
            
            // Calculate total semitones from A4 (440 Hz reference)
            val totalSemitones = semitones_from_a + adjustment + ((octave - 4) * 12)
            
            return when (temperament) {
                Temperament.EQUAL -> a4Freq * 2.0f.pow(totalSemitones / 12.0f)
                Temperament.JUST -> a4Freq * getJustRatio(totalSemitones)
                Temperament.JUST_ANCIENT -> a4Freq * getJustAncientRatio(totalSemitones)
                Temperament.MEANTONE -> a4Freq * getMeantoneRatio(totalSemitones)
            }
        }
        
        private fun getJustRatio(semitones: Float): Float {
            if (semitones.rem(1.0f) != 0.0f) {
                return 2.0f.pow(semitones / 12.0f)
            }
            
            val ratios = arrayOf(
                1.0f,      // A
                16.0f/15.0f, // A#/Bb
                9.0f/8.0f,   // B
                6.0f/5.0f,   // C
                5.0f/4.0f,   // C#/Db
                4.0f/3.0f,   // D
                45.0f/32.0f, // D#/Eb
                3.0f/2.0f,   // E
                8.0f/5.0f,   // F
                5.0f/3.0f,   // F#/Gb
                9.0f/5.0f,   // G
                15.0f/8.0f   // G#/Ab
            )
            
            val octaves = floor(semitones / 12.0f).toInt()
            val noteIndex = ((semitones % 12.0f + 12.0f) % 12.0f).toInt()
            
            return ratios[noteIndex] * 2.0f.pow(octaves.toFloat())
        }
        
        private fun getJustAncientRatio(semitones: Float): Float {
            val shrutiCents = arrayOf(
                0.0f, 22.0f, 90.0f, 112.0f, 182.0f, 204.0f, 294.0f, 316.0f, 386.0f, 408.0f,
                498.0f, 520.0f, 590.0f, 612.0f, 702.0f, 722.0f, 792.0f, 814.0f, 884.0f, 906.0f,
                996.0f, 1018.0f, 1088.0f, 1110.0f
            )
            
            val ratios = shrutiCents.map { cents -> 2.0f.pow(cents / 1200.0f) }
            
            val octaves = floor(semitones / 12.0f).toInt()
            val semitoneInOctave = (semitones % 12.0f + 12.0f) % 12.0f
            
            val quarterTonesFromA = (semitoneInOctave * 2.0f).roundToInt()
            val quarterToneIndex = (quarterTonesFromA % 24)
            
            return ratios[quarterToneIndex] * 2.0f.pow(octaves.toFloat())
        }
        
        private fun getMeantoneRatio(semitones: Float): Float {
            if (semitones.rem(1.0f) != 0.0f) {
                return 2.0f.pow(semitones / 12.0f)
            }
            
            val ratios = arrayOf(
                1.0f,        // A
                1.0449f,     // A#/Bb
                1.1180f,     // B
                1.1963f,     // C
                1.2500f,     // C#/Db
                1.3375f,     // D
                1.3975f,     // D#/Eb
                1.4953f,     // E
                1.5625f,     // F
                1.6719f,     // F#/Gb
                1.7889f,     // G
                1.8692f      // G#/Ab
            )
            
            val octaves = floor(semitones / 12.0f).toInt()
            val noteIndex = ((semitones % 12.0f + 12.0f) % 12.0f).toInt()
            
            return ratios[noteIndex] * 2.0f.pow(octaves.toFloat())
        }
        
        fun getClosestNoteIndex(frequency: Float, scaleData: ScaleData): Int {
            if (frequency <= 0.0f) return -1
            
            var minDiff = Float.MAX_VALUE
            var closestIndex = -1
            
            for (i in scaleData.frequencies.indices) {
                val diff = abs(frequency - scaleData.frequencies[i])
                if (diff < minDiff) {
                    minDiff = diff
                    closestIndex = i
                }
            }
            
            // Debug logging for problematic cases
            if (frequency > 500 && frequency < 540 && closestIndex == 0) {
                android.util.Log.e("ScaleCalculator", "getClosestNoteIndex returning E (index 0) for ${frequency}Hz!")
                android.util.Log.e("ScaleCalculator", "Scale frequencies: ${scaleData.frequencies.joinToString()}")
                android.util.Log.e("ScaleCalculator", "Scale notes: ${scaleData.notes.joinToString()}")
                android.util.Log.e("ScaleCalculator", "Distance to each: ${scaleData.frequencies.map { abs(frequency - it) }.joinToString()}")
            }
            
            return closestIndex
        }
        
        fun getCentsDifference(frequency: Float, targetFrequency: Float): Float {
            if (frequency <= 0.0f || targetFrequency <= 0.0f) return 0.0f
            return 1200.0f * log2(frequency / targetFrequency)
        }
    }
}