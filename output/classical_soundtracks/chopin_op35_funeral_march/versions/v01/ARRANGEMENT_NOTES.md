# Arrangement notes — Chopin Op. 35, Movement III — v01

## Scope and source order

v01 is a full-movement treatment intended to make later death-screen slice selection possible. It extracts source ticks 1,124,160 through 1,331,520 and retains all 108 complete 4/4 measures in their source order:

- measures 1–32: first funeral-march span;
- measures 33–78: contrasting D-flat-major Trio, including the source-realized repeat;
- measures 79–108: funeral-march reprise and terminal cadence.

No source measure is cut, reordered, or newly repeated. The source already realizes its notated repeats. The Finale beginning at tick 1,331,520 is excluded.

## Reduction and voice allocation

The source is one solo-piano instrument exported as separate right- and left-hand MIDI streams. The normalized score preserves both streams independently. The audition reduces dense keyboard sonorities to five monophonic bowed voices plus one percussion voice:

- **Grave Cello / Funeral Cantus:** the highest right-hand source line in the two march spans; the highest left-hand source line in the Trio. This gives the iconic march melody a dark, cello-led center.
- **Veiled Violin / Trio Cantilena:** the highest right-hand source line in the Trio. In selected climactic march measures it adds only a quiet unison timbral doubling of an existing source pitch.
- **Ashen Violin / Upper Harmony:** the second-highest simultaneous right-hand source pitch when present.
- **Hollow Viola / Inner Lament:** the third-highest right-hand source pitch when present, otherwise an unused inner or upper left-hand source pitch.
- **Undercrypt Bass / Processional Root:** the lowest simultaneous left-hand source pitch.

Every primary melodic and harmonic pitch comes from the source MIDI. There are no reharmonizations, chromatic additions, or transpositions. The only doubling added by the project is the explicitly described selective violin/cello unison; there is no octave doubling in v01.

Each selected source event keeps its onset. Gate lengths are derived from the source duration, then clipped before the next onset on the same output voice to keep the practical texture monophonic. Gate scales are 92–98% by voice. Source velocity contrast is retained through deterministic track-specific remapping; the cello and bass receive the strongest center while the two violins remain legible.

## Tempo, balance, and timbre

The source's 60 QPM opening and terminal rallentando are deliberately flattened to a fixed 66 QPM for the v01 audition. This keeps measure numbers and future slice timings stable while preserving a slow funeral tread. The approximate structural duration before the audition crossfade is 6:32.7.

The canonical `classical_dark_fantasy_v1` bank is used unchanged. The mix favors grave cello and undercrypt bass, keeps the Ashen Violin as a continuous upper-harmony thread, and lets the Veiled Violin brighten the Trio without masking the low center. Strings use the repository's dark three-tap circular echo; percussion stays dry and quieter.

## Added percussion

Percussion is project-authored MIDI triggering only the canonical procedural bank:

- low war drum on each march downbeat, slightly stronger at four-bar boundaries;
- muted bone tom on every second march measure's third beat;
- sparse ash ticks at four-bar march cadences;
- in the Trio, one quiet war drum every four measures, alternating ash ticks, and two restrained tom cadences.

It does not add pitched material or alter Chopin's harmony. The Trio is deliberately much lighter than the two march spans.

## Audition loop treatment

The complete movement receives an approximately one-measure equal-power crossfade of 159,994 samples (3.627981859 seconds at 44.1 kHz) so the pipeline can verify a clean audition seam. The boundary is 8.39 ms before the mathematical 66-QPM measure edge, at a nearby stereo zero crossing; that codec-aware offset prevents the native Vorbis encoder from creating an audible boundary transient without changing the perceived musical cut. This is not the proposed final death-screen loop. The user will choose source slices and their order in a later version, which must be preserved as a new `vNN` rather than replacing v01.

## Difference from previous audition

This is the first Chopin audition; there is no previous version. It does not overwrite or modify the existing Old Castle or Death and the Maiden workspaces.
