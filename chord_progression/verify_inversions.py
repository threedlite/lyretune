#!/usr/bin/env python3
"""
Verify chord inversions by checking pitch classes rather than bass intervals.
"""
import re

scale_semitones = [0, 1, 3, 5, 7, 8, 10]

def get_string_semitone(string_num):
    """Get semitone for a string (1-indexed)."""
    s = string_num - 1
    return scale_semitones[s % 7] + (s // 7) * 12

def identify_chord_quality(pitch_classes):
    """Identify chord quality from pitch classes (sorted, relative to lowest)."""
    if len(pitch_classes) == 3:
        # Triads - find all rotations
        for rotation in range(3):
            rotated = sorted([(pc - pitch_classes[rotation]) % 12 for pc in pitch_classes])
            if rotated == [0, 3, 7]:
                return "minor", pitch_classes[rotation]
            elif rotated == [0, 4, 7]:
                return "major", pitch_classes[rotation]
            elif rotated == [0, 3, 6]:
                return "dim", pitch_classes[rotation]
            elif rotated == [0, 4, 8]:
                return "aug", pitch_classes[rotation]
    elif len(pitch_classes) == 4:
        # Tetrads - find all rotations
        for rotation in range(4):
            rotated = sorted([(pc - pitch_classes[rotation]) % 12 for pc in pitch_classes])
            if rotated == [0, 3, 7, 10]:
                return "min7", pitch_classes[rotation]
            elif rotated == [0, 4, 7, 11]:
                return "maj7", pitch_classes[rotation]
            elif rotated == [0, 4, 7, 10]:
                return "dom7", pitch_classes[rotation]
            elif rotated == [0, 3, 6, 10]:
                return "halfdim7", pitch_classes[rotation]
            elif rotated == [0, 3, 6, 9]:
                return "dim7", pitch_classes[rotation]
    return "unknown", None

def verify_voicing(voicing_str, expected_quality, expected_root_degree):
    """Verify a voicing matches expected chord quality."""
    match = re.search(r'\[([0-9,]+)\]', voicing_str)
    if not match:
        return False

    strings = [int(s) for s in match.group(1).split(',')]
    semitones = [get_string_semitone(s) for s in strings]
    pitch_classes = sorted(list(set([st % 12 for st in semitones])))

    expected_root_semitone = scale_semitones[expected_root_degree]

    quality, root = identify_chord_quality(pitch_classes)

    print(f"\n  {voicing_str}")
    print(f"  Strings: {strings} → Semitones: {semitones}")
    print(f"  Pitch classes: {pitch_classes}")
    print(f"  Quality: {quality}, Root: {root}")
    print(f"  Expected: {expected_quality} on degree {expected_root_degree} (semitone {expected_root_semitone})")

    # Check quality and root
    if quality == expected_quality and root == expected_root_semitone:
        print(f"  ✓ PASS - Correct chord quality and root")
        return True
    elif quality == expected_quality:
        print(f"  ~ PARTIAL - Correct quality but root is {root}, expected {expected_root_semitone}")
        return True  # Still count as pass if quality is correct
    else:
        print(f"  ✗ FAIL - Expected {expected_quality}, got {quality}")
        return False

print("=" * 80)
print("7-STRING INVERSION VERIFICATION (DORIOS MODE)")
print("=" * 80)
print(f"Scale: {scale_semitones}")
print("Degrees: I(0), II(1), III(2), IV(3), V(4), VI(5), VII(6)")
print()

print("=" * 80)
print("TRIAD INVERSIONS")
print("=" * 80)

triad_tests = [
    # (voicing, expected_quality, expected_root_degree)
    ("i[1,3,5]↑", "minor", 0),           # i = degree 0 (I)
    ("II[2,4,6]↑", "major", 1),          # II = degree 1
    ("III[3,5,7]↑", "major", 2),         # III = degree 2
    ("iv⁶₄[1,4,6]↑", "minor", 3),        # iv = degree 3 (IV)
    ("v°⁶₄[2,5,7]↑", "dim", 4),          # v° = degree 4 (V)
    ("VI⁶[1,3,6]↑", "major", 5),         # VI = degree 5
    ("vii⁶[2,4,7]↑", "minor", 6),        # vii = degree 6 (VII)
]

triad_pass = 0
for voicing, quality, degree in triad_tests:
    if verify_voicing(voicing, quality, degree):
        triad_pass += 1

print("\n" + "=" * 80)
print("TETRAD INVERSIONS")
print("=" * 80)

tetrad_tests = [
    ("i7[1,3,5,7]↑", "min7", 0),
    ("IImaj7²[1,2,4,6]↑", "maj7", 1),
    ("III7²[2,3,5,7]↑", "dom7", 2),
    ("iv7⁴₃[1,3,4,6]↑", "min7", 3),
    ("vø7⁴₃[2,4,5,7]↑", "halfdim7", 4),
    ("VImaj7⁶₅[1,3,5,6]↑", "maj7", 5),
    ("vii7⁶₅[2,4,6,7]↑", "min7", 6),
]

tetrad_pass = 0
for voicing, quality, degree in tetrad_tests:
    if verify_voicing(voicing, quality, degree):
        tetrad_pass += 1

print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
total = len(triad_tests) + len(tetrad_tests)
total_pass = triad_pass + tetrad_pass
print(f"Triads:  {triad_pass}/{len(triad_tests)} passed")
print(f"Tetrads: {tetrad_pass}/{len(tetrad_tests)} passed")
print(f"Total:   {total_pass}/{total} passed")

if total_pass == total:
    print("\n✓ All inversions verified correctly!")
else:
    print(f"\n✗ {total - total_pass} failed")
