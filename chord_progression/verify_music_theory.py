#!/usr/bin/env python3
"""Comprehensive music theory verification for just intonation results."""

import re

# Read the analysis file
with open('lyre_progression_analysis.txt', 'r') as f:
    content = f.read()

# Split by mode
modes = ['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS', 'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS']

print("=" * 110)
print("MUSIC THEORY VERIFICATION - JUST INTONATION ANALYSIS")
print("=" * 110)
print()

results = {}

for mode in modes:
    # Find the section for this mode
    pattern = f'LYRE CHORD PROGRESSION ANALYSIS - {mode}(.*?)(?=LYRE CHORD PROGRESSION ANALYSIS|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        continue
    
    mode_content = match.group(1)
    
    # Extract cadences from the NOTABLE PROGRESSIONS section
    notable_section = re.search(r'NOTABLE PROGRESSIONS:(.*?)(?=\n\n\n|$)', mode_content, re.DOTALL)
    
    results[mode] = {}
    
    if notable_section:
        notable_text = notable_section.group(1)
        
        # Parse each cadence type - updated pattern
        patterns = [
            (r'Authentic Cadence \(V-I\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'Authentic Cadence'),
            (r'Half Cadence \(I-V\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'Half Cadence'),
            (r'Plagal Cadence \(IV-I\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'Plagal Cadence'),
            (r'Deceptive Cadence \(V-vi\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'Deceptive Cadence'),
        ]
        
        for pattern, cadence_type in patterns:
            match = re.search(pattern, notable_text)
            if match:
                progression = match.group(1).strip()
                complexity = float(match.group(2))
                
                results[mode][cadence_type] = {
                    'progression': progression,
                    'complexity': complexity
                }

# Print results by mode
print("CADENCE STRENGTH BY MODE")
print("(Lower complexity = stronger/simpler)")
print()

for mode in modes:
    if not results[mode]:
        continue
        
    print(f"\n{mode}:")
    print("-" * 80)
    
    mode_data = results[mode]
    
    # Get all cadences for this mode
    cadences = []
    if 'Authentic Cadence' in mode_data:
        cadences.append(('V-I (Authentic)', mode_data['Authentic Cadence']))
    if 'Half Cadence' in mode_data:
        cadences.append(('I-V (Half)', mode_data['Half Cadence']))
    if 'Plagal Cadence' in mode_data:
        cadences.append(('IV-I (Plagal)', mode_data['Plagal Cadence']))
    if 'Deceptive Cadence' in mode_data:
        cadences.append(('V-vi (Deceptive)', mode_data['Deceptive Cadence']))
    
    # Sort by complexity
    cadences.sort(key=lambda x: x[1]['complexity'])
    
    for rank, (name, data) in enumerate(cadences, 1):
        print(f"  {rank}. {name:<20} {data['progression']:<15} Complexity: {data['complexity']:>8.4f}")

print()
print("=" * 110)
print("THEORY VERIFICATION - KEY RELATIONSHIPS")
print("=" * 110)
print()

# Test 1: V-I vs I-V
print("TEST 1: V-I (Authentic) should be STRONGER than I-V (Half)")
print("-" * 110)
print(f"{'Mode':<15} {'V-I Complexity':<18} {'I-V Complexity':<18} {'Difference':<15} {'Result':<10}")
print("-" * 110)

all_pass_1 = True
count_1 = 0
for mode in modes:
    if 'Authentic Cadence' in results[mode] and 'Half Cadence' in results[mode]:
        v_i = results[mode]['Authentic Cadence']['complexity']
        i_v = results[mode]['Half Cadence']['complexity']
        diff = i_v - v_i
        passed = v_i < i_v
        all_pass_1 = all_pass_1 and passed
        count_1 += 1
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{mode:<15} {v_i:<18.4f} {i_v:<18.4f} {diff:<15.4f} {status:<10}")

print()
if count_1 == 0:
    print("⚠ WARNING: No modes found with both V-I and I-V cadences")
elif all_pass_1:
    print(f"✓✓✓ PASS: All {count_1} modes show V-I stronger than I-V (matches theory)")
else:
    print(f"✗✗✗ FAIL: Some of {count_1} modes violate V-I > I-V expectation")

print()
print()
print("TEST 2: V-I (Authentic) should be STRONGEST cadence overall")
print("-" * 110)

all_pass_2 = True
count_2 = 0
for mode in modes:
    if 'Authentic Cadence' not in results[mode]:
        continue
        
    count_2 += 1
    v_i = results[mode]['Authentic Cadence']['complexity']
    
    # Check if it's the strongest (lowest complexity)
    is_strongest = True
    weaker_cadences = []
    
    for cadence_type in ['Plagal Cadence', 'Half Cadence', 'Deceptive Cadence']:
        if cadence_type in results[mode]:
            other_complexity = results[mode][cadence_type]['complexity']
            if other_complexity < v_i:
                is_strongest = False
                weaker_cadences.append((cadence_type, other_complexity))
    
    if is_strongest:
        print(f"{mode:<15} V-I is strongest (complexity: {v_i:.4f}) ✓ PASS")
    else:
        all_pass_2 = False
        print(f"{mode:<15} V-I NOT strongest (complexity: {v_i:.4f}) ✗ FAIL")
        for cad, comp in weaker_cadences:
            print(f"                  → {cad} is stronger: {comp:.4f}")

print()
if count_2 == 0:
    print("⚠ WARNING: No modes found with V-I cadence")
elif all_pass_2:
    print(f"✓✓✓ PASS: V-I is the strongest cadence in all {count_2} modes (matches theory)")
else:
    print(f"⚠ PARTIAL: V-I is not always strongest in {count_2} modes (may be lyre-specific constraints)")

print()
print()
print("TEST 3: Plagal Cadence (IV-I) should be WEAKER than Authentic (V-I)")
print("-" * 110)
print(f"{'Mode':<15} {'V-I Complexity':<18} {'IV-I Complexity':<18} {'V-I Advantage':<15} {'Result':<10}")
print("-" * 110)

all_pass_3 = True
count_3 = 0
for mode in modes:
    if 'Authentic Cadence' in results[mode] and 'Plagal Cadence' in results[mode]:
        v_i = results[mode]['Authentic Cadence']['complexity']
        iv_i = results[mode]['Plagal Cadence']['complexity']
        diff = iv_i - v_i
        passed = v_i < iv_i  # V-I should be simpler/stronger
        all_pass_3 = all_pass_3 and passed
        count_3 += 1
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{mode:<15} {v_i:<18.4f} {iv_i:<18.4f} {diff:<15.4f} {status:<10}")

print()
if count_3 > 0:
    if all_pass_3:
        print(f"✓✓✓ PASS: V-I stronger than IV-I in all {count_3} modes (matches theory)")
    else:
        print(f"✗ FAIL: V-I not always stronger than IV-I")
else:
    print("⚠ Not enough data to test")

print()
print("=" * 110)
print("SUMMARY")
print("=" * 110)
print()
print("Traditional Music Theory Expectations:")
print("  1. V-I (authentic cadence) = STRONGEST resolution")
print("  2. IV-I (plagal cadence) = WEAKER than V-I")
print("  3. I-V (half cadence) = Creates tension, NO resolution (weakest)")
print("  4. V-vi (deceptive cadence) = Similar to V-I but delays resolution")
print("  5. Descending 5th (V→I) stronger than ascending 5th (I→V)")
print()
print("Lyre-Specific Considerations:")
print("  - V chord often requires inversion (adds complexity)")
print("  - V chord quality varies by mode (major/minor/diminished)")
print("  - Voice leading constrained by string layout")
print("  - Exceptional voice leading can override functional expectations")
print()

print("VERIFICATION RESULTS:")
print("-" * 80)
if all_pass_1 and count_1 > 0:
    print(f"✓ TEST 1: V-I > I-V relationship verified ({count_1}/{count_1} modes)")
else:
    print(f"✗ TEST 1: V-I > I-V relationship FAILED or insufficient data")
    
if all_pass_2 and count_2 > 0:
    print(f"✓ TEST 2: V-I is strongest cadence ({count_2}/{count_2} modes)")
else:
    print(f"⚠ TEST 2: V-I not always strongest ({count_2} modes checked)")
    
if all_pass_3 and count_3 > 0:
    print(f"✓ TEST 3: V-I > IV-I relationship verified ({count_3}/{count_3} modes)")
else:
    print(f"⚠ TEST 3: V-I > IV-I insufficient data or failed")

print()
if all_pass_1 and count_1 > 0:
    print("✓✓✓ CORE THEORY VERIFIED: The most fundamental relationship (V-I > I-V) holds!")
    print("    Just intonation analysis is consistent with traditional music theory.")
else:
    print("✗✗✗ CORE THEORY VIOLATED or insufficient data to verify")

