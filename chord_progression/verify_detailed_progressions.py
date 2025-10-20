#!/usr/bin/env python3
"""
Detailed analysis of specific progressions across all modes.
"""

import re

# Read the analysis file
with open('lyre_progression_analysis.txt', 'r') as f:
    content = f.read()

modes = ['DORIOS', 'PHRYGIOS', 'LYDIOS', 'MIXOLYDIOS', 'HYPODORIOS', 'HYPOLYDIOS', 'HYPOPHRYGIOS']

print("=" * 130)
print("DETAILED PROGRESSION ANALYSIS - TRADITIONAL MUSIC THEORY VERIFICATION")
print("=" * 130)
print()

# ==============================================================================
# Analyze specific important progressions
# ==============================================================================

progressions_to_check = [
    ('V-I', 'Authentic Cadence (V→I)', 'Descending 5th'),
    ('I-V', 'Half Cadence (I→V)', 'Ascending 5th'),
    ('IV-I', 'Plagal Cadence (IV→I)', 'Ascending 4th'),
    ('I-IV', 'I→IV', 'Descending 5th'),
    ('ii-V', 'ii→V (pre-dominant)', 'Descending 5th'),
    ('V-vi', 'Deceptive Cadence', 'Ascending 2nd'),
    ('vi-ii', 'vi→ii', 'Descending 5th'),
    ('ii-V-I', 'Jazz ii-V-I', 'Circle of 5ths'),
    ('I-IV-V', 'I-IV-V', 'Tonic-Subdominant-Dominant'),
    ('I-V-vi-IV', 'Pop progression', 'Popular pattern'),
]

print("=" * 130)
print("SPECIFIC PROGRESSION COMPLEXITIES BY MODE")
print("=" * 130)
print()

for prog_pattern, name, interval_type in progressions_to_check:
    print(f"\n{name} ({prog_pattern})")
    print(f"Type: {interval_type}")
    print("-" * 130)
    print(f"{'Mode':<15} {'Found':<10} {'Complexity':<15} {'Rank':<10} {'Notes':<50}")
    print("-" * 130)
    
    found_count = 0
    total_complexity = 0
    
    for mode in modes:
        # Search for this progression in the mode's NOTABLE PROGRESSIONS section
        pattern = f'LYRE CHORD PROGRESSION ANALYSIS - {mode}(.*?)(?=LYRE CHORD PROGRESSION ANALYSIS|$)'
        match = re.search(pattern, content, re.DOTALL)
        
        if not match:
            continue
        
        mode_content = match.group(1)
        
        # Try to find in notable progressions
        # Format: "Authentic Cadence (V-I)        - v° - i               (complexity: 68.9291)"
        
        if '-' in prog_pattern:
            # Search pattern for this specific progression
            # Handle both roman numerals with quality markers
            search_str = re.escape(prog_pattern)
            notable_pattern = rf'{search_str}.*?-\s*([^(]+)\(complexity:\s*([\d.]+)\)'
            
            notable_match = re.search(notable_pattern, mode_content, re.IGNORECASE)
            
            if notable_match:
                progression_str = notable_match.group(1).strip()
                complexity = float(notable_match.group(2))
                found_count += 1
                total_complexity += complexity
                
                # Try to find rank in the 2-chord or 3-chord section
                rank_search = re.search(rf'(\d+)\s+{re.escape(progression_str)}.*?{complexity:.4f}', mode_content)
                rank = rank_search.group(1) if rank_search else "?"
                
                notes = ""
                if 'diminished' in progression_str.lower() or '°' in progression_str:
                    notes = "Contains diminished chord"
                
                print(f"{mode:<15} {'Yes':<10} {complexity:<15.4f} {rank:<10} {notes:<50}")
            else:
                print(f"{mode:<15} {'No':<10} {'-':<15} {'-':<10} {'Not found in notable progressions':<50}")
    
    if found_count > 0:
        avg_complexity = total_complexity / found_count
        print("-" * 130)
        print(f"{'AVERAGE':<15} {f'{found_count}/7':<10} {avg_complexity:<15.4f}")

# ==============================================================================
# Compare related progressions
# ==============================================================================

print()
print()
print("=" * 130)
print("COMPARATIVE ANALYSIS: RELATED PROGRESSIONS")
print("=" * 130)
print()

comparisons = [
    {
        'title': 'DESCENDING 5TH vs ASCENDING 5TH',
        'desc': 'V→I (desc 5th) vs I→V (asc 5th)',
        'prog1': 'V-I',
        'prog2': 'I-V',
        'theory': 'V-I should be stronger (lower complexity)'
    },
    {
        'title': 'AUTHENTIC vs PLAGAL',
        'desc': 'V→I vs IV→I',
        'prog1': 'V-I',
        'prog2': 'IV-I',
        'theory': 'V-I should be stronger (lower complexity)'
    },
    {
        'title': 'DESCENDING 5TH: DIFFERENT STARTING POINTS',
        'desc': 'V→I vs IV→I (both desc 5th)',
        'prog1': 'V-I',
        'prog2': 'I-IV',
        'theory': 'V-I should be stronger (resolves to tonic)'
    },
]

for comparison in comparisons:
    print(f"\n{comparison['title']}")
    print(f"{comparison['desc']}")
    print(f"Theory expectation: {comparison['theory']}")
    print("-" * 130)
    print(f"{'Mode':<15} {comparison['prog1']:<20} {comparison['prog2']:<20} {'Difference':<15} {'Theory Met?':<15}")
    print("-" * 130)
    
    pass_count = 0
    total_count = 0
    
    for mode in modes:
        pattern = f'LYRE CHORD PROGRESSION ANALYSIS - {mode}(.*?)(?=LYRE CHORD PROGRESSION ANALYSIS|$)'
        match = re.search(pattern, content, re.DOTALL)
        
        if not match:
            continue
        
        mode_content = match.group(1)
        
        # Find both progressions
        def find_prog(prog_name):
            search_str = re.escape(prog_name)
            notable_pattern = rf'{search_str}.*?-\s*([^(]+)\(complexity:\s*([\d.]+)\)'
            notable_match = re.search(notable_pattern, mode_content, re.IGNORECASE)
            if notable_match:
                return float(notable_match.group(2))
            return None
        
        comp1 = find_prog(comparison['prog1'])
        comp2 = find_prog(comparison['prog2'])
        
        if comp1 is not None and comp2 is not None:
            diff = comp2 - comp1
            passed = comp1 < comp2  # prog1 should be simpler (lower)
            pass_count += passed
            total_count += 1
            
            status = "✓ Yes" if passed else "✗ No"
            
            print(f"{mode:<15} {comp1:<20.4f} {comp2:<20.4f} {diff:<15.4f} {status:<15}")
    
    if total_count > 0:
        print("-" * 130)
        print(f"Result: {pass_count}/{total_count} modes meet theoretical expectation")
        if pass_count == total_count:
            print("✓✓✓ PERFECT: All modes match theory")
        elif pass_count >= total_count * 0.7:
            print("✓ GOOD: Most modes match theory (exceptions likely due to modal variations)")
        else:
            print("⚠ WARNING: Theory not consistently met")

# ==============================================================================
# Circle of Fifths Analysis
# ==============================================================================

print()
print()
print("=" * 130)
print("CIRCLE OF FIFTHS PROGRESSIONS")
print("=" * 130)
print()
print("Moving clockwise (descending 5ths): ii→V→I, vi→ii→V→I, etc.")
print("This is the strongest harmonic motion in traditional theory")
print()

# Look for 3-chord progressions
for mode in modes:
    pattern = f'LYRE CHORD PROGRESSION ANALYSIS - {mode}(.*?)(?=LYRE CHORD PROGRESSION ANALYSIS|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        continue
    
    mode_content = match.group(1)
    
    # Find notable 3-chord progressions
    notable_section = re.search(r'3-chord progressions:(.*?)(?=\n\n|$)', mode_content, re.DOTALL)
    
    if notable_section:
        print(f"\n{mode}:")
        print("-" * 130)
        
        notable_text = notable_section.group(1)
        
        # Parse each notable progression
        prog_pattern = r'([^-]+)-\s*([^(]+)\(complexity:\s*([\d.]+)\)'
        
        for match in re.finditer(prog_pattern, notable_text):
            name = match.group(1).strip()
            progression = match.group(2).strip()
            complexity = float(match.group(3))
            
            # Highlight circle of fifths patterns
            circle_indicators = ['ii-V-I', 'vi-ii-V', 'I-IV-V']
            is_circle = any(indicator in name or indicator.lower() in progression.lower() 
                          for indicator in circle_indicators)
            
            marker = " ★ CIRCLE OF 5THS" if is_circle else ""
            
            print(f"  {name:<30} {progression:<25} {complexity:>10.4f}{marker}")

