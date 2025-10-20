#!/usr/bin/env python3
"""
Analyze all possible chord progressions for each ancient Greek mode on a 7-string lyre.
Considers voicing constraints, inversions, and voice leading.

IMPORTANT: This analysis uses JUST INTONATION (pure integer frequency ratios),
not equal temperament. This is critical for accurate consonance calculations
on a lyre, which uses just-tuned strings.
"""

import sys
from pathlib import Path

# Add parent directory to path to import from parent folder
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

import numpy as np
from itertools import product, combinations
from collections import defaultdict
from analyze_lyre_chords import LyreChordAnalyzer
from run_all_consonance_tests import complexity_with_five_adjustments

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


class Triad:
    """Represents a triad with its properties."""

    QUALITIES = {
        (4, 7): 'maj',   # Major: M3 + P5
        (3, 7): 'min',   # Minor: m3 + P5
        (3, 6): 'dim',   # Diminished: m3 + d5
        (4, 8): 'aug',   # Augmented: M3 + A5
    }

    def __init__(self, root_degree, scale_semitones, root_semitone):
        """
        Args:
            root_degree: Scale degree (0-6)
            scale_semitones: List of semitones for the mode
            root_semitone: Absolute semitone of the root
        """
        self.root_degree = root_degree
        self.scale_semitones = scale_semitones
        self.root_semitone = root_semitone

        # Build triad: root, third, fifth (scale degrees 0, 2, 4 above root)
        degrees = [(root_degree + i) % 7 for i in [0, 2, 4]]
        self.degrees = degrees

        # Get semitones (wrapping to next octave if needed)
        semitones = []
        for i, deg in enumerate(degrees):
            st = scale_semitones[deg]
            if deg < root_degree:
                st += 12  # Next octave
            semitones.append(st)

        self.semitones = semitones

        # Determine quality
        third_interval = semitones[1] - semitones[0]
        fifth_interval = semitones[2] - semitones[0]
        self.quality = self.QUALITIES.get((third_interval, fifth_interval), 'unk')

    def __repr__(self):
        roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][self.root_degree]
        if self.quality == 'min':
            roman = roman.lower()
        elif self.quality == 'dim':
            roman = roman.lower() + '°'
        elif self.quality == 'aug':
            roman = roman + '+'
        return roman

    def get_name(self):
        """Get full chord name."""
        return str(self)


class LyreVoicing:
    """Represents how a triad is voiced on the lyre."""

    def __init__(self, triad, string_indices, semitones):
        """
        Args:
            triad: Triad object
            string_indices: List of string numbers (1-7) used
            semitones: List of actual semitones played (may span octaves)
        """
        self.triad = triad
        self.string_indices = string_indices
        self.semitones = semitones

        # Determine inversion
        # Root position: bass note is root
        # 1st inversion: bass note is third
        # 2nd inversion: bass note is fifth
        root_mod = triad.semitones[0] % 12
        bass_mod = semitones[0] % 12

        if bass_mod == root_mod:
            self.inversion = 'root'
        elif bass_mod == (triad.semitones[1] % 12):
            self.inversion = '1st'
        elif bass_mod == (triad.semitones[2] % 12):
            self.inversion = '2nd'
        else:
            self.inversion = 'unk'

        # Check if ascending
        self.is_ascending = all(semitones[i] < semitones[i+1] for i in range(len(semitones)-1))

    def __repr__(self):
        inv_symbol = {'root': '', '1st': '⁶', '2nd': '⁶₄', 'unk': '?'}[self.inversion]
        asc = '↑' if self.is_ascending else '↓'
        strings = ','.join(str(s) for s in self.string_indices)
        return f"{self.triad}{inv_symbol}[{strings}]{asc}"

    def voicing_penalty(self):
        """Calculate penalty for non-ideal voicing."""
        penalty = 0.0

        # Heavy penalty for non-root position
        if self.inversion == '1st':
            penalty += 1.5
        elif self.inversion == '2nd':
            penalty += 2.0
        elif self.inversion == 'unk':
            penalty += 3.0

        # Small penalty for non-ascending (crossed voices)
        if not self.is_ascending:
            penalty += 1.0

        return penalty


class LyreProgressionAnalyzer:
    """Analyzes chord progressions for a given mode on a 7-string lyre.

    Uses just intonation (pure integer frequency ratios) for accurate
    consonance calculations. The complexity formula evaluates:
    - Individual chord consonance (harmonic complexity)
    - Voicing quality (root position vs inversions)
    - Voice leading smoothness (string distances)
    - Root movement strength (harmonic function)
    """

    def __init__(self, mode_name, complexity_params=None):
        """
        Args:
            mode_name: Ancient Greek mode name (e.g., 'DORIOS')
            complexity_params: Parameters for complexity formula
        """
        self.mode_name = mode_name
        self.params = complexity_params or DEFAULT_PARAMS

        # Get mode pattern
        self.scale_semitones = LyreChordAnalyzer.MODES[mode_name]

        # Create a LyreChordAnalyzer instance to get just intonation frequencies
        # We need to determine the first note based on the mode
        # Using E4 as default starting note (works well for most modes)
        self.chord_analyzer = LyreChordAnalyzer(
            num_strings=7,
            mode=mode_name,
            first_note='E',
            temperament='JUST',
            formula='NUMERIC_EMPIRIC_20251018'
        )

        # Store the just intonation frequencies for each string
        self.just_frequencies = self.chord_analyzer.frequencies

        # Build interval pattern
        self.interval_pattern = self._build_interval_pattern()

        # Build all triads
        self.triads = self._build_triads()

        # Build all voicings for each triad
        self.voicings = self._build_voicings()

    def _build_interval_pattern(self):
        """Convert semitone list to H/W pattern."""
        pattern = []
        for i in range(len(self.scale_semitones)):
            next_i = (i + 1) % len(self.scale_semitones)
            interval = self.scale_semitones[next_i] - self.scale_semitones[i]
            if next_i == 0:  # Wrap around
                interval = (12 - self.scale_semitones[i])

            if interval == 1:
                pattern.append('H')
            elif interval == 2:
                pattern.append('W')
            else:
                pattern.append(f'{interval}')

        return '-'.join(pattern)

    def _build_triads(self):
        """Build all diatonic triads in this mode."""
        triads = []
        for degree in range(7):
            triad = Triad(degree, self.scale_semitones, self.scale_semitones[degree])
            triads.append(triad)
        return triads

    def _build_voicings(self):
        """Find all possible voicings for each triad on 7 strings."""
        voicings_by_triad = {}

        for triad in self.triads:
            voicings = []

            # Try all combinations of 3 strings
            for strings in combinations(range(7), 3):
                # Map strings to scale degrees
                # String i plays scale degree i (0-indexed)
                played_degrees = list(strings)

                # Get semitones played (considering octave wrapping)
                semitones = [self.scale_semitones[deg] for deg in played_degrees]

                # Check if this forms the triad
                # Normalize to root octave
                triad_notes = [(st % 12) for st in triad.semitones]
                played_notes = [(st % 12) for st in semitones]

                if set(played_notes) == set(triad_notes):
                    # This is a valid voicing!
                    voicing = LyreVoicing(
                        triad,
                        [s+1 for s in strings],  # 1-indexed for display
                        semitones
                    )
                    voicings.append(voicing)

            voicings_by_triad[triad.root_degree] = voicings

        return voicings_by_triad

    def _voice_leading_distance(self, voicing1, voicing2):
        """Calculate voice leading distance between two voicings."""
        # Simple metric: sum of string movements
        strings1 = set(voicing1.string_indices)
        strings2 = set(voicing2.string_indices)

        # Count how many strings change
        common = strings1 & strings2

        # Penalty for each voice that moves
        # Bonus for common tones
        distance = len(strings1 - common) + len(strings2 - common)
        common_tone_bonus = -len(common) * 0.5

        return distance + common_tone_bonus

    def _root_movement_complexity(self, triad1, triad2):
        """Calculate complexity of root movement.

        Lower (more negative) values = stronger/simpler progressions.
        Based on traditional harmonic theory of root movement strength.
        """
        # Movement in scale degrees
        degree_distance = (triad2.root_degree - triad1.root_degree) % 7

        # Interval movements ranked by strength (lower = stronger)
        # Distance 3 includes V→I (strongest resolution in tonal harmony)
        # Distance 4 includes I→V (half cadence, creates tension)
        movement_strength = {
            0: 0.0,   # No movement (pedal)
            3: -1.5,  # Includes V→I (authentic cadence) - STRONGEST
            4: -0.3,  # Includes IV→I (plagal) and I→V (half) - mixed
            5: -0.5,  # Ascending 5th
            2: 0.3,   # Stepwise (up by 2nd)
            6: 1.5,   # Tritone (unstable)
            1: 0.8,   # Half step
        }

        return movement_strength.get(degree_distance, 1.0)

    def _calculate_progression_complexity(self, voicing_sequence):
        """Calculate total complexity of a progression."""
        complexity = 0.0

        # Individual chord complexities
        for voicing in voicing_sequence:
            # Get actual just intonation frequencies for this voicing
            # voicing.string_indices are 1-indexed, so subtract 1 for array access
            freqs = [self.just_frequencies[idx - 1] for idx in voicing.string_indices]

            # Convert frequencies to integer ratios using the parent class method
            ratios = self.chord_analyzer.frequencies_to_ratios(freqs)

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
            complexity += vl_distance * 0.5  # Weight factor

        # Root movement
        for i in range(len(voicing_sequence) - 1):
            root_complexity = self._root_movement_complexity(
                voicing_sequence[i].triad,
                voicing_sequence[i+1].triad
            )
            complexity += root_complexity

        return complexity

    def generate_progressions(self, min_length=2, max_length=4, max_results=100):
        """
        Generate all possible progressions.

        Args:
            min_length: Minimum number of chords
            max_length: Maximum number of chords
            max_results: Maximum progressions to return per length

        Returns:
            Dict mapping length to list of (complexity, voicing_sequence, description)
        """
        results_by_length = {}

        for length in range(min_length, max_length + 1):
            progressions = []

            # Generate all possible triad sequences
            for triad_sequence in product(range(7), repeat=length):
                # Skip sequences with consecutive repeats (boring)
                if any(triad_sequence[i] == triad_sequence[i+1]
                       for i in range(len(triad_sequence)-1)):
                    continue

                # For each triad sequence, try all voicing combinations
                voicing_options = [self.voicings[deg] for deg in triad_sequence]

                # Try all combinations of voicings (limit to avoid explosion)
                # Use best voicing for each chord to keep it manageable
                for voicing_combo in product(*voicing_options):
                    complexity = self._calculate_progression_complexity(voicing_combo)

                    # Build description
                    chord_names = ' - '.join(str(v) for v in voicing_combo)
                    triad_sequence_str = ' - '.join(
                        str(self.triads[deg]) for deg in triad_sequence
                    )

                    progressions.append({
                        'complexity': complexity,
                        'voicings': voicing_combo,
                        'triads': [self.triads[deg] for deg in triad_sequence],
                        'description': chord_names,
                        'functional': triad_sequence_str
                    })

            # Sort by complexity and take top results
            progressions.sort(key=lambda x: x['complexity'])
            results_by_length[length] = progressions[:max_results]

        return results_by_length

    def identify_common_progressions(self, progressions_by_length):
        """Identify well-known progression patterns."""
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
                triad_degrees = tuple(t.root_degree for t in prog['triads'])

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

    def print_analysis(self, output_file=None):
        """Print comprehensive analysis of this mode."""
        lines = []

        lines.append("=" * 120)
        lines.append(f"LYRE CHORD PROGRESSION ANALYSIS - {self.mode_name}")
        lines.append("=" * 120)
        lines.append("")
        lines.append(f"Interval Pattern: {self.interval_pattern}")
        lines.append(f"Scale Degrees (semitones): {self.scale_semitones}")
        lines.append("")

        # Show available triads
        lines.append("-" * 120)
        lines.append("AVAILABLE TRIADS")
        lines.append("-" * 120)
        lines.append("")

        for triad in self.triads:
            voicings = self.voicings[triad.root_degree]
            root_voicings = [v for v in voicings if v.inversion == 'root']
            inv_voicings = [v for v in voicings if v.inversion != 'root']

            lines.append(f"{str(triad):>6} ({triad.quality:>3}): ", )
            if root_voicings:
                lines[-1] += f"Root position: {root_voicings[0]}"
            else:
                lines[-1] += f"Root position: NONE"

            if inv_voicings:
                lines[-1] += f"  | Inversions: {', '.join(str(v) for v in inv_voicings[:3])}"

        lines.append("")

        # Generate progressions
        lines.append("-" * 120)
        lines.append("GENERATING PROGRESSIONS...")
        lines.append("-" * 120)
        lines.append("")

        progressions = self.generate_progressions(min_length=2, max_length=4, max_results=50)
        identified = self.identify_common_progressions(progressions)

        # Print top progressions for each length
        for length in [2, 3, 4]:
            lines.append("=" * 120)
            lines.append(f"{length}-CHORD PROGRESSIONS (Top 30)")
            lines.append("=" * 120)
            lines.append("")
            lines.append(f"{'Rank':<6} {'Progression':<35} {'Voicings':<45} {'Complexity':<12} {'Common Name':<25}")
            lines.append("-" * 120)

            for rank, prog in enumerate(identified[length][:30], 1):
                common = prog['common_name'] or ''
                lines.append(
                    f"{rank:<6} {prog['functional']:<35} {prog['description']:<45} "
                    f"{prog['complexity']:<12.4f} {common:<25}"
                )

            lines.append("")

        # Summary statistics
        lines.append("=" * 120)
        lines.append("SUMMARY")
        lines.append("=" * 120)
        lines.append("")

        # Count triads by quality
        quality_counts = defaultdict(int)
        for triad in self.triads:
            quality_counts[triad.quality] += 1

        lines.append("Triad qualities available:")
        for quality, count in sorted(quality_counts.items()):
            lines.append(f"  {quality}: {count}")
        lines.append("")

        # Count root position vs inversions
        root_count = sum(1 for t in self.triads if any(v.inversion == 'root' for v in self.voicings[t.root_degree]))
        lines.append(f"Triads available in root position: {root_count}/7")
        lines.append(f"Triads requiring inversion: {7 - root_count}/7")
        lines.append("")

        # Best progressions of each type
        lines.append("NOTABLE PROGRESSIONS:")
        lines.append("")

        for length in [2, 3, 4]:
            notable = [p for p in identified[length] if p['common_name']]
            if notable:
                lines.append(f"  {length}-chord progressions:")
                for prog in notable[:5]:
                    lines.append(f"    {prog['common_name']:<30} - {prog['functional']:<20} (complexity: {prog['complexity']:.4f})")
                lines.append("")

        lines.append("")

        # Write output
        output = '\n'.join(lines)
        if output_file:
            with open(output_file, 'w') as f:
                f.write(output)
        else:
            print(output)


def analyze_all_modes(output_file=None):
    """Analyze all 7 ancient Greek modes."""

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
    all_lines.append("=" * 120)
    all_lines.append("COMPREHENSIVE LYRE PROGRESSION ANALYSIS - ALL ANCIENT GREEK MODES")
    all_lines.append("=" * 120)
    all_lines.append("")
    all_lines.append("This analysis examines chord progressions on a 7-string lyre for each mode.")
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
        analyzer = LyreProgressionAnalyzer(mode)

        # Collect output
        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            analyzer.print_analysis()

        mode_output = f.getvalue()
        all_lines.append(mode_output)
        all_lines.append("\n" * 3)

    # Write combined output
    output = '\n'.join(all_lines)
    if output_file:
        with open(output_file, 'w') as f:
            f.write(output)
        print(f"\nAnalysis complete! Results written to: {output_file}")
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
    parser.add_argument('--output', '-o', type=str, default='lyre_progression_analysis.txt',
                       help='Output file path')

    args = parser.parse_args()

    if args.mode:
        # Analyze single mode
        analyzer = LyreProgressionAnalyzer(args.mode)
        analyzer.print_analysis(output_file=args.output)
        print(f"\nAnalysis complete! Results written to: {args.output}")
    else:
        # Analyze all modes
        analyze_all_modes(output_file=args.output)


if __name__ == "__main__":
    main()
