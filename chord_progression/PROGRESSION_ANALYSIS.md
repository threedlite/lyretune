# Progression Analysis in analyze_lyre_progressions.py

**Date:** 2025-10-20

## What's Currently Handled

### ✅ Progressions Analyzed

The script generates and analyzes progressions from **2 to 4 chords** by default.

**Currently identified common progressions:**

#### 2-Chord Patterns
- ✅ **V-I** (Authentic Cadence)
- ✅ **IV-I** (Plagal Cadence)
- ✅ **I-V** (Half Cadence)
- ✅ **V-vi** (Deceptive Cadence)

#### 3-Chord Patterns
- ✅ **I-IV-V**
- ✅ **I-V-I**
- ✅ **ii-V-I** (Jazz progression)
- ✅ **I-vi-IV**

#### 4-Chord Patterns
- ✅ **I-IV-V-I** (Classic progression)
- ✅ **I-V-vi-IV** (Pop progression)
- ✅ **I-vi-IV-V** ("50s" progression)
- ✅ **vi-IV-I-V** (Sensitive progression)
- ✅ **ii-V-I-I** (Jazz extension)

**Code location:** Lines 405-428 in `analyze_lyre_progressions.py`

---

## What's NOT Currently Handled

### ❌ Circle of Fifths Progressions

Circle of fifths progressions require **5+ chords**:
- **Full circle:** I-IV-vii°-iii-vi-ii-V-I (8 chords)
- **Partial:** I-IV-vii°-iii-vi (5 chords)
- **Diatonic:** ii-V-I-IV-vii°-iii-vi (7 chords)

**Limitation:** Current `max_length=4` doesn't capture these.

**Why not included:**
1. Combinatorial explosion (7^5 = 16,807 possibilities for 5-chord sequences)
2. Processing time increases significantly
3. Most practical lyre playing uses 2-4 chord progressions

---

## Important Discovery: Why I-IV-V-I Isn't Showing in Notable Progressions

### The V Chord Problem

Even with **8 strings**, the **V chord lacks root position** in most modes!

**Example: LYDIOS (Ionian/Major)**

```
V chord = degree 4 (G in C major)
Uses scale degrees: [4, 6, 1] (G-B-D)

8-string layout:
String 0 = degree 0 (C)
String 1 = degree 1 (D)  ← too low!
String 2 = degree 2 (E)
String 3 = degree 3 (F)
String 4 = degree 4 (G)  ← root of V
String 5 = degree 5 (A)
String 6 = degree 6 (B)  ← third of V
String 7 = degree 0 (C)  ← not degree 1!

To get V in root position [4,6,1]:
- Need degree 4 in bass (string 4) ✓
- Need degree 6 (string 6) ✓
- Need degree 1 ABOVE degree 6 ✗

But degree 1 is only on string 1 (lower octave)!
```

**Result:** V chord stuck in **2nd inversion** (V⁶₄ = [2,5,7])

### What String Count Would Fix V Chord?

**15 strings** would give two full octaves + tonic:
```
Strings 0-6:  degrees 0,1,2,3,4,5,6 (first octave)
Strings 7-13: degrees 0,1,2,3,4,5,6 (second octave)
String 14:    degree 0 (third octave tonic)
```

Then V chord could use strings [11, 13, 8] = degrees [4, 6, 1] in root position!

But that's impractical for a hand-held lyre.

### Why IV-I Works but I-IV-V-I Doesn't

| Progression | Why It Works/Doesn't |
|-------------|----------------------|
| **IV-I** | IV uses [3,5,0], string 8 provides degree 0 → root position ✓ |
| **I-IV-V-I** | V uses [4,6,1], no upper octave degree 1 → inversion only ✗ |

**The 8-string improvement is specific to IV chord!**

---

## Test Results (LYDIOS Mode)

### 8-String Output Analysis

**From `/tmp/test_8string.txt`:**

```
IV (maj): Root position: IV[4,6,8]↑  ← 8th string enables this!
V (maj): Root position: NONE         ← Still stuck in inversion

Notable Progressions:
  Plagal Cadence (IV-I):   complexity 12.92  ← Excellent!
  Authentic Cadence (V-I): complexity 15.71  ← Still good (unchanged)
  ii-V-I (Jazz):           complexity 21.08  ← Works with inverted V
```

**I-IV-V-I** is generated but:
- V chord must use inversion (V⁶₄)
- Adds ~3-5 points of inversion penalty
- Not as strong as pure root position progressions
- Therefore doesn't appear in "top 30" notable progressions

You can still find it in the full output, just not highlighted.

---

## Recommendations

### Option 1: Increase max_length for Circle of Fifths

Add parameter to generate longer progressions:

```python
# In main():
parser.add_argument('--max-length', type=int, default=4,
                   help='Maximum progression length (default: 4, increase for circle of fifths)')

# Usage:
python3 analyze_lyre_progressions.py --mode LYDIOS --num-strings 8 --max-length 7
```

**Pros:**
- Can analyze circle of fifths
- More comprehensive

**Cons:**
- Much slower (exponential growth)
- Most progressions won't be playable/practical
- Output becomes overwhelming

### Option 2: Add Specific Circle of Fifths Patterns

Add to `identify_common_progressions()`:

```python
# 5-chord patterns
five_chord_patterns = {
    (0, 3, 6, 2, 5): 'Circle: I-IV-vii°-iii-vi',
    (1, 4, 0, 3, 6): 'Circle: ii-V-I-IV-vii°',
}

# 6-chord patterns
six_chord_patterns = {
    (0, 3, 6, 2, 5, 1): 'Circle: I-IV-vii°-iii-vi-ii',
    (1, 4, 0, 3, 6, 2): 'Circle: ii-V-I-IV-vii°-iii',
}

# 7-chord patterns (full diatonic circle)
seven_chord_patterns = {
    (1, 4, 0, 3, 6, 2, 5): 'Full Circle: ii-V-I-IV-vii°-iii-vi',
}
```

**Pros:**
- Specifically targets requested progressions
- Controlled output size

**Cons:**
- Still slow for 7-chord progressions
- Many inversions make them less ideal

### Option 3: Accept Limitations and Document

**Reality check:**
- 8-string lyre is optimized for **plagal cadences (IV-I)**
- V chord remains in inversion (inherent limitation)
- Circle of fifths progressions are academic more than practical
- Traditional lyre music uses simpler 2-3 chord patterns

**Current implementation is excellent for:**
- ✅ IV-I progressions (now properly voiced!)
- ✅ I-IV patterns
- ✅ ii-V-I jazz patterns (even with inverted V)
- ✅ Most practical 2-4 chord sequences

---

## Summary Table

| Progression Type | Currently Handled? | Complexity | Notes |
|------------------|-------------------|------------|-------|
| **V-I** (Authentic) | ✅ Yes | 15.71 | V in inversion, but still good |
| **IV-I** (Plagal) | ✅ Yes | 12.92 | Excellent with 8 strings! |
| **I-IV-V-I** | ⚠️ Generated but weak | ~35-40 | V inversion adds penalty |
| **ii-V-I** (Jazz) | ✅ Yes | 21.08 | Works despite V inversion |
| **I-vi-IV-V** ("50s") | ✅ Yes | Generated | Multiple inversions |
| **Circle of Fifths (5+ chords)** | ❌ No | N/A | Exceeds max_length=4 |

---

## Conclusion

The script **DOES handle** most of the requested progressions:
- ✅ I-IV-V-I (generated, though V is inverted)
- ✅ ii-V-I (identified as "Jazz" progression)
- ✅ I-vi-IV-V (identified as "50s" progression)
- ❌ Circle of fifths (too long, max_length=4)

**The real insight:** 8 strings specifically improve IV chord, but V chord remains problematic. This is an inherent limitation of the diatonic string layout, not a bug!

**For practical lyre playing**, focus on:
1. **IV-I** progressions (now excellent!)
2. **ii-V-I** patterns (good even with inverted V)
3. **I-IV** patterns (both root position)
4. Accept V chord inversions as part of the lyre's character

**If you want circle of fifths analysis**, I can add `--max-length` parameter, but be warned: the output will be massive and most progressions won't be practically playable.
