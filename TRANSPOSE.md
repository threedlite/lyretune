
https://en.wikipedia.org/wiki/Musical_system_of_ancient_Greece
See Octave species, Diatonic section

The 7 Diatonic Modes (Ancient Greek Octave Species):

  1. Mixolydian - B C D E F G A
    - H W W H W W W
  2. Lydian - C D E F G A B
    - W W H W W W H
  3. Phrygian - D E F G A B C
    - W H W W W H W
  4. Dorian - E F G A B C D
    - H W W W H W W
  5. Hypolydian - F G A B C D E
    - W W W H W W H
  6. Hypophrygian - G A B C D E F
    - W W H W W H W
  7. Hypodorian - A B C D E F G
    - W H W W H W W


The transposition process, an example for a lyre tuned in Dorios mode, lower octave:

  1. Get unique notes from melody (sorted low to high)
  2. Calculate interval pattern between consecutive unique notes
  3. Check if that exact interval pattern exists as a consecutive sequence within the lyre's pattern
  4. If yes, transpose to start on the matching position

  Your lyre E3 F3 G3 A3 B3 C4 D4:
  Intervals: H W W W H W

  Frère Jacques uses C D E F G A:
  Intervals: W W H W W

  Does W W H W W appear consecutively in H W W W H W?
  No - the lyre in this mode doesn't have 6 consecutive notes with that pattern.

  So Frère Jacques won't work in this mode.

  Edelweiss uses E F G A B C D:
  Intervals: H W W W H W

  Does H W W W H W appear in H W W W H W?
  Yes! Exact match. That's why it works perfectly.

E3 G3 C4 
B3 G3 F3 
E3 E3 
E3 F3 G3 
A3 G3 
E3 G3 C4 
B3 G3 F3 
E3 G3 
G3 A3 B3 C4 
B3 C4 D4 
G3 G3 B3 
A3 G3 
E3 G3 C4 
A3 C4 D4 
C4 B3 G3

  So we need to find songs where the unique notes' interval structure matches a substring of H W W W H W.

  A sharp or flat just shifts the note by a half step - what matters is the interval pattern between the unique notes, regardless of their
  names.

  So for example, if a song uses C D E F# G:
  - C to D = W
  - D to E = W
  - E to F# = W
  - F# to G = H
  - Pattern: W W W H

  Does W W W H appear in your lyre H W W W H W?
  Yes! At F G A B C (W W W H)

  So it can be transposed to F3 G3 A3 B3 C4 on your lyre.


  
Another example for 7 strings in a different mode:

  https://thesession.org/tunes/3761
 Saltarello (Italian dance) for 7-string lyre tuned to Hypophrygios: G3 A3 B3 C4 D4 E4 F4

  Part A (play twice):
  G3 A3 G3 B3 A3 B3 D4 D4 D4 D4 E4 D4 C4 C4 C4 A3 B3 C4 B3 A3 B3 G3 G3 B3
  G3 A3 G3 B3 A3 B3 D4 D4 D4 D4 D4 E4 F4 E4 D4 C4 B3 A3 G3 G3 G3 G3 G3 G3

  Part B (play twice, with 1st and 2nd endings):
  D4 D4 D4 D4 E4 F4 E4 E4 D4 D4 E4 F4 E4 E4 D4 C4 B3 A3 B3 A3 B3 G3 G3 B3
  D4 D4 D4 D4 E4 F4 E4 E4 D4 D4 D4 E4 F4 E4 D4 C4 B3 A3
  [1st ending: G3 G3 G3 G3 G3 B3]
  [2nd ending: G3 G3 G3 D4 E4 D4]

  Part C (play once):
  B3 B3 D4 D4 E4 D4 A3 A3 A3 D4 D4 E4 F4 E4 D4 F4 E4 D4 E4 E4 D4 D4 E4 D4
  B3 B3 D4 D4 E4 D4 A3 A3 D4 D4 D4 E4 F4 E4 D4 C4 B3 A3 G3 G3 D4 D4 E4 D4
  B3 B3 D4 D4 E4 D4 C4 C4 D4 D4 D4 E4 F4 E4 D4 F4 E4 D4 E4 E4 D4 D4 E4 D4
  B3 B3 D4 D4 E4 D4 C4 C4 D4 D4 D4 E4 F4 E4 D4 C4 B3 A3 G3 G3 G3 G3 G3 B3

  Part D (play twice, with endings):
  G3 G3 B3 G3 G3 B3 B3 B3 A3 A3 B3 C4 A3 A3 C4 A3 A3 C4 C4 C4 B3 G3 A3 B3
  G3 G3 B3 G3 G3 B3 B3 B3 A3 A3 B3 C4 D4 E4 D4 C4 B3 A3
  [1st: G3 G3 G3 G3 G3 B3]
  [2nd: G3 G3 G3 G3 B3 C4]

  Part E (play twice, with endings):
  D4 D4 D4 C4 C4 C4 B3 B3 B3 G3 G3 B3 A3 A3 A3 C4 B3 A3 B3 B3 G3 B3 B3 C4
  D4 D4 D4 C4 C4 C4 B3 B3 B3 G3 G3 B3 A3 A3 A3 C4 B3 A3
  [1st: G3 G3 G3 B3 B3 C4]
  [2nd: G3 G3 G3 B3 B3 A3]

  This is in 6/8 time (bouncy, dance-like rhythm). 


Examples of intervals that do not conform to any of the regular 7 diatonic modes:

 Double Harmonic scale example (composed by Claude):
 Uses: E F G# A B C D#
 Intervals: H 3H H W H 3H H
 (Note: 3H = augmented second)

 E4 F4 G#4 A4 G#4 F4 E4 E4 F4 G#4 A4 B4 A4 G#4 F4 E4
 E4 F4 G#4 A4 B4 C5 D#5 C5 B4 A4 G#4 F4 E4 E4 E4
 B4 C5 D#5 C5 B4 A4 A4 A4 G#4 A4 B4 A4 G#4 F4 F4
 E4 F4 G#4 F4 E4 F4 G#4 A4 B4 A4 G#4 F4 E4 E4 E4


 Nahawand maqam example (composed by Claude):
 Uses: A B C D E F G# (same as harmonic minor)
 Intervals: W H W W H 3H H

 A4 B4 C5 D5 E5 D5 C5 B4 A4 A4 G#4 A4
 A4 C5 B4 A4 G#4 F4 F4 G#4 A4 A4
 E5 E5 D5 C5 B4 A4 G#4 A4 B4 C5 D5 E5
 F4 G#4 A4 B4 C5 D5 E5 F4 G#4 A4 A4 A4


8 string lyre example:

  This is Setting #1 from The Session. https://thesession.org/tunes/2721

 Tarantella Napoletana (in A minor) uses: A B C D E F G A
 Intervals: W H W W H W W

 Ancient Greek Hypodorios mode (A B C D E F G A)

  Part A (repeat this section):
  A4 A4 A4 E4 E4 E4 A4 A4 A4 E4 E4 E4 E4 D4 E4 F4 F4 F4 F4 G4 F4 E4 E4 E4 E4 F4 E4 D4 D4 D4 D4 E4 D4 C4 C4 C4 C4 D4 C4 B3 B3 D4 C4 C4 B3 A3 A3 A3

  Part B (repeat this section):
  C4 B3 C4 D4 C4 B3 C4 C4 A3 A3 B3 C4 B3 B3 B3 D4 C4 B3 C4 C4 A3 A3 A3 B3

  Full structure: Play Part A twice, then Part B twice, then repeat the whole thing.

  Notes about rhythm: This is in 6/8 time (like "1-2-3, 4-5-6"), with a bouncy tarantella feel. Some notes are held longer than others - play along with recordings.


See also relation to Byzantine music: https://en.wikipedia.org/wiki/Byzantine_music





