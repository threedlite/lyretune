#!/usr/bin/env python3
"""
Analyze all possible chord combinations for a given lyre tuning.
Uses the complexity formula from run_all_consonance_tests.py to rank chords.
"""

import numpy as np
from itertools import combinations
from math import gcd, floor
from functools import reduce
from run_all_consonance_tests import complexity_with_five_adjustments

# Available complexity formulas
AVAILABLE_FORMULAS = ['NUMERIC_EMPIRIC_20251018']

# Formula parameters
FORMULA_PARAMS = {
    'NUMERIC_EMPIRIC_20251018': {
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
}

# Default formula
DEFAULT_FORMULA = 'NUMERIC_EMPIRIC_20251018'

class LyreChordAnalyzer:
    A4_FREQ = 440.0

    # Ancient Greek modes (interval patterns in semitones from first note)
    MODES = {
        'DORIOS': [0, 1, 3, 5, 7, 8, 10],      # Ancient Dorios = Modern Phrygian (E mode)
        'PHRYGIOS': [0, 2, 3, 5, 7, 9, 10],    # Ancient Phrygios = Modern Dorian (D mode)
        'LYDIOS': [0, 2, 4, 5, 7, 9, 11],      # Ancient Lydios = Modern Ionian (C mode)
        'MIXOLYDIOS': [0, 1, 3, 5, 6, 8, 10],  # Ancient Mixolydios = Modern Locrian (B mode)
        'HYPODORIOS': [0, 2, 3, 5, 7, 8, 10],  # Ancient Hypodorios = Modern Aeolian (A mode)
        'HYPOLYDIOS': [0, 2, 4, 6, 7, 9, 11],  # Ancient Hypolydios = Modern Lydian (F mode)
        'HYPOPHRYGIOS': [0, 2, 4, 5, 7, 9, 10] # Ancient Hypophrygios = Modern Mixolydian (G mode)
    }

    # Note names to semitones from C
    NOTE_TO_SEMITONE = {
        'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
        'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
        'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11
    }

    def __init__(self, num_strings=7, mode='DORIOS', first_note='E', temperament='JUST', formula='NUMERIC_EMPIRIC_20251018'):
        """
        Initialize the lyre chord analyzer.

        Args:
            num_strings: Number of strings on the lyre (default 7)
            mode: Ancient Greek mode name (default 'DORIOS')
            first_note: Starting note (default 'E')
            temperament: Tuning system - 'EQUAL' or 'JUST' (default 'JUST')
            formula: Complexity formula to use (default 'NUMERIC_EMPIRIC_20251018')
        """
        self.num_strings = num_strings
        self.mode = mode.upper()
        self.first_note = first_note
        self.temperament = temperament.upper()
        self.formula = formula
        self.frequencies = []
        self.note_names = []

        if self.mode not in self.MODES:
            raise ValueError(f"Unknown mode: {mode}. Available: {list(self.MODES.keys())}")

        if self.first_note not in self.NOTE_TO_SEMITONE:
            raise ValueError(f"Unknown note: {first_note}. Available: {list(self.NOTE_TO_SEMITONE.keys())}")

        if self.formula not in AVAILABLE_FORMULAS:
            raise ValueError(f"Unknown formula: {formula}. Available: {AVAILABLE_FORMULAS}")

        self._calculate_tuning()

    def _calculate_tuning(self):
        """Calculate the frequencies for each string based on mode and temperament."""
        mode_pattern = self.MODES[self.mode]
        base_semitone = self.NOTE_TO_SEMITONE[self.first_note]

        # Start at octave 4 (around middle C)
        octave = 4
        last_freq = 0

        for i in range(self.num_strings):
            # Get interval from mode pattern (cycle through if more strings than notes in mode)
            pattern_index = i % len(mode_pattern)
            interval_semitones = mode_pattern[pattern_index]

            # Calculate octave offset
            octave_offset = i // len(mode_pattern)
            current_octave = octave + octave_offset

            # Calculate semitones from A4 (440 Hz reference)
            semitones_from_c4 = interval_semitones
            semitones_from_a4 = (base_semitone - 9) + semitones_from_c4 + (current_octave - 4) * 12

            # Calculate frequency based on temperament
            if self.temperament == 'EQUAL':
                freq = self.A4_FREQ * (2.0 ** (semitones_from_a4 / 12.0))
            else:  # JUST intonation
                freq = self.A4_FREQ * self._get_just_ratio(semitones_from_a4)

            # Ensure ascending frequencies (bump octave if needed)
            while freq <= last_freq and current_octave < 10:
                current_octave += 1
                semitones_from_a4 += 12
                if self.temperament == 'EQUAL':
                    freq = self.A4_FREQ * (2.0 ** (semitones_from_a4 / 12.0))
                else:
                    freq = self.A4_FREQ * self._get_just_ratio(semitones_from_a4)

            self.frequencies.append(freq)

            # Generate note name with octave
            note_name = self._get_note_name(base_semitone, interval_semitones, current_octave)
            self.note_names.append(note_name)

            last_freq = freq

    def _get_just_ratio(self, semitones):
        """Get just intonation ratio for a given number of semitones from A4."""
        # Just intonation ratios for each semitone in an octave from A
        ratios = [
            1.0,       # A
            16.0/15.0, # A#/Bb
            9.0/8.0,   # B
            6.0/5.0,   # C
            5.0/4.0,   # C#/Db
            4.0/3.0,   # D
            45.0/32.0, # D#/Eb
            3.0/2.0,   # E
            8.0/5.0,   # F
            5.0/3.0,   # F#/Gb
            9.0/5.0,   # G
            15.0/8.0   # G#/Ab
        ]

        octaves = floor(semitones / 12.0)
        note_index = int((semitones % 12 + 12) % 12)

        return ratios[note_index] * (2.0 ** octaves)

    def _get_note_name(self, base_semitone, interval, octave):
        """Generate note name with octave."""
        total_semitones = base_semitone + interval
        note_semitone = total_semitones % 12
        octave_adjustment = total_semitones // 12
        actual_octave = octave + octave_adjustment

        # Find note name for this semitone
        for note, st in self.NOTE_TO_SEMITONE.items():
            if st == note_semitone and len(note) <= 2:  # Prefer natural/sharp over flat
                return f"{note}{actual_octave}"

        return f"Note{note_semitone}{actual_octave}"

    def frequencies_to_ratios(self, freqs):
        """
        Convert a list of frequencies to integer ratios.

        Args:
            freqs: List of frequencies

        Returns:
            Tuple of integers representing the ratio
        """
        if not freqs:
            return ()

        # Normalize to lowest frequency
        min_freq = min(freqs)
        ratios = [f / min_freq for f in freqs]

        # Convert to integers by finding a common denominator
        # We'll use a precision-based approach
        precision = 10000
        int_ratios = [int(round(r * precision)) for r in ratios]

        # Reduce by GCD
        g = reduce(gcd, int_ratios)
        int_ratios = tuple(r // g for r in int_ratios)

        return int_ratios

    def analyze_all_chords(self, min_strings=2, max_strings=None):
        """
        Analyze all possible chord combinations.

        Args:
            min_strings: Minimum number of strings in a chord (default 2)
            max_strings: Maximum number of strings in a chord (default all strings)

        Returns:
            List of dicts with chord analysis results, sorted by complexity
        """
        # Get parameters for the selected formula
        params = FORMULA_PARAMS[self.formula]

        if max_strings is None:
            max_strings = self.num_strings

        results = []

        # Generate all combinations from min_strings to max_strings
        for size in range(min_strings, max_strings + 1):
            for combo in combinations(range(self.num_strings), size):
                # Get frequencies for this combination
                chord_freqs = [self.frequencies[i] for i in combo]
                chord_notes = [self.note_names[i] for i in combo]
                string_indices = [i + 1 for i in combo]  # 1-indexed for display

                # Convert to ratios
                ratios = self.frequencies_to_ratios(chord_freqs)

                # Calculate complexity using the selected formula
                complexity = complexity_with_five_adjustments(ratios, **params)

                results.append({
                    'strings': string_indices,
                    'notes': chord_notes,
                    'frequencies': chord_freqs,
                    'ratios': ratios,
                    'complexity': complexity,
                    'num_strings': size
                })

        # Sort by complexity (ascending - simplest first)
        results.sort(key=lambda x: (x['complexity'], x['num_strings']))

        return results

    def print_tuning(self, output_file=None):
        """Print the current tuning setup."""
        lines = []
        lines.append("=" * 80)
        lines.append(f"LYRE TUNING")
        lines.append("=" * 80)
        lines.append(f"Number of strings: {self.num_strings}")
        lines.append(f"Mode: {self.mode}")
        lines.append(f"First note: {self.first_note}")
        lines.append(f"Temperament: {self.temperament}")
        lines.append(f"Complexity formula: {self.formula}")
        lines.append("")
        lines.append(f"{'String':<8} {'Note':<10} {'Frequency (Hz)':<15} {'Ratio from String 1':<20}")
        lines.append("-" * 80)

        for i in range(self.num_strings):
            ratio = self.frequencies[i] / self.frequencies[0]
            lines.append(f"{i+1:<8} {self.note_names[i]:<10} {self.frequencies[i]:<15.2f} {ratio:<20.6f}")
        lines.append("")

        output = '\n'.join(lines)

        if output_file:
            with open(output_file, 'w') as f:
                f.write(output)
        else:
            print(output)

    def print_results(self, results, complexity_threshold=None, output_file=None):
        """
        Print analysis results.

        Args:
            results: List of chord analysis results
            complexity_threshold: Only show chords below this complexity (default: no filter)
            output_file: File path to write results (default: None, prints to console)
        """
        # Filter results
        filtered = results
        if complexity_threshold is not None:
            filtered = [r for r in filtered if r['complexity'] <= complexity_threshold]

        # Build output lines
        lines = []
        lines.append("=" * 120)
        lines.append(f"CHORD COMPLEXITY ANALYSIS - {len(filtered)} chords shown")
        lines.append("=" * 120)
        lines.append("")
        lines.append(f"{'Rank':<6} {'Strings':<15} {'Notes':<30} {'Ratio':<25} {'Complexity':<12} {'Size':<5}")
        lines.append("-" * 120)

        for rank, result in enumerate(filtered, 1):
            strings_str = ','.join(str(s) for s in result['strings'])
            notes_str = ' '.join(result['notes'])
            ratio_str = ':'.join(str(r) for r in result['ratios'])

            lines.append(f"{rank:<6} {strings_str:<15} {notes_str:<30} {ratio_str:<25} "
                  f"{result['complexity']:<12.6f} {result['num_strings']:<5}")

        lines.append("")
        lines.append("=" * 120)
        lines.append("STATISTICS")
        lines.append("=" * 120)
        lines.append(f"Total chords analyzed: {len(results)}")
        lines.append(f"Simplest chord: {filtered[0]['notes']} (complexity {filtered[0]['complexity']:.6f})")
        lines.append(f"Most complex chord: {results[-1]['notes']} (complexity {results[-1]['complexity']:.6f})")
        lines.append("")

        # Show distribution by size
        lines.append("Distribution by number of strings:")
        for size in range(2, self.num_strings + 1):
            chords_of_size = [r for r in results if r['num_strings'] == size]
            if chords_of_size:
                avg_complexity = np.mean([r['complexity'] for r in chords_of_size])
                lines.append(f"  {size} strings: {len(chords_of_size)} chords, avg complexity: {avg_complexity:.6f}")
        lines.append("")

        output = '\n'.join(lines)

        # Write to file if specified
        if output_file:
            with open(output_file, 'a') as f:  # Append mode to add to tuning info
                f.write(output)
        else:
            print(output)


def main():
    """Example usage."""
    import argparse

    parser = argparse.ArgumentParser(description='Analyze lyre chord complexity')
    parser.add_argument('--strings', type=int, default=7,
                        help='Number of strings (default: 7)')
    parser.add_argument('--mode', type=str, default='DORIOS',
                        choices=list(LyreChordAnalyzer.MODES.keys()),
                        help='Ancient Greek mode (default: DORIOS)')
    parser.add_argument('--note', type=str, default='E',
                        help='First note (default: E)')
    parser.add_argument('--temperament', type=str, default='JUST',
                        choices=['EQUAL', 'JUST'],
                        help='Temperament (default: JUST)')
    parser.add_argument('--formula', type=str, default=DEFAULT_FORMULA,
                        choices=AVAILABLE_FORMULAS,
                        help=f'Complexity formula (default: {DEFAULT_FORMULA})')
    parser.add_argument('--min-size', type=int, default=2,
                        help='Minimum chord size (default: 2)')
    parser.add_argument('--max-size', type=int, default=None,
                        help='Maximum chord size (default: all strings)')
    parser.add_argument('--threshold', type=float, default=None,
                        help='Only show chords with complexity below threshold')
    parser.add_argument('--output', '-o', type=str, default=None,
                        help='Output file path (default: print to console)')

    args = parser.parse_args()

    # Create analyzer
    analyzer = LyreChordAnalyzer(
        num_strings=args.strings,
        mode=args.mode,
        first_note=args.note,
        temperament=args.temperament,
        formula=args.formula
    )

    # Print tuning
    analyzer.print_tuning(output_file=args.output)

    # Analyze all chords
    status_msg = (f"Analyzing all chord combinations from {args.min_size} to "
                  f"{args.max_size or args.strings} strings...")
    if args.output:
        print(status_msg)
    else:
        print(status_msg)
        print()

    results = analyzer.analyze_all_chords(
        min_strings=args.min_size,
        max_strings=args.max_size
    )

    # Print results
    analyzer.print_results(results, complexity_threshold=args.threshold, output_file=args.output)

    # Final message if writing to file
    if args.output:
        print(f"Analysis complete! Results written to: {args.output}")


if __name__ == "__main__":
    main()
