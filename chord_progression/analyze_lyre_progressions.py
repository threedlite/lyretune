#!/usr/bin/env python3
"""
Analyze all possible chord progressions for each ancient Greek mode on an N-string lyre.
Considers voicing constraints, inversions, and voice leading.

IMPORTANT: This analysis uses JUST INTONATION (pure integer frequency ratios),
not equal temperament. This is critical for accurate consonance calculations
on a lyre, which uses just-tuned strings.

Supports variable string counts (default: 7). Use --num-strings to analyze
different configurations (e.g., 8 strings to complete the octave).
"""

import sys
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set
from dataclasses import dataclass

# Add parent directory to path to import from parent folder
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

import heapq
import io
import numpy as np
from contextlib import redirect_stdout
from itertools import product, combinations
from collections import defaultdict
from analyze_lyre_chords import LyreChordAnalyzer
from run_all_consonance_tests import complexity_with_five_adjustments

# Chord size constants
DYAD_SIZE = 2
TRIAD_SIZE = 3
TETRAD_SIZE = 4

# Use the same parameters as the chord analyzer
DEFAULT_PARAMS = {
    'augmented_penalty': 0.6,
    'sus2inv_penalty': 0.08,
    'major1inv_bonus': 0.057,
    'dominant7_bonus': 0.65,
    'halfdim7_penalty': 0.65,
    'alpha': 1.0,
    'beta': 0.3,
    'kappa': 1.0,
    'delta': 0.15,
    'psi': 1.6,
    'omega': 3.3,
    'nu': 0.0,
    'chi': 0.5,
}

# Voicing quality penalties
INVERSION_PENALTIES = {
    'root': 0.0,
    '1st': 1.5,
    '2nd': 2.0,
    'unk': 3.0
}
CROSSED_VOICES_PENALTY = 1.0

# Voice leading weights
VOICE_LEADING_WEIGHT = 0.5
COMMON_TONE_BONUS = -0.5

# Root movement strength based on traditional harmonic theory
# Lower (more negative) values = stronger/simpler progressions
ROOT_MOVEMENT_STRENGTH = {
    0: 0.0,   # No movement (pedal)
    3: -1.5,  # Includes V→I (authentic cadence) - STRONGEST
    4: -0.3,  # Includes IV→I (plagal) and I→V (half) - mixed
    5: -0.5,  # Ascending 5th
    2: 0.3,   # Stepwise (up by 2nd)
    6: 1.5,   # Tritone (unstable)
    1: 0.8,   # Half step
}

# Minimum and maximum strings supported
# Note: 4 strings is the minimum to attempt triad analysis. With fewer strings,
# you can only form dyads (2-note chords). With 4-5 strings, very few complete
# triads will be available. 6+ strings recommended for chord progressions.
# Maximum is 9 strings (10+ exceeds 15s performance target even without tetrads).
# Tetrads are only enabled for exactly 7 strings due to performance constraints.
MIN_STRINGS_FOR_TRIADS = 4
MAX_STRINGS_SUPPORTED = 9


class Chord:
    """Represents a chord with variable size (2, 3, or 4 notes).

    - Dyad (2 notes): root + one interval
    - Triad (3 notes): root, third, fifth
    - Tetrad (4 notes): root, third, fifth, seventh
    """

    # Dyad qualities (intervals)
    DYAD_QUALITIES = {
        1: 'm2',    # Minor 2nd
        2: 'M2',    # Major 2nd
        3: 'm3',    # Minor 3rd
        4: 'M3',    # Major 3rd
        5: 'P4',    # Perfect 4th
        6: 'TT',    # Tritone
        7: 'P5',    # Perfect 5th
        8: 'm6',    # Minor 6th
        9: 'M6',    # Major 6th
        10: 'm7',   # Minor 7th
        11: 'M7',   # Major 7th
    }

    # Triad qualities
    TRIAD_QUALITIES = {
        (4, 7): 'maj',   # Major: M3 + P5
        (3, 7): 'min',   # Minor: m3 + P5
        (3, 6): 'dim',   # Diminished: m3 + d5
        (4, 8): 'aug',   # Augmented: M3 + A5
    }

    # Tetrad qualities (7th chords)
    TETRAD_QUALITIES = {
        (4, 7, 11): 'maj7',     # Major 7th: M3 + P5 + M7
        (4, 7, 10): 'dom7',     # Dominant 7th: M3 + P5 + m7
        (3, 7, 10): 'min7',     # Minor 7th: m3 + P5 + m7
        (3, 6, 10): 'halfdim7', # Half-diminished: m3 + d5 + m7
        (3, 6, 9): 'dim7',      # Diminished 7th: m3 + d5 + d7
    }

    def __init__(self, root_degree: int, scale_semitones: List[int], root_semitone: int, size: int = 3):
        """
        Args:
            root_degree: Scale degree (0-6)
            scale_semitones: List of semitones for the mode
            root_semitone: Absolute semitone of the root
            size: Number of notes in chord (2, 3, or 4)
        """
        self.root_degree = root_degree
        self.scale_semitones = scale_semitones
        self.root_semitone = root_semitone
        self.size = size

        # Build chord based on size
        # Dyad: root + 3rd (degrees 0, 2)
        # Triad: root + 3rd + 5th (degrees 0, 2, 4)
        # Tetrad: root + 3rd + 5th + 7th (degrees 0, 2, 4, 6)
        degree_offsets = {
            DYAD_SIZE: [0, 2],
            TRIAD_SIZE: [0, 2, 4],
            TETRAD_SIZE: [0, 2, 4, 6]
        }

        degrees = [(root_degree + i) % 7 for i in degree_offsets[size]]
        self.degrees = degrees
        self.semitones = self._get_chord_semitones(degrees, root_degree, scale_semitones)

        # Determine quality based on size
        if size == DYAD_SIZE:
            interval = self.semitones[1] - self.semitones[0]
            self.quality = self.DYAD_QUALITIES.get(interval, f'{interval}st')
        elif size == TRIAD_SIZE:
            third_interval = self.semitones[1] - self.semitones[0]
            fifth_interval = self.semitones[2] - self.semitones[0]
            self.quality = self.TRIAD_QUALITIES.get((third_interval, fifth_interval), 'unk')
        elif size == TETRAD_SIZE:
            third_interval = self.semitones[1] - self.semitones[0]
            fifth_interval = self.semitones[2] - self.semitones[0]
            seventh_interval = self.semitones[3] - self.semitones[0]
            self.quality = self.TETRAD_QUALITIES.get(
                (third_interval, fifth_interval, seventh_interval), 'unk'
            )
        else:
            self.quality = 'unk'

    def __repr__(self) -> str:
        roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][self.root_degree]

        if self.size == DYAD_SIZE:
            # Dyad: show as "I-M3" (root-interval)
            return f"{roman}-{self.quality}"
        elif self.size == TRIAD_SIZE:
            # Triad: traditional notation
            if self.quality == 'min':
                roman = roman.lower()
            elif self.quality == 'dim':
                roman = roman.lower() + '°'
            elif self.quality == 'aug':
                roman = roman + '+'
            return roman
        elif self.size == TETRAD_SIZE:
            # Tetrad: add 7 suffix
            if self.quality == 'maj7':
                return roman + 'maj7'
            elif self.quality == 'dom7':
                return roman + '7'
            elif self.quality == 'min7':
                return roman.lower() + '7'
            elif self.quality == 'halfdim7':
                return roman.lower() + 'ø7'
            elif self.quality == 'dim7':
                return roman.lower() + '°7'
            else:
                return roman + '?' + str(self.size)
        else:
            return f"{roman}({self.size})"

    @staticmethod
    def _get_chord_semitones(degrees: List[int], root_degree: int, scale_semitones: List[int]) -> List[int]:
        """Get semitones for chord degrees, wrapping to next octave as needed.

        Args:
            degrees: Scale degrees for the chord notes
            root_degree: The root scale degree
            scale_semitones: The semitones for the scale

        Returns:
            List of semitones with octave wrapping applied
        """
        semitones = []
        for deg in degrees:
            st = scale_semitones[deg]
            if deg < root_degree:
                st += 12  # Next octave
            semitones.append(st)
        return semitones


class LyreVoicing:
    """Represents how a chord is voiced on the lyre.

    A voicing specifies which strings are played and accounts for
    inversions and voice ordering. Supports dyads (2), triads (3), and tetrads (4).
    """

    def __init__(self, chord: Chord, string_indices: List[int], semitones: List[int]):
        """
        Args:
            chord: Chord object (can be dyad, triad, or tetrad)
            string_indices: List of string numbers (1-indexed) used
            semitones: List of actual semitones played (may span octaves)

        Raises:
            ValueError: If inputs are inconsistent
        """
        # Validate inputs
        if len(string_indices) != chord.size:
            raise ValueError(
                f"String indices length ({len(string_indices)}) must match chord size ({chord.size})"
            )
        if len(semitones) != chord.size:
            raise ValueError(
                f"Semitones length ({len(semitones)}) must match chord size ({chord.size})"
            )
        if len(string_indices) != len(semitones):
            raise ValueError(
                f"String indices length ({len(string_indices)}) must match semitones length ({len(semitones)})"
            )

        self.chord = chord
        self.string_indices = string_indices
        self.semitones = semitones

        # Determine inversion based on chord size
        root_mod = chord.semitones[0] % 12
        bass_mod = semitones[0] % 12

        if chord.size == DYAD_SIZE:
            # Dyads don't have inversions in the traditional sense
            if bass_mod == root_mod:
                self.inversion = 'root'
            else:
                self.inversion = '1st'
        elif chord.size == TRIAD_SIZE:
            # Triads: root, 1st (bass is 3rd), 2nd (bass is 5th)
            if bass_mod == root_mod:
                self.inversion = 'root'
            elif bass_mod == (chord.semitones[1] % 12):
                self.inversion = '1st'
            elif bass_mod == (chord.semitones[2] % 12):
                self.inversion = '2nd'
            else:
                self.inversion = 'unk'
        elif chord.size == TETRAD_SIZE:
            # Tetrads: root, 1st (bass is 3rd), 2nd (bass is 5th), 3rd (bass is 7th)
            if bass_mod == root_mod:
                self.inversion = 'root'
            elif bass_mod == (chord.semitones[1] % 12):
                self.inversion = '1st'
            elif bass_mod == (chord.semitones[2] % 12):
                self.inversion = '2nd'
            elif bass_mod == (chord.semitones[3] % 12):
                self.inversion = '3rd'
            else:
                self.inversion = 'unk'
        else:
            self.inversion = 'unk'

        # Check if ascending
        self.is_ascending = all(semitones[i] < semitones[i+1] for i in range(len(semitones)-1))

    def __repr__(self) -> str:
        # Inversion symbols
        inv_symbols = {
            DYAD_SIZE: {'root': '', '1st': '⁶'},  # Dyads
            TRIAD_SIZE: {'root': '', '1st': '⁶', '2nd': '⁶₄'},  # Triads
            TETRAD_SIZE: {'root': '', '1st': '⁶₅', '2nd': '⁴₃', '3rd': '²'},  # Tetrads (figured bass)
        }

        inv_symbol = inv_symbols.get(self.chord.size, {}).get(self.inversion, '?')
        asc = '↑' if self.is_ascending else '↓'
        strings = ','.join(str(s) for s in self.string_indices)
        return f"{self.chord}{inv_symbol}[{strings}]{asc}"

    def voicing_penalty(self) -> float:
        """Calculate penalty for non-ideal voicing.

        Root position is preferred. Crossed voices (non-ascending order)
        are penalized.

        Returns:
            Penalty value (0.0 = perfect, higher = worse)
        """
        # Adjust penalty for tetrad inversions
        if self.chord.size == TETRAD_SIZE and self.inversion == '3rd':
            penalty = INVERSION_PENALTIES.get('2nd', 2.0)  # 3rd inversion like 2nd
        else:
            penalty = INVERSION_PENALTIES.get(self.inversion, 3.0)

        # Small penalty for non-ascending (crossed voices)
        if not self.is_ascending:
            penalty += CROSSED_VOICES_PENALTY

        return penalty


class LyreProgressionAnalyzer:
    """Analyzes chord progressions for a given mode on an N-string lyre.

    Uses just intonation (pure integer frequency ratios) for accurate
    consonance calculations. The complexity formula evaluates:
    - Individual chord consonance (harmonic complexity)
    - Voicing quality (root position vs inversions)
    - Voice leading smoothness (string distances)
    - Root movement strength (harmonic function)

    Example:
        >>> analyzer = LyreProgressionAnalyzer('DORIOS', num_strings=7)
        >>> progressions = analyzer.generate_progressions(min_length=2, max_length=3)
        >>> analyzer.print_analysis(output_file='dorios_analysis.txt')
    """

    def __init__(self,
                 mode_name: str,
                 num_strings: int = 7,
                 first_note: str = 'E',
                 first_octave: int = 4,
                 complexity_params: Optional[Dict[str, float]] = None):
        """
        Args:
            mode_name: Ancient Greek mode name (e.g., 'DORIOS')
            num_strings: Number of strings on the lyre (default: 7)
            first_note: Root note for the scale (default: 'E')
            first_octave: Starting octave for the root note (default: 4)
            complexity_params: Parameters for complexity formula

        Note:
            For chord progression analysis, individual chord complexity uses the
            middle note of each chord as reference (or lower-middle if even number).
            Multi-chord metrics use the middle string of the lyre as tonic reference.

        Raises:
            ValueError: If mode_name is invalid or num_strings < 3
        """
        # Validate inputs
        if mode_name not in LyreChordAnalyzer.MODES:
            available = ', '.join(LyreChordAnalyzer.MODES.keys())
            raise ValueError(
                f"Unknown mode: {mode_name}. Available modes: {available}"
            )

        if num_strings < MIN_STRINGS_FOR_TRIADS:
            raise ValueError(
                f"Need at least {MIN_STRINGS_FOR_TRIADS} strings for triad analysis, got {num_strings}. "
                f"With fewer strings, only dyads (2-note chords) are possible."
            )

        if num_strings > MAX_STRINGS_SUPPORTED:
            raise ValueError(
                f"Maximum {MAX_STRINGS_SUPPORTED} strings supported, got {num_strings}"
            )

        self.mode_name = mode_name
        self.num_strings = num_strings
        self.params = complexity_params or DEFAULT_PARAMS

        # Calculate middle string index (1-indexed) for tonic reference in multi-chord metrics
        # For odd number: middle = (n+1)/2, for even: lower-middle = n/2
        self.tonic_string_index = (num_strings + 1) // 2

        # Get mode pattern
        self.scale_semitones = LyreChordAnalyzer.MODES[mode_name]

        # Create a LyreChordAnalyzer instance to get just intonation frequencies
        self.chord_analyzer = LyreChordAnalyzer(
            num_strings=num_strings,
            mode=mode_name,
            first_note=first_note,
            temperament='JUST',
            formula='NUMERIC_EMPIRIC_20251018'
        )

        # Store the just intonation frequencies for each string
        self.just_frequencies = self.chord_analyzer.frequencies

        # Validate that we got the expected number of frequencies
        if len(self.just_frequencies) != num_strings:
            raise ValueError(
                f"LyreChordAnalyzer returned {len(self.just_frequencies)} frequencies "
                f"but expected {num_strings}. The analyzer may not support {num_strings} strings."
            )

        # Build interval pattern
        self.interval_pattern = self._build_interval_pattern()

        # Determine which chord sizes to analyze based on num_strings
        self.chord_sizes = self._determine_chord_sizes()

        # Build all chords (dyads, triads, and/or tetrads)
        self.chords = self._build_chords()
        self.triads = [c for c in self.chords if c.size == 3]  # Backward compat

        # Build all voicings for each chord
        self.voicings = self._build_voicings()

        # Store first note info for note name conversion
        self.first_note = first_note
        self.first_octave = first_octave

    @staticmethod
    def _get_middle_index(sequence):
        """
        Get the middle index of a sequence (0-indexed).
        For even-length sequences, returns the lower-middle index.

        Args:
            sequence: Any sequence with length

        Returns:
            Middle index (0-indexed)

        Examples:
            [a, b, c] -> 1 (middle)
            [a, b, c, d] -> 1 (lower-middle)
            [a, b, c, d, e] -> 2 (middle)
        """
        n = len(sequence)
        return (n - 1) // 2

    def _build_interval_pattern(self) -> str:
        """Convert semitone list to H/W pattern.

        Returns:
            String like "W-W-H-W-W-W-H" representing whole/half steps
        """
        pattern = []
        for i in range(len(self.scale_semitones)):
            next_i = (i + 1) % len(self.scale_semitones)

            if next_i == 0:  # Wrap around to next octave
                interval = 12 - self.scale_semitones[i] + self.scale_semitones[0]
            else:
                interval = self.scale_semitones[next_i] - self.scale_semitones[i]

            if interval == 1:
                pattern.append('H')
            elif interval == 2:
                pattern.append('W')
            else:
                pattern.append(f'{interval}')

        return '-'.join(pattern)

    def _semitone_to_note_name(self, semitone: int) -> str:
        """Convert semitone offset to note name with octave.

        Args:
            semitone: Semitone offset from the scale root (0-based)

        Returns:
            Note name with octave (e.g., 'E4', 'G#4', 'C5')
        """
        # Note names in chromatic scale
        note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

        # Find the semitone offset of the first note from C
        try:
            first_note_semitone = note_names.index(self.first_note)
        except ValueError:
            raise ValueError(f"Invalid first_note: {self.first_note}. Must be one of {note_names}")

        # Calculate absolute semitone from C
        absolute_semitone = first_note_semitone + semitone

        # Calculate octave (starting from first_octave)
        octave = self.first_octave + (absolute_semitone // 12)

        # Get note name
        note_index = absolute_semitone % 12
        note_name = note_names[note_index]

        return f"{note_name}{octave}"

    def _voicing_to_note_names(self, voicing: LyreVoicing) -> str:
        """Convert a voicing to note names.

        Args:
            voicing: LyreVoicing object

        Returns:
            String like "E4-G4-B4"
        """
        notes = []
        for semitone in voicing.semitones:
            notes.append(self._semitone_to_note_name(semitone))
        return '-'.join(notes)

    def _determine_chord_sizes(self) -> List[int]:
        """Determine which chord sizes to analyze based on num_strings.

        Always attempts all possible sizes - the voicing builder will naturally
        filter out impossible voicings based on available strings.

        Physical requirements:
        - Dyads (2 notes): Need 2+ strings (span 2 scale degrees)
        - Triads (3 notes): Need 5+ strings (span 4 scale degrees)
        - Tetrads (4 notes): Need 7+ strings (span 6 scale degrees)

        Performance constraints:
        - Tetrads are only enabled for exactly 7 strings (8+ is too slow)

        Returns:
            List of chord sizes to prioritize (e.g., [3, 4, 2])
        """
        if self.num_strings <= 4:
            # Only dyads possible
            return [DYAD_SIZE]
        elif self.num_strings <= 6:
            # Dyads and triads possible
            return [TRIAD_SIZE, DYAD_SIZE]
        elif self.num_strings == 7:
            # All sizes possible (triads, tetrads, dyads)
            # Prioritize triads, then tetrads, then dyads
            return [TRIAD_SIZE, TETRAD_SIZE, DYAD_SIZE]
        else:
            # 8+ strings: triads and dyads only (no tetrads due to performance)
            return [TRIAD_SIZE, DYAD_SIZE]

    def _build_chords(self) -> List[Chord]:
        """Build all diatonic chords in this mode.

        Returns:
            List of chords (dyads, triads, and/or tetrads) for each scale degree
        """
        chords = []
        for size in self.chord_sizes:
            for degree in range(7):
                chord = Chord(degree, self.scale_semitones, self.scale_semitones[degree], size=size)
                chords.append(chord)
        return chords

    @staticmethod
    def _is_valid_voicing(semitones: List[int], chord: Chord) -> bool:
        """Check if semitones form a valid voicing of the chord.

        Args:
            semitones: Actual semitones played (may span octaves)
            chord: Chord to match against

        Returns:
            True if the played notes match the chord notes (modulo octave)
        """
        chord_notes = {(st % 12) for st in chord.semitones}
        played_notes = {(st % 12) for st in semitones}
        return played_notes == chord_notes

    def _build_voicings(self) -> Dict[Tuple[int, int], List[LyreVoicing]]:
        """Find all possible voicings for each chord on N strings.

        For lyres with more than 7 strings, assumes the scale pattern repeats
        across octaves. String i plays scale degree (i % 7) at octave (i // 7).

        Returns:
            Dict mapping (root_degree, chord_size) to list of possible voicings

        Raises:
            ValueError: If num_strings exceeds available frequencies
        """
        voicings_by_chord = {}

        for chord in self.chords:
            voicings = []

            # Try all combinations of chord.size strings
            for strings in combinations(range(self.num_strings), chord.size):
                # Validate string indices are within bounds
                # (should always be true, but defensive check)
                if any(s >= self.num_strings for s in strings):
                    continue

                # Get semitones played (considering octave wrapping)
                # For string i: semitone = scale_semitones[i % scale_length] + (i // scale_length) * 12
                scale_length = len(self.scale_semitones)
                semitones = []
                for s in strings:
                    degree = s % scale_length
                    octave = s // scale_length
                    semitone = self.scale_semitones[degree] + (octave * 12)
                    semitones.append(semitone)

                # Check if this forms the chord
                if self._is_valid_voicing(semitones, chord):
                    # This is a valid voicing!
                    voicing = LyreVoicing(
                        chord,
                        [s+1 for s in strings],  # 1-indexed for display
                        semitones
                    )
                    voicings.append(voicing)

            # Store with key (root_degree, size) for lookup
            key = (chord.root_degree, chord.size)
            voicings_by_chord[key] = voicings

        return voicings_by_chord

    def _voice_leading_distance(self, voicing1: LyreVoicing, voicing2: LyreVoicing) -> float:
        """Calculate voice leading distance between two voicings.

        Measures how many voices move and rewards common tones.
        Also considers the actual pitch distance moved (in semitones).

        Args:
            voicing1: First voicing
            voicing2: Second voicing

        Returns:
            Distance metric (lower is smoother voice leading)
        """
        strings1 = set(voicing1.string_indices)
        strings2 = set(voicing2.string_indices)

        # Find common tones (strings that don't move)
        common = strings1 & strings2

        # Count voices that move
        voices_that_move = len(strings1 - common) + len(strings2 - common)

        # Bonus for common tones (negative = good)
        common_tone_bonus = len(common) * COMMON_TONE_BONUS

        # For more accurate voice leading, we could track pitch distances
        # between corresponding voices, but for simplicity we use string count
        # TODO: Consider implementing pitch-aware voice leading that tracks
        # semitone distances between corresponding voices in both voicings

        return voices_that_move + common_tone_bonus

    def _root_movement_complexity(self, chord1: Chord, chord2: Chord) -> float:
        """Calculate complexity of root movement.

        Lower (more negative) values = stronger/simpler progressions.
        Based on traditional harmonic theory of root movement strength.

        For example:
        - V→I (distance 3 in most modes) is the strongest resolution
        - I→V (distance 4) creates tension (half cadence)
        - Tritone movements (distance 6) are unstable

        Args:
            chord1: Starting chord
            chord2: Ending chord

        Returns:
            Complexity value (negative = strong, positive = weak)
        """
        # Movement in scale degrees
        degree_distance = (chord2.root_degree - chord1.root_degree) % 7

        return ROOT_MOVEMENT_STRENGTH.get(degree_distance, 1.0)

    def _calculate_progression_complexity(self, voicing_sequence: List[LyreVoicing]) -> float:
        """Calculate total complexity of a progression.

        Combines multiple factors:
        1. Individual chord harmonic complexity (using just intonation ratios)
        2. Voicing penalties (inversions, crossed voices)
        3. Voice leading distances (how far voices move)
        4. Root movement strength (harmonic function)

        Args:
            voicing_sequence: List of voicings forming the progression

        Returns:
            Total complexity score (lower is better)
        """
        complexity = 0.0

        # Individual chord complexities
        for voicing in voicing_sequence:
            # Get actual just intonation frequencies for this voicing
            # voicing.string_indices are 1-indexed, so subtract 1 for array access
            # Validate all indices are within bounds
            for idx in voicing.string_indices:
                if idx < 1 or idx > len(self.just_frequencies):
                    raise IndexError(
                        f"Invalid string index {idx} in voicing {voicing}. "
                        f"Valid range is 1-{len(self.just_frequencies)} for {self.num_strings} strings."
                    )

            freqs = [self.just_frequencies[idx - 1] for idx in voicing.string_indices]

            # For chord progression analysis, use the middle note of the chord as reference
            # (or lower-middle if even number of notes)
            middle_idx = self._get_middle_index(freqs)
            reference_freq = freqs[middle_idx]

            # Convert frequencies to integer ratios using the parent class method
            ratios = self.chord_analyzer.frequencies_to_ratios(freqs, reference_frequency=reference_freq)

            chord_complexity = complexity_with_five_adjustments(ratios, **self.params)
            complexity += chord_complexity

            # Voicing penalty
            complexity += voicing.voicing_penalty()

        # Voice leading distances
        for i in range(len(voicing_sequence) - 1):
            vl_distance = self._voice_leading_distance(
                voicing_sequence[i],
                voicing_sequence[i+1]
            )
            complexity += vl_distance * VOICE_LEADING_WEIGHT

        # Root movement
        for i in range(len(voicing_sequence) - 1):
            root_complexity = self._root_movement_complexity(
                voicing_sequence[i].chord,
                voicing_sequence[i+1].chord
            )
            complexity += root_complexity

        return complexity

    def generate_progressions(self,
                            min_length: int = 2,
                            max_length: int = 4,
                            max_results: int = 100) -> Dict[int, List[Dict]]:
        """
        Generate all possible progressions with variable chord sizes.
        Uses heap-based approach to avoid storing millions of progressions.

        Args:
            min_length: Minimum number of chords
            max_length: Maximum number of chords
            max_results: Maximum progressions to return per length

        Returns:
            Dict mapping length to list of progression dicts with keys:
            - complexity: float
            - voicings: tuple of LyreVoicing
            - chords: list of Chord
            - description: str (voicing notation)
            - functional: str (roman numeral notation)
        """
        results_by_length = {}

        for length in range(min_length, max_length + 1):
            # Use max-heap (negate complexity for min-heap behavior)
            # Store tuples of (-complexity, index, voicing_combo, chord_sequence)
            # Index prevents comparison of voicing objects when complexities are equal
            heap = []
            counter = 0  # Unique counter for tiebreaking

            # Generate all possible chord sequences (degree, size) pairs
            # Build list of available (degree, size) combinations
            available_chords = [(c.root_degree, c.size) for c in self.chords]

            for chord_sequence in product(available_chords, repeat=length):
                # Skip sequences with consecutive identical chords
                if any(chord_sequence[i] == chord_sequence[i+1]
                       for i in range(len(chord_sequence)-1)):
                    continue

                # For each chord sequence, get voicing options
                voicing_options = [self.voicings.get(chord_key, []) for chord_key in chord_sequence]

                # Skip if any chord has no voicings
                if any(len(opts) == 0 for opts in voicing_options):
                    continue

                # Try all combinations of voicings (limit to avoid explosion)
                for voicing_combo in product(*voicing_options):
                    complexity = self._calculate_progression_complexity(voicing_combo)

                    # Only keep if better than worst in heap, or heap not full
                    if len(heap) < max_results:
                        # Heap not full, add this progression
                        heapq.heappush(heap, (-complexity, counter, voicing_combo, chord_sequence))
                        counter += 1
                    elif complexity < -heap[0][0]:  # Better (lower) than worst
                        # Replace worst with this better progression
                        heapq.heapreplace(heap, (-complexity, counter, voicing_combo, chord_sequence))
                        counter += 1

            # Extract results from heap and format
            progressions = []
            for neg_complexity, counter, voicing_combo, chord_sequence in heap:
                complexity = -neg_complexity

                # Build description
                chord_names = ' - '.join(str(v) for v in voicing_combo)

                # Get chord objects for display
                chord_objs = [v.chord for v in voicing_combo]
                functional_str = ' - '.join(str(c) for c in chord_objs)

                progressions.append({
                    'complexity': complexity,
                    'voicings': voicing_combo,
                    'chords': chord_objs,
                    'description': chord_names,
                    'functional': functional_str
                })

            # Sort by complexity and take top results
            progressions.sort(key=lambda x: x['complexity'])
            results_by_length[length] = progressions[:max_results]

        return results_by_length

    def identify_common_progressions(self,
                                    progressions_by_length: Dict[int, List[Dict]]) -> Dict[int, List[Dict]]:
        """Identify well-known progression patterns.

        Note: Pattern names are based on standard major/minor harmony and may not
        apply directly to all ancient Greek modes, as the harmonic function of
        scale degrees differs between modes.

        Args:
            progressions_by_length: Output from generate_progressions()

        Returns:
            Same structure with 'common_name' field added to each progression
        """
        identified = {}

        # Common 2-chord patterns
        two_chord_patterns = {
            (4, 0): 'Authentic Cadence (V-I)',
            (3, 0): 'Plagal Cadence (IV-I)',
            (0, 4): 'Half Cadence (I-V)',
            (4, 5): 'Deceptive Cadence (V-vi)',
        }

        # Common 3-chord patterns
        three_chord_patterns = {
            (0, 3, 4): 'I-IV-V',
            (0, 4, 0): 'I-V-I',
            (1, 4, 0): 'ii-V-I (Jazz)',
            (0, 5, 3): 'I-vi-IV',
        }

        # Common 4-chord patterns
        four_chord_patterns = {
            (0, 4, 5, 3): 'I-V-vi-IV (Pop)',
            (0, 5, 3, 4): 'I-vi-IV-V (50s)',
            (5, 3, 0, 4): 'vi-IV-I-V (Sensitive)',
            (0, 3, 4, 0): 'I-IV-V-I',
            (1, 4, 0, 0): 'ii-V-I-I',
        }

        for length, progressions in progressions_by_length.items():
            identified[length] = []

            for prog in progressions:
                # Only identify patterns for triads (size 3)
                chord_degrees = tuple(c.root_degree for c in prog['chords'])

                # Skip pattern matching if not all triads
                all_triads = all(c.size == TRIAD_SIZE for c in prog['chords'])
                if not all_triads:
                    # Skip common pattern matching for dyads/tetrads
                    identified[length].append({**prog, 'common_name': None})
                    continue

                triad_degrees = chord_degrees

                name = None
                if length == 2:
                    name = two_chord_patterns.get(triad_degrees)
                elif length == 3:
                    name = three_chord_patterns.get(triad_degrees)
                elif length == 4:
                    name = four_chord_patterns.get(triad_degrees)

                identified[length].append({
                    **prog,
                    'common_name': name
                })

        return identified

    def print_analysis(self, output_file: Optional[str] = None) -> None:
        """Print comprehensive analysis of this mode.

        Args:
            output_file: Optional file path to write output (prints to stdout if None)
        """
        lines = []

        lines.append("=" * 160)
        lines.append(f"LYRE CHORD PROGRESSION ANALYSIS - {self.mode_name}")
        lines.append("=" * 160)
        lines.append("")
        lines.append(f"Number of strings: {self.num_strings}")

        # Show which part of the pattern is used/unused for < 7 strings
        if self.num_strings < 7:
            # Build interval pattern with brackets
            intervals = self.interval_pattern.split('-')
            used_intervals = '-'.join(intervals[:self.num_strings - 1])
            unused_intervals = '-'.join(intervals[self.num_strings - 1:])
            pattern_display = f"{used_intervals} [{unused_intervals}]"

            # Build semitone list with brackets
            used_semitones = ', '.join(map(str, self.scale_semitones[:self.num_strings]))
            unused_semitones = ', '.join(map(str, self.scale_semitones[self.num_strings:]))
            semitones_display = f"[{used_semitones}] [{unused_semitones}]"

            lines.append(f"Interval Pattern: {pattern_display}")
            lines.append(f"Scale Degrees (semitones): {semitones_display}")
            lines.append(f"Note: Using first {self.num_strings} degrees of the mode (degrees 0-{self.num_strings-1})")
        else:
            lines.append(f"Interval Pattern: {self.interval_pattern}")
            lines.append(f"Scale Degrees (semitones): {self.scale_semitones}")

        lines.append("")

        # Show available chords by size
        lines.append("-" * 160)
        lines.append("AVAILABLE CHORDS")
        lines.append("-" * 160)
        lines.append("")

        # Group chords by size
        chords_by_size = {}
        for chord in self.chords:
            if chord.size not in chords_by_size:
                chords_by_size[chord.size] = []
            chords_by_size[chord.size].append(chord)

        # Display each chord size group
        for size in sorted(chords_by_size.keys()):
            size_names = {2: "DYADS (2-note)", 3: "TRIADS (3-note)", 4: "TETRADS (4-note)"}
            lines.append(f"  {size_names.get(size, f'{size}-note chords')}:")
            lines.append("")

            for chord in chords_by_size[size]:
                voicings = self.voicings.get((chord.root_degree, chord.size), [])
                root_voicings = [v for v in voicings if v.inversion == 'root']
                inv_voicings = [v for v in voicings if v.inversion != 'root']

                line = f"    {str(chord):>10} ({chord.quality:>8}): "
                if root_voicings:
                    line += f"Root: {root_voicings[0]}"
                else:
                    line += "Root: NONE"

                if inv_voicings:
                    line += f"  | Inversions: {', '.join(str(v) for v in inv_voicings[:3])}"

                lines.append(line)

            lines.append("")

        lines.append("")

        # Generate progressions
        lines.append("-" * 160)
        lines.append("GENERATING PROGRESSIONS...")
        lines.append("-" * 160)
        lines.append("")

        progressions = self.generate_progressions(min_length=2, max_length=4, max_results=50)
        identified = self.identify_common_progressions(progressions)

        # Print top progressions for each length
        for length in [2, 3, 4]:
            if length not in identified or not identified[length]:
                lines.append(f"No {length}-chord progressions found")
                lines.append("")
                continue

            lines.append("=" * 160)
            lines.append(f"{length}-CHORD PROGRESSIONS (Top 30)")
            lines.append("=" * 160)
            lines.append("")
            lines.append(f"{'Rank':<5} {'Notes':<45} {'Progression':<22} {'Voicings':<38} {'Complexity':<10} {'Common Name':<20}")
            lines.append("-" * 160)

            for rank, prog in enumerate(identified[length][:30], 1):
                common = prog['common_name'] or ''

                # Generate note names for this progression
                note_sequence = []
                for voicing in prog['voicings']:
                    note_sequence.append(self._voicing_to_note_names(voicing))
                notes_str = '  '.join(note_sequence)  # Two spaces between chords for clarity

                lines.append(
                    f"{rank:<5} {notes_str:<45} {prog['functional']:<22} {prog['description']:<38} "
                    f"{prog['complexity']:<10.4f} {common:<20}"
                )

            lines.append("")

        # Summary statistics
        lines.append("=" * 160)
        lines.append("SUMMARY")
        lines.append("=" * 160)
        lines.append("")

        # Count chords by size and quality
        for size in sorted(chords_by_size.keys()):
            size_names = {2: "Dyad", 3: "Triad", 4: "Tetrad"}
            size_name = size_names.get(size, f"{size}-note chord")

            quality_counts = defaultdict(int)
            for chord in chords_by_size[size]:
                quality_counts[chord.quality] += 1

            lines.append(f"{size_name} qualities available:")
            for quality, count in sorted(quality_counts.items()):
                lines.append(f"  {quality}: {count}")

            # Count root position vs inversions
            root_count = sum(1 for c in chords_by_size[size]
                           if any(v.inversion == 'root' for v in self.voicings.get((c.root_degree, c.size), [])))
            total = len(chords_by_size[size])
            lines.append(f"{size_name}s in root position: {root_count}/{total}")
            lines.append("")

        # Best progressions of each type (only show if any exist)
        # Note: Common progression patterns are based on major/minor harmony
        # and rarely match ancient Greek modes, so this section is usually empty
        notable_found = False
        for length in [2, 3, 4]:
            if length not in identified:
                continue
            notable = [p for p in identified[length] if p['common_name']]
            if notable:
                if not notable_found:
                    lines.append("NOTABLE PROGRESSIONS (standard harmony patterns):")
                    lines.append("")
                    notable_found = True
                lines.append(f"  {length}-chord progressions:")
                for prog in notable[:5]:
                    lines.append(f"    {prog['common_name']:<30} - {prog['functional']:<20} (complexity: {prog['complexity']:.4f})")
                lines.append("")

        if notable_found:
            lines.append("")

        # Write output
        output = '\n'.join(lines)
        if output_file:
            try:
                with open(output_file, 'w') as f:
                    f.write(output)
            except IOError as e:
                print(f"Error writing to {output_file}: {e}")
                print(output)
        else:
            print(output)


def analyze_all_modes(num_strings: int = 7,
                      first_note: str = 'E',
                      first_octave: int = 4,
                      output_file: Optional[str] = None) -> None:
    """Analyze all 7 ancient Greek modes.

    Args:
        num_strings: Number of strings on the lyre (default: 7)
        first_note: Root note for the scale (default: 'E')
        first_octave: Starting octave for the root note (default: 4)
        output_file: Output file path (optional)
    """

    modes = [
        'DORIOS',
        'PHRYGIOS',
        'LYDIOS',
        'MIXOLYDIOS',
        'HYPODORIOS',
        'HYPOLYDIOS',
        'HYPOPHRYGIOS'
    ]

    all_lines = []
    all_lines.append("=" * 160)
    all_lines.append("COMPREHENSIVE LYRE PROGRESSION ANALYSIS - ALL ANCIENT GREEK MODES")
    all_lines.append("=" * 160)
    all_lines.append("")
    all_lines.append(f"This analysis examines chord progressions on a {num_strings}-string lyre for each mode.")
    all_lines.append("Progressions are ranked by combined complexity including:")
    all_lines.append("  - Individual chord consonance (harmonic complexity formula)")
    all_lines.append("  - Voicing quality (root position vs inversions)")
    all_lines.append("  - Voice leading smoothness (string distance)")
    all_lines.append("  - Root movement strength (harmonic function)")
    all_lines.append("")
    all_lines.append("")

    # Analyze each mode
    for mode in modes:
        print(f"Analyzing {mode}...")
        try:
            analyzer = LyreProgressionAnalyzer(mode,
                                              num_strings=num_strings,
                                              first_note=first_note,
                                              first_octave=first_octave)

            # Collect output
            f = io.StringIO()
            with redirect_stdout(f):
                analyzer.print_analysis()

            mode_output = f.getvalue()
            all_lines.append(mode_output)
            all_lines.append("\n" * 3)
        except Exception as e:
            print(f"Error analyzing {mode}: {e}")
            all_lines.append(f"ERROR analyzing {mode}: {e}\n\n")

    # Write combined output
    output = '\n'.join(all_lines)
    if output_file:
        try:
            with open(output_file, 'w') as f:
                f.write(output)
            print(f"\nAnalysis complete! Results written to: {output_file}")
        except IOError as e:
            print(f"Error writing to {output_file}: {e}")
            print(output)
    else:
        print(output)


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Analyze lyre chord progressions by mode')
    parser.add_argument('--mode', type=str, default=None,
                       choices=['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS',
                               'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS'],
                       help='Analyze specific mode (default: analyze all)')
    parser.add_argument('--num-strings', type=int, default=7,
                       help=f'Number of strings on the lyre (default: 7, range: {MIN_STRINGS_FOR_TRIADS}-{MAX_STRINGS_SUPPORTED})')
    parser.add_argument('--first-note', type=str, default='E',
                       choices=['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'],
                       help='Root note for the scale (default: E)')
    parser.add_argument('--first-octave', type=int, default=4,
                       help='Starting octave for the root note (default: 4)')
    parser.add_argument('--output', '-o', type=str, default='lyre_progression_analysis.txt',
                       help='Output file path')

    args = parser.parse_args()

    # Validate num_strings parameter
    if args.num_strings < MIN_STRINGS_FOR_TRIADS:
        print(f"Error: num_strings must be at least {MIN_STRINGS_FOR_TRIADS} for triad analysis")
        print(f"       (With fewer strings, only dyads/2-note chords are possible)")
        sys.exit(1)
    if args.num_strings > MAX_STRINGS_SUPPORTED:
        print(f"Error: num_strings cannot exceed {MAX_STRINGS_SUPPORTED} (requested {args.num_strings})")
        sys.exit(1)

    try:
        if args.mode:
            # Analyze single mode
            analyzer = LyreProgressionAnalyzer(args.mode,
                                              num_strings=args.num_strings,
                                              first_note=args.first_note,
                                              first_octave=args.first_octave)
            analyzer.print_analysis(output_file=args.output)
            print(f"\nAnalysis complete! Results written to: {args.output}")
        else:
            # Analyze all modes
            analyze_all_modes(num_strings=args.num_strings,
                            first_note=args.first_note,
                            first_octave=args.first_octave,
                            output_file=args.output)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
