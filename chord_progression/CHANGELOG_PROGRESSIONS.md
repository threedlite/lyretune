# Lyre Progression Analysis - Changelog

## Version 2 - Fixed Root Movement Scoring

### Date
2025-10-20

### Summary
Fixed critical bug in root movement complexity scoring that caused V-I progressions to rank weaker than I-V, opposite of music theory expectations.

---

## What Was Wrong

### Original Implementation (INCORRECT)
```python
movement_strength = {
    4: -1.0,  # I→V motion (half cadence)
    3: -0.5,  # V→I motion (authentic cadence)
}
```

**Problem:**
- I→V (half cadence, creates tension) got -1.0 bonus = STRONGER
- V→I (authentic cadence, resolution) got -0.5 bonus = WEAKER
- This caused V-I to consistently rank below I-V in all modes
- **Completely backwards from traditional music theory!**

### Root Cause Analysis

The mismatch was caused by **THREE factors**, not just inversion:

1. **Root movement scoring was backwards** ★★★ (PRIMARY)
   - Accounted for ~1.0-1.5 point swing
   - This alone reversed the V-I vs I-V ranking

2. **Inversion penalties** ★★ (SECONDARY)
   - V chord requires 2nd inversion (+2.0 penalty)
   - Affects both V-I and I-V equally
   - Doesn't explain the ranking reversal

3. **V chord quality varies by mode** ★ (MODE-DEPENDENT)
   - Diminished V (DORIOS): very high base complexity
   - Minor V (PHRYGIOS, etc.): medium complexity
   - Major V (LYDIOS, etc.): appropriate complexity
   - But root movement was still the dominant factor

---

## The Fix

### New Implementation (CORRECT)
```python
movement_strength = {
    3: -1.5,  # V→I motion (authentic cadence) - STRONGEST
    4: -0.3,  # I→V motion (half cadence) and IV→I (plagal) - weaker
    5: -0.5,  # Ascending 5th
    2: 0.3,   # Stepwise motion
    6: 1.5,   # Tritone (unstable)
    1: 0.8,   # Half step
    0: 0.0,   # No movement (pedal)
}
```

**Changes:**
- V→I (distance 3) now gets **-1.5** bonus (was -0.5)
- I→V (distance 4) now gets **-0.3** bonus (was -1.0)
- Net effect: V→I is now 1.2 points simpler than I→V

---

## Results Comparison

### Before Fix (WRONG)
```
LYDIOS Mode:
1. V-vi (Deceptive)  =  98.82
2. I-V  (Half)       = 135.31  ← Should be weakest!
3. IV-I (Plagal)     = 135.31
4. V-I  (Authentic)  = 135.81  ← Should be strongest!
```

### After Fix (CORRECT)
```
LYDIOS Mode:
1. V-vi (Deceptive)  =  98.82  (excellent voice leading)
2. V-I  (Authentic)  = 134.81  ✓ Stronger than I-V!
3. I-V  (Half)       = 136.01  ✓ Correctly weakest
4. IV-I (Plagal)     = 136.01
```

### Verification Across All Modes

| Mode | V-I < I-V? | Status |
|------|-----------|--------|
| DORIOS | 134.26 < 135.46 | ✓ PASS |
| PHRYGIOS | 138.56 < 139.76 | ✓ PASS |
| LYDIOS | 134.81 < 136.01 | ✓ PASS |
| MIXOLYDIOS | 120.96 < 122.16 | ✓ PASS |
| HYPODORIOS | 138.56 < 139.76 | ✓ PASS |
| HYPOLYDIOS | 134.81 < 136.01 | ✓ PASS |
| HYPOPHRYGIOS | 140.11 < 141.31 | ✓ PASS |

**Result: V-I now ranks stronger than I-V in ALL 7 modes! ✓**

---

## Remaining Variations from Theory

### V-vi (Deceptive Cadence) Sometimes Ranks #1

In modes like LYDIOS, HYPOLYDIOS, HYPOPHRYGIOS, V-vi has exceptionally low complexity (~98-104):

**Reason:**
- Excellent voice leading (many common tones)
- Smooth string transitions on the lyre
- Both chords in inversion, but minimal movement

**Is this wrong?**
Possibly not! It may accurately reflect that V-vi is genuinely easier to play smoothly on certain lyre tunings.

### V Chord Quality Varies by Mode

V-I strength depends on V chord quality:
- **Best:** MIXOLYDIOS, LYDIOS, HYPOLYDIOS (V is major)
- **Moderate:** DORIOS (V is diminished)
- **Weaker:** PHRYGIOS, HYPODORIOS, HYPOPHRYGIOS (V is minor)

This is not a bug - it's inherent to diatonic modal harmony.

---

## Impact

### Fixed ✓
- V-I vs I-V relationship now matches traditional theory
- Authentic cadence consistently strongest resolution
- Half cadence correctly creates tension
- Root movement properly weighted

### Still Variable (by design)
- Absolute ranking of V-I varies by mode (depends on V chord quality)
- V-vi sometimes very strong (reflects voice leading on lyre)
- Inversion penalties affect all progressions using V chord

---

## Files Modified

1. **analyze_lyre_progressions.py**
   - Updated `_root_movement_complexity()` method
   - Swapped and adjusted values for degree distances 3 and 4
   - Added documentation explaining the weighting

2. **THEORY_VERIFICATION_REPORT.md**
   - Updated to reflect fix
   - Changed from "DOES NOT MATCH" to "MOSTLY YES"
   - Added before/after comparison
   - Removed claims about historical usage

3. **lyre_progression_analysis.txt**
   - Regenerated with corrected root movement scoring
   - All 7 modes now show V-I > I-V

---

## Usage

The fixed analysis is now in:
- `lyre_progression_analysis.txt` (new version)
- `lyre_progression_analysis_OLD.txt` (original, for reference)

To regenerate:
```bash
source venv/bin/activate
python analyze_lyre_progressions.py --output lyre_progression_analysis.txt
```

---

## Validation

The fix was validated by:
1. Checking V-I < I-V in all 7 modes ✓
2. Comparing against traditional cadence strength theory ✓
3. Verifying root movement scoring matches theory ✓
4. Testing with major V (LYDIOS), minor V (PHRYGIOS), and dim V (DORIOS) ✓

All tests passed.
