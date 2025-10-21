#!/usr/bin/env python3
"""Quick comparison of 7-string vs 8-string lyre capabilities."""

import sys
from pathlib import Path

parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_progressions import LyreProgressionAnalyzer

def compare_configurations():
    """Compare 7 vs 8 string lyres."""

    print("="*80)
    print("7-STRING vs 8-STRING LYRE COMPARISON (DORIOS MODE)")
    print("="*80)
    print()

    for num_strings in [7, 8]:
        print(f"\n{'='*80}")
        print(f"{num_strings}-STRING LYRE")
        print(f"{'='*80}\n")

        analyzer = LyreProgressionAnalyzer('DORIOS', num_strings=num_strings)

        # Show voicings
        print("Voicing Options:")
        for triad in analyzer.triads:
            voicings = analyzer.voicings[triad.root_degree]
            if voicings:
                root_voicings = [v for v in voicings if v.inversion == 'root']
                inv_voicings = [v for v in voicings if v.inversion != 'root']

                print(f"  {str(triad):>6}: ", end='')
                if root_voicings:
                    print(f"Root: {root_voicings[0]}", end='')
                    if inv_voicings:
                        print(f" + {len(inv_voicings)} inversion(s)", end='')
                else:
                    print(f"Inversions only: {inv_voicings[0]}", end='')
                    if len(inv_voicings) > 1:
                        print(f" + {len(inv_voicings)-1} more", end='')
                print()

        # Generate progressions
        progressions = analyzer.generate_progressions(min_length=2, max_length=4, max_results=20)

        print("\nTop 5 Progressions by Length:")
        for length in [2, 3, 4]:
            if length in progressions and progressions[length]:
                print(f"\n  {length}-chord progressions:")
                for i, prog in enumerate(progressions[length][:5], 1):
                    identified = analyzer.identify_common_progressions({length: [prog]})[length][0]
                    common = identified['common_name']
                    common_str = f" ({common})" if common else ""
                    print(f"    {i}. {prog['functional']:<20} "
                          f"complexity: {prog['complexity']:>7.4f}{common_str}")

    print("\n" + "="*80)
    print("KEY INSIGHTS")
    print("="*80)
    print("""
7-STRING LYRE (Traditional):
  • Only I, II, III triads have root position voicings
  • IV, V, VI, VII require inversions (less stable sound)
  • Limited voicing options (exactly 1 per triad)
  • Minimum functional configuration

8-STRING LYRE (Complete Octave):
  • More triads with root position options
  • Tonic (I) has 2 voicing choices for better voice leading
  • Subdominant (IV) gains root position voicing
  • Generally lower complexity scores (smoother progressions)
  • Recommended for harmonic flexibility

RECOMMENDATION: 8-string configuration provides significantly better
harmonic possibilities while maintaining playability.
""")

if __name__ == "__main__":
    compare_configurations()
