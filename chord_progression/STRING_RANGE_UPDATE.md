# String Range Update Summary

## Changes Made

Updated `analyze_lyre_progressions.py` to support lyres with **4-13 strings** (previously 3-20).

## Modified Files

### 1. `analyze_lyre_progressions.py`
- **Lines 71-73**: Added centralized constants
  ```python
  MIN_STRINGS_FOR_TRIADS = 4
  MAX_STRINGS_SUPPORTED = 13
  ```

- **Lines 229-237**: Added validation in `LyreProgressionAnalyzer.__init__()`
  - Validates minimum string count (≥ 4)
  - Validates maximum string count (≤ 13)
  - Raises `ValueError` with clear messages for invalid inputs

- **Lines 254-259**: Frequency count validation
  - Ensures `LyreChordAnalyzer` returns exactly `num_strings` frequencies
  - Prevents index errors downstream

- **Lines 420-425**: Index bounds checking in complexity calculation
  - Validates all string indices before accessing frequency array
  - Provides detailed error messages if voicings are invalid

- **Lines 806-812**: CLI argument validation
  - Validates `--num-strings` parameter before processing
  - Exits with clear error messages for invalid inputs

- **Line 800**: Updated help text
  ```python
  help=f'Number of strings on the lyre (default: 7, range: {MIN_STRINGS_FOR_TRIADS}-{MAX_STRINGS_SUPPORTED})'
  ```

### 2. `test_octave_wrapping_fix.py`
- Added test for minimum 4-string configuration
- Added test for maximum 13-string configuration
- Updated test for too few strings (now tests 3 strings)
- Added test for too many strings (now tests 14 strings)
- All 7 tests pass successfully

### 3. `OCTAVE_WRAPPING_FIXES.md`
- Updated documentation to reflect 4-13 string range
- Added detailed explanations of all validation layers
- Updated example usage and test results

## Validation Layers

The code now validates string count at **three levels**:

1. **Class Level** (`LyreProgressionAnalyzer.__init__()`)
   - Validates range when creating analyzer instance
   - Used by both CLI and programmatic usage

2. **CLI Level** (`main()`)
   - Validates before creating analyzer
   - Provides user-friendly error messages

3. **Runtime Level** (during complexity calculation)
   - Validates actual string indices used in voicings
   - Catches any bugs in voicing generation logic

## Test Results

All tests pass with the new 4-13 range:

```
✓ 4-string lyre (min): PASS
✓ 7-string lyre: PASS
✓ 8-string lyre: PASS
✓ 13-string lyre (max): PASS
✓ Too few strings (3): PASS
✓ Too many strings (14): PASS
✓ Frequency validation: PASS
```

## Example Usage

```bash
# Valid configurations
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 4 --mode DORIOS
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 7 --mode DORIOS
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 13 --mode DORIOS

# Invalid configurations (rejected with clear errors)
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 3 --mode DORIOS
# Error: num_strings must be at least 4 to form triads

venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 14 --mode DORIOS
# Error: num_strings cannot exceed 13 (requested 14)
```

## Verified Features

✅ **4-string lyre**: Works, though limited voicing options (only inversions available)
✅ **7-string lyre**: Standard configuration, all triads have root position voicings
✅ **8-string lyre**: Extended range with octave wrapping
✅ **13-string lyre**: Maximum configuration, many voicing options per triad
✅ **Octave wrapping**: String i plays degree (i % 7) at octave (i // 7)
✅ **Error handling**: Clear messages for all invalid inputs
✅ **Boundary validation**: All three validation layers working correctly

## Rationale for 4-13 Range

- **Minimum (4 strings)**: Technically only 3 strings needed for triads, but 4 provides more voicing options and is more practical for chord progressions
- **Maximum (13 strings)**: Nearly two full octaves (7 + 6), provides extensive harmonic possibilities while remaining manageable

## Backward Compatibility

- Default remains 7 strings (most common ancient Greek lyre configuration)
- Existing scripts using 4-13 strings will continue to work
- Scripts using < 4 or > 13 strings will now fail with clear error messages (previously may have caused cryptic errors)

## Future Enhancements

If the range needs adjustment in the future:
1. Update `MIN_STRINGS_FOR_TRIADS` and/or `MAX_STRINGS_SUPPORTED` constants (lines 72-73)
2. Re-run test suite to verify
3. Update documentation

The centralized constants make this easy and maintain consistency across validation layers.
