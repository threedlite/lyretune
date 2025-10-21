#!/usr/bin/env python3
"""
Compare V-I, IV-I and other key progressions on N-string vs M-string lyre.
Analysis focusing on main cadences with proper just intonation handling.
"""

import sys
import argparse
import json
import math
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
    # Convert semitones to ratios using just intonation
    # This matches the analyzer's actual tuning
    scale_ratios = analyzer.frequencies_to_ratios(analyzer.frequencies[:7])

    # Build semitone-to-degree mapping for this mode
    scale_map = {st: deg for deg, st in enumerate(scale_semitones)}

    # Build ratios for the triad
    ratios = []
    for st in triad_semitones:
        # Find the scale degree for this semitone (mod 12 for octave wrapping)
        st_mod = st % 12
        if st_mod in scale_map:
            scale_deg = scale_map[st_mod]
            ratio = scale_ratios[scale_deg]
            # Adjust for octave
            octaves = st // 12
            ratio *= (2 ** octaves)
            ratios.append(ratio)

    return ratios

def analyze_vi_cadence(mode, num_strings=7):
    """Analyze V-I cadence for given string count."""
    
    # Get mode pattern
    scale_semitones = LyreChordAnalyzer.MODES[mode]
    
    # Create chord analyzer with just intonation
    analyzer = LyreChordAnalyzer(
        num_strings=num_strings,
        mode=mode,
        first_note='E',
        temperament='JUST',
        formula='NUMERIC_EMPIRIC_20251018'
    )
    
    # Build string degrees (handles any number of strings correctly)
    string_degrees = []
    for i in range(num_strings):
        pattern_index = i % 7
        string_degrees.append(pattern_index)

    # Find V chord (degree 4) and I chord (degree 0)
    v_degree = 4
    i_degree = 0
    
    # Build triads
    v_triad_degrees = [(v_degree + i) % 7 for i in [0, 2, 4]]
    i_triad_degrees = [(i_degree + i) % 7 for i in [0, 2, 4]]
    
    v_triad_semitones = [scale_semitones[d] for d in v_triad_degrees]
    i_triad_semitones = [scale_semitones[d] for d in i_triad_degrees]
    
    # Adjust for octave
    for i in range(1, 3):
        if v_triad_semitones[i] < v_triad_semitones[0]:
            v_triad_semitones[i] += 12
        if i_triad_semitones[i] < i_triad_semitones[0]:
            i_triad_semitones[i] += 12
    
    # Find best voicings
    v_notes_mod = set([st % 12 for st in v_triad_semitones])
    i_notes_mod = set([st % 12 for st in i_triad_semitones])
    
    v_root_mod = v_triad_semitones[0] % 12
    i_root_mod = i_triad_semitones[0] % 12
    
    # Get expected ratios for V and I chords
    v_expected_ratios = get_chord_ratios(analyzer, v_triad_semitones, scale_semitones)
    i_expected_ratios = get_chord_ratios(analyzer, i_triad_semitones, scale_semitones)

    # Find voicings
    v_voicings = []
    i_voicings = []

    for string_combo in combinations(range(num_strings), 3):
        # Get degrees for this combination
        combo_degrees = [string_degrees[s] for s in string_combo]

        # Get frequencies for this combination
        freqs = [analyzer.frequencies[s] for s in string_combo]
        ratios = analyzer.frequencies_to_ratios(freqs)
        complexity = complexity_with_five_adjustments(ratios, **DEFAULT_PARAMS)

        # Check if matches V chord by degrees (not ratios!)
        if set(combo_degrees) == set(v_triad_degrees):
            bass_degree = string_degrees[string_combo[0]]
            is_root = (bass_degree == v_degree)
            v_voicings.append({
                'strings': string_combo,
                'complexity': complexity,
                'is_root': is_root,
                'ratios': ratios
            })

        # Check if matches I chord by degrees
        if set(combo_degrees) == set(i_triad_degrees):
            bass_degree = string_degrees[string_combo[0]]
            is_root = (bass_degree == i_degree)
            i_voicings.append({
                'strings': string_combo,
                'complexity': complexity,
                'is_root': is_root,
                'ratios': ratios
            })
    
    # Find best V and I voicings
    if v_voicings and i_voicings:
        best_v = min(v_voicings, key=lambda x: x['complexity'])
        best_i = min(i_voicings, key=lambda x: x['complexity'])
        
        # Voice leading distance (count string position changes)
        v_strings = list(best_v['strings'])
        i_strings = list(best_i['strings'])

        # Calculate finger movement distance
        total_movement = 0
        for i in range(3):
            total_movement += abs(v_strings[i] - i_strings[i])

        # Voice leading complexity (penalize large jumps)
        vl_complexity = total_movement * 0.3

        # Common tones bonus
        common = set(v_strings) & set(i_strings)
        vl_complexity -= len(common) * 0.5

        # Root movement bonus (V to I is strong, descending 4th)
        root_movement = -1.5

        # Total progression complexity
        total = best_v['complexity'] + best_i['complexity'] + vl_complexity + root_movement
        
        return {
            'v_complexity': best_v['complexity'],
            'i_complexity': best_i['complexity'],
            'v_root': best_v['is_root'],
            'i_root': best_i['is_root'],
            'v_strings': best_v['strings'],
            'i_strings': best_i['strings'],
            'vl_distance': vl_complexity,
            'total': total,
            'v_voicing_count': len(v_voicings),
            'i_voicing_count': len(i_voicings)
        }
    
    return None

def analyze_ivi_cadence(mode, num_strings=7):
    """Analyze IV-I cadence for given string count."""

    # Get mode pattern
    scale_semitones = LyreChordAnalyzer.MODES[mode]

    # Create chord analyzer with just intonation
    analyzer = LyreChordAnalyzer(
        num_strings=num_strings,
        mode=mode,
        first_note='E',
        temperament='JUST',
        formula='NUMERIC_EMPIRIC_20251018'
    )

    # Build string degrees (handles any number of strings correctly)
    string_degrees = []
    for i in range(num_strings):
        pattern_index = i % 7
        string_degrees.append(pattern_index)

    # Find IV chord (degree 3) and I chord (degree 0)
    iv_degree = 3
    i_degree = 0

    # Build triads
    iv_triad_degrees = [(iv_degree + i) % 7 for i in [0, 2, 4]]
    i_triad_degrees = [(i_degree + i) % 7 for i in [0, 2, 4]]

    iv_triad_semitones = [scale_semitones[d] for d in iv_triad_degrees]
    i_triad_semitones = [scale_semitones[d] for d in i_triad_degrees]

    # Adjust for octave
    for i in range(1, 3):
        if iv_triad_semitones[i] < iv_triad_semitones[0]:
            iv_triad_semitones[i] += 12
        if i_triad_semitones[i] < i_triad_semitones[0]:
            i_triad_semitones[i] += 12

    # Get expected ratios for IV and I chords
    iv_expected_ratios = get_chord_ratios(analyzer, iv_triad_semitones, scale_semitones)
    i_expected_ratios = get_chord_ratios(analyzer, i_triad_semitones, scale_semitones)

    # Find voicings
    iv_voicings = []
    i_voicings = []

    for string_combo in combinations(range(num_strings), 3):
        # Get degrees for this combination
        combo_degrees = [string_degrees[s] for s in string_combo]

        # Get frequencies for this combination
        freqs = [analyzer.frequencies[s] for s in string_combo]
        ratios = analyzer.frequencies_to_ratios(freqs)
        complexity = complexity_with_five_adjustments(ratios, **DEFAULT_PARAMS)

        # Check if matches IV chord by degrees (not ratios!)
        if set(combo_degrees) == set(iv_triad_degrees):
            bass_degree = string_degrees[string_combo[0]]
            is_root = (bass_degree == iv_degree)
            iv_voicings.append({
                'strings': string_combo,
                'complexity': complexity,
                'is_root': is_root,
                'ratios': ratios
            })

        # Check if matches I chord by degrees
        if set(combo_degrees) == set(i_triad_degrees):
            bass_degree = string_degrees[string_combo[0]]
            is_root = (bass_degree == i_degree)
            i_voicings.append({
                'strings': string_combo,
                'complexity': complexity,
                'is_root': is_root,
                'ratios': ratios
            })

    # Find best IV and I voicings
    if iv_voicings and i_voicings:
        best_iv = min(iv_voicings, key=lambda x: x['complexity'])
        best_i = min(i_voicings, key=lambda x: x['complexity'])

        # Voice leading distance (count string position changes)
        iv_strings = list(best_iv['strings'])
        i_strings = list(best_i['strings'])

        # Calculate finger movement distance
        total_movement = 0
        for i in range(3):
            total_movement += abs(iv_strings[i] - i_strings[i])

        # Voice leading complexity (penalize large jumps)
        vl_complexity = total_movement * 0.3

        # Common tones bonus
        common = set(iv_strings) & set(i_strings)
        vl_complexity -= len(common) * 0.5

        # Root movement bonus (IV to I is plagal, ascending 4th)
        root_movement = -1.2  # Slightly less strong than V-I

        # Total progression complexity
        total = best_iv['complexity'] + best_i['complexity'] + vl_complexity + root_movement

        return {
            'iv_complexity': best_iv['complexity'],
            'i_complexity': best_i['complexity'],
            'iv_root': best_iv['is_root'],
            'i_root': best_i['is_root'],
            'iv_strings': best_iv['strings'],
            'i_strings': best_i['strings'],
            'vl_distance': vl_complexity,
            'total': total,
            'iv_voicing_count': len(iv_voicings),
            'i_voicing_count': len(i_voicings)
        }

    return None

def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(description='Compare progressions on N-string vs M-string lyre')
    parser.add_argument('--min-strings', type=int, default=7, help='Minimum string count (default: 7)')
    parser.add_argument('--max-strings', type=int, default=8, help='Maximum string count (default: 8)')
    parser.add_argument('--cadence', choices=['V-I', 'IV-I', 'both'], default='both',
                        help='Which cadence to analyze (default: both)')
    parser.add_argument('--output-format', choices=['text', 'json'], default='text',
                        help='Output format (default: text)')
    parser.add_argument('--modes', nargs='+',
                        default=['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS', 'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS'],
                        help='Modes to analyze')

    args = parser.parse_args()

    min_strings = args.min_strings
    max_strings = args.max_strings
    modes = args.modes
    cadence_type = args.cadence
    output_format = args.output_format

    # Analyze all modes
    results_vi = []
    results_ivi = []

    for mode in modes:
        if cadence_type in ['V-I', 'both']:
            result_min = analyze_vi_cadence(mode, min_strings)
            result_max = analyze_vi_cadence(mode, max_strings)
            results_vi.append({
                'mode': mode,
                f'{min_strings}str': result_min,
                f'{max_strings}str': result_max
            })

        if cadence_type in ['IV-I', 'both']:
            result_min = analyze_ivi_cadence(mode, min_strings)
            result_max = analyze_ivi_cadence(mode, max_strings)
            results_ivi.append({
                'mode': mode,
                f'{min_strings}str': result_min,
                f'{max_strings}str': result_max
            })

    # Output results
    if output_format == 'json':
        output_data = {
            'comparison': f'{min_strings}_vs_{max_strings}_strings',
            'cadences': {}
        }
        if results_vi:
            output_data['cadences']['V-I'] = results_vi
        if results_ivi:
            output_data['cadences']['IV-I'] = results_ivi
        print(json.dumps(output_data, indent=2, default=str))
        return

    # Text output
    if results_vi:
        print("=" * 110)
        print(f"V-I CADENCE: {min_strings}-STRING vs {max_strings}-STRING COMPARISON")
        print("=" * 110)
        print()

        print(f"{'Mode':<15} {f'{min_strings}-str V-I':<12} {f'{max_strings}-str V-I':<12} {'Δ':<10} {f'{min_strings}-str Voicings':<18} {f'{max_strings}-str Voicings':<18}")
        print("-" * 110)

        for r in results_vi:
            r_min = r[f'{min_strings}str']
            r_max = r[f'{max_strings}str']
            if r_min and r_max:
                delta = r_max['total'] - r_min['total']
                delta_str = f"{delta:+.2f}" if delta != 0 else "0.00"

                voicings_min = f"V:{r_min['v_voicing_count']} I:{r_min['i_voicing_count']}"
                voicings_max = f"V:{r_max['v_voicing_count']} I:{r_max['i_voicing_count']}"

                better = "✓" if delta < 0 else ("=" if delta == 0 else "")

                print(f"{r['mode']:<15} {r_min['total']:<12.4f} {r_max['total']:<12.4f} "
                      f"{delta_str:<10} {voicings_min:<18} {voicings_max:<18} {better}")

        print()
        print("=" * 110)
        print("DETAILED V-I BREAKDOWN BY MODE")
        print("=" * 110)

        for r in results_vi:
            r_min = r[f'{min_strings}str']
            r_max = r[f'{max_strings}str']
            if r_min and r_max:
                print(f"\n{r['mode']}:")
                print(f"  {min_strings}-string: V-I = {r_min['total']:.4f}")
                print(f"    V: {r_min['v_complexity']:.4f} ({'root' if r_min['v_root'] else 'inv'}), "
                      f"I: {r_min['i_complexity']:.4f} ({'root' if r_min['i_root'] else 'inv'}), "
                      f"VL: {r_min['vl_distance']:.4f}")
                print(f"    V voicings: {r_min['v_voicing_count']}, I voicings: {r_min['i_voicing_count']}")

                print(f"  {max_strings}-string: V-I = {r_max['total']:.4f}")
                print(f"    V: {r_max['v_complexity']:.4f} ({'root' if r_max['v_root'] else 'inv'}), "
                      f"I: {r_max['i_complexity']:.4f} ({'root' if r_max['i_root'] else 'inv'}), "
                      f"VL: {r_max['vl_distance']:.4f}")
                print(f"    V voicings: {r_max['v_voicing_count']}, I voicings: {r_max['i_voicing_count']}")

                delta = r_max['total'] - r_min['total']
                if delta < -0.1:
                    print(f"  → {max_strings}-string is BETTER by {-delta:.4f} points")
                elif delta > 0.1:
                    print(f"  → {min_strings}-string is BETTER by {delta:.4f} points")
                else:
                    print(f"  → Essentially the SAME")

    if results_ivi:
        print()
        print()
        print("=" * 110)
        print(f"IV-I CADENCE: {min_strings}-STRING vs {max_strings}-STRING COMPARISON")
        print("=" * 110)
        print()

        print(f"{'Mode':<15} {f'{min_strings}-str IV-I':<12} {f'{max_strings}-str IV-I':<12} {'Δ':<10} {f'{min_strings}-str Voicings':<18} {f'{max_strings}-str Voicings':<18}")
        print("-" * 110)

        for r in results_ivi:
            r_min = r[f'{min_strings}str']
            r_max = r[f'{max_strings}str']
            if r_min and r_max:
                delta = r_max['total'] - r_min['total']
                delta_str = f"{delta:+.2f}" if delta != 0 else "0.00"

                voicings_min = f"IV:{r_min['iv_voicing_count']} I:{r_min['i_voicing_count']}"
                voicings_max = f"IV:{r_max['iv_voicing_count']} I:{r_max['i_voicing_count']}"

                better = "✓✓" if delta < -30 else ("✓" if delta < 0 else ("=" if delta == 0 else ""))

                print(f"{r['mode']:<15} {r_min['total']:<12.4f} {r_max['total']:<12.4f} "
                      f"{delta_str:<10} {voicings_min:<18} {voicings_max:<18} {better}")

        print()
        print("=" * 110)
        print("DETAILED IV-I BREAKDOWN BY MODE")
        print("=" * 110)

        for r in results_ivi:
            r_min = r[f'{min_strings}str']
            r_max = r[f'{max_strings}str']
            if r_min and r_max:
                print(f"\n{r['mode']}:")
                print(f"  {min_strings}-string: IV-I = {r_min['total']:.4f}")
                print(f"    IV: {r_min['iv_complexity']:.4f} ({'root' if r_min['iv_root'] else 'inv'}), "
                      f"I: {r_min['i_complexity']:.4f} ({'root' if r_min['i_root'] else 'inv'}), "
                      f"VL: {r_min['vl_distance']:.4f}")
                print(f"    IV voicings: {r_min['iv_voicing_count']}, I voicings: {r_min['i_voicing_count']}")

                print(f"  {max_strings}-string: IV-I = {r_max['total']:.4f}")
                print(f"    IV: {r_max['iv_complexity']:.4f} ({'root' if r_max['iv_root'] else 'inv'}), "
                      f"I: {r_max['i_complexity']:.4f} ({'root' if r_max['i_root'] else 'inv'}), "
                      f"VL: {r_max['vl_distance']:.4f}")
                print(f"    IV voicings: {r_max['iv_voicing_count']}, I voicings: {r_max['i_voicing_count']}")

                delta = r_max['total'] - r_min['total']
                if delta < -0.1:
                    print(f"  → {max_strings}-string is BETTER by {-delta:.4f} points")
                elif delta > 0.1:
                    print(f"  → {min_strings}-string is BETTER by {delta:.4f} points")
                else:
                    print(f"  → Essentially the SAME")

    # Summary
    print()
    print()
    print("=" * 110)
    print("SUMMARY")
    print("=" * 110)
    print()

    if results_vi:
        better_max = sum(1 for r in results_vi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and r[f'{max_strings}str']['total'] < r[f'{min_strings}str']['total'])
        same = sum(1 for r in results_vi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and abs(r[f'{max_strings}str']['total'] - r[f'{min_strings}str']['total']) < 0.1)
        better_min = sum(1 for r in results_vi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and r[f'{min_strings}str']['total'] < r[f'{max_strings}str']['total'])

        print(f"V-I Cadence:")
        print(f"  {max_strings}-string better: {better_max}/{len(modes)} modes")
        print(f"  Same:                {same}/{len(modes)} modes")
        print(f"  {min_strings}-string better: {better_min}/{len(modes)} modes")

        results_with_data_min = [r for r in results_vi if r[f'{min_strings}str']]
        results_with_data_max = [r for r in results_vi if r[f'{max_strings}str']]

        if results_with_data_min and results_with_data_max:
            avg_min = sum(r[f'{min_strings}str']['total'] for r in results_with_data_min) / len(results_with_data_min)
            avg_max = sum(r[f'{max_strings}str']['total'] for r in results_with_data_max) / len(results_with_data_max)

            print(f"  Average V-I complexity:")
            print(f"    {min_strings}-string: {avg_min:.4f}")
            print(f"    {max_strings}-string: {avg_max:.4f}")
            print(f"    Difference: {avg_max - avg_min:+.4f}")
        else:
            print(f"  Warning: No valid V-I progressions found")
        print()

    if results_ivi:
        better_max = sum(1 for r in results_ivi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and r[f'{max_strings}str']['total'] < r[f'{min_strings}str']['total'])
        same = sum(1 for r in results_ivi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and abs(r[f'{max_strings}str']['total'] - r[f'{min_strings}str']['total']) < 0.1)
        better_min = sum(1 for r in results_ivi if r[f'{min_strings}str'] and r[f'{max_strings}str'] and r[f'{min_strings}str']['total'] < r[f'{max_strings}str']['total'])

        print(f"IV-I Cadence:")
        print(f"  {max_strings}-string better: {better_max}/{len(modes)} modes")
        print(f"  Same:                {same}/{len(modes)} modes")
        print(f"  {min_strings}-string better: {better_min}/{len(modes)} modes")

        results_with_data_min = [r for r in results_ivi if r[f'{min_strings}str']]
        results_with_data_max = [r for r in results_ivi if r[f'{max_strings}str']]

        if results_with_data_min and results_with_data_max:
            avg_min = sum(r[f'{min_strings}str']['total'] for r in results_with_data_min) / len(results_with_data_min)
            avg_max = sum(r[f'{max_strings}str']['total'] for r in results_with_data_max) / len(results_with_data_max)

            print(f"  Average IV-I complexity:")
            print(f"    {min_strings}-string: {avg_min:.4f}")
            print(f"    {max_strings}-string: {avg_max:.4f}")
            print(f"    Difference: {avg_max - avg_min:+.4f}")
        else:
            print(f"  Warning: No valid IV-I progressions found")

if __name__ == '__main__':
    main()

