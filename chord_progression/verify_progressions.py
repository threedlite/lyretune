#!/usr/bin/env python3
"""
Verify specific chord voicings and progressions from the 8-string analysis.
"""

# DORIOS mode for testing
scale_semitones = [0, 1, 3, 5, 7, 8, 10]
scale_length = len(scale_semitones)

def get_string_semitone(string_num):
    """Get semitone for a string (1-indexed)."""
    s = string_num - 1  # Convert to 0-indexed
    degree = s % scale_length
    octave = s // scale_length
    return scale_semitones[degree] + (octave * 12)

def verify_voicing(voicing_str, expected_chord_type):
    """Verify a voicing produces the expected chord type."""
    # Parse voicing string like "iv[4,6,8]↑"
    import re
    match = re.search(r'\[([0-9,]+)\]', voicing_str)
    if not match:
        return False, "Could not parse voicing"

    strings = [int(s) for s in match.group(1).split(',')]
    semitones = [get_string_semitone(s) for s in strings]

    print(f"\n  Voicing: {voicing_str}")
    print(f"  Strings: {strings} → Semitones: {semitones}")

    # Calculate intervals from bass
    bass = semitones[0]
    intervals = [st - bass for st in semitones]
    print(f"  Intervals from bass: {intervals}")

    # Check chord type
    if len(semitones) == 2:
        # Dyad
        interval = intervals[1]
        if interval == 3:
            chord_type = "minor 3rd"
        elif interval == 4:
            chord_type = "major 3rd"
        elif interval == 7:
            chord_type = "perfect 5th"
        elif interval == 8:
            chord_type = "minor 6th (inverted M3)"
        elif interval == 9:
            chord_type = "major 6th (inverted m3)"
        else:
            chord_type = f"{interval} semitones"

    elif len(semitones) == 3:
        # Triad - check quality
        if intervals == [0, 3, 7] or set([(st % 12) for st in semitones]) == set([0, 3, 7]):
            chord_type = "minor triad"
        elif intervals == [0, 4, 7] or set([(st % 12) for st in semitones]) == set([0, 4, 7]):
            chord_type = "major triad"
        elif intervals == [0, 3, 6]:
            chord_type = "diminished triad"
        elif intervals == [0, 4, 8]:
            chord_type = "augmented triad"
        # Check inversions
        elif intervals[1] - intervals[0] == 3 and intervals[2] - intervals[0] == 8:
            chord_type = "minor triad (1st inv)"
        elif intervals[1] - intervals[0] == 4 and intervals[2] - intervals[0] == 9:
            chord_type = "major triad (1st inv)"
        elif intervals[1] - intervals[0] == 5 and intervals[2] - intervals[0] == 8:
            chord_type = "minor triad (2nd inv)"
        elif intervals[1] - intervals[0] == 5 and intervals[2] - intervals[0] == 9:
            chord_type = "major triad (2nd inv)"
        else:
            # Check by pitch classes
            pitch_classes = sorted([st % 12 for st in semitones])
            print(f"  Pitch classes (mod 12): {pitch_classes}")
            root = pitch_classes[0]
            ints = [(pc - root) % 12 for pc in pitch_classes]
            if ints == [0, 3, 7]:
                chord_type = "minor triad (some inversion)"
            elif ints == [0, 4, 7]:
                chord_type = "major triad (some inversion)"
            else:
                chord_type = f"unknown ({ints})"

    print(f"  Chord type: {chord_type}")

    if expected_chord_type.lower() in chord_type.lower():
        print(f"  ✓ PASS: Matches expected '{expected_chord_type}'")
        return True, chord_type
    else:
        print(f"  ✗ FAIL: Expected '{expected_chord_type}', got '{chord_type}'")
        return False, chord_type

print("=" * 80)
print("VERIFYING CHORD VOICINGS FOR DORIOS MODE (8 strings)")
print("=" * 80)
print(f"Scale semitones: {scale_semitones}")
print(f"\nString tuning:")
for i in range(8):
    print(f"  String {i+1}: semitone {get_string_semitone(i+1)}")

print("\n" + "=" * 80)
print("TESTING SPECIFIC VOICINGS FROM ANALYSIS")
print("=" * 80)

# Test cases from the actual output
test_cases = [
    ("i[1,3,5]↑", "minor triad"),  # i chord in root position
    ("iv[4,6,8]↑", "minor triad"),  # iv chord in root position
    ("II[2,4,6]↑", "major triad"),  # II chord in root position
    ("III[3,5,7]↑", "major triad"),  # III chord in root position
    ("I-m3[1,3]↑", "minor 3rd"),  # I dyad
    ("VI-M3[6,8]↑", "major 3rd"),  # VI dyad
    ("I-m3⁶[3,8]↑", "minor 6th"),  # I dyad inverted
    ("i⁶[3,5,8]↑", "minor triad"),  # i chord in 1st inversion
]

passed = 0
failed = 0

for voicing, expected in test_cases:
    success, result = verify_voicing(voicing, expected)
    if success:
        passed += 1
    else:
        failed += 1

print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"Passed: {passed}/{passed + failed}")
print(f"Failed: {failed}/{passed + failed}")

if failed == 0:
    print("\n✓ All voicings verified successfully!")
else:
    print(f"\n✗ {failed} voicing(s) failed verification")
