# Arrangement notes - Pictures at an Exhibition: The Old Castle v02

## Selection and order

- v02 covers all 107 printed measures of `Il vecchio castello`, from PDF page 8 / printed page 7 through PDF page 10 / printed page 9, in the score's order.
- There are no cuts, reordered passages, inserted repeats, shortened introductions, or constructed cadence. Measure 106 carries the final cadence and measure 107 retains the printed fermata rest.
- At a fixed 72 quarter notes per minute, the score structure lasts 267.5 seconds (approximately 4:28) before the renderer's short instrument releases.
- The first one-minute v01 loop sketch and all seven artifacts in its version tree remain byte-for-byte unchanged.

## Melody, rhythm, and harmony

- A no-license-conflict CC0 PDMX v9 solo-piano MIDI supplies the complete machine-readable score; the public-domain 1918 reprint is the visual cross-check.
- The builder preserves the source onset ticks and playback durations. The opening lament, including its printed ornaments, is frozen event-by-event; every printed system has a checked pitch/onset anchor; the final cadence and rest bar are checked separately.
- The highest and lowest pitch at each treble-staff onset and each bass-staff onset are retained. This keeps the principal melody, rhythmic placement, bass motion, harmonic outer voices, chord changes, and formal sequence while omitting only middle tones from dense piano sonorities.
- There are no pitch-class substitutions, new functional harmonies, key changes, or transpositions of the whole piece. The audition remains in G-sharp minor and 6/8.
- Instrument-range octave placement is the deliberate exception: the cello doubles the leading treble line one octave lower, and isolated source notes may move by octaves to stay in the procedural instrument's practical range. These octave choices do not change pitch class or harmonic function.

## Voice allocation and balance

- `Veiled Violin / Castle Air` presents the highest treble-staff source pitch at every onset in the source register.
- `Grave Cello / Troubadour` doubles that leading line one octave lower and remains the most prominent melodic timbre.
- `Ashen Violin / Inner Voice` retains the lowest distinct treble-staff pitch at chordal onsets.
- `Hollow Viola / Lower Harmony` retains the highest bass-staff pitch at every onset.
- `Undercrypt Bass / G-sharp Pedal` retains the lowest bass-staff pitch at every onset, including the movement's characteristic G-sharp pedal.
- Source dynamics are mapped into a restrained procedural range. Pan, gain, vibrato, release, filtering, echo, saturation, and peak normalization are frozen in `track.v02.json`.

## Timbre, percussion, and ending

- The arrangement uses the unchanged `classical_dark_fantasy_v1` procedural instrument bank. No samples, recordings, SoundFonts, or generated-model audio are used.
- v02 adds no percussion so the first full-piece audition exposes the source melody and harmony without extra rhythmic interpretation.
- v02 is not looped and applies no end-to-start crossfade. The source cadence and fermata rest remain intact so gameplay-loop candidates can be chosen from an honest complete-movement listen.

## Difference from v01

v01 was an intentionally condensed, reordered 32-measure sketch with a constructed loop close, light percussion, and a ten-second crossfade. v02 replaces none of it: this version instead provides the complete source sequence, principal melody and ornaments, source-form harmony, and natural ending as the baseline from which shorter gameplay loops can be selected.
