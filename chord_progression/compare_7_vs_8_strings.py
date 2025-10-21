#!/usr/bin/env python3
"""
Compare 7-string vs 8-string lyre analysis results.
"""

print("=" * 80)
print("7-STRING vs 8-STRING LYRE COMPARISON")
print("=" * 80)
print()

print("PHYSICAL DIFFERENCES")
print("-" * 80)
print("7-string lyre:")
print("  • Covers exactly one octave (7 scale degrees)")
print("  • String 7 is NOT an octave of string 1")
print("  • Maximum span: 10 semitones (in DORIOS: 0 to 10)")
print()
print("8-string lyre:")
print("  • Covers one full octave + 1 note")
print("  • String 8 IS an octave of string 1 (12 semitones higher)")
print("  • Maximum span: 12 semitones (perfect octave)")
print()

print("CHORD AVAILABILITY (DORIOS MODE)")
print("-" * 80)

# Data from the analysis files
comparison = {
    "Dyads in root position": ("5/7", "6/7"),
    "Triads in root position": ("3/7", "4/7"),
    "Tetrads available": ("Yes (7)", "No"),
}

print(f"{'Feature':<30} {'7-string':<15} {'8-string':<15}")
print("-" * 80)
for feature, (seven, eight) in comparison.items():
    print(f"{feature:<30} {seven:<15} {eight:<15}")

print()
print("KEY DIFFERENCES:")
print("-" * 80)
print()

print("1. ROOT POSITION AVAILABILITY")
print("   7-string: Some chords only available as inversions")
print("   8-string: More chords available in root position due to octave")
print()
print("   Example in DORIOS:")
print("   • iv chord (minor on degree IV):")
print("     - 7-string: Only iv⁶₄[1,4,6] (2nd inversion)")
print("     - 8-string: Has iv[4,6,8] (root position!) ✓")
print()

print("2. TETRAD (7th CHORD) AVAILABILITY")
print("   7-string: ✓ Can play tetrads (uses 4 of 7 strings)")
print("             - i7[1,3,5,7] = minor 7th")
print("             - IImaj7, III7, iv7, vø7, VImaj7, vii7")
print()
print("   8-string: ✗ Tetrads disabled (performance constraint)")
print("             - Would take too long to compute all combinations")
print()

print("3. VOICING FLEXIBILITY")
print("   7-string: More constrained voicings")
print("             - Some chords unreachable in root position")
print()
print("   8-string: Greater voicing options")
print("             - Octave doubling available")
print("             - Better voice leading possibilities")
print()

print("4. PROGRESSION QUALITY")
print("   7-string:")
print("     Top 2-chord: III-M3 - I-m3 [3,5] → [1,3]")
print("     Complexity: 6.2870")
print()
print("   8-string:")
print("     Top 2-chord: IV-m3 - II-M3 [4,6] → [2,4]")
print("     Complexity: 6.2870 (same!)")
print()
print("   Both have equivalent top progressions in terms of consonance.")
print()

print("5. MUSICAL TRADE-OFFS")
print("   7-string:")
print("     ✓ Can play 7th chords (tetrads)")
print("     ✓ More jazz/complex harmony available")
print("     ✗ Fewer root position chords")
print("     ✗ More inversions required")
print()
print("   8-string:")
print("     ✓ More root position chords")
print("     ✓ Octave completion (better for melody)")
print("     ✓ Better voice leading (more string options)")
print("     ✗ No 7th chords (by design/performance)")
print()

print("=" * 80)
print("RECOMMENDATION")
print("=" * 80)
print()
print("Use 7 strings if:")
print("  • You want 7th chord voicings (jazz, complex harmony)")
print("  • You're comfortable with inversions")
print("  • Traditional lyre configuration")
print()
print("Use 8 strings if:")
print("  • You want more root position chords")
print("  • You need octave completion for melodies")
print("  • You prefer simpler triadic harmony")
print("  • Better for beginners (more straightforward voicings)")
print()
