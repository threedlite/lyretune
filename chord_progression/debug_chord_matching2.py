#!/usr/bin/env python3
"""Debug script to check chord matching logic - part 2."""

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

scale_semitones = LyreChordAnalyzer.MODES[mode]
print(f"Mode: {mode} (C Major)")
print(f"Scale semitones: {scale_semitones}")
print(f"Scale degrees: 0=C, 1=D, 2=E, 3=F, 4=G, 5=A, 6=B")

# IV chord = F A C = degrees [3, 5, 0]
iv_degree = 3
iv_triad_degrees = [(iv_degree + i) % 7 for i in [0, 2, 4]]
print(f"\nIV chord (F major):")
print(f"  Degrees: {iv_triad_degrees} (F, A, C)")

# Get semitones for IV triad
iv_triad_semitones = [scale_semitones[d] for d in iv_triad_degrees]
print(f"  Semitones: {iv_triad_semitones}")

# Adjust for octave (as done in the script)
for i in range(1, 3):
    if iv_triad_semitones[i] < iv_triad_semitones[0]:
        iv_triad_semitones[i] += 12
print(f"  Semitones (adjusted): {iv_triad_semitones}")

# Now let's manually check string combinations for 8-string lyre
print(f"\n8-string lyre string layout:")
for i in range(8):
    pattern_index = i % 7
    octave_offset = i // 7
    degree = pattern_index
    semitone_in_scale = scale_semitones[degree]
    semitone_absolute = semitone_in_scale + (octave_offset * 12)
    freq = analyzer.frequencies[i]
    print(f"  String {i}: degree {degree}, semitone {semitone_absolute:2d}, {freq:.2f} Hz")

# For IV chord (degrees [3, 5, 0]), we need:
# - degree 3 (F) - string 3
# - degree 5 (A) - string 5
# - degree 0 (C) - string 0 OR string 7 (octave)

print(f"\nPossible IV chord voicings:")
print(f"  Root position (F in bass): strings [3, 5, 7] - F(low), A(mid), C(high)")
print(f"  1st inversion (A in bass): strings [5, 7, 3] - A(low), C(mid), F(high)")
print(f"  2nd inversion (C in bass): strings [0, 3, 5] or [7, 3, 5] - C(low), F(mid), A(high)")

# Actually, combinations returns in sorted order,  so let's check what we get
print(f"\nAll 3-string combinations (first 20):")
count = 0
for combo in combinations(range(8), 3):
    degrees = [i % 7 for i in combo]
    if set(degrees) == set([3, 5, 0]):  # IV chord degrees
        freqs = [analyzer.frequencies[i] for i in combo]
        ratios = analyzer.frequencies_to_ratios(freqs)
        bass_deg = combo[0] % 7
        is_root = (bass_deg == 3)  # IV chord root is degree 3
        print(f"  {combo}: degrees {degrees}, ratios {ratios}, {'ROOT' if is_root else 'INVERSION'}")
    count += 1
    if count >= 56:  # C(8,3) = 56
        break
