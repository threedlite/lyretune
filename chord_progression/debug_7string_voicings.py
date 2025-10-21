#!/usr/bin/env python3
"""Debug script to check 7-string IV voicings."""

import sys
from pathlib import Path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_chords import LyreChordAnalyzer
from run_all_consonance_tests import complexity_with_five_adjustments
from itertools import combinations

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

# Test with LYDIOS (C major) - 7 strings
mode = 'LYDIOS'
num_strings = 7

analyzer = LyreChordAnalyzer(
    num_strings=num_strings,
    mode=mode,
    first_note='E',
    temperament='JUST',
    formula='NUMERIC_EMPIRIC_20251018'
)

scale_semitones = LyreChordAnalyzer.MODES[mode]
string_degrees = [i % 7 for i in range(num_strings)]

# IV chord = degree 3
iv_degree = 3
iv_triad_degrees = [(iv_degree + i) % 7 for i in [0, 2, 4]]

print(f"Mode: {mode} (C Major) - 7 STRINGS")
print(f"IV chord degrees: {iv_triad_degrees} (F, A, C)")
print(f"\nAll IV chord voicings:")

for combo in combinations(range(num_strings), 3):
    combo_degrees = [string_degrees[s] for s in combo]
    if set(combo_degrees) == set(iv_triad_degrees):
        freqs = [analyzer.frequencies[s] for s in combo]
        ratios = analyzer.frequencies_to_ratios(freqs)
        complexity = complexity_with_five_adjustments(ratios, **DEFAULT_PARAMS)
        bass_degree = string_degrees[combo[0]]
        is_root = (bass_degree == iv_degree)
        print(f"  Strings {combo}: degrees {combo_degrees}, ratios {ratios}, "
              f"complexity {complexity:.4f}, {'ROOT' if is_root else 'INV'}")
