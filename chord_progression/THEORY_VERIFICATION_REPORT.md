# Music Theory Verification Report
## Does the Lyre Progression Analysis Match Traditional Theory?

### Executive Summary
**MOSTLY YES** (after fix) - The chord progression complexity rankings now align with traditional music theory for the most important relationship: **V-I is stronger than I-V**.

However, some deviations remain due to the **physical constraints of the 7-string lyre** and modal chord quality variations.

---

## Traditional Music Theory Expectations

Cadence strength ranking (strongest → weakest):
1. **Authentic Cadence (V-I)** - Strongest resolution
2. **Plagal Cadence (IV-I)** - Weaker than V-I
3. **Deceptive Cadence (V-vi)** - Similar to V-I but delays resolution
4. **Half Cadence (I-V)** - Creates tension, NO resolution (weakest)

---

## Actual Results from Lyre Analysis (After Fix)

### Sample: DORIOS Mode (V is diminished)
```
Rank  Cadence             Progression    Complexity
1.    V-I (Authentic)     v° - i         134.26  ✓
2.    V-vi (Deceptive)    v° - VI        135.11
3.    I-V (Half)          i - v°         135.46  ✓
4.    IV-I (Plagal)       iv - i         139.76
```

### Sample: LYDIOS Mode (V is MAJOR)
```
Rank  Cadence             Progression    Complexity
1.    V-vi (Deceptive)    V - vi         98.82   (excellent voice leading)
2.    V-I (Authentic)     V - I          134.81  ✓
3.    I-V (Half)          I - V          136.01  ✓
4.    IV-I (Plagal)       IV - I         136.01
```

### Sample: MIXOLYDIOS Mode (V is MAJOR)
```
Rank  Cadence             Progression    Complexity
1.    V-I (Authentic)     V - i°         120.96  ✓ Best ranking!
2.    I-V (Half)          i° - V         122.16  ✓
3.    IV-I (Plagal)       iv - i°        127.47  ✓
4.    V-vi (Deceptive)    V - VI         134.10
```

**Result: V-I now consistently ranks stronger than I-V! ✓**

---

## Root Cause Analysis

### What Was Fixed

**Root Movement Scoring** (FIXED ✓)

The original code incorrectly assigned:
- I→V (half cadence): -1.0 bonus = stronger
- V→I (authentic cadence): -0.5 bonus = weaker

**This has been corrected to:**
- V→I (degree distance 3): -1.5 bonus = STRONGEST
- I→V (degree distance 4): -0.3 bonus = much weaker

This fix ensures V-I always ranks stronger than I-V, matching traditional theory.

---

### Remaining Variations from Theory

#### Issue 1: V Chord Quality Varies by Mode

Traditional harmony assumes **V is MAJOR** with strong leading tone.

On the lyre, V chord quality depends on the mode:

| Mode        | V Chord Quality | Problem |
|-------------|----------------|---------|
| DORIOS      | Diminished (v°) | ✗ Very dissonant |
| PHRYGIOS    | Minor (v)       | ✗ Weak leading tone |
| LYDIOS      | MAJOR (V)       | ✓ Matches theory |
| MIXOLYDIOS  | MAJOR (V)       | ✓ Matches theory |
| HYPODORIOS  | Minor (v)       | ✗ Weak leading tone |
| HYPOLYDIOS  | MAJOR (V)       | ✓ Matches theory |
| HYPOPHRYGIOS| Minor (v)       | ✗ Weak leading tone |

**Only 3/7 modes have major V chord!**

#### Issue 2: V Chord ALWAYS Requires Inversion

Due to the lyre's string layout (ascending notes from string 1→7), the V chord (scale degree 4) typically includes higher-numbered strings with lower-numbered strings, often forcing inversions.

**Example from LYDIOS:**
- I chord: strings [1,3,5] = root position ✓
- V chord: strings [2,5,7] = **2nd inversion** (⁶₄) ✗

**Voicing penalty: +2.0 for 2nd inversion**

This affects BOTH V→I and I→V progressions equally, so it doesn't reverse their ranking, but it does add overall complexity to both.

#### Issue 3: Deceptive Cadence (V-vi) Sometimes Ranks Very High

In some modes (LYDIOS, HYPOLYDIOS, HYPOPHRYGIOS), V-vi has exceptionally low complexity (~98-104) due to:
- Excellent voice leading (many common tones)
- Smooth string transitions
- Both chords requiring inversions, but with minimal movement

This isn't necessarily wrong - it reflects that V-vi may genuinely be easier to play smoothly on the lyre than other progressions.

#### Issue 4: What The Formula Models

Current formula considers:
1. Individual chord consonance (from harmonic complexity formula)
2. Voice leading distance (string movements)
3. Root movement (now correctly weighted)
4. Voicing quality (penalizes inversions)

**Not modeled:**
1. Functional expectation in specific tonal contexts
2. Tendency tone resolution (leading tone → tonic)
3. Metric weight or rhythmic context
4. Cultural/stylistic expectations beyond acoustics

---

## Complexity Breakdown Examples (After Fix)

### DORIOS: V-I with Diminished V
```
v° - i: v°⁶₄[2,5,7]↑ - i[1,3,5]↑
       └── 2nd inv    └── root pos

Complexity = 134.26 because:
  - v° base complexity: ~65 (diminished = high)
  - Inversion penalty: +2.0
  - Voice leading: moderate
  - Root movement: -1.5 (V→I bonus) ✓
  Total: MEDIUM
```

### LYDIOS: V-I with Major V
```
V - I: V⁶₄[2,5,7]↑ - I[1,3,5]↑
      └── 2nd inv  └── root pos

Complexity = 134.81 because:
  - V base complexity: ~50 (major triad)
  - Inversion penalty: +2.0
  - Voice leading: moderate
  - Root movement: -1.5 (V→I bonus) ✓
  Total: MEDIUM
```

### LYDIOS: Deceptive Cadence (Still Very Strong)
```
V - vi: V⁶₄[2,5,7]↑ - vi⁶[1,3,6]↑
       └── 2nd inv   └── 1st inv

Complexity = 98.82 because:
  - V base complexity: ~50
  - Inversion penalty: +2.0
  - vi inversion: +1.5
  - Voice leading: EXCELLENT (common tones!)
  - Root movement: moderate
  Total: LOW due to exceptional voice leading
```

**The deceptive cadence still has excellent voice leading on the lyre!**

---

## Verification Against Theory: Summary (After Fix)

| Expectation | Reality | Match? | Reason |
|-------------|---------|--------|--------|
| V-I > I-V | V-I always stronger | ✓ PASS | Root movement now correctly weighted |
| V-I strongest | V-I strongest in 4/7 modes | ~ PARTIAL | Depends on V chord quality (major/minor/dim) |
| V-I ≈ V-vi | V-vi sometimes stronger | ~ PARTIAL | Exceptional voice leading in some modes |
| V-I > IV-I | True in 5/7 modes | ~ PARTIAL | V chord quality affects this |

**Core requirement (V-I > I-V) now met in ALL modes! ✓**

---

## Conclusion

### The Formula Now Works Well

After fixing the root movement scoring, the complexity formula accurately measures:
- Chord consonance (from harmonic complexity formula)
- Voice leading smoothness (string distances)
- Voicing quality (root position vs inversions)
- Root movement strength (correctly weighted)

**Most importantly:** V-I is now always ranked stronger than I-V, matching the fundamental relationship in tonal harmony.

### Lyre-Specific Constraints

A 7-string diatonic lyre with ascending tuning has inherent limitations:
1. V chord typically requires inversion (cannot get root position easily)
2. V chord quality varies by mode (major/minor/diminished)
3. Voice leading options are constrained by string layout
4. Only 3 adjacent strings can sound simultaneously

These constraints mean:
- Not all progressions from Common Practice harmony work equally well
- Some modes are better suited for tonal progressions than others
- Voice leading considerations may outweigh other factors

### Remaining Variations

**V-vi (Deceptive Cadence) sometimes ranks #1:**
- In LYDIOS, HYPOLYDIOS, HYPOPHRYGIOS modes
- Due to exceptional voice leading (many common tones)
- This may accurately reflect that V-vi is easier to voice smoothly on these tunings

**V chord quality affects V-I strength:**
- Best in MIXOLYDIOS, LYDIOS, HYPOLYDIOS (V is major)
- Weaker in PHRYGIOS, HYPOPHRYGIOS (V is minor)
- Weakest in DORIOS (V is diminished)

---

## Recommendations

### For Traditional Harmonic Analysis

The formula now provides reasonable rankings for standard cadences:
- ✓ Use as-is for comparing progression strength
- ✓ V-I reliably stronger than I-V
- ✓ Root movement correctly weighted

### For Mode Selection

If you want strong V-I progressions on a 7-string lyre:
- **Best modes:** MIXOLYDIOS, LYDIOS, HYPOLYDIOS (major V)
- **Moderate:** DORIOS (diminished V can work in some contexts)
- **Challenging:** PHRYGIOS, HYPODORIOS, HYPOPHRYGIOS (minor V)

### For Further Improvement

To model functional harmony even more accurately, could add:
1. Tendency tone resolution (leading tone → tonic)
2. Context-aware voicing penalties (accept that V needs inversion)
3. Scale degree gravity modeling

---

## Final Answer

**Does the analysis match music theory?**

**YES** for the core relationship: V-I is now consistently stronger than I-V across all modes.

**PARTIALLY** for absolute rankings: Some deviations remain due to:
- Modal variations in chord quality
- Lyre-specific voicing constraints
- Exceptional voice leading in certain progressions

The formula now successfully balances traditional harmonic theory with the practical constraints of the instrument.
