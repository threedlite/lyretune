# Chord Progression Analysis for 7-String Lyre

This folder contains tools and analysis for chord progressions on a 7-string lyre tuned to ancient Greek modes.

**IMPORTANT:** This analysis uses **JUST INTONATION** (pure integer frequency ratios), not equal temperament. This is critical for accurate consonance analysis on a lyre.

## Files

### Analysis Tool
- **analyze_lyre_progressions.py** - Main analysis script that generates all possible chord progressions for each mode, ranks them by complexity, and identifies common progressions.

### Analysis Results
- **lyre_progression_analysis.txt** - Complete analysis of all 7 modes using JUST INTONATION (current version)
- **lyre_progression_analysis_OLD_EQUAL_TEMPERAMENT.txt** - Original analysis using equal temperament (INCORRECT - for reference only)

### Documentation
- **COMPREHENSIVE_THEORY_VERIFICATION.md** - **[READ THIS FIRST]** Complete verification against traditional music theory (descending 5ths, circle of fifths, cadence strength, root movement, etc.)
- **THEORY_VERIFICATION_JUST_INTONATION.md** - V-I vs I-V relationship verification across all modes
- **MODE_CHARACTERISTICS_SUMMARY.md** - Summary of each mode's harmonic characteristics, best progressions, and musical character
- **TRADITIONAL_RELATIONSHIPS_VERIFIED.md** - Original verification (outdated - based on equal temperament)
- **THEORY_VERIFICATION_REPORT.md** - Original theory report (outdated - based on equal temperament)
- **CHANGELOG_PROGRESSIONS.md** - Technical changelog documenting bug fixes (just intonation, root movement scoring)

## Quick Start

### Run the Analysis
```bash
# From the chord_progression directory:
cd chord_progression
source ../venv/bin/activate
python analyze_lyre_progressions.py --output my_analysis.txt

# Or from the parent directory:
source venv/bin/activate
python chord_progression/analyze_lyre_progressions.py --output my_analysis.txt
```

### Analyze a Specific Mode
```bash
cd chord_progression
python analyze_lyre_progressions.py --mode LYDIOS --output lydios_only.txt
```

### Command Line Options
```
--mode MODE       Analyze specific mode (DORIOS, PHRYGIOS, LYDIOS, etc.)
--output FILE     Output file path (default: lyre_progression_analysis.txt)
```

## What It Does

The analysis:
1. **Generates all triads** for each mode (major, minor, diminished)
2. **Identifies voicings** (root position vs inversions) based on string layout
3. **Creates all possible progressions** (2-chord, 3-chord, 4-chord)
4. **Ranks by complexity** using:
   - Individual chord consonance (harmonic complexity formula)
   - Voice leading smoothness (string distance)
   - Root movement strength (descending 5th = strongest)
   - Voicing quality (root position preferred)
5. **Identifies common progressions** (V-I, I-V, ii-V-I, I-V-vi-IV, etc.)

## Key Findings

### Best Modes for Tonal Harmony
- **LYDIOS** (Modern Major) - Major I and V chords
- **HYPOLYDIOS** (Modern Lydian) - Major I and V chords
- **MIXOLYDIOS** (Modern Locrian) - Strongest V-I despite diminished tonic!

### Best Modes for Modal Music
- **HYPODORIOS** (Natural Minor) - Pure Aeolian
- **PHRYGIOS** (Modern Dorian) - Bright minor
- **HYPOPHRYGIOS** (Modern Mixolydian) - Major with b7

### Surprising Discovery
**V-vi (Deceptive Cadence)** often ranks stronger than V-I due to exceptional voice leading on the lyre (complexity ~98-104 vs 134-140).

### All Modes Verified
V-I is consistently stronger than I-V across all 7 modes (1.2-1.5 point difference).

## Theory Validation

All traditional music theory relationships verified:
- ✓ V→I stronger than I→V
- ✓ Descending 5th > Ascending 5th
- ✓ Circle of fifths direction matters
- ✓ IV→V stronger than V→IV
- ✓ Root movement hierarchy matches theory

See **TRADITIONAL_RELATIONSHIPS_VERIFIED.md** for complete verification.

## Background

The 7-string lyre with diatonic tuning has unique constraints:
- Only 3/7 triads available in root position
- V chord typically requires inversion
- V chord quality varies by mode (major/minor/diminished)
- Voice leading limited by string layout

These constraints mean some traditional progressions work better than others, and the analysis correctly identifies which progressions are most playable on the instrument.

## Important: Just Intonation vs Equal Temperament

**Version 3 (2025-10-20): Critical Fix Applied**

The analysis now uses **just intonation** (pure integer frequency ratios) instead of equal temperament. This change had a dramatic impact:

- **Complexity scores dropped 8-10x** for consonant chords
- Major triads (4:5:6 ratio) now show as perfectly simple
- Rankings are now accurate for actual lyre acoustics

**Example changes:**
- LYDIOS V-I cadence: 134.8 → 15.7 complexity
- DORIOS v°-i cadence: ~134 → 68.9 complexity

The old equal-temperament analysis is preserved in `lyre_progression_analysis_OLD_EQUAL_TEMPERAMENT.txt` for reference, but should not be used.

## References

The complexity formula is based on:
- Harmonic consonance (odd limit, largest prime factor)
- Voice leading principles
- Traditional root movement strength
- Voicing quality (inversions vs root position)

Validated against:
- Piston's "Harmony"
- Kostka & Payne "Tonal Harmony"
- Schoenberg "Structural Functions of Harmony"
