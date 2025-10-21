#!/usr/bin/env python3
"""Debug script to check chord matching logic."""

import sys
from pathlib import Path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_chords import LyreChordAnalyzer
from itertools import combinations

# Test with LYDIOS (C major) - simplest case
mode = 'LYDIOS'
num_strings = 8

analyzer = LyreChordAnalyzer(
    num_strings=num_strings,
    mode=mode,
    first_note='E',
    temperament='JUST',
    formula='NUMERIC_EMPIRIC_20251018'
)

print(f"Mode: {mode}")
print(f"Scale semitones: {LyreChordAnalyzer.MODES[mode]}")
print(f"\nString frequencies:")
for i, freq in enumerate(analyzer.frequencies):
    print(f"  String {i}: {freq:.2f} Hz")

print(f"\nScale ratios (first 7 strings):")
ratios = analyzer.frequencies_to_ratios(analyzer.frequencies[:7])
for i, ratio in enumerate(ratios):
    print(f"  Degree {i}: {ratio:.4f}")

# Test IV chord (degree 3)
scale_semitones = LyreChordAnalyzer.MODES[mode]
iv_degree = 3
iv_triad_degrees = [(iv_degree + i) % 7 for i in [0, 2, 4]]
print(f"\nIV chord:")
print(f"  Degrees: {iv_triad_degrees}")
print(f"  Semitones: {[scale_semitones[d] for d in iv_triad_degrees]}")

# Expected IV chord in LYDIOS (C major): F A C = degrees [3, 5, 0]
# Semitones: F=5, A=9, C=0+12=12
# For 8 strings: should be strings [4, 6, 8] (degrees [3, 5, 0])

print(f"\nLooking for IV chord in 8-string combinations:")
print(f"Expected degrees: [3, 5, 0]")

# Check if string combination [4, 6, 8] exists
if num_strings >= 8:
    string_degrees = list(range(7)) + [0]  # 8th string is degree 0
    print(f"\nString degrees for 8-string lyre: {string_degrees}")
    print(f"\nString combo [4, 6, 8] has degrees: [{string_degrees[4]}, {string_degrees[6]}, {string_degrees[8]}]")

    # Check the frequencies
    freqs = [analyzer.frequencies[i] for i in [4, 6, 8]]
    print(f"Frequencies: {freqs}")
    ratios_check = analyzer.frequencies_to_ratios(freqs)
    print(f"Ratios: {ratios_check}")
