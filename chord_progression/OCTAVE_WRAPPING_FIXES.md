# Octave Wrapping Fixes for analyze_lyre_progressions.py

## Summary
Fixed potential bugs related to handling lyres with more than 7 strings, ensuring proper bounds checking and validation throughout the chord progression analysis.

**Supported Range**: 4-13 strings (configurable via constants `MIN_STRINGS_FOR_TRIADS` and `MAX_STRINGS_SUPPORTED`)

## Issues Fixed

### 1. Missing Frequency Count Validation (Lines 254-259)
**Problem**: When creating a `LyreProgressionAnalyzer` with N strings, the code assumed `LyreChordAnalyzer` would return exactly N frequencies, but didn't validate this assumption. This could cause index errors later.

**Fix**: Added validation after creating the chord analyzer:
```python
# Validate that we got the expected number of frequencies
if len(self.just_frequencies) != num_strings:
    raise ValueError(
        f"LyreChordAnalyzer returned {len(self.just_frequencies)} frequencies "
        f"but expected {num_strings}. The analyzer may not support {num_strings} strings."
    )
```

**Benefit**: Fails fast with a clear error message if there's a mismatch, rather than causing cryptic index errors later.

---

### 2. Index Bounds Checking in Complexity Calculation (Lines 420-425)
**Problem**: In `_calculate_progression_complexity()`, when accessing `self.just_frequencies[idx - 1]`, there was no validation that `idx` was within valid bounds. For 8+ string voicings, this could cause an IndexError.

**Fix**: Added validation before accessing the frequency array:
```python
# Validate all indices are within bounds
for idx in voicing.string_indices:
    if idx < 1 or idx > len(self.just_frequencies):
        raise IndexError(
            f"Invalid string index {idx} in voicing {voicing}. "
            f"Valid range is 1-{len(self.just_frequencies)} for {self.num_strings} strings."
        )
```

**Benefit**: Provides clear error messages if voicings contain invalid string indices, making debugging easier.

---

### 3. Improved Documentation for _build_voicings() (Lines 309-317)
**Problem**: The octave wrapping logic (`degree = s % 7`, `octave = s // 7`) wasn't clearly documented.

**Fix**: Enhanced docstring:
```python
"""Find all possible voicings for each triad on N strings.

For lyres with more than 7 strings, assumes the scale pattern repeats
across octaves. String i plays scale degree (i % 7) at octave (i // 7).

Returns:
    Dict mapping triad root_degree to list of possible voicings

Raises:
    ValueError: If num_strings exceeds available frequencies
"""
```

**Benefit**: Makes the octave wrapping logic explicit and documents the assumption.

---

### 4. Defensive Bounds Check in _build_voicings() (Lines 325-328)
**Problem**: Although `combinations(range(self.num_strings), 3)` should never produce out-of-bounds indices, there was no defensive check.

**Fix**: Added defensive validation:
```python
# Validate string indices are within bounds
# (should always be true, but defensive check)
if any(s >= self.num_strings for s in strings):
    continue
```

**Benefit**: Defense in depth - prevents potential bugs if the logic changes.

---

### 5. String Count Limits (Lines 71-73)
**Problem**: No centralized constants for minimum and maximum supported strings.

**Fix**: Added configurable constants:
```python
# Minimum and maximum strings supported
MIN_STRINGS_FOR_TRIADS = 4
MAX_STRINGS_SUPPORTED = 13
```

**Benefit**: Easy to adjust supported range in one place; self-documenting code.

---

### 6. Class-Level Validation (Lines 229-237)
**Problem**: The `LyreProgressionAnalyzer.__init__()` didn't validate the maximum string count.

**Fix**: Added validation for both minimum and maximum:
```python
if num_strings < MIN_STRINGS_FOR_TRIADS:
    raise ValueError(
        f"Need at least {MIN_STRINGS_FOR_TRIADS} strings to form triads, got {num_strings}"
    )

if num_strings > MAX_STRINGS_SUPPORTED:
    raise ValueError(
        f"Maximum {MAX_STRINGS_SUPPORTED} strings supported, got {num_strings}"
    )
```

**Benefit**: Validation happens at the class level, catching errors regardless of how the class is instantiated.

---

### 7. Command-Line Argument Validation (Lines 806-812)
**Problem**: The `--num-strings` argument wasn't validated, allowing users to request invalid configurations.

**Fix**: Added validation in `main()`:
```python
# Validate num_strings parameter
if args.num_strings < MIN_STRINGS_FOR_TRIADS:
    print(f"Error: num_strings must be at least {MIN_STRINGS_FOR_TRIADS} to form triads")
    sys.exit(1)
if args.num_strings > MAX_STRINGS_SUPPORTED:
    print(f"Error: num_strings cannot exceed {MAX_STRINGS_SUPPORTED} (requested {args.num_strings})")
    sys.exit(1)
```

**Benefit**: Users get immediate, clear error messages rather than confusing tracebacks.

---

## Test Results

Created comprehensive test suite in `test_octave_wrapping_fix.py`:

```
✓ 4-string lyre (min): PASS
✓ 7-string lyre: PASS
✓ 8-string lyre: PASS
✓ 13-string lyre (max): PASS
✓ Too few strings (3): PASS
✓ Too many strings (14): PASS
✓ Frequency validation: PASS
```

All tests verified:
- Minimum 4-string configuration works correctly
- Standard 7-string analysis works correctly
- Extended 8-string analysis works (tests octave wrapping)
- Maximum 13-string configuration works correctly
- Proper rejection of invalid string counts (< 4 or > 13)
- Clear error messages for all failure cases

## Example Usage

```bash
# Minimum 4-string lyre
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 4 --mode DORIOS

# Standard 7-string lyre
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 7 --mode DORIOS

# Extended 8-string lyre (octave wrapping)
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 8 --mode DORIOS

# Maximum 13-string lyre
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 13 --mode DORIOS

# Invalid cases now properly handled
venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 3 --mode DORIOS
# Error: num_strings must be at least 4 to form triads

venv/bin/python chord_progression/analyze_lyre_progressions.py --num-strings 14 --mode DORIOS
# Error: num_strings cannot exceed 13 (requested 14)
```

## Impact

These fixes ensure:
1. **Robustness**: No index errors for valid configurations (4-13 strings)
2. **Clear errors**: Descriptive messages when things go wrong
3. **Documentation**: Explicit explanation of octave wrapping logic
4. **Validation**: Input constraints enforced at multiple levels (class and CLI)
5. **Testability**: Comprehensive test coverage for edge cases
6. **Configurability**: Easy to adjust supported range via centralized constants

The code now safely handles any valid N-string configuration from 4 to 13 strings, with proper octave wrapping for 8+ strings.
