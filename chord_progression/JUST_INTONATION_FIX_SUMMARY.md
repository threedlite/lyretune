# Just Intonation Fix - Impact Summary

## Date
2025-10-20

## Critical Fix Applied

The chord progression analyzer was using **equal temperament** instead of **just intonation**. This has been corrected.

## Impact on Results

### Complexity Score Changes (Examples)

| Mode | Progression | OLD (Equal Temp) | NEW (Just Intonation) | Change |
|------|-------------|------------------|----------------------|--------|
| LYDIOS | V-I (Authentic) | 134.8 | 15.7 | **-88%** |
| LYDIOS | I-V (Half) | ~136 | 16.9 | **-88%** |
| DORIOS | v°-i (Authentic) | ~134 | 68.9 | **-49%** |
| DORIOS | i-v° (Half) | ~135 | 70.1 | **-48%** |

### Why the Dramatic Change?

**Equal Temperament:**
- Major third: 2^(4/12) ≈ 1.25992 (irrational)
- Perfect fifth: 2^(7/12) ≈ 1.49831 (irrational)
- Major triad: Complex irrational ratios

**Just Intonation:**
- Major third: 5/4 = 1.25 (pure integer ratio)
- Perfect fifth: 3/2 = 1.5 (pure integer ratio)
- Major triad: 4:5:6 (perfectly simple!)

### What Changed in Rankings?

**General patterns remain the same:**
- V-I still stronger than I-V ✓
- Root movement hierarchy still correct ✓
- Voice leading quality still matters ✓

**Absolute complexity values changed dramatically:**
- Consonant chords became 8-10x simpler
- Dissonant chords (diminished, etc.) still relatively complex
- The gap between consonant and dissonant widened

## Files Updated

1. **analyze_lyre_progressions.py** - Now uses LyreChordAnalyzer with JUST temperament
2. **lyre_progression_analysis.txt** - Regenerated with correct just intonation
3. **lyre_progression_analysis_OLD_EQUAL_TEMPERAMENT.txt** - Backup of incorrect analysis
4. **README.md** - Updated to emphasize just intonation
5. **CHANGELOG_PROGRESSIONS.md** - Version 3 entry added

## Validation

Test confirmed just intonation is working:
```
✓ Temperament: JUST
✓ Sample frequencies (Hz): 330.00, 366.67, 412.50, 440.00
✓ Major triad complexity: ~6-8 (was ~50-60 with equal temp)
```

## Conclusion

**All previous complexity scores were INCORRECT.**

The new analysis accurately reflects the acoustics of a just-tuned lyre, where pure integer ratios create perfect consonance.

Rankings and relationships are now musically accurate.
