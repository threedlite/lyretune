
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


================================================================================


Wikipedia has two scores by Mesomedes, Emperor Hadrian's court musician. 

Here are all the notes from Mesomedes' "Kalliopeia sopha" (Prayer to Calliope):

  Complete Note Sequence:

  F E D C C D F F F E D D F F F D C C D E D D E F E E D C C Bb Bb Bb D E F E F F

  Breakdown by phrases (matching the Greek text):

  Phrase 1: F E D C (held) D F F F E D (held)
  - "Kal-li-ó-pei-a so-phá, Mou-sṓn pro-ka-tha-gé-ti ter-pnṓn"

  Phrase 2: D F F F D C C D E D D E F E E D C C Bb
  - "kai so-phé mus-to-dó-ta, La-toûs gó-ne, Dê-li-e, Pai-án"

  Phrase 3: Bb Bb D E F E F F
  - "eû-me-neîs pá-re-o-té moi"

  Key Information:

  - Key: F major (one flat: Bb)
  - Time signature: 2/4 (changes to 6/8 at measure 13, then 6/8 at measure 18)
  - Unique notes used: F, E, D, C, Bb
  - Interval pattern: Looking at the unique notes in order: Bb C D E F
    - Intervals: W W W H (whole, whole, whole, half)

Checking the 7 diatonic modes, this pattern appears in:

  Hypolydian mode: F G A B C D E (W W W H W W H)

  The hymn uses exactly the first 5 notes of Hypolydian!

  Transposed to Hypolydian (F G A B C):

  Original → Transposed mapping:
  - Bb → F
  - C → G
  - D → A
  - E → B
  - F → C

  Complete transposed sequence:

  C B A G G A C C C B A A C C C A G G A B A A B C B B A G G F F F A B C B C C

  Breakdown by phrases:

  Phrase 1: C B A G (held) A C C C B A (held)

  Phrase 2: A C C C A G G A B A A B C B B A G G F

  Phrase 3: F F A B C B C C


Hymn to the Sun:

Mesomedes: Hymn to the Sun - Original Notes

  Complete note sequence:

  Bb Bb Bb Eb Eb Eb Eb Eb D C Bb C Bb Eb D C Bb Bb C D Eb D C Bb C D Eb F
  Eb D C Bb Bb Bb Bb Bb Bb Bb D C Bb Bb Bb Bb Bb Bb Bb Eb D C Bb Bb Bb Bb Bb Bb Bb
  Eb D C Bb Bb Bb Bb Bb Bb Bb D C Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb
  Ab D C Bb Bb Bb Bb Bb Bb Eb Eb D C Bb C Bb Bb Bb Bb Bb Bb Bb D C
  Bb Eb D C Bb Bb Bb Bb Bb Bb Bb Eb C Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb
  C Bb C Bb Bb Bb Bb Bb Bb Bb C Bb C Bb Bb Bb Bb C C Bb Bb Bb D C
  Bb Eb D C Bb Bb Bb Bb Bb Bb Bb Ab D C Bb Bb Bb Bb Bb Bb Eb Bb Eb
  Eb D C Bb Bb Bb Bb Bb Bb Bb F Eb Eb C Bb Eb Eb Bb Bb Bb Bb Bb Bb Bb D C
  Eb D C Bb Bb Bb Bb Bb Bb Bb Eb Eb Eb C Bb C Bb Bb Bb Bb Bb Bb Bb Bb Bb Bb
  Bb Eb C Bb Bb Bb Bb Bb Eb Eb Eb Eb C C Bb

  Analysis:

  - Key: Bb major (2 flats: Bb, Eb)
  - Unique notes used: Ab, Bb, C, D, Eb, F
  - Interval pattern: W W W H W
    - Ab to Bb = W
    - Bb to C = W
    - C to D = W
    - D to Eb = H
    - Eb to F = W

  This pattern W W W H W matches F G A B C D in natural notes!

  Transposed to Natural Notes (no sharps/flats):

  Mapping:
  - Ab → F
  - Bb → G
  - C → A
  - D → B
  - Eb → C
  - F → D

  Complete transposed sequence:

  G G G C C C C C B A G A G C B A G G A B C B A G A B C D
  C B A G G G G G G G B A G G G G G G G C B A G G G G G G G
  C B A G G G G G G G B A G G G G G G G G G G G G G
  F B A G G G G G G C C B A G A G G G G G G G B A
  G C B A G G G G G G G C A G G G G G G G G G G
  A G A G G G G G G G A G A G G G G A A G G G B A
  G C B A G G G G G G G F B A G G G G G G C G C
  C B A G G G G G G G D C C A G C C G G G G G G G B A
  C B A G G G G G G G C C C A G A G G G G G G G G G G
  G C A G G G G G C C C C A A G

  This hymn works on a 6-string lyre tuned to F G A B C D (natural notes, no sharps or flats)!

  This matches the Hypolydian mode starting from F: F G A B C D E (using the first 6 notes).







