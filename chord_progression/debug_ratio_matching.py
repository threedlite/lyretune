#!/usr/bin/env python3
"""Debug ratio matching."""

import sys
from pathlib import Path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_chords import LyreChordAnalyzer
from itertools import combinations

def ratios_match(ratios1, ratios2, tolerance=0.02):
    """Check if two sets of frequency ratios match (ignoring octaves and transposition)."""
    # Normalize both sets of ratios to start from 1.0
    def normalize_ratios(ratios):
        if not ratios:
            return []
        min_ratio = min(ratios)
        normalized = [r / min_ratio for r in ratios]
        # Further normalize to [1, 2) range (one octave)
        result = []
        for r in normalized:
            while r >= 2.0:
                r /= 2.0
            while r < 1.0:
                r *= 2.0
            result.append(r)
        return sorted(result)

    norm1 = normalize_ratios(ratios1)
    norm2 = normalize_ratios(ratios2)

    if len(norm1) != len(norm2):
        return False

    return all(abs(n1 - n2) < tolerance for n1, n2 in zip(norm1, norm2))

def get_chord_ratios(analyzer, triad_semitones, scale_semitones):
    """Get frequency ratios for a triad from semitone intervals."""
    scale_ratios = analyzer.frequencies_to_ratios(analyzer.frequencies[:7])
    scale_map = {st: deg for deg, st in enumerate(scale_semitones)}

    ratios = []
    for st in triad_semitones:
        st_mod = st % 12
        if st_mod in scale_map:
            scale_deg = scale_map[st_mod]
            ratio = scale_ratios[scale_deg]
            octaves = st // 12
            ratio *= (2 ** octaves)
            ratios.append(ratio)

    return ratios

# Test LYDIOS
mode = 'LYDIOS'
analyzer8 = LyreChordAnalyzer(num_strings=8, mode=mode, first_note='E', temperament='JUST', formula='NUMERIC_EMPIRIC_20251018')

scale_semitones = LyreChordAnalyzer.MODES[mode]
iv_triad_semitones = [5, 9, 12]  # F, A, C (adjusted for octave)

# Get expected ratios
iv_expected = get_chord_ratios(analyzer8, iv_triad_semitones, scale_semitones)
print(f"Mode: {mode}")
print(f"IV chord expected semitones: {iv_triad_semitones}")
print(f"IV chord expected ratios: {iv_expected}")
print()

# Check actual string combination (3, 5, 7)
combo = (3, 5, 7)
freqs = [analyzer8.frequencies[s] for s in combo]
ratios_actual = analyzer8.frequencies_to_ratios(freqs)
print(f"String combo {combo}:")
print(f"  Actual ratios: {ratios_actual}")
print(f"  Match? {ratios_match(ratios_actual, iv_expected)}")
print()

# Debug normalization
def normalize_ratios(ratios):
    if not ratios:
        return []
    min_ratio = min(ratios)
    normalized = [r / min_ratio for r in ratios]
    result = []
    for r in normalized:
        while r >= 2.0:
            r /= 2.0
        while r < 1.0:
            r *= 2.0
        result.append(r)
    return sorted(result)

print(f"Expected normalized: {normalize_ratios(iv_expected)}")
print(f"Actual normalized: {normalize_ratios(ratios_actual)}")
