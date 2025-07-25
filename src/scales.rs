
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ScaleType {
    Modes,
    Genres,
    Pentatonic,
    DoubleHarmonic,
    Phorminx,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Mode {
    Mixolydios,
    Hypodorios,
    Lydios,
    Phrygios,
    Dorios,
    Hypolydios,
    Hypophrygios,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Genus {
    Diatonic,
    Chromatic,
    Enharmonic,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Temperament {
    Equal,
    Just,
    JustAncient,
    Meantone,
}

pub struct ScaleData {
    pub notes: Vec<String>,
    pub frequencies: Vec<f32>,
}

impl ScaleData {
    pub fn new(
        scale_type: ScaleType,
        mode: Option<Mode>,
        genus: Option<Genus>,
        first_note: &str,
        num_strings: usize,
        temperament: Temperament,
        octave_offset: i32,
    ) -> Self {
        let scale_notes = get_scale_notes(scale_type, mode, genus, first_note);
        let (notes_with_octaves, frequencies) = calculate_frequencies_with_octaves(&scale_notes, temperament, octave_offset, num_strings, Some(scale_type));
        
        Self {
            notes: notes_with_octaves,
            frequencies,
        }
    }
}

fn get_scale_notes(
    scale_type: ScaleType,
    mode: Option<Mode>,
    genus: Option<Genus>,
    first_note: &str,
) -> Vec<String> {
    match scale_type {
        ScaleType::Modes => {
            let mode = mode.unwrap_or(Mode::Hypophrygios);
            get_mode_scale(mode, first_note)
        }
        ScaleType::Genres => {
            let genus = genus.unwrap_or(Genus::Diatonic);
            get_genus_scale(genus, first_note)
        }
        ScaleType::Pentatonic => get_pentatonic_scale(first_note),
        ScaleType::DoubleHarmonic => get_double_harmonic_scale(first_note),
        ScaleType::Phorminx => get_phorminx_scale(first_note),
    }
}

fn get_mode_scale(mode: Mode, first_note: &str) -> Vec<String> {
    let scales = match mode {
        Mode::Hypophrygios => vec![
            "G A B C D E F G A B C D E F G A B C D E F G A B",
            "A B C# D E F# G A B C# D E F# G A B C# D E F# G A B C#",
            "B C# D# E F# G# A B C# D# E F# G# A B C# D# E F# G# A B C# D#",
            "C D E F G A Bb C D E F G A Bb C D E F G A Bb C D E",
            "D E F# G A B C D E F# G A B C D E F# G A B C D E F#",
            "E F# G# A B C# D E F# G# A B C# D E F# G# A B C# D E F# G#",
            "F G A Bb C D Eb F G A Bb C D Eb F G A Bb C D Eb F G A"
        ],
        Mode::Hypolydios => vec![
            "F G A B C D E F G A B C D E F G A B C D E F G A",
            "G A B C# D E F# G A B C# D E F# G A B C# D E F# G A B",
            "A B C# D# E F# G# A B C# D# E F# G# A B C# D# E F# G# A B C#",
            "B C# D# E# F# G# A# B C# D# E# F# G# A# B C# D# E# F# G# A# B C# D#",
            "C D E F# G A B C D E F# G A B C D E F# G A B C D E",
            "D E F# G# A B C# D E F# G# A B C# D E F# G# A B C# D E F#",
            "E F# G# A# B C# D# E F# G# A# B C# D# E F# G# A# B C# D# E F# G#"
        ],
        Mode::Dorios => vec![
            "E F G A B C D E F G A B C D E F G A B C D E F G",
            "F Gb Ab Bb C Db Eb F Gb Ab Bb C Db Eb F Gb Ab Bb C Db Eb F Gb Ab",
            "G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab Bb",
            "A Bb C D E F G A Bb C D E F G A Bb C D E F G A Bb C",
            "B C D E F# G A B C D E F# G A B C D E F# G A B C D",
            "C Db Eb F G Ab Bb C Db Eb F G Ab Bb C Db Eb F G Ab Bb C Db Eb",
            "D Eb F G A Bb C D Eb F G A Bb C D Eb F G A Bb C D Eb F"
        ],
        Mode::Phrygios => vec![
            "D E F G A B C D E F G A B C D E F G A B C D E F",
            "E F# G A B C# D E F# G A B C# D E F# G A B C# D E F# G",
            "F G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab",
            "G A Bb C D E F G A Bb C D E F G A Bb C D E F G A Bb",
            "A B C D E F# G A B C D E F# G A B C D E F# G A B C",
            "B C# D E F# G# A B C# D E F# G# A B C# D E F# G# A B C# D",
            "C D Eb F G A Bb C D Eb F G A Bb C D Eb F G A Bb C D Eb"
        ],
        Mode::Lydios => vec![
            "C D E F G A B C D E F G A B C D E F G A B C D E",
            "D E F# G A B C# D E F# G A B C# D E F# G A B C D E F#",
            "E F# G# A B C# D# E F# G# A B C# D# E F# G# A B C# D# E F# G#",
            "F G A Bb C D E F G A Bb C D E F G A Bb C D E F G A",
            "G A B C D E F# G A B C D E F# G A B C D E F# G A B",
            "A B C# D E F# G# A B C# D E F# G# A B C# D E F# G# A B C#",
            "B C# D# E F# G# A# B C# D# E F# G# A# B C# D# E F# G# A# B C# D#"
        ],
        Mode::Hypodorios => vec![
            "A B C D E F G A B C D E F G A B C D E F G A B C",
            "B C# D E F# G A B C# D E F# G A B C# D E F# B C# D",
            "C D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb",
            "D E F G A Bb C D E F G A Bb C D E F G A Bb C D E F",
            "E F# G A B C D E F# G A B C D E F# G A B C D E F# G",
            "F G Ab Bb C Db Eb F G Ab Bb C Db Eb F G Ab Bb C Db Eb F G Ab",
            "G A Bb C D Eb F G A Bb C D Eb F G A Bb C D Eb F G A Bb"
        ],
        Mode::Mixolydios => vec![
            "B C D E F G A B C D E F G A B C D E F G A B C D",
            "C Db Eb F Gb Ab Bb C Db Eb F Gb Ab Bb C Db Eb F Gb Ab Bb C Db Eb",
            "D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb F G Ab Bb C D Eb F",
            "E F G A Bb C D E F G A Bb C D E F G A Bb C D E F G",
            "F Gb Ab Bb Cb Db Eb F Gb Ab Bb Cb Db Eb F Gb Ab Bb Cb Db Eb F Gb Ab",
            "G Ab Bb C Db Eb F G Ab Bb C Db Eb F G Ab Bb C D Eb F G Ab Bb",
            "A Bb C D Eb F G A Bb C D Eb F G A Bb C D Eb F G A Bb C"
        ],
    };
    
    // Try to find a scale that starts with the requested first note
    let matching_scale = scales.iter().find(|scale| {
        scale.split_whitespace().next().unwrap_or("") == first_note
    });
    
    if let Some(scale) = matching_scale {
        // Found a scale that starts with the requested note
        scale.split_whitespace().map(|s| s.to_string()).collect()
    } else {
        // No scale found, transpose the first scale to the requested note
        let base_scale: Vec<&str> = scales[0].split_whitespace().collect();
        let base_first_note = base_scale[0];
        transpose_scale(&base_scale, base_first_note, first_note)
    }
}

fn get_genus_scale(genus: Genus, first_note: &str) -> Vec<String> {
    let base_scale = match genus {
        Genus::Diatonic => {
            vec!["C", "Db", "Eb", "F", "Gb", "Ab", "Bb", "B", "Db", "Eb", "E", "F#", "G#", "A", "B", "C#", "D", "E", "F#", "G", "A", "B", "C", "D"]
        }
        Genus::Chromatic => {
            vec!["C", "C#", "D", "F", "F#", "G", "Bb", "B", "C", "Eb", "E", "F", "Ab", "A", "Bb", "Db", "D", "D#", "F#", "G", "G#", "B", "C", "C#"]
        }
        Genus::Enharmonic => {
            vec!["C", "C*", "C#", "F", "F*", "F#", "A#", "A#*", "B", "D#", "D#*", "E", "G#", "G#*", "A", "C#", "C#*", "D", "F#", "F#*", "G", "B", "B*"]
        }
    };
    
    transpose_scale(&base_scale, "C", first_note)
}

fn get_pentatonic_scale(first_note: &str) -> Vec<String> {
    // Pentatonic scale patterns from the HTML implementation
    let pentatonic_scales = vec![
        ("F", "F G Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C"),
        ("G", "G A C D E G A C D E G A C D E G A C D E G A C D"),
        ("A", "A C D E G A C D E G A C D E G A C D E G A C D E"),
        ("Bb", "Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C D F"),
        ("C", "C D E G A C D E G A C D E G A C D E G A C D E G"),
        ("D", "D E G A C D E G A C D E G A C D E G A C D E G A"),
        ("E", "E G A C D E G A C D E G A C D E G A C D E G A C"),
    ];
    
    // Handle special case for B note (becomes Bb)
    let lookup_note = if first_note == "B" { "Bb" } else { first_note };
    
    // Find the scale that matches the first note
    for (scale_first, scale_notes) in pentatonic_scales {
        if scale_first == lookup_note {
            return scale_notes.split_whitespace().map(|s| s.to_string()).collect();
        }
    }
    
    // If no direct match, transpose from the first scale (F)
    let base_scale: Vec<&str> = "F G Bb C D F G Bb C D F G Bb C D F G Bb C D F G Bb C".split_whitespace().collect();
    transpose_scale(&base_scale, "F", lookup_note)
}

fn get_double_harmonic_scale(first_note: &str) -> Vec<String> {
    let base_scale = vec!["C", "Db", "E", "F", "G", "Ab", "B", "C", "Db", "E", "F", "G", "Ab", "B", "C", "Db", "E", "F", "G", "Ab", "B", "C", "Db", "E"];
    transpose_scale(&base_scale, "C", first_note)
}

fn get_phorminx_scale(first_note: &str) -> Vec<String> {
    // Phorminx tuning: A, B, C, E (4 strings)
    // The pattern is: root, major 2nd, minor 3rd, perfect 5th
    let base_scale = vec!["A", "B", "C", "E"];
    transpose_scale(&base_scale, "A", first_note)
}

fn calculate_frequencies_with_octaves(
    notes: &[String],
    temperament: Temperament,
    octave_offset: i32,
    num_strings: usize,
    _scale_type_hint: Option<ScaleType>,
) -> (Vec<String>, Vec<f32>) {
    let a4_freq = 440.0;
    let mut notes_with_octaves = Vec::new();
    let mut frequencies = Vec::new();
    let mut current_octave = octave_offset + 4;  // Base octave for reasonable frequency range
    let mut last_note_base = None;
    
    for (i, note) in notes.iter().enumerate() {
        if i >= num_strings {
            break;
        }
        
        let note_base = note.chars().next().unwrap_or('C');
        
        // Calculate octave for this note
        if i > 0 {
            if let Some(last_base) = last_note_base {
                // Increment octave when going from B to C (natural octave boundary)
                if last_base == 'B' && note_base == 'C' {
                    current_octave += 1;
                }
                // Also increment octave when going from a high note to a low note
                // This handles cases like G# -> C where C should be in the next octave
                else {
                    let last_semitone = match last_base {
                        'C' => 0, 'D' => 2, 'E' => 4, 'F' => 5, 'G' => 7, 'A' => 9, 'B' => 11, _ => 0,
                    };
                    let current_semitone = match note_base {
                        'C' => 0, 'D' => 2, 'E' => 4, 'F' => 5, 'G' => 7, 'A' => 9, 'B' => 11, _ => 0,
                    };
                    
                    // If we're going from a high semitone to a low semitone, increment octave
                    if current_semitone < last_semitone && (last_semitone - current_semitone) > 6 {
                        current_octave += 1;
                    }
                }
            }
        }
        
        last_note_base = Some(note_base);
        let octave_for_freq = current_octave;
        
        
        let freq = note_to_frequency(note, temperament, octave_for_freq, a4_freq);
        
        // For display, use the same octave as frequency calculation
        let octave_for_display = octave_for_freq;
        
        // Calculate display octave based on C-based octave numbering
        // where C4 is middle C and A4 = 440 Hz
        let display_octave = if note_base >= 'C' {
            octave_for_display
        } else {
            octave_for_display
        };
        
        let note_with_octave = format!("{}{}", note, display_octave);
        
        notes_with_octaves.push(note_with_octave);
        frequencies.push(freq);
    }
    
    // Check if we need to sort for proper frequency order
    // This is needed for genus scales where transposition can cause ordering issues
    // Don't sort genus scales to preserve first note requirement
    // The user specifically wants the first note to match what they selected
    let needs_sorting = false;
    
    if needs_sorting {
        // Sort all notes by frequency but try to preserve the first note if possible
        let mut combined: Vec<(String, f32)> = notes_with_octaves.into_iter()
            .zip(frequencies.into_iter())
            .collect();
        combined.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        
        let (sorted_notes, sorted_freqs): (Vec<String>, Vec<f32>) = combined.into_iter().unzip();
        (sorted_notes, sorted_freqs)
    } else {
        // Keep original order
        (notes_with_octaves, frequencies)
    }
}


fn note_to_frequency(note: &str, temperament: Temperament, octave: i32, a4_freq: f32) -> f32 {
    let semitones_from_a = match note.chars().next().unwrap_or('A') {
        'C' => -9,
        'D' => -7,
        'E' => -5,
        'F' => -4,
        'G' => -2,
        'A' => 0,
        'B' => 2,
        _ => 0,
    };
    
    let mut adjustment = 0.0;
    if note.contains('#') {
        adjustment += 1.0;
    }
    if note.contains('b') {
        adjustment -= 1.0;
    }
    if note.contains('*') {
        adjustment += 0.5; // Quarter tone (half semitone)
    }
    
    // Calculate total semitones from A4 (440 Hz reference)
    let total_semitones = semitones_from_a as f32 + adjustment + ((octave - 4) * 12) as f32;
    
    // Debug all note calculations
    // println!("DEBUG: {} note calculation - semitones_from_a={}, octave={}, total_semitones={}", 
    //          note, semitones_from_a, octave, total_semitones);
    
    match temperament {
        Temperament::Equal => a4_freq * 2.0_f32.powf(total_semitones as f32 / 12.0),
        Temperament::Just => a4_freq * get_just_ratio(total_semitones),
        Temperament::JustAncient => a4_freq * get_just_ancient_ratio(total_semitones),
        Temperament::Meantone => a4_freq * get_meantone_ratio(total_semitones),
    }
}

fn get_just_ratio(semitones: f32) -> f32 {
    // For fractional semitones, use equal temperament approximation
    // This is a simplified approach for quarter tones
    if semitones.fract() != 0.0 {
        return 2.0_f32.powf(semitones / 12.0);
    }
    
    let ratios = [
        1.0,      // A
        16.0/15.0, // A#/Bb
        9.0/8.0,   // B
        6.0/5.0,   // C
        5.0/4.0,   // C#/Db
        4.0/3.0,   // D
        45.0/32.0, // D#/Eb
        3.0/2.0,   // E
        8.0/5.0,   // F
        5.0/3.0,   // F#/Gb
        9.0/5.0,   // G
        15.0/8.0,  // G#/Ab
    ];
    
    let octaves = (semitones / 12.0).floor() as i32;
    let note_index = ((semitones % 12.0 + 12.0) % 12.0) as usize;
    
    
    ratios[note_index] * 2.0_f32.powi(octaves)
}

fn get_just_ancient_ratio(semitones: f32) -> f32 {
    // 22-Shruti system based on ancient Greek/Indian musical theory
    // These are the cent values from the HTML implementation
    let shruti_cents = [
        0.0, 22.0, 90.0, 112.0, 182.0, 204.0, 294.0, 316.0, 386.0, 408.0, 
        498.0, 520.0, 590.0, 612.0, 702.0, 722.0, 792.0, 814.0, 884.0, 906.0, 
        996.0, 1018.0, 1088.0, 1110.0
    ];
    
    // Convert cents to frequency ratios
    let mut ratios = Vec::new();
    for cents in shruti_cents.iter() {
        ratios.push(2.0_f32.powf(cents / 1200.0));
    }
    
    // In the HTML, the array is indexed by quarter-tones from A
    // A=0, A*=1, A#=2, A#*=3, B=4, B*=5, C=6, C*=7, C#=8, C#*=9, D=10, D*=11, D#=12, D#*=13, E=14, E*=15, F=16, F*=17, F#=18, F#*=19, G=20, G*=21, G#=22, G#*=23
    // For non-quarter-tone notes, we use the base note index (multiply semitones by 2)
    
    let octaves = (semitones / 12.0).floor() as i32;
    let semitone_in_octave = (semitones % 12.0 + 12.0) % 12.0;
    
    // Convert semitones to quarter-tones from A
    // Each semitone = 2 quarter-tones, so multiply by 2
    let quarter_tones_from_a = (semitone_in_octave * 2.0).round() as i32;
    let quarter_tone_index = (quarter_tones_from_a % 24) as usize;
    
    ratios[quarter_tone_index] * 2.0_f32.powi(octaves)
}

fn get_meantone_ratio(semitones: f32) -> f32 {
    // For fractional semitones, use equal temperament approximation
    if semitones.fract() != 0.0 {
        return 2.0_f32.powf(semitones / 12.0);
    }
    
    let ratios = [
        1.0,        // A
        1.0449,     // A#/Bb
        1.1180,     // B
        1.1963,     // C
        1.2500,     // C#/Db
        1.3375,     // D
        1.3975,     // D#/Eb
        1.4953,     // E
        1.5625,     // F
        1.6719,     // F#/Gb
        1.7889,     // G
        1.8692,     // G#/Ab
    ];
    
    let octaves = (semitones / 12.0).floor() as i32;
    let note_index = ((semitones % 12.0 + 12.0) % 12.0) as usize;
    
    ratios[note_index] * 2.0_f32.powi(octaves)
}


pub fn get_string_count_defaults(strings: usize) -> (Mode, f32) {
    match strings {
        4 => (Mode::Dorios, 1.0),
        7 => (Mode::Dorios, 1.0),
        8 => (Mode::Hypolydios, 2.0),
        9 => (Mode::Dorios, 1.5),
        10 => (Mode::Phrygios, 1.5),
        11 => (Mode::Lydios, 1.5),
        12 => (Mode::Mixolydios, 1.0),
        13 => (Mode::Hypodorios, 1.0),
        24 => (Mode::Hypodorios, 1.0),
        _ => (Mode::Hypophrygios, 1.0),
    }
}

fn transpose_scale(scale: &[&str], from_note: &str, to_note: &str) -> Vec<String> {
    // For no transposition, return as is
    if from_note == to_note {
        return scale.iter().map(|s| s.to_string()).collect();
    }
    
    // Helper function to calculate semitone distance including quartertones
    fn note_to_semitones(note: &str) -> f32 {
        let base = match note.chars().next().unwrap_or('C') {
            'C' => 0.0,
            'D' => 2.0,
            'E' => 4.0,
            'F' => 5.0,
            'G' => 7.0,
            'A' => 9.0,
            'B' => 11.0,
            _ => 0.0,
        };
        
        let mut adjustment = 0.0;
        if note.contains('#') {
            adjustment += 1.0;
        }
        if note.contains('b') {
            adjustment -= 1.0;
        }
        if note.contains('*') {
            adjustment += 0.5;
        }
        
        base + adjustment
    }
    
    // Helper function to convert semitones back to note name
    fn semitones_to_note(semitones: f32) -> String {
        let whole_semitones = semitones.floor() as i32;
        let is_quartertone = (semitones - semitones.floor()).abs() > 0.25;
        
        let base_notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        let base_note = base_notes[(whole_semitones % 12) as usize];
        
        if is_quartertone {
            format!("{}*", base_note)
        } else {
            base_note.to_string()
        }
    }
    
    
    let from_semitones = note_to_semitones(from_note);
    let to_semitones = note_to_semitones(to_note);
    let interval = to_semitones - from_semitones;
    
    scale.iter().map(|note| {
        let note_semitones = note_to_semitones(note);
        let new_semitones = (note_semitones + interval + 12.0) % 12.0;
        semitones_to_note(new_semitones)
    }).collect()
}

// Remove unused transpose_note function - now handled by the new transpose_scale logic

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_debug_scale_sequence() {
        // Test the actual scale sequence for A first note
        let scale_notes = get_scale_notes(ScaleType::Modes, Some(Mode::Dorios), None, "A");
        println!("Scale sequence for A: {:?}", scale_notes.iter().take(7).collect::<Vec<_>>());
        
        // The scale should be: A, Bb, C, D, E, F, G
        // But let's see what we actually get
        let expected = vec!["A", "Bb", "C", "D", "E", "F", "G"];
        for (i, note) in scale_notes.iter().take(7).enumerate() {
            println!("  Position {}: {} (expected {})", i, note, expected[i]);
        }
    }

    #[test]
    fn test_all_first_note_dropdown_values() {
        // Test ALL dropdown values to ensure first note matches selection
        let all_notes = [
            "C", "C*", "C#", "C#*", 
            "D", "D*", "D#", "D#*",
            "E", "E*", 
            "F", "F*", "F#", "F#*",
            "G", "G*", "G#", "G#*",
            "A", "A*", "A#", "A#*",
            "B", "B*"
        ];
        
        println!("=== Testing ALL first note dropdown values ===");
        
        for &first_note in &all_notes {
            // Test with Modes (Dorios)
            let scale_data = ScaleData::new(
                ScaleType::Modes,
                Some(Mode::Dorios),
                None,
                first_note,
                7,
                Temperament::Just,
                0,
            );
            
            let actual_first_note = &scale_data.notes[0];
            let expected_note_base = first_note.chars().next().unwrap();
            let actual_note_base = actual_first_note.chars().next().unwrap();
            
            // Check if the base note matches
            if actual_note_base != expected_note_base {
                println!("❌ MODES {} - Expected {}, got {} ({})", 
                         first_note, first_note, actual_first_note, scale_data.frequencies[0]);
            } else {
                // Check if modifiers match (* and #)
                let expected_has_star = first_note.contains('*');
                let expected_has_sharp = first_note.contains('#');
                let actual_has_star = actual_first_note.contains('*');
                let actual_has_sharp = actual_first_note.contains('#');
                
                if expected_has_star != actual_has_star || expected_has_sharp != actual_has_sharp {
                    println!("❌ MODES {} - Expected {}, got {} (modifiers don't match)", 
                             first_note, first_note, actual_first_note);
                } else {
                    println!("✅ MODES {} - Correctly shows {} ({:.1} Hz)", 
                             first_note, actual_first_note, scale_data.frequencies[0]);
                }
            }
        }
        
        // Test with other scale types
        println!("\n=== Testing Pentatonic Scale ===");
        for &first_note in &["C", "C#", "D", "E", "F", "G", "A", "B"] {  // Test basic notes for pentatonic
            let scale_data = ScaleData::new(
                ScaleType::Pentatonic,
                None,
                None,
                first_note,
                7,
                Temperament::Just,
                0,
            );
            
            let actual_first_note = &scale_data.notes[0];
            let expected_note_base = first_note.chars().next().unwrap();
            let actual_note_base = actual_first_note.chars().next().unwrap();
            
            if actual_note_base != expected_note_base {
                println!("❌ PENTATONIC {} - Expected {}, got {}", first_note, first_note, actual_first_note);
            } else {
                println!("✅ PENTATONIC {} - Correctly shows {}", first_note, actual_first_note);
            }
        }
        
        // Test with Genres (Enharmonic) - the most complex case
        println!("\n=== Testing Enharmonic Genus ===");
        for &first_note in &all_notes {
            let scale_data = ScaleData::new(
                ScaleType::Genres,
                None,
                Some(Genus::Enharmonic),
                first_note,
                7,
                Temperament::Just,
                0,
            );
            
            let actual_first_note = &scale_data.notes[0];
            let expected_note_base = first_note.chars().next().unwrap();
            let actual_note_base = actual_first_note.chars().next().unwrap();
            
            if actual_note_base != expected_note_base {
                println!("❌ ENHARMONIC {} - Expected {}, got {} ({})", 
                         first_note, first_note, actual_first_note, scale_data.frequencies[0]);
            } else {
                let expected_has_star = first_note.contains('*');
                let expected_has_sharp = first_note.contains('#');
                let actual_has_star = actual_first_note.contains('*');
                let actual_has_sharp = actual_first_note.contains('#');
                
                if expected_has_star != actual_has_star || expected_has_sharp != actual_has_sharp {
                    println!("❌ ENHARMONIC {} - Expected {}, got {} (modifiers don't match)", 
                             first_note, first_note, actual_first_note);
                } else {
                    println!("✅ ENHARMONIC {} - Correctly shows {} ({:.1} Hz)", 
                             first_note, actual_first_note, scale_data.frequencies[0]);
                }
            }
        }
    }


    #[test]
    fn test_enharmonic_d_first_note_ordering() {
        // Test D with enharmonic genus - check ordering issue
        let scale_data = ScaleData::new(
            ScaleType::Genres,
            None,
            Some(Genus::Enharmonic),
            "D",
            7,
            Temperament::Just,
            0,
        );
        
        println!("Enharmonic genus with D first note:");
        for (i, (note, freq)) in scale_data.notes.iter().zip(scale_data.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Check frequency ordering
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data.frequencies.iter().enumerate() {
            if i > 0 && freq < last_freq {
                println!("  ❌ Frequency ordering issue: {} ({:.1} Hz) should be higher than previous ({:.1} Hz)", 
                         scale_data.notes[i], freq, last_freq);
            }
            last_freq = freq;
        }
        
        // Debug the raw scale before frequency calculation
        let d_scale = get_genus_scale(Genus::Enharmonic, "D");
        println!("\nD enharmonic scale (first 10): {:?}", &d_scale[..10.min(d_scale.len())]);
    }

    #[test]
    fn test_enharmonic_genus_issues() {
        // Test C* with enharmonic genus - should not have duplicates
        let scale_data_cstar = ScaleData::new(
            ScaleType::Genres,
            None,
            Some(Genus::Enharmonic),
            "C*",
            7,
            Temperament::Just,
            0,
        );
        
        // Debug the base scale first
        let base_scale = vec!["C", "C*", "C#", "F", "F*", "F#", "A#", "A#*", "B", "D#", "D#*", "E", "G#", "G#*", "A", "C#", "C#*", "D", "F#", "F#*", "G", "B", "B*"];
        println!("Base enharmonic scale (first 7): {:?}", &base_scale[..7]);
        
        let transposed = get_genus_scale(Genus::Enharmonic, "C*");
        println!("Transposed to C* (first 7): {:?}", &transposed[..7]);
        
        println!("\nEnharmonic genus with C* first note:");
        for (i, (note, freq)) in scale_data_cstar.notes.iter().zip(scale_data_cstar.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Check for duplicates
        let mut seen_notes = std::collections::HashSet::new();
        for note in &scale_data_cstar.notes {
            if seen_notes.contains(note) {
                println!("  ❌ Duplicate note found: {}", note);
            }
            seen_notes.insert(note);
        }
        
        // Test E with enharmonic genus - should be in order
        let scale_data_e = ScaleData::new(
            ScaleType::Genres,
            None,
            Some(Genus::Enharmonic),
            "E",
            7,
            Temperament::Just,
            0,
        );
        
        // Debug what notes we get from the scale
        let e_scale = get_genus_scale(Genus::Enharmonic, "E");
        println!("\nE enharmonic scale (first 10): {:?}", &e_scale[..10.min(e_scale.len())]);
        
        println!("\nEnharmonic genus with E first note:");
        for (i, (note, freq)) in scale_data_e.notes.iter().zip(scale_data_e.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Check frequency ordering
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data_e.frequencies.iter().enumerate() {
            if i > 0 && freq <= last_freq {
                println!("  ❌ Frequency ordering issue: {} ({:.1} Hz) should be higher than previous ({:.1} Hz)", 
                         scale_data_e.notes[i], freq, last_freq);
            }
            last_freq = freq;
        }
    }

    #[test]
    fn test_first_note_sharps_and_quartertones() {
        // Test with sharp notes
        let scale_data_asharp = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "A#",
            7,
            Temperament::Just,
            0,
        );
        
        println!("First note A# test:");
        for (i, (note, freq)) in scale_data_asharp.notes.iter().zip(scale_data_asharp.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Test with quartertone notes
        let scale_data_astar = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "A*",
            7,
            Temperament::Just,
            0,
        );
        
        println!("\nFirst note A* test:");
        for (i, (note, freq)) in scale_data_astar.notes.iter().zip(scale_data_astar.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Verify first note matches
        assert_eq!(scale_data_asharp.notes[0].chars().next().unwrap(), 'A');
        assert!(scale_data_asharp.notes[0].contains('#'));
        
        assert_eq!(scale_data_astar.notes[0].chars().next().unwrap(), 'A');
        assert!(scale_data_astar.notes[0].contains('*'));
    }

    #[test]
    fn test_first_note_issues() {
        // Test with "A" as first note to reproduce the ordering issue
        let scale_data_a = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "A",
            7,
            Temperament::Just,
            0,
        );
        
        println!("First note A test:");
        for (i, (note, freq)) in scale_data_a.notes.iter().zip(scale_data_a.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Test with different first notes to see the general issue
        for first_note in ["B", "C", "D", "E", "F", "G"] {
            let scale_data = ScaleData::new(
                ScaleType::Modes,
                Some(Mode::Dorios),
                None,
                first_note,
                7,
                Temperament::Just,
                0,
            );
            
            println!("\nFirst note {} test:", first_note);
            for (i, (note, freq)) in scale_data.notes.iter().zip(scale_data.frequencies.iter()).enumerate() {
                println!("  {}: {} = {:.1} Hz", i, note, freq);
                if i == 0 {
                    let actual_first_note = note.chars().next().unwrap().to_string();
                    if actual_first_note != first_note {
                        println!("    ❌ First note mismatch: expected {}, got {}", first_note, actual_first_note);
                    }
                }
            }
        }
        
        
        // Check that all frequencies are in ascending order for the A test
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data_a.frequencies.iter().enumerate() {
            if i > 0 {
                if freq <= last_freq {
                    println!("❌ Frequency ordering issue: {} ({:.1} Hz) should be higher than {} ({:.1} Hz)", 
                             scale_data_a.notes[i], freq, scale_data_a.notes[i-1], last_freq);
                }
            }
            last_freq = freq;
        }
        
        // Check frequency ratios to detect octave skips
        println!("\nFrequency ratios between adjacent notes:");
        for i in 1..scale_data_a.frequencies.len() {
            let ratio = scale_data_a.frequencies[i] / scale_data_a.frequencies[i-1];
            println!("  {} / {} = {:.3}", 
                     scale_data_a.notes[i], scale_data_a.notes[i-1], ratio);
            if ratio > 1.5 {
                println!("    ❌ Octave skip detected!");
            }
        }
    }

    #[test]
    fn test_default_settings_comprehensive() {
        // Test the exact default settings: 7 strings, E first note, Dorios mode, octave 0
        let scale_data = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "E",
            7,
            Temperament::Just,
            0,
        );
        
        println!("Default settings test:");
        for (i, (note, freq)) in scale_data.notes.iter().zip(scale_data.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Test 1: Check that all frequencies are in ascending order
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data.frequencies.iter().enumerate() {
            if i > 0 {
                assert!(freq > last_freq, 
                    "Frequency ordering issue: {} ({:.1} Hz) should be higher than {} ({:.1} Hz)",
                    scale_data.notes[i], freq, scale_data.notes[i-1], last_freq);
            }
            last_freq = freq;
        }
        
        // Test 2: Check that there are no inappropriate octave jumps
        // A reasonable musical progression should not have frequency ratios > 1.5 between adjacent notes
        for i in 1..scale_data.frequencies.len() {
            let ratio = scale_data.frequencies[i] / scale_data.frequencies[i-1];
            assert!(ratio <= 1.5, 
                "Octave skip detected: {} ({:.1} Hz) / {} ({:.1} Hz) = {:.2} ratio is too high",
                scale_data.notes[i], scale_data.frequencies[i],
                scale_data.notes[i-1], scale_data.frequencies[i-1], ratio);
        }
        
        // Test 3: Check expected note sequence for E Dorios mode
        let expected_notes = vec!["E", "F", "G", "A", "B", "C", "D"];
        for (i, note) in scale_data.notes.iter().enumerate() {
            let note_base = note.chars().next().unwrap().to_string();
            assert_eq!(note_base, expected_notes[i], 
                "Note sequence error at position {}: expected {}, got {}",
                i, expected_notes[i], note);
        }
        
        // Test 4: Check that octave numbers are reasonable
        // E4, F4, G4, A4, B4, C5, D5 would be the expected progression with octave offset 0
        for (_i, note) in scale_data.notes.iter().enumerate() {
            let octave_digit = note.chars().nth(1).unwrap().to_digit(10).unwrap();
            assert!(octave_digit >= 2 && octave_digit <= 6, 
                "Unreasonable octave number in {}: octave {} is outside range 2-6",
                note, octave_digit);
        }
        
        // Test 5: Check specific frequency relationships
        // Adjacent notes should have reasonable frequency ratios
        println!("\nFrequency ratios between adjacent notes:");
        for i in 1..scale_data.frequencies.len() {
            let ratio = scale_data.frequencies[i] / scale_data.frequencies[i-1];
            println!("  {} / {} = {:.3}", 
                     scale_data.notes[i], scale_data.notes[i-1], ratio);
        }
    }

    #[test]
    fn test_phorminx_tuning() {
        // Test Phorminx tuning with A first note (should be A, B, C, E)
        let scale_data = ScaleData::new(
            ScaleType::Phorminx,
            None,
            None,
            "A",
            4,
            Temperament::Equal,
            0,
        );
        
        println!("Phorminx tuning with A first note:");
        for (i, (note, freq)) in scale_data.notes.iter().zip(scale_data.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Check that we have the expected notes
        assert_eq!(scale_data.notes.len(), 4);
        assert_eq!(scale_data.notes[0].chars().next().unwrap(), 'A');
        assert_eq!(scale_data.notes[1].chars().next().unwrap(), 'B');
        assert_eq!(scale_data.notes[2].chars().next().unwrap(), 'C');
        assert_eq!(scale_data.notes[3].chars().next().unwrap(), 'E');
        
        // Test with different first note (C should give C, D, Eb, G)
        let scale_data_c = ScaleData::new(
            ScaleType::Phorminx,
            None,
            None,
            "C",
            4,
            Temperament::Equal,
            0,
        );
        
        println!("\nPhorminx tuning with C first note:");
        for (i, (note, freq)) in scale_data_c.notes.iter().zip(scale_data_c.frequencies.iter()).enumerate() {
            println!("  {}: {} = {:.1} Hz", i, note, freq);
        }
        
        // Check that we have the expected notes (transposed)
        assert_eq!(scale_data_c.notes[0].chars().next().unwrap(), 'C');
        assert_eq!(scale_data_c.notes[1].chars().next().unwrap(), 'D');
        assert_eq!(scale_data_c.notes[2].chars().next().unwrap(), 'D'); // D# is equivalent to Eb
        assert_eq!(scale_data_c.notes[3].chars().next().unwrap(), 'G');
    }

    #[test]
    fn test_default_scale_frequencies() {
        // Test with exactly the default settings first
        println!("=== Testing default settings (7 strings, E, Dorios, octave 0) ===");
        // Test default settings: 7 strings, E first note, Dorios mode
        let scale_data = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "E",
            7,
            Temperament::Just,
            0,
        );
        
        // Also test with more strings to see extended range
        let scale_data_extended = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "E",
            12,
            Temperament::Just,
            0,
        );
        
        // Test with lower octave offset to see lower range
        let scale_data_lower = ScaleData::new(
            ScaleType::Modes,
            Some(Mode::Dorios),
            None,
            "E",
            12,
            Temperament::Just,
            -1,  // Lower octave
        );
        
        println!("Notes and frequencies (7 strings):");
        for (note, freq) in scale_data.notes.iter().zip(scale_data.frequencies.iter()) {
            println!("{}: {:.1} Hz", note, freq);
        }
        
        println!("\nExtended notes and frequencies (12 strings):");
        for (note, freq) in scale_data_extended.notes.iter().zip(scale_data_extended.frequencies.iter()) {
            println!("{}: {:.1} Hz", note, freq);
        }
        
        println!("\nLower octave notes and frequencies (12 strings, octave -1):");
        for (note, freq) in scale_data_lower.notes.iter().zip(scale_data_lower.frequencies.iter()) {
            println!("{}: {:.1} Hz", note, freq);
        }
        
        // Show raw scale sequence for debugging
        let scale_notes = get_scale_notes(ScaleType::Modes, Some(Mode::Dorios), None, "E");
        println!("\nRaw scale sequence (first 12): {:?}", scale_notes.iter().take(12).collect::<Vec<_>>());
        
        // Debug the octave calculation for 12 strings
        println!("\nDebug octave calculation for 12 strings:");
        let mut current_octave = -1;
        let mut last_note_base = None;
        
        for (i, note) in scale_notes.iter().enumerate().take(12) {
            let note_base = note.chars().next().unwrap_or('C');
            
            if i > 0 {
                if let Some(last_base) = last_note_base {
                    if note_base < last_base {
                        current_octave += 1;
                        println!("  Octave incremented to {} because {} < {}", current_octave, note_base, last_base);
                    }
                }
            }
            last_note_base = Some(note_base);
            
            let mut c_based_octave = current_octave + 5;
            if note_base < 'C' {
                c_based_octave -= 1;
            }
            
            println!("  {}: pos={}, internal_octave={}, c_based_octave={}", note, i, current_octave, c_based_octave);
        }
        
        // Debug the octave calculation process
        let scale_notes = get_scale_notes(ScaleType::Modes, Some(Mode::Dorios), None, "E");
        println!("\nScale notes: {:?}", scale_notes.iter().take(7).collect::<Vec<_>>());
        
        let mut current_octave = -2;
        let mut last_note_base = None;
        
        println!("\nDebug octave calculation:");
        for (i, note) in scale_notes.iter().enumerate().take(7) {
            let note_base = note.chars().next().unwrap_or('C');
            
            if i > 0 {
                if let Some(last_base) = last_note_base {
                    if note_base < last_base {
                        current_octave += 1;
                        println!("  Octave incremented to {} because {} < {}", current_octave, note_base, last_base);
                    }
                }
            }
            last_note_base = Some(note_base);
            
            let actual_octave_debug = if i == 6 && note_base == 'D' {
                current_octave + 1
            } else {
                current_octave
            };
            
            let mut c_based_octave = actual_octave_debug + 5;
            if note_base < 'C' {
                c_based_octave -= 1;
                println!("  {} < C, so c_based_octave decremented to {}", note_base, c_based_octave);
            }
            
            println!("  {}: internal_octave={}, actual_octave={}, c_based_octave={}", note, current_octave, actual_octave_debug, c_based_octave);
        }
        
        // Check that frequencies are in ascending order for default 7 strings
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data.frequencies.iter().enumerate() {
            if i > 0 {
                assert!(freq > last_freq, 
                    "Frequency {} ({:.1} Hz) should be higher than {} ({:.1} Hz)", 
                    scale_data.notes[i], freq, 
                    scale_data.notes[i-1], last_freq);
            }
            last_freq = freq;
        }
        
        // Check that frequencies are in ascending order for 12 strings
        println!("\n=== Checking frequency ordering for 12 strings ===");
        let mut last_freq = 0.0;
        for (i, &freq) in scale_data_lower.frequencies.iter().enumerate() {
            if i > 0 {
                if freq <= last_freq {
                    println!("❌ Frequency ordering issue: {} ({:.1} Hz) should be higher than {} ({:.1} Hz)", 
                             scale_data_lower.notes[i], freq, 
                             scale_data_lower.notes[i-1], last_freq);
                } else {
                    println!("✓ {} ({:.1} Hz) > {} ({:.1} Hz)", 
                             scale_data_lower.notes[i], freq, 
                             scale_data_lower.notes[i-1], last_freq);
                }
            }
            last_freq = freq;
        }
        
        // Test some specific expected relationships
        // D4 should be higher than B3
        let b3_idx = scale_data.notes.iter().position(|n| n.starts_with("B3"));
        let d4_idx = scale_data.notes.iter().position(|n| n.starts_with("D4"));
        
        if let (Some(b3_idx), Some(d4_idx)) = (b3_idx, d4_idx) {
            assert!(scale_data.frequencies[d4_idx] > scale_data.frequencies[b3_idx],
                "D4 ({:.1} Hz) should be higher than B3 ({:.1} Hz)",
                scale_data.frequencies[d4_idx], scale_data.frequencies[b3_idx]);
            println!("✓ D4 ({:.1} Hz) is correctly higher than B3 ({:.1} Hz)", 
                     scale_data.frequencies[d4_idx], scale_data.frequencies[b3_idx]);
        } else {
            println!("Could not find B3 or D4 in notes: {:?}", scale_data.notes);
        }
    }
}