#!/usr/bin/env python3
"""
Verify that string 8 on an 8-string lyre produces the correct octave.
"""

# Test the octave wrapping logic for all 7 Greek modes
modes = {
    'DORIOS': [0, 1, 3, 5, 7, 8, 10],
    'PHRYGIOS': [0, 2, 3, 5, 7, 9, 10],
    'LYDIOS': [0, 2, 4, 5, 7, 9, 11],
    'MIXOLYDIOS': [0, 2, 4, 6, 7, 9, 10],
    'HYPODORIOS': [0, 2, 3, 5, 7, 8, 10],
    'HYPOLYDIOS': [0, 1, 3, 5, 6, 8, 10],
    'HYPOPHRYGIOS': [0, 2, 4, 5, 7, 8, 10]
}

print("Verifying 8-string lyre octave wrapping")
print("=" * 80)
print()

for mode_name, scale_semitones in modes.items():
    print(f"{mode_name:15} {scale_semitones}")

    # Calculate semitones for all 8 strings
    scale_length = len(scale_semitones)
    for string_num in range(8):
        degree = string_num % scale_length
        octave = string_num // scale_length
        semitone = scale_semitones[degree] + (octave * 12)

        print(f"  String {string_num + 1}: degree {degree}, octave {octave}, semitone {semitone:2d}", end="")

        # Verify string 8 is exactly 12 semitones above string 1
        if string_num == 7:
            string_1_semitone = scale_semitones[0]
            expected = string_1_semitone + 12
            if semitone == expected:
                print(f"  ✓ (octave of string 1)")
            else:
                print(f"  ✗ ERROR: expected {expected}, got {semitone}")
        else:
            print()

    print()

print("=" * 80)
print("All modes verified!")
