#!/usr/bin/env python3
"""Compare N-string vs M-string lyre for chord availability."""

import sys
import argparse
import json
from pathlib import Path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_chords import LyreChordAnalyzer
from itertools import combinations

def analyze_string_count(mode, num_strings):
    """Analyze chord availability for given string count."""
    
    # Get mode pattern
    scale_semitones = LyreChordAnalyzer.MODES[mode]
    
    # For 8 strings, we add the octave
    if num_strings == 8:
        # String layout: [0, 1, 2, 3, 4, 5, 6, 0+12]
        # The 8th string is the octave of the 1st
        extended_semitones = scale_semitones + [scale_semitones[0] + 12]
        string_degrees = list(range(7)) + [0]  # Last string is degree 0 (octave)
    else:
        extended_semitones = scale_semitones
        string_degrees = list(range(7))
    
    # Build all triads
    triads = []
    for degree in range(7):
        # Get the three notes of the triad (root, third, fifth)
        triad_degrees = [(degree + i) % 7 for i in [0, 2, 4]]
        triad_semitones = [scale_semitones[d] for d in triad_degrees]
        
        # Adjust for octave wrapping
        for i in range(1, 3):
            if triad_semitones[i] < triad_semitones[0]:
                triad_semitones[i] += 12
        
        # Determine quality
        third_interval = triad_semitones[1] - triad_semitones[0]
        fifth_interval = triad_semitones[2] - triad_semitones[0]
        
        quality_map = {
            (4, 7): 'maj',
            (3, 7): 'min',
            (3, 6): 'dim',
            (4, 8): 'aug',
        }
        quality = quality_map.get((third_interval, fifth_interval), 'unk')
        
        triads.append({
            'degree': degree,
            'quality': quality,
            'semitones': triad_semitones,
            'root_voicings': [],
            'inv_voicings': []
        })
    
    # Find voicings for each triad
    for triad in triads:
        triad_notes_mod = [(st % 12) for st in triad['semitones']]
        root_mod = triad['semitones'][0] % 12
        
        # Try all 3-string combinations
        for string_combo in combinations(range(num_strings), 3):
            # Get the scale degrees and semitones for these strings
            played_degrees = [string_degrees[s] for s in string_combo]
            played_semitones = [extended_semitones[s] for s in string_combo]
            
            # Check if this matches the triad (ignoring octaves)
            played_notes_mod = [(st % 12) for st in played_semitones]
            
            if set(played_notes_mod) == set(triad_notes_mod):
                # This is a valid voicing!
                bass_note = played_semitones[0] % 12
                
                if bass_note == root_mod:
                    triad['root_voicings'].append(list(string_combo))
                else:
                    triad['inv_voicings'].append(list(string_combo))
    
    return triads

def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(description='Compare N-string vs M-string lyre for chord availability')
    parser.add_argument('--min-strings', type=int, default=7, help='Minimum string count (default: 7)')
    parser.add_argument('--max-strings', type=int, default=8, help='Maximum string count (default: 8)')
    parser.add_argument('--output-format', choices=['text', 'json', 'csv'], default='text',
                        help='Output format (default: text)')
    parser.add_argument('--modes', nargs='+',
                        default=['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS', 'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS'],
                        help='Modes to analyze')

    args = parser.parse_args()

    min_strings = args.min_strings
    max_strings = args.max_strings
    modes = args.modes
    output_format = args.output_format

    if output_format == 'text':
        print("=" * 100)
        print(f"{min_strings}-STRING vs {max_strings}-STRING LYRE COMPARISON")
        print("=" * 100)
        print()

    summary = []

    for mode in modes:
        triads_min = analyze_string_count(mode, min_strings)
        triads_max = analyze_string_count(mode, max_strings)

        # Count root position availability
        root_min = sum(1 for t in triads_min if len(t['root_voicings']) > 0)
        root_max = sum(1 for t in triads_max if len(t['root_voicings']) > 0)

        # Count total voicings
        total_voicings_min = sum(len(t['root_voicings']) + len(t['inv_voicings']) for t in triads_min)
        total_voicings_max = sum(len(t['root_voicings']) + len(t['inv_voicings']) for t in triads_max)

        summary.append({
            'mode': mode,
            f'root_{min_strings}': root_min,
            f'root_{max_strings}': root_max,
            f'voicings_{min_strings}': total_voicings_min,
            f'voicings_{max_strings}': total_voicings_max,
            f'triads_{min_strings}': triads_min,
            f'triads_{max_strings}': triads_max
        })

        if output_format == 'text':
            print(f"\n{mode}")
            print("-" * 100)
            print(f"Root position triads: {min_strings}-string: {root_min}/7  |  {max_strings}-string: {root_max}/7")
            print(f"Total voicings:       {min_strings}-string: {total_voicings_min}  |  {max_strings}-string: {total_voicings_max}")

            # Show which triads gain root position
            gained_root = []
            for i, (t_min, t_max) in enumerate(zip(triads_min, triads_max)):
                if len(t_min['root_voicings']) == 0 and len(t_max['root_voicings']) > 0:
                    roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][i]
                    if t_max['quality'] == 'min':
                        roman = roman.lower()
                    elif t_max['quality'] == 'dim':
                        roman = roman.lower() + '°'
                    gained_root.append(f"{roman} ({t_max['quality']})")

            if gained_root:
                print(f"Gained root position: {', '.join(gained_root)}")
            else:
                print(f"Gained root position: None")

    # Output results based on format
    if output_format == 'json':
        # JSON output
        output_data = {
            'comparison': f'{min_strings}_vs_{max_strings}_strings',
            'modes': []
        }
        for s in summary:
            mode_data = {
                'mode': s['mode'],
                'root_position': {
                    f'{min_strings}_string': s[f'root_{min_strings}'],
                    f'{max_strings}_string': s[f'root_{max_strings}'],
                    'gain': s[f'root_{max_strings}'] - s[f'root_{min_strings}']
                },
                'total_voicings': {
                    f'{min_strings}_string': s[f'voicings_{min_strings}'],
                    f'{max_strings}_string': s[f'voicings_{max_strings}'],
                    'gain': s[f'voicings_{max_strings}'] - s[f'voicings_{min_strings}']
                }
            }
            output_data['modes'].append(mode_data)

        print(json.dumps(output_data, indent=2))

    elif output_format == 'csv':
        # CSV output
        print(f"Mode,{min_strings}str_Root,{max_strings}str_Root,Root_Gain,{min_strings}str_Voicings,{max_strings}str_Voicings,Voicing_Gain")
        for s in summary:
            gain = s[f'root_{max_strings}'] - s[f'root_{min_strings}']
            voicing_gain = s[f'voicings_{max_strings}'] - s[f'voicings_{min_strings}']
            print(f"{s['mode']},{s[f'root_{min_strings}']},{s[f'root_{max_strings}']},{gain},{s[f'voicings_{min_strings}']},{s[f'voicings_{max_strings}']},{voicing_gain}")

    else:  # text format
        # Summary table
        print()
        print()
        print("=" * 100)
        print("SUMMARY TABLE")
        print("=" * 100)
        print()
        print(f"{'Mode':<15} {f'{min_strings}-str Root':<12} {f'{max_strings}-str Root':<12} {'Gain':<8} {f'{min_strings}-str Voicings':<18} {f'{max_strings}-str Voicings':<18}")
        print("-" * 100)

        for s in summary:
            gain = s[f'root_{max_strings}'] - s[f'root_{min_strings}']
            gain_str = f"+{gain}" if gain > 0 else str(gain)
            voicing_gain = s[f'voicings_{max_strings}'] - s[f'voicings_{min_strings}']

            print(f"{s['mode']:<15} {s[f'root_{min_strings}']}/7{'':>7} {s[f'root_{max_strings}']}/7{'':>7} {gain_str:<8} "
                  f"{s[f'voicings_{min_strings}']:<18} {s[f'voicings_{max_strings}']:<18} (+{voicing_gain})")

        print()
        print()
        print("=" * 100)
        print("KEY INSIGHTS")
        print("=" * 100)
        print()

        # Calculate overall statistics
        total_root_min = sum(s[f'root_{min_strings}'] for s in summary)
        total_root_max = sum(s[f'root_{max_strings}'] for s in summary)
        total_voicings_min = sum(s[f'voicings_{min_strings}'] for s in summary)
        total_voicings_max = sum(s[f'voicings_{max_strings}'] for s in summary)

        num_modes = len(modes)
        total_triads = num_modes * 7

        print(f"Across all {num_modes} modes:")
        print(f"  Total root position triads: {min_strings}-string: {total_root_min}/{total_triads}  |  {max_strings}-string: {total_root_max}/{total_triads}")
        print(f"  Total voicings available:   {min_strings}-string: {total_voicings_min}  |  {max_strings}-string: {total_voicings_max}")
        print(f"  Average root position:      {min_strings}-string: {total_root_min/num_modes:.1f}/7  |  {max_strings}-string: {total_root_max/num_modes:.1f}/7")
        print()

        # Check if any mode gets all 7 in root position
        all_root = [s['mode'] for s in summary if s[f'root_{max_strings}'] == 7]
        if all_root:
            print(f"Modes with ALL triads in root position ({max_strings}-string): {', '.join(all_root)}")
        else:
            print(f"No mode achieves all 7 triads in root position even with {max_strings} strings")

        print()
        print("Voicing increase per mode:")
        avg_increase = (total_voicings_max - total_voicings_min) / num_modes
        print(f"  Average: +{avg_increase:.1f} voicings per mode")
        print(f"  Total increase: +{total_voicings_max - total_voicings_min} voicings across all modes")

if __name__ == '__main__':
    main()

