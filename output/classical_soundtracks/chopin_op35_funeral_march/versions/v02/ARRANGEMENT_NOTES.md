# v02 arrangement notes — subtle death-loop structure

## User reference and exact source mapping

The user's rough timestamp order refers to the loop-rotated v01 Ogg. v01 begins 3.627981859 seconds into the source movement, so v02 snaps those audible regions to complete musical boundaries:

1. **v01 5:01–5:08 → source measures 85–86.** Exact snapped v01-preview range: 5:01.827–5:09.099.
2. **v01 5:29–5:52 → source measures 93–98.** Exact snapped v01-preview range: 5:30.917–5:52.736.
3. **v01 2:50–3:09 → source measures 49–53.** Exact snapped v01-preview range: 2:50.917–3:09.099.

The order is A → B → C. No selected source measure is reordered internally or repeated.

## Removing the culturally familiar motif

Slices A and B come from the funeral-march reprise. In v01, `Grave Cello / Funeral Cantus` carries the source right-hand lead and `Veiled Violin / Trio Cantilena` selectively doubles it. v02 removes both tracks completely during A and B. Those march excerpts retain only:

- `Ashen Violin / Upper Harmony`;
- `Hollow Viola / Inner Lament`;
- `Undercrypt Bass / Processional Root`;
- a newly thinned, non-melodic percussion pulse.

This deliberately removes 42 Grave Cello lead events and 8 Veiled Violin doubles from the selected march material. The builder also rejects the exact onset/pitch signature of the famous opening/reprise contour if it appears on any v02 melodic track. The result keeps Chopin's somber harmony and processional weight without stating the pop-culture melody.

Slice C is Trio material, not the famous march tune, so its Veiled Violin cantilena, Grave Cello arpeggiation, and bass are retained at reduced velocity.

## Bridges and loop structure

- A one-beat loop pre-roll contains the same quiet B-flat-minor inner sonority used at the end of the loop. The renderer consumes it in the one-beat crossfade, so audible playback starts at slice A.
- **A → B:** one beat sustaining only the outgoing inner voices and bass, followed by an ash-tick breath.
- **B → C:** two beats pivot on D-flat. The first beat decays the march's inner harmony; the second introduces only the Trio's opening upper tone and bass.
- **C → A:** two beats. The first lets the Trio resonance fall away; the second states the quiet inner sonority shared with the pre-roll and is crossfaded into A.

Every bridge pitch is asserted against an adjacent selected v01 source window. There are no new pitch classes, transpositions, octave doublings, or reharmonizations.

## Sound and percussion

The canonical `classical_dark_fantasy_v1` bank is unchanged. Relative to v01, v02 lowers the lead and percussion energy, darkens the short echo, and targets -8.5 dBFS. Percussion is rebuilt as isolated distant war-drum entries, two low bone pivots, and widely spaced ash breaths; the march's regular downbeat pattern is not copied.

The MIDI is 58 beats at fixed 66 QPM. A one-beat equal-power loop overlap produces an intended audible duration of approximately 51.818 seconds. This remains an audition only: it is not approved, promoted, or routed into the game.
