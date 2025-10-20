#!/usr/bin/env python3
"""Extract mode characteristics from just intonation analysis."""

import re

with open('lyre_progression_analysis.txt', 'r') as f:
    content = f.read()

modes = ['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS', 'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS']

mode_data = {}

for mode in modes:
    pattern = f'LYRE CHORD PROGRESSION ANALYSIS - {mode}(.*?)(?=LYRE CHORD PROGRESSION ANALYSIS|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        continue
    
    mode_content = match.group(1)
    
    # Get scale pattern
    scale_pattern = re.search(r'Interval Pattern: ([^\n]+)', mode_content)
    semitones_pattern = re.search(r'Scale Degrees \(semitones\): (\[[^\]]+\])', mode_content)
    
    # Get available triads
    triads_section = re.search(r'AVAILABLE TRIADS.*?\n-+\n(.*?)(?=\n-+\n|$)', mode_content, re.DOTALL)
    
    # Get notable progressions
    notable_section = re.search(r'NOTABLE PROGRESSIONS:(.*?)(?=\n\n\n|$)', mode_content, re.DOTALL)
    
    data = {
        'scale_pattern': scale_pattern.group(1) if scale_pattern else None,
        'semitones': semitones_pattern.group(1) if semitones_pattern else None,
        'triads': [],
        'progressions': {}
    }
    
    # Parse triads
    if triads_section:
        triad_lines = triads_section.group(1).strip().split('\n')
        for line in triad_lines:
            # Format: "     i (min): Root position: i[1,3,5]↑"
            triad_match = re.match(r'\s+([ivIV°+]+)\s+\((\w+)\):', line)
            if triad_match:
                numeral = triad_match.group(1)
                quality = triad_match.group(2)
                has_root = 'Root position: NONE' not in line
                data['triads'].append({
                    'numeral': numeral,
                    'quality': quality,
                    'has_root_position': has_root
                })
    
    # Parse progressions
    if notable_section:
        notable_text = notable_section.group(1)
        
        patterns = [
            (r'Authentic Cadence \(V-I\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'V-I'),
            (r'Half Cadence \(I-V\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'I-V'),
            (r'Plagal Cadence \(IV-I\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'IV-I'),
            (r'Deceptive Cadence \(V-vi\)\s+-\s+([^(]+)\(complexity:\s*([\d.]+)\)', 'V-vi'),
        ]
        
        for pattern, name in patterns:
            match = re.search(pattern, notable_text)
            if match:
                progression = match.group(1).strip()
                complexity = float(match.group(2))
                data['progressions'][name] = {
                    'progression': progression,
                    'complexity': complexity
                }
    
    mode_data[mode] = data

# Print in format for MODE_CHARACTERISTICS_SUMMARY.md
for mode in modes:
    data = mode_data[mode]
    print(f"\n{'='*80}")
    print(f"{mode}")
    print(f"{'='*80}")
    print(f"Scale Pattern: {data['scale_pattern']}")
    print(f"Semitones: {data['semitones']}")
    print()
    print("Triads:")
    for triad in data['triads']:
        root_status = "✓ Root position" if triad['has_root_position'] else "✗ Inversions only"
        print(f"  {triad['numeral']:>4} ({triad['quality']:>3}): {root_status}")
    print()
    print("Key Progressions:")
    for name, prog in data['progressions'].items():
        print(f"  {name:<10} {prog['progression']:<20} Complexity: {prog['complexity']:.4f}")

