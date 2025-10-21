#!/usr/bin/env python3
"""
Verify 7-string lyre analysis including tetrads.
"""
import re

# DORIOS mode for testing
scale_semitones = [0, 1, 3, 5, 7, 8, 10]
scale_length = len(scale_semitones)

def get_string_semitone(string_num):
    """Get semitone for a string (1-indexed)."""
    s = string_num - 1  # Convert to 0-indexed
    # For 7 strings, no octave wrapping needed - each string maps to one degree
    degree = s % scale_length
    octave = s // scale_length
    return scale_semitones[degree] + (octave * 12)

def verify_chord(voicing_str, expected_type):
    """Verify a chord voicing."""
    match = re.search(r'\[([0-9,]+)\]', voicing_str)
    if not match:
        return False, "Could not parse"

    strings = [int(s) for s in match.group(1).split(',')]
    semitones = [get_string_semitone(s) for s in strings]

    print(f"\n  {voicing_str}")
    print(f"  Strings: {strings} → Semitones: {semitones}")

    # Get pitch classes
    pitch_classes = sorted([st % 12 for st in semitones])
    intervals = [(pc - pitch_classes[0]) % 12 for pc in pitch_classes]
    print(f"  Intervals: {intervals}")

    # Identify chord type
    if len(strings) == 2:
        # Dyad
        interval = intervals[1]
        types = {3: "m3", 4: "M3", 5: "P4", 7: "P5", 8: "m6", 9: "M6"}
        chord_type = types.get(interval, f"{interval}st")
    elif len(strings) == 3:
        # Triad
        if intervals == [0, 3, 7]:
            chord_type = "minor"
        elif intervals == [0, 4, 7]:
            chord_type = "major"
        elif intervals == [0, 3, 6]:
            chord_type = "dim"
        elif intervals == [0, 4, 8]:
            chord_type = "aug"
        else:
            chord_type = f"unknown {intervals}"
    elif len(strings) == 4:
        # Tetrad (7th chord)
        if intervals == [0, 3, 7, 10]:
            chord_type = "min7"
        elif intervals == [0, 4, 7, 11]:
            chord_type = "maj7"
        elif intervals == [0, 4, 7, 10]:
            chord_type = "dom7"
        elif intervals == [0, 3, 6, 10]:
            chord_type = "halfdim7"
        elif intervals == [0, 3, 6, 9]:
            chord_type = "dim7"
        else:
            chord_type = f"unknown {intervals}"
    else:
        chord_type = "unknown size"

    print(f"  Type: {chord_type}")

    # Check if matches expected
    if expected_type.lower() in chord_type.lower() or chord_type.lower() in expected_type.lower():
        print(f"  ✓ PASS")
        return True, chord_type
    else:
        print(f"  ✗ FAIL: Expected '{expected_type}'")
        return False, chord_type

print("=" * 80)
print("7-STRING LYRE VERIFICATION (DORIOS MODE)")
print("=" * 80)
print(f"Scale: {scale_semitones}")
print(f"\nString tuning:")
for i in range(7):
    print(f"  String {i+1}: semitone {get_string_semitone(i+1)}")

print("\n" + "=" * 80)
print("DYAD VERIFICATION")
print("=" * 80)

dyad_tests = [
    ("I-m3[1,3]↑", "m3"),
    ("II-M3[2,4]↑", "M3"),
    ("III-M3[3,5]↑", "M3"),
    ("IV-m3[4,6]↑", "m3"),
    ("V-m3[5,7]↑", "m3"),
]

dyad_pass = 0
for voicing, expected in dyad_tests:
    if verify_chord(voicing, expected)[0]:
        dyad_pass += 1

print("\n" + "=" * 80)
print("TRIAD VERIFICATION")
print("=" * 80)

triad_tests = [
    ("i[1,3,5]↑", "minor"),
    ("II[2,4,6]↑", "major"),
    ("III[3,5,7]↑", "major"),
    ("iv⁶₄[1,4,6]↑", "minor"),
    ("v°⁶₄[2,5,7]↑", "dim"),
    ("VI⁶[1,3,6]↑", "major"),
]

triad_pass = 0
for voicing, expected in triad_tests:
    if verify_chord(voicing, expected)[0]:
        triad_pass += 1

print("\n" + "=" * 80)
print("TETRAD VERIFICATION (7th chords)")
print("=" * 80)

tetrad_tests = [
    ("i7[1,3,5,7]↑", "min7"),
    ("IImaj7²[1,2,4,6]↑", "maj7"),
    ("III7²[2,3,5,7]↑", "dom7"),
    ("vø7⁴₃[2,4,5,7]↑", "halfdim7"),
]

tetrad_pass = 0
for voicing, expected in tetrad_tests:
    if verify_chord(voicing, expected)[0]:
        tetrad_pass += 1

print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
total = len(dyad_tests) + len(triad_tests) + len(tetrad_tests)
total_pass = dyad_pass + triad_pass + tetrad_pass
print(f"Dyads:   {dyad_pass}/{len(dyad_tests)} passed")
print(f"Triads:  {triad_pass}/{len(triad_tests)} passed")
print(f"Tetrads: {tetrad_pass}/{len(tetrad_tests)} passed")
print(f"Total:   {total_pass}/{total} passed")

if total_pass == total:
    print("\n✓ All 7-string voicings verified!")
else:
    print(f"\n✗ {total - total_pass} voicing(s) failed")
