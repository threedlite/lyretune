# Final String Range Configuration: 4-13 Strings

## Summary

The lyre chord progression analyzer now supports **4-13 strings** with proper validation and informative error messages.

## Why 4-13 Strings?

### Minimum: 4 Strings
- **Allows analysis to run** even with limited triad voicings
- **Informative output**: Shows which triads (if any) can be formed
- **Educational value**: Demonstrates the limitations of fewer strings
- **Practical use**: Some simple 2-note chords (dyads) may still be playable

**Note**: With 4-5 strings, you'll get very few or no complete triad voicings:
- 4 strings covers 4 scale degrees (0-3), missing the 5-degree span needed for most triads
- 5 strings covers 5 degrees (0-4), can form ~1 triad
- 6 strings covers 6 degrees (0-5), can form multiple triads and progressions ✓
- **6+ strings recommended** for meaningful chord progression analysis

### Maximum: 13 Strings
- Nearly **two full octaves** (7 + 6 strings)
- Provides **extensive harmonic possibilities**
- **Many voicing options** for each triad (root position + inversions)
- Remains **manageable** for analysis

## What Happens with Different String Counts

| Strings | Coverage | Complete Triads | Progressions | Notes |
|---------|----------|-----------------|--------------|-------|
| 3 | 3 degrees | ❌ Rejected | ❌ | Only dyads possible |
| 4 | 4 degrees | ⚠️ Very few/none | ⚠️ Unlikely | Analysis runs but limited |
| 5 | 5 degrees | ⚠️ ~1 triad | ⚠️ Very limited | Minimal progressions |
| 6 | 6 degrees | ✓ Multiple | ✓ Yes | First practical minimum |
| 7 | 7 degrees (full scale) | ✓✓ All triads | ✓✓ Many | **Recommended standard** |
| 8-13 | 1-2 octaves | ✓✓✓ Many voicings | ✓✓✓ Extensive | Advanced options |

## Example Outputs

### 4-String Lyre (Limited)
```bash
$ venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 4 --mode LYDIOS
```
Output shows:
- All 7 triads listed
- **Root position: NONE** for all triads
- **No progressions found**
- Summary: "Triads available in root position: 0/7"

This is **informative** - it shows the user why 4 strings isn't enough.

### 7-String Lyre (Standard)
```bash
$ venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 7 --mode DORIOS
```
Output shows:
- Most triads have root position voicings
- Many 2, 3, and 4-chord progressions found
- Common progressions identified (V-I, I-V, etc.)

### 13-String Lyre (Extended)
```bash
$ venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 13 --mode PHRYGIOS
```
Output shows:
- Multiple voicings per triad (root + inversions across octaves)
- Extensive progression options
- Voicings using strings 1-13

## Error Messages

### Too Few Strings
```bash
$ venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 3 --mode DORIOS
Error: num_strings must be at least 4 for triad analysis
       (With fewer strings, only dyads/2-note chords are possible)
```

### Too Many Strings
```bash
$ venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 14 --mode DORIOS
Error: num_strings cannot exceed 13 (requested 14)
```

## Test Coverage

All edge cases tested:
```
✓ 4-string lyre (min): PASS - Analysis runs, shows limitations
✓ 7-string lyre: PASS - Standard configuration works
✓ 8-string lyre: PASS - Octave wrapping works
✓ 13-string lyre (max): PASS - Maximum configuration works
✓ Too few strings (3): PASS - Clear error message
✓ Too many strings (14): PASS - Clear error message
✓ Frequency validation: PASS - Index bounds checking
```

## Code Constants

Located in `analyze_lyre_progressions.py` lines 71-76:

```python
# Minimum and maximum strings supported
# Note: 4 strings is the minimum to attempt triad analysis. With fewer strings,
# you can only form dyads (2-note chords). With 4-5 strings, very few complete
# triads will be available. 6+ strings recommended for chord progressions.
MIN_STRINGS_FOR_TRIADS = 4
MAX_STRINGS_SUPPORTED = 13
```

## Recommendations for Users

- **4-5 strings**: Analysis will run but expect limited/no results. Good for understanding limitations.
- **6 strings**: Minimum for practical chord progressions
- **7 strings**: Recommended standard (full diatonic scale)
- **8-13 strings**: Advanced configurations with more voicing options

## Music Theory Rationale

**Why triads need 5+ degrees:**
- A triad consists of: root (degree 0), third (degree +2), fifth (degree +4)
- This requires a span of 5 scale degrees: 0, 1, 2, 3, 4
- With only 4 strings covering degrees 0-3, you can't reach degree 4
- Example in LYDIOS [0,2,4,5,7,9,11]:
  - 4 strings give semitones: 0, 2, 4, 5
  - Triad I needs semitones: 0, 4, 7 (missing the 7!)

**Why 6 strings is the practical minimum:**
- 6 strings cover degrees 0-5
- This allows multiple triads to be formed
- Enough variety for basic progressions
- Trade-off between completeness and practicality

## Future Adjustments

To change the supported range, modify lines 75-76 in `analyze_lyre_progressions.py`:
```python
MIN_STRINGS_FOR_TRIADS = 4  # Change this
MAX_STRINGS_SUPPORTED = 13  # Or this
```

Then run the test suite to verify:
```bash
venv/bin/python chord_progression/test_octave_wrapping_fix.py
```
