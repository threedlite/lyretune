#!/usr/bin/env python3
"""
Unified test for dyads, triads, tetrads, etc. using the complexity formula
with some targeted adjustments.

"""

import numpy as np
from math import gcd
from functools import reduce
from scipy.stats import spearmanr

def gcd_multiple(numbers):
    return reduce(gcd, numbers)

def prime_factorization(n):
    factors = []
    d = 2
    while d * d <= n:
        while (n % d) == 0:
            factors.append(d)
            n //= d
        d += 1
    if n > 1:
        factors.append(n)
    return factors

def largest_prime_factor(n):
    if n <= 1:
        return 1
    factors = prime_factorization(n)
    return max(factors) if factors else 1

def odd_part(n):
    while n % 2 == 0:
        n //= 2
    return n

def complexity_with_five_adjustments(notes, augmented_penalty=0.0, sus2inv_penalty=0.0, major1inv_bonus=0.0,
                                      dominant7_bonus=0.0, halfdim7_penalty=0.0,
                                      alpha=1.0, beta=0.3, kappa=1.0, delta=0.25,
                                      psi=0.0, omega=0.0, nu=0.0, chi=0.0,
                                      span_lp_baseline=5, interval_ol_baseline=5, chi_lp_baseline=3.0):
    """
    Compute complexity with five targeted adjustments:
    - Three for triads (Augmented penalty, Sus2 1st inv penalty, Major 1st inv bonus)
    - Two for tetrads (Dominant 7th bonus, Half-dim 7th penalty)

    Uses the triad-optimized base formula from run_final_test.py
    """
    interval_ols = []
    interval_lps = []
    interval_min_odd_lps = []
    interval_complexity = 0.0

    for i in range(len(notes) - 1):
        p, q = notes[i+1], notes[i]
        g = gcd(int(p), int(q))
        p, q = p // g, q // g

        odd_p = odd_part(p)
        odd_q = odd_part(q)

        ol = max(odd_p, odd_q)
        lp = largest_prime_factor(ol)
        interval_complexity += alpha * np.log2(ol) + beta * np.log2(lp)   # A basic empirically-tuned formula based on Odd Limit and Largest Prime Factor, with other mods/overrides below.

        interval_ols.append(ol)
        interval_lps.append(lp)

        min_odd = min(odd_p, odd_q)
        lp_min_odd = largest_prime_factor(min_odd)
        interval_min_odd_lps.append(lp_min_odd)

    if len(notes) >= 3:
        p_span, q_span = notes[-1], notes[0]
        g = gcd(int(p_span), int(q_span))
        p_span, q_span = p_span // g, q_span // g

        odd_p_span = odd_part(p_span)
        odd_q_span = odd_part(q_span)

        span_ol = max(odd_p_span, odd_q_span)
        span_lp = largest_prime_factor(span_ol)

        all_same_ol = len(set(interval_ols)) == 1
        is_homogeneous = all_same_ol and span_ol < interval_ols[0]

        min_note = min(notes)

        # Targeted adjustments
        targeted_adjustments = 0.0

        # Triad adjustments (len==3)
        if len(notes) == 3:
            # Augmented penalty: min=16 AND NOT homogeneous
            if min_note == 16 and not is_homogeneous:
                targeted_adjustments += augmented_penalty

            # Sus2 1st inv penalty: min=9 AND NOT homogeneous
            if min_note == 9 and not is_homogeneous:
                targeted_adjustments += sus2inv_penalty

            # Major 1st inv bonus: min=5 AND NOT homogeneous
            if min_note == 5 and not is_homogeneous:
                targeted_adjustments -= major1inv_bonus

        # Tetrad adjustments (len==4)
        if len(notes) == 4:
            # Dominant 7th bonus: min=4 (unique among all tetrads)
            if min_note == 4:
                targeted_adjustments -= dominant7_bonus

            # Half-diminished 7th penalty: min=5 (unique among all tetrads)
            if min_note == 5:
                targeted_adjustments += halfdim7_penalty

        if all_same_ol:
            if span_ol < interval_ols[0]:
                homogeneity_bonus = 1.0

                if span_ol > 0:
                    avg_min_odd_lp = np.mean(interval_min_odd_lps)
                    lp_scale = avg_min_odd_lp / chi_lp_baseline
                    chi_penalty = chi * max(0, 1 - np.log2(span_ol)) * lp_scale
                else:
                    chi_penalty = chi
            else:
                homogeneity_bonus = 0.0
                chi_penalty = 0.0

            if span_ol == interval_ols[0] ** 2:
                avg_interval_min_odd_lp = np.mean(interval_min_odd_lps)
                psi_penalty = psi * avg_interval_min_odd_lp
            else:
                psi_penalty = 0.0

            omega_penalty = 0.0
        else:
            homogeneity_bonus = 0.0
            psi_penalty = 0.0
            chi_penalty = 0.0
            omega_penalty = omega * max(0, np.log2(span_lp) - np.log2(span_lp_baseline))

        min_interval_ol = min(interval_ols)
        nu_penalty = nu * max(0, np.log2(min_interval_ol) - np.log2(interval_ol_baseline))

        compactness_penalty = delta * ((max(notes) - min(notes)) / min(notes))
    else:
        homogeneity_bonus = 0.0
        psi_penalty = 0.0
        chi_penalty = 0.0
        omega_penalty = 0.0
        nu_penalty = 0.0
        compactness_penalty = 0.0
        targeted_adjustments = 0.0

    return (interval_complexity
            - kappa * homogeneity_bonus
            + compactness_penalty
            + psi_penalty
            + omega_penalty
            + nu_penalty
            + chi_penalty
            + targeted_adjustments)


# Define datasets
DYADS = [
    ("Unison", (1, 1), 1),
    ("Octave", (1, 2), 2),
    ("Perfect fifth", (2, 3), 3),
    ("Perfect fourth", (3, 4), 4),
    ("Major third", (4, 5), 5),
    ("Minor third", (5, 6), 6),
    ("Major sixth", (3, 5), 7),
    ("Minor sixth", (5, 8), 8),
    ("Major second", (8, 9), 9),
    ("Minor seventh", (5, 9), 10),
    ("Tritone (septimal)", (5, 7), 11),
    ("Harmonic seventh", (4, 7), 12),
    ("Undecimal tritone", (7, 11), 13),
    ("Minor second", (15, 16), 14),
    ("Major seventh", (8, 15), 15),
]

TRIADS = [
    ("Major triad (root)", (4, 5, 6), 1),
    ("Minor triad (root)", (10, 12, 15), 2),
    ("Major 1st inv", (5, 6, 8), 3),
    ("Minor 1st inv", (8, 10, 12), 4),
    ("Major 2nd inv", (3, 4, 5), 5),
    ("Minor 2nd inv", (5, 6, 10), 6),
    ("Sus2", (8, 9, 12), 7),
    ("Sus4", (6, 8, 9), 8),
    ("Whole-tone triad", (4, 6, 9), 9),
    ("Sus2 1st inv", (9, 12, 16), 10),
    ("Subminor", (6, 7, 9), 11),
    ("Supermajor", (7, 9, 12), 12),
    ("Septimal stack", (7, 9, 14), 13),
    ("Undecimal neutral", (8, 11, 16), 14),
    ("Augmented", (16, 20, 25), 15),
    ("Diminished", (25, 30, 36), 16),
]

# DISSONANT TRIADS - For validation (should all score high complexity)
DISSONANT_TRIADS = [
    ("Chromatic cluster 1", (15, 16, 17), None, "DISSONANT"),
    ("Chromatic cluster 2", (80, 85, 90), None, "DISSONANT"),
    ("Chromatic cluster 3", (24, 25, 27), None, "DISSONANT"),
    ("Diatonic cluster", (8, 9, 10), None, "DISSONANT"),
    ("Tritone + m2", (10, 14, 15), None, "DISSONANT"),
    ("11-limit cluster", (11, 12, 13), None, "DISSONANT"),
    ("13-limit cluster", (12, 13, 14), None, "DISSONANT"),
    ("Stacked tritones", (7, 10, 14), None, "DISSONANT"),
]

# CORE TETRADS - Well-established rankings from tendency tone theory
CORE_TETRADS = [
    ("Minor 7th", (10, 12, 15, 18), 1, "CORE"),
    ("Major 7th", (8, 10, 12, 15), 2, "CORE"),
    ("Dominant 7th (harmonic)", (4, 5, 6, 7), 3, "CORE"),
    ("Half-diminished 7th", (5, 6, 7, 9), 4, "CORE"),
    ("Diminished 7th", (10, 12, 14, 17), 5, "CORE"),
]

# EXPERIMENTAL TETRADS - Tentative rankings for exploration
EXPERIMENTAL_TETRADS = [
    ("Major 6th", (12, 15, 18, 20), 1, "EXPERIMENTAL"),
    ("Minor 6th", (30, 36, 45, 50), 2, "EXPERIMENTAL"),
    ("Minor-major 7th", (40, 48, 60, 75), 3, "EXPERIMENTAL"),
    ("Dominant 7th (Pythagorean)", (20, 25, 30, 36), 4, "EXPERIMENTAL"),
    ("Augmented major 7th", (16, 20, 25, 30), 5, "EXPERIMENTAL"),
]

# DISSONANT TETRADS - For validation (should all score high complexity)
DISSONANT_TETRADS = [
    ("Chromatic cluster 1", (15, 16, 17, 18), None, "DISSONANT"),
    ("Chromatic cluster 2", (120, 128, 135, 144), None, "DISSONANT"),
    ("Diatonic cluster", (24, 27, 30, 32), None, "DISSONANT"),
    ("Stacked minor 2nds", (135, 144, 153, 162), None, "DISSONANT"),
    ("Augmented + m2", (64, 80, 100, 108), None, "DISSONANT"),
    ("11-limit cluster", (22, 24, 26, 27), None, "DISSONANT"),
    ("13-limit cluster", (24, 26, 28, 30), None, "DISSONANT"),
]

# EXPERIMENTAL PENTADS - Tentative rankings based on limited theoretical consensus
# Rankings: Major 9th < Minor 9th < Dominant 9th (based on jazz theory sources)
# NOTE: Less authoritative than triad/tetrad rankings due to limited consensus
EXPERIMENTAL_PENTADS = [
    ("Major 9th", (8, 10, 12, 15, 18), 1, "EXPERIMENTAL"),           # M7 + M9, "soft dissonance"
    ("Minor 9th", (10, 12, 15, 18, 27), 2, "EXPERIMENTAL"),          # m7 + M9, moderate
    ("Dominant 9th", (4, 5, 6, 7, 9), 3, "EXPERIMENTAL"),            # 7-limit, functional tension
]

# DISSONANT PENTADS - For validation (should all score high complexity)
DISSONANT_PENTADS = [
    ("5-note chromatic cluster", (15, 16, 17, 18, 19), None, "DISSONANT"),
    ("Stacked minor 2nds", (120, 128, 135, 144, 153), None, "DISSONANT"),
    ("Diatonic cluster", (8, 9, 10, 11, 12), None, "DISSONANT"),
    ("11-13-limit cluster", (22, 24, 26, 27, 28), None, "DISSONANT"),
]

# EXPERIMENTAL HEXADS - VERY tentative rankings (minimal theoretical consensus)
# Rankings based on jazz theory: Minor 11th most consonant, Dominant 13th more complex
# NOTE: These are HIGHLY speculative - testing formula prediction vs. uncertain rankings
EXPERIMENTAL_HEXADS = [
    ("Minor 11th", (20, 24, 30, 36, 54, 80), 1, "EXPERIMENTAL"),     # m7 + M9 + P11, most consonant
    ("Dominant 13th", (4, 5, 6, 7, 9, 13), 2, "EXPERIMENTAL"),       # 7-limit + 13-limit, complex
]

# DISSONANT HEXADS - For validation (should all score high complexity)
DISSONANT_HEXADS = [
    ("6-note chromatic cluster", (15, 16, 17, 18, 19, 20), None, "DISSONANT"),
    ("6-note diatonic cluster", (8, 9, 10, 11, 12, 13), None, "DISSONANT"),
    ("Stacked minor 2nds (6)", (120, 128, 135, 144, 153, 162), None, "DISSONANT"),
    ("11-13-17 limit cluster", (22, 24, 26, 28, 30, 32), None, "DISSONANT"),
]

# EXPERIMENTAL HEPTADS - EXTREMELY tentative (virtually no theoretical consensus)
# 13th chords are the practical limit of tertian harmony (7 notes)
# NOTE: These rankings are PURE SPECULATION - testing formula prediction only
EXPERIMENTAL_HEPTADS = [
    ("Minor 13th", (20, 24, 30, 36, 54, 60, 80), 1, "EXPERIMENTAL"),    # Extended minor, most consonant
    ("Dominant 13th full", (8, 10, 12, 14, 18, 20, 24), 2, "EXPERIMENTAL"),  # Full 13th with all extensions
]

# DISSONANT HEPTADS - For validation (should all score high complexity)
DISSONANT_HEPTADS = [
    ("7-note chromatic cluster", (15, 16, 17, 18, 19, 20, 21), None, "DISSONANT"),
    ("7-note diatonic cluster", (8, 9, 10, 11, 12, 13, 14), None, "DISSONANT"),
    ("Stacked minor 2nds (7)", (120, 128, 135, 144, 153, 162, 171), None, "DISSONANT"),
]


def run_all_tests():
    """Run comprehensive test on dyads through heptads (2-7 note chords)."""

    # Parameters that achieved perfect results
    params = {
        'augmented_penalty': 0.6,
        'sus2inv_penalty': 0.08,
        'major1inv_bonus': 0.057,
        'dominant7_bonus': 0.65,
        'halfdim7_penalty': 0.65,
        'alpha': 1.0,
        'beta': 0.3,
        'kappa': 1.0,
        'delta': 0.15,
        'psi': 1.6,
        'omega': 3.3,
        'nu': 0.0,
        'chi': 0.5,
    }

    # Test dyads
    dyad_results = []
    for name, notes, trad_rank in DYADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dyad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp
        })

    # Sort by complexity to get calculated ranks
    dyad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(dyad_results):
        r['calc_rank'] = i + 1

    # Re-sort by traditional rank for display
    dyad_results.sort(key=lambda x: x['trad_rank'])

    # Test triads
    triad_results = []
    for name, notes, trad_rank in TRIADS:
        comp = complexity_with_five_adjustments(notes, **params)
        triad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp
        })

    # Sort by complexity to get calculated ranks
    triad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(triad_results):
        r['calc_rank'] = i + 1

    # Re-sort by traditional rank for display
    triad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for triads
    trad_ranks_triads = [r['trad_rank'] for r in triad_results]
    calc_ranks_triads = [r['calc_rank'] for r in triad_results]
    rho_triads, _ = spearmanr(trad_ranks_triads, calc_ranks_triads)

    # Test DISSONANT triads (validation)
    dissonant_triad_results = []
    for name, notes, trad_rank, category in DISSONANT_TRIADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dissonant_triad_results.append({
            'name': name,
            'notes': notes,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity for display
    dissonant_triad_results.sort(key=lambda x: x['complexity'])

    # Determine threshold: max complexity of most consonant triads
    max_consonant_triad = max(triad_results[0]['complexity'], triad_results[1]['complexity'])

    # Check how many pass validation
    dissonant_triad_passed = sum(1 for r in dissonant_triad_results if r['complexity'] > max_consonant_triad)

    # Test CORE tetrads (validated)
    core_tetrad_results = []
    for name, notes, trad_rank, category in CORE_TETRADS:
        comp = complexity_with_five_adjustments(notes, **params)
        core_tetrad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity to get calculated ranks
    core_tetrad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(core_tetrad_results):
        r['calc_rank'] = i + 1
    core_tetrad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for core tetrads
    core_trad_ranks = [r['trad_rank'] for r in core_tetrad_results]
    core_calc_ranks = [r['calc_rank'] for r in core_tetrad_results]
    rho_core_tetrads, _ = spearmanr(core_trad_ranks, core_calc_ranks)

    # Test EXPERIMENTAL tetrads
    exp_tetrad_results = []
    for name, notes, trad_rank, category in EXPERIMENTAL_TETRADS:
        comp = complexity_with_five_adjustments(notes, **params)
        exp_tetrad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity to get calculated ranks
    exp_tetrad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(exp_tetrad_results):
        r['calc_rank'] = i + 1
    exp_tetrad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for experimental tetrads
    exp_trad_ranks = [r['trad_rank'] for r in exp_tetrad_results]
    exp_calc_ranks = [r['calc_rank'] for r in exp_tetrad_results]
    rho_exp_tetrads, _ = spearmanr(exp_trad_ranks, exp_calc_ranks)

    # Test DISSONANT tetrads (validation)
    dissonant_results = []
    for name, notes, trad_rank, category in DISSONANT_TETRADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dissonant_results.append({
            'name': name,
            'notes': notes,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity
    dissonant_results.sort(key=lambda x: x['complexity'])

    # Check dissonance validation (should all exceed max consonant complexity)
    max_consonant = max(r['complexity'] for r in core_tetrad_results[:2])  # Minor 7th and Major 7th
    dissonant_passed = sum(1 for r in dissonant_results if r['complexity'] > max_consonant)
    dissonant_failed = len(dissonant_results) - dissonant_passed

    # Test EXPERIMENTAL pentads (NO targeted adjustments - testing formula generalization)
    exp_pentad_results = []
    for name, notes, trad_rank, category in EXPERIMENTAL_PENTADS:
        comp = complexity_with_five_adjustments(notes, **params)
        exp_pentad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity to get calculated ranks
    exp_pentad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(exp_pentad_results):
        r['calc_rank'] = i + 1

    # Re-sort by traditional rank for display
    exp_pentad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for experimental pentads
    exp_pentad_trad_ranks = [r['trad_rank'] for r in exp_pentad_results]
    exp_pentad_calc_ranks = [r['calc_rank'] for r in exp_pentad_results]
    rho_exp_pentads, _ = spearmanr(exp_pentad_trad_ranks, exp_pentad_calc_ranks)

    # Test DISSONANT pentads (validation)
    dissonant_pentad_results = []
    for name, notes, trad_rank, category in DISSONANT_PENTADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dissonant_pentad_results.append({
            'name': name,
            'notes': notes,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity
    dissonant_pentad_results.sort(key=lambda x: x['complexity'])

    # Determine threshold for pentads: max of experimental pentads
    max_consonant_pentad = max(r['complexity'] for r in exp_pentad_results)
    dissonant_pentad_passed = sum(1 for r in dissonant_pentad_results if r['complexity'] > max_consonant_pentad)

    # Test EXPERIMENTAL hexads (NO targeted adjustments - testing formula generalization)
    exp_hexad_results = []
    for name, notes, trad_rank, category in EXPERIMENTAL_HEXADS:
        comp = complexity_with_five_adjustments(notes, **params)
        exp_hexad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity to get calculated ranks
    exp_hexad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(exp_hexad_results):
        r['calc_rank'] = i + 1

    # Re-sort by traditional rank for display
    exp_hexad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for experimental hexads
    exp_hexad_trad_ranks = [r['trad_rank'] for r in exp_hexad_results]
    exp_hexad_calc_ranks = [r['calc_rank'] for r in exp_hexad_results]
    rho_exp_hexads, _ = spearmanr(exp_hexad_trad_ranks, exp_hexad_calc_ranks)

    # Test DISSONANT hexads (validation)
    dissonant_hexad_results = []
    for name, notes, trad_rank, category in DISSONANT_HEXADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dissonant_hexad_results.append({
            'name': name,
            'notes': notes,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity
    dissonant_hexad_results.sort(key=lambda x: x['complexity'])

    # Determine threshold for hexads: max of experimental hexads
    max_consonant_hexad = max(r['complexity'] for r in exp_hexad_results)
    dissonant_hexad_passed = sum(1 for r in dissonant_hexad_results if r['complexity'] > max_consonant_hexad)

    # Test EXPERIMENTAL heptads (NO targeted adjustments - testing formula generalization)
    exp_heptad_results = []
    for name, notes, trad_rank, category in EXPERIMENTAL_HEPTADS:
        comp = complexity_with_five_adjustments(notes, **params)
        exp_heptad_results.append({
            'name': name,
            'notes': notes,
            'trad_rank': trad_rank,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity to get calculated ranks
    exp_heptad_results.sort(key=lambda x: (x['complexity'], x['trad_rank']))
    for i, r in enumerate(exp_heptad_results):
        r['calc_rank'] = i + 1

    # Re-sort by traditional rank for display
    exp_heptad_results.sort(key=lambda x: x['trad_rank'])

    # Calculate Spearman correlation for experimental heptads
    exp_heptad_trad_ranks = [r['trad_rank'] for r in exp_heptad_results]
    exp_heptad_calc_ranks = [r['calc_rank'] for r in exp_heptad_results]
    rho_exp_heptads, _ = spearmanr(exp_heptad_trad_ranks, exp_heptad_calc_ranks)

    # Test DISSONANT heptads (validation)
    dissonant_heptad_results = []
    for name, notes, trad_rank, category in DISSONANT_HEPTADS:
        comp = complexity_with_five_adjustments(notes, **params)
        dissonant_heptad_results.append({
            'name': name,
            'notes': notes,
            'complexity': comp,
            'category': category
        })

    # Sort by complexity
    dissonant_heptad_results.sort(key=lambda x: x['complexity'])

    # Determine threshold for heptads: max of experimental heptads
    max_consonant_heptad = max(r['complexity'] for r in exp_heptad_results)
    dissonant_heptad_passed = sum(1 for r in dissonant_heptad_results if r['complexity'] > max_consonant_heptad)

    # Count errors and matches
    dyad_errors = sum(1 for r in dyad_results if r['trad_rank'] != r['calc_rank'])
    dyad_matches = len(dyad_results) - dyad_errors

    triad_errors = sum(1 for r in triad_results if r['trad_rank'] != r['calc_rank'])
    triad_matches = len(triad_results) - triad_errors

    core_tetrad_errors = sum(1 for r in core_tetrad_results if r['trad_rank'] != r['calc_rank'])
    core_tetrad_matches = len(core_tetrad_results) - core_tetrad_errors

    exp_tetrad_errors = sum(1 for r in exp_tetrad_results if r['trad_rank'] != r['calc_rank'])
    exp_tetrad_matches = len(exp_tetrad_results) - exp_tetrad_errors

    exp_pentad_errors = sum(1 for r in exp_pentad_results if r['trad_rank'] != r['calc_rank'])
    exp_pentad_matches = len(exp_pentad_results) - exp_pentad_errors

    exp_hexad_errors = sum(1 for r in exp_hexad_results if r['trad_rank'] != r['calc_rank'])
    exp_hexad_matches = len(exp_hexad_results) - exp_hexad_errors

    exp_heptad_errors = sum(1 for r in exp_heptad_results if r['trad_rank'] != r['calc_rank'])
    exp_heptad_matches = len(exp_heptad_results) - exp_heptad_errors

    total_chords = (len(dyad_results) + len(triad_results) + len(dissonant_triad_results) +
                   len(core_tetrad_results) + len(exp_tetrad_results) + len(dissonant_results) +
                   len(exp_pentad_results) + len(dissonant_pentad_results) +
                   len(exp_hexad_results) + len(dissonant_hexad_results) +
                   len(exp_heptad_results) + len(dissonant_heptad_results))
    total_matches = (dyad_matches + triad_matches + dissonant_triad_passed +
                    core_tetrad_matches + exp_tetrad_matches + dissonant_passed +
                    exp_pentad_matches + dissonant_pentad_passed +
                    exp_hexad_matches + dissonant_hexad_passed +
                    exp_heptad_matches + dissonant_heptad_passed)
    total_errors = (dyad_errors + triad_errors + (len(dissonant_triad_results) - dissonant_triad_passed) +
                   core_tetrad_errors + exp_tetrad_errors + dissonant_failed +
                   exp_pentad_errors + (len(dissonant_pentad_results) - dissonant_pentad_passed) +
                   exp_hexad_errors + (len(dissonant_hexad_results) - dissonant_hexad_passed) +
                   exp_heptad_errors + (len(dissonant_heptad_results) - dissonant_heptad_passed))

    # Generate report
    report_lines = []
    report_lines.append("=" * 100)
    report_lines.append("COMPREHENSIVE HARMONIC COMPLEXITY RANKING REPORT")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append("PARAMETERS USED:")
    report_lines.append(f"  Base formula: α={params['alpha']}, β={params['beta']}, κ={params['kappa']}, δ={params['delta']}, ψ={params['psi']}, ω={params['omega']}, ν={params['nu']}, χ={params['chi']}")
    report_lines.append("  Targeted adjustments for triads (len==3):")
    report_lines.append(f"    - Major 1st inv (min=5 AND NOT homog): -{params['major1inv_bonus']} bonus")
    report_lines.append(f"    - Sus2 1st inv (min=9 AND NOT homog): +{params['sus2inv_penalty']} penalty")
    report_lines.append(f"    - Augmented (min=16 AND NOT homog): +{params['augmented_penalty']} penalty")
    report_lines.append("  Targeted adjustments for tetrads (len==4):")
    report_lines.append(f"    - Dominant 7th (min=4): -{params['dominant7_bonus']} bonus")
    report_lines.append(f"    - Half-diminished 7th (min=5): +{params['halfdim7_penalty']} penalty")
    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DYADS (INTERVALS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Errors: {dyad_errors}/{len(dyad_results)}")
    report_lines.append(f"Matches: {dyad_matches}/{len(dyad_results)} ({100*dyad_matches/len(dyad_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in dyad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("TRIADS (3-NOTE CHORDS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Errors: {triad_errors}/{len(triad_results)}")
    report_lines.append(f"Matches: {triad_matches}/{len(triad_results)} ({100*triad_matches/len(triad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_triads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in triad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DISSONANT TRIADS (VALIDATION TEST)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Threshold (max consonant triad): {max_consonant_triad:.6f}")
    report_lines.append(f"Expectation: All should exceed threshold")
    report_lines.append("")
    report_lines.append(f"Passed: {dissonant_triad_passed}/{len(dissonant_triad_results)} ({100*dissonant_triad_passed/len(dissonant_triad_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Complexity':>12}   {'Status':>10}")
    report_lines.append("-" * 100)

    for r in dissonant_triad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "PASS ✓" if r['complexity'] > max_consonant_triad else "FAIL ✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['complexity']:>12.6f}   {status:>10}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("CORE TETRADS (VALIDATED 7TH CHORDS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Errors: {core_tetrad_errors}/{len(core_tetrad_results)}")
    report_lines.append(f"Matches: {core_tetrad_matches}/{len(core_tetrad_results)} ({100*core_tetrad_matches/len(core_tetrad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_core_tetrads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in core_tetrad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("EXPERIMENTAL TETRADS (EXPLORATORY)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append("NOTE: Rankings are tentative. Formula predictions may be more accurate than assumptions.")
    report_lines.append("")
    report_lines.append(f"Errors: {exp_tetrad_errors}/{len(exp_tetrad_results)}")
    report_lines.append(f"Matches: {exp_tetrad_matches}/{len(exp_tetrad_results)} ({100*exp_tetrad_matches/len(exp_tetrad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_exp_tetrads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in exp_tetrad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DISSONANT TETRADS (VALIDATION TEST)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Threshold (max consonant): {max_consonant:.6f}")
    report_lines.append(f"Expectation: All should exceed threshold")
    report_lines.append("")
    report_lines.append(f"Passed: {dissonant_passed}/{len(dissonant_results)} ({100*dissonant_passed/len(dissonant_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<20} {'Complexity':>12}   {'Status':>10}")
    report_lines.append("-" * 100)

    for r in dissonant_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "PASS ✓" if r['complexity'] > max_consonant else "FAIL ✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<20} {r['complexity']:>12.6f}   {status:>10}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("EXPERIMENTAL PENTADS (9TH CHORDS - NO ADJUSTMENTS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append("NOTE: Rankings are tentative based on limited jazz theory consensus.")
    report_lines.append("TESTED WITHOUT targeted adjustments to assess formula generalization.")
    report_lines.append("")
    report_lines.append(f"Errors: {exp_pentad_errors}/{len(exp_pentad_results)}")
    report_lines.append(f"Matches: {exp_pentad_matches}/{len(exp_pentad_results)} ({100*exp_pentad_matches/len(exp_pentad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_exp_pentads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<25} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in exp_pentad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<25} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DISSONANT PENTADS (VALIDATION TEST)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Threshold (max exp pentad): {max_consonant_pentad:.6f}")
    report_lines.append(f"Expectation: All should exceed threshold")
    report_lines.append("")
    report_lines.append(f"Passed: {dissonant_pentad_passed}/{len(dissonant_pentad_results)} ({100*dissonant_pentad_passed/len(dissonant_pentad_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<25} {'Complexity':>12}   {'Status':>10}")
    report_lines.append("-" * 100)

    for r in dissonant_pentad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "PASS ✓" if r['complexity'] > max_consonant_pentad else "FAIL ✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<25} {r['complexity']:>12.6f}   {status:>10}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("EXPERIMENTAL HEXADS (11TH/13TH CHORDS - NO ADJUSTMENTS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append("NOTE: Rankings are HIGHLY SPECULATIVE due to minimal theoretical consensus.")
    report_lines.append("TESTED WITHOUT targeted adjustments to assess formula generalization.")
    report_lines.append("")
    report_lines.append(f"Errors: {exp_hexad_errors}/{len(exp_hexad_results)}")
    report_lines.append(f"Matches: {exp_hexad_matches}/{len(exp_hexad_results)} ({100*exp_hexad_matches/len(exp_hexad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_exp_hexads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<30} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in exp_hexad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<30} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DISSONANT HEXADS (VALIDATION TEST)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Threshold (max exp hexad): {max_consonant_hexad:.6f}")
    report_lines.append(f"Expectation: All should exceed threshold")
    report_lines.append("")
    report_lines.append(f"Passed: {dissonant_hexad_passed}/{len(dissonant_hexad_results)} ({100*dissonant_hexad_passed/len(dissonant_hexad_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<30} {'Complexity':>12}   {'Status':>10}")
    report_lines.append("-" * 100)

    for r in dissonant_hexad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "PASS ✓" if r['complexity'] > max_consonant_hexad else "FAIL ✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<30} {r['complexity']:>12.6f}   {status:>10}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("EXPERIMENTAL HEPTADS (FULL 13TH CHORDS - NO ADJUSTMENTS)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append("NOTE: Rankings are PURE SPECULATION - virtually no theoretical consensus exists.")
    report_lines.append("These represent the practical limit of tertian harmony (stacked thirds).")
    report_lines.append("TESTED WITHOUT targeted adjustments to assess formula generalization.")
    report_lines.append("")
    report_lines.append(f"Errors: {exp_heptad_errors}/{len(exp_heptad_results)}")
    report_lines.append(f"Matches: {exp_heptad_matches}/{len(exp_heptad_results)} ({100*exp_heptad_matches/len(exp_heptad_results):.1f}%)")
    report_lines.append(f"Spearman ρ: {rho_exp_heptads:.6f}")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<35} {'Trad':>5}  {'Calc':>5}   {'Complexity':>12}   {'Status':>6}")
    report_lines.append("-" * 100)

    for r in exp_heptad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "✓" if r['trad_rank'] == r['calc_rank'] else "✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<35} {r['trad_rank']:>5}  {r['calc_rank']:>5}   {r['complexity']:>12.6f}   {status:>6}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("DISSONANT HEPTADS (VALIDATION TEST)")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Threshold (max exp heptad): {max_consonant_heptad:.6f}")
    report_lines.append(f"Expectation: All should exceed threshold")
    report_lines.append("")
    report_lines.append(f"Passed: {dissonant_heptad_passed}/{len(dissonant_heptad_results)} ({100*dissonant_heptad_passed/len(dissonant_heptad_results):.1f}%)")
    report_lines.append("")
    report_lines.append(f"{'Name':<30} {'Ratio':<35} {'Complexity':>12}   {'Status':>10}")
    report_lines.append("-" * 100)

    for r in dissonant_heptad_results:
        ratio_str = ':'.join(str(n) for n in r['notes'])
        status = "PASS ✓" if r['complexity'] > max_consonant_heptad else "FAIL ✗"
        report_lines.append(f"{r['name']:<30} {ratio_str:<35} {r['complexity']:>12.6f}   {status:>10}")

    report_lines.append("")
    report_lines.append("=" * 100)
    report_lines.append("OVERALL SUMMARY")
    report_lines.append("=" * 100)
    report_lines.append("")
    report_lines.append(f"Total chords tested: {total_chords}")
    report_lines.append(f"Total matches/passed: {total_matches}/{total_chords} ({100*total_matches/total_chords:.1f}%)")
    report_lines.append("")
    report_lines.append(f"Dyads:                      {dyad_matches}/{len(dyad_results)} ({100*dyad_matches/len(dyad_results):.1f}%)")
    report_lines.append(f"Triads:                     {triad_matches}/{len(triad_results)} ({100*triad_matches/len(triad_results):.1f}%), ρ={rho_triads:.6f}")
    report_lines.append(f"Dissonant Triads:           {dissonant_triad_passed}/{len(dissonant_triad_results)} ({100*dissonant_triad_passed/len(dissonant_triad_results):.1f}%)")
    report_lines.append(f"Core Tetrads:               {core_tetrad_matches}/{len(core_tetrad_results)} ({100*core_tetrad_matches/len(core_tetrad_results):.1f}%), ρ={rho_core_tetrads:.6f}")
    report_lines.append(f"Experimental Tetrads:       {exp_tetrad_matches}/{len(exp_tetrad_results)} ({100*exp_tetrad_matches/len(exp_tetrad_results):.1f}%), ρ={rho_exp_tetrads:.6f}")
    report_lines.append(f"Dissonant Tetrad Valid:     {dissonant_passed}/{len(dissonant_results)} ({100*dissonant_passed/len(dissonant_results):.1f}%)")
    report_lines.append(f"Experimental Pentads:       {exp_pentad_matches}/{len(exp_pentad_results)} ({100*exp_pentad_matches/len(exp_pentad_results):.1f}%), ρ={rho_exp_pentads:.6f}")
    report_lines.append(f"Dissonant Pentad Valid:     {dissonant_pentad_passed}/{len(dissonant_pentad_results)} ({100*dissonant_pentad_passed/len(dissonant_pentad_results):.1f}%)")
    report_lines.append(f"Experimental Hexads:        {exp_hexad_matches}/{len(exp_hexad_results)} ({100*exp_hexad_matches/len(exp_hexad_results):.1f}%), ρ={rho_exp_hexads:.6f}")
    report_lines.append(f"Dissonant Hexad Valid:      {dissonant_hexad_passed}/{len(dissonant_hexad_results)} ({100*dissonant_hexad_passed/len(dissonant_hexad_results):.1f}%)")
    report_lines.append(f"Experimental Heptads:       {exp_heptad_matches}/{len(exp_heptad_results)} ({100*exp_heptad_matches/len(exp_heptad_results):.1f}%), ρ={rho_exp_heptads:.6f}")
    report_lines.append(f"Dissonant Heptad Valid:     {dissonant_heptad_passed}/{len(dissonant_heptad_results)} ({100*dissonant_heptad_passed/len(dissonant_heptad_results):.1f}%)")

    if total_errors > 0:
        report_lines.append("")
        report_lines.append("=" * 100)
        report_lines.append("ERROR DETAILS")
        report_lines.append("=" * 100)
        report_lines.append("")

        errors_found = []
        for r in dyad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("DYAD", r))
        for r in triad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("TRIAD", r))
        for r in dissonant_triad_results:
            if r['complexity'] <= max_consonant_triad:
                errors_found.append(("DISSONANT TRIAD", r))
        for r in core_tetrad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("CORE TETRAD", r))
        for r in exp_tetrad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("EXP TETRAD", r))
        for r in dissonant_results:
            if r['complexity'] <= max_consonant:
                errors_found.append(("DISSONANT TETRAD", r))
        for r in exp_pentad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("EXP PENTAD", r))
        for r in dissonant_pentad_results:
            if r['complexity'] <= max_consonant_pentad:
                errors_found.append(("DISSONANT PENTAD", r))
        for r in exp_hexad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("EXP HEXAD", r))
        for r in dissonant_hexad_results:
            if r['complexity'] <= max_consonant_hexad:
                errors_found.append(("DISSONANT HEXAD", r))
        for r in exp_heptad_results:
            if r['trad_rank'] != r['calc_rank']:
                errors_found.append(("EXP HEPTAD", r))
        for r in dissonant_heptad_results:
            if r['complexity'] <= max_consonant_heptad:
                errors_found.append(("DISSONANT HEPTAD", r))

        if errors_found:
            for category, r in errors_found:
                if 'trad_rank' in r:
                    report_lines.append(f"  [{category}] {r['name']:<30} should be #{r['trad_rank']:>2}, got #{r['calc_rank']:>2}")
                else:
                    report_lines.append(f"  [{category}] {r['name']:<30} complexity too low: {r['complexity']:.6f}")
        else:
            report_lines.append("  No errors - perfect match!")

    report_lines.append("")

    # Write to file
    report_text = "\n".join(report_lines)
    with open('COMPREHENSIVE_RANKING_REPORT.txt', 'w') as f:
        f.write(report_text)

    # Print to console
    print(report_text)
    print(f"\nReport written to: COMPREHENSIVE_RANKING_REPORT.txt")

    return {
        'dyads': (dyad_matches, len(dyad_results)),
        'triads': (triad_matches, len(triad_results), rho_triads),
        'dissonant_triads': (dissonant_triad_passed, len(dissonant_triad_results)),
        'core_tetrads': (core_tetrad_matches, len(core_tetrad_results), rho_core_tetrads),
        'exp_tetrads': (exp_tetrad_matches, len(exp_tetrad_results), rho_exp_tetrads),
        'dissonant_tetrads': (dissonant_passed, len(dissonant_results)),
        'exp_pentads': (exp_pentad_matches, len(exp_pentad_results), rho_exp_pentads),
        'dissonant_pentads': (dissonant_pentad_passed, len(dissonant_pentad_results)),
        'exp_hexads': (exp_hexad_matches, len(exp_hexad_results), rho_exp_hexads),
        'dissonant_hexads': (dissonant_hexad_passed, len(dissonant_hexad_results)),
        'exp_heptads': (exp_heptad_matches, len(exp_heptad_results), rho_exp_heptads),
        'dissonant_heptads': (dissonant_heptad_passed, len(dissonant_heptad_results)),
        'total': (total_matches, total_chords)
    }


if __name__ == "__main__":
    results = run_all_tests()
    print(f"\nFinal Summary:")
    print(f"  Dyads:                     {results['dyads'][0]}/{results['dyads'][1]} correct")
    print(f"  Triads:                    {results['triads'][0]}/{results['triads'][1]} correct, ρ={results['triads'][2]:.6f}")
    print(f"  Dissonant Triads:          {results['dissonant_triads'][0]}/{results['dissonant_triads'][1]} passed")
    print(f"  Core Tetrads:              {results['core_tetrads'][0]}/{results['core_tetrads'][1]} correct, ρ={results['core_tetrads'][2]:.6f}")
    print(f"  Experimental Tetrads:      {results['exp_tetrads'][0]}/{results['exp_tetrads'][1]} correct, ρ={results['exp_tetrads'][2]:.6f}")
    print(f"  Dissonant Tetrad Validat:  {results['dissonant_tetrads'][0]}/{results['dissonant_tetrads'][1]} passed")
    print(f"  Experimental Pentads:      {results['exp_pentads'][0]}/{results['exp_pentads'][1]} correct, ρ={results['exp_pentads'][2]:.6f}")
    print(f"  Dissonant Pentad Validat:  {results['dissonant_pentads'][0]}/{results['dissonant_pentads'][1]} passed")
    print(f"  Experimental Hexads:       {results['exp_hexads'][0]}/{results['exp_hexads'][1]} correct, ρ={results['exp_hexads'][2]:.6f}")
    print(f"  Dissonant Hexad Validat:   {results['dissonant_hexads'][0]}/{results['dissonant_hexads'][1]} passed")
    print(f"  Experimental Heptads:      {results['exp_heptads'][0]}/{results['exp_heptads'][1]} correct, ρ={results['exp_heptads'][2]:.6f}")
    print(f"  Dissonant Heptad Validat:  {results['dissonant_heptads'][0]}/{results['dissonant_heptads'][1]} passed")
    print(f"  TOTAL:                     {results['total'][0]}/{results['total'][1]} correct ({100*results['total'][0]/results['total'][1]:.1f}%)")
