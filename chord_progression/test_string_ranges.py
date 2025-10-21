#!/usr/bin/env python3
"""Test analyze_lyre_progressions.py with various string counts."""

import sys
from pathlib import Path

# Add parent directory to path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from analyze_lyre_progressions import LyreProgressionAnalyzer

def test_string_count(num_strings, mode='DORIOS'):
    """Test a specific string count."""
    print(f"\n{'='*80}")
    print(f"Testing {num_strings}-string lyre in {mode} mode")
    print(f"{'='*80}")

    try:
        analyzer = LyreProgressionAnalyzer(mode, num_strings=num_strings)

        # Check basic properties
        print(f"✓ Analyzer created successfully")
        print(f"  - Interval pattern: {analyzer.interval_pattern}")
        print(f"  - Number of triads: {len(analyzer.triads)}")

        # Check voicings
        total_voicings = sum(len(v) for v in analyzer.voicings.values())
        print(f"  - Total voicings available: {total_voicings}")

        voicing_stats = {}
        for triad in analyzer.triads:
            voicings = analyzer.voicings[triad.root_degree]
            root_count = len([v for v in voicings if v.inversion == 'root'])
            inv_count = len(voicings) - root_count
            voicing_stats[str(triad)] = {
                'total': len(voicings),
                'root': root_count,
                'inversions': inv_count
            }

        print(f"\n  Voicings by triad:")
        for triad_name, stats in voicing_stats.items():
            print(f"    {triad_name:>6}: {stats['total']:>3} total "
                  f"({stats['root']:>2} root, {stats['inversions']:>2} inversions)")

        # Generate progressions (limited results for speed)
        print(f"\n  Generating progressions...")
        progressions = analyzer.generate_progressions(
            min_length=2,
            max_length=3,
            max_results=10
        )

        for length, progs in progressions.items():
            if progs:
                print(f"    {length}-chord: {len(progs)} progressions found")
                print(f"      Best: {progs[0]['functional']} (complexity: {progs[0]['complexity']:.4f})")
            else:
                print(f"    {length}-chord: No progressions found")

        print(f"\n✓ Test PASSED for {num_strings} strings")
        return True

    except ValueError as e:
        print(f"✗ ValueError: {e}")
        return False
    except Exception as e:
        print(f"✗ Unexpected error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run tests with various string counts."""
    print("="*80)
    print("TESTING LYRE PROGRESSION ANALYZER WITH VARIOUS STRING COUNTS")
    print("="*80)

    test_cases = [
        # (num_strings, should_succeed)
        (2, False),   # Too few strings - should fail
        (3, True),    # Minimum valid
        (4, True),    # Small lyre
        (7, True),    # Traditional 7-string lyre
        (8, True),    # Complete octave
        (10, True),   # Extended range
        (12, True),   # Two octaves (minus 2)
        (14, True),   # Two full octaves
    ]

    results = {}

    for num_strings, should_succeed in test_cases:
        succeeded = test_string_count(num_strings)
        results[num_strings] = succeeded

        # Verify expectation
        if succeeded == should_succeed:
            print(f"✓ Expected result for {num_strings} strings")
        else:
            print(f"✗ UNEXPECTED result for {num_strings} strings "
                  f"(expected {'success' if should_succeed else 'failure'})")

    # Summary
    print(f"\n\n{'='*80}")
    print("SUMMARY")
    print(f"{'='*80}")

    passed = sum(1 for success in results.values() if success)
    total = len(results)

    print(f"\nTests passed: {passed}/{total}")
    print(f"\nResults by string count:")
    for num_strings, succeeded in results.items():
        status = "✓ PASS" if succeeded else "✗ FAIL"
        print(f"  {num_strings:>2} strings: {status}")

    # Test different modes with standard 7 strings
    print(f"\n\n{'='*80}")
    print("TESTING ALL MODES WITH 7 STRINGS")
    print(f"{'='*80}")

    modes = ['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS',
             'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS']

    mode_results = {}
    for mode in modes:
        print(f"\nTesting {mode}...")
        try:
            analyzer = LyreProgressionAnalyzer(mode, num_strings=7)
            progressions = analyzer.generate_progressions(min_length=2, max_length=2, max_results=5)
            total_voicings = sum(len(v) for v in analyzer.voicings.values())
            print(f"  ✓ {mode}: {total_voicings} voicings, {len(progressions.get(2, []))} 2-chord progressions")
            mode_results[mode] = True
        except Exception as e:
            print(f"  ✗ {mode}: {e}")
            mode_results[mode] = False

    modes_passed = sum(1 for success in mode_results.values() if success)
    print(f"\nModes passed: {modes_passed}/{len(modes)}")

    return all(results.values()) and all(mode_results.values())

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
