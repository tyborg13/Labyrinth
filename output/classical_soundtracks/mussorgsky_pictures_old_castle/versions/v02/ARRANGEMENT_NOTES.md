# Arrangement notes - Pictures at an Exhibition: The Old Castle v02

## Selection and order

- v02 covers all 106 measures of `Il vecchio castello`, from PDF page 8 / printed page 7 through PDF page 10 / printed page 9, in the score's printed order.
- There are no cuts, reordered passages, inserted repeats, shortened introductions, or constructed cadence. The full measure and page map is recorded in `transcription/TRANSCRIPTION_AUDIT.md`.
- At a fixed 72 quarter notes per minute, the score structure lasts 265 seconds (approximately 4:25) before the renderer's short instrument releases.
- The first one-minute v01 loop sketch and all of its artifacts are retained byte-for-byte for comparison.

## Melody, rhythm, and harmony

- The upper-primary source voice supplies the full principal melody, including its returns and later development. Its recognized onsets, note durations, grace-note lead-ins, and measure placement are retained.
- The remaining stable upper and lower piano voices supply the inner line, lower harmony, and pedal/bass motion. Dense piano chords are reduced to representative tones when mapped to a monophonic procedural instrument.
- There are no pitch-class substitutions, new functional harmonies, key changes, or transpositions of the whole piece. The audition remains in G-sharp minor and 6/8.
- Instrument-range octave placement is the deliberate exception: the cello presents the upper melody one octave lower, while the selective upper violin keeps a source chord tone in its practical register. These octave choices do not change pitch class or harmonic function.
- Mechanical OMR duration repair is restricted to the printed barlines and documented in the build report. The public-domain scan remains authoritative for later detail edits.

## Voice allocation and balance

- `Grave Cello / Troubadour` carries the complete principal melody and remains the loudest melodic voice.
- `Veiled Violin / Castle Air` preserves a high source chord tone in dense or heightened passages, giving the upper register presence without continuously masking the cello.
- `Ashen Violin / Inner Voice` follows the second upper-staff voice.
- `Hollow Viola / Lower Harmony` follows the upper tone of the first lower-staff voice.
- `Undercrypt Bass / G-sharp Pedal` follows the lowest stable lower voice, falling back to the lower harmony where the scan contains no separate pedal event.
- Section-shaped velocities follow the work's large-scale rises and withdrawals. Each MIDI note uses a 92% gate, leaving a small amount of air while preserving cantabile continuity through the procedural release tails.

## Timbre, percussion, and ending

- The arrangement uses the unchanged `classical_dark_fantasy_v1` procedural instrument bank. No samples, recordings, SoundFonts, or generated-model audio are used.
- Pan, gain, vibrato, release, filtering, echo, saturation, and peak normalization are frozen in `track.v02.json`.
- v02 adds no percussion so the first full-piece audition exposes the source melody and harmony without extra rhythmic interpretation.
- v02 is not looped and applies no end-to-start crossfade. The source ending and final silence remain intact so gameplay-loop candidates can be chosen from an honest complete-movement listen.

## Difference from v01

v01 was an intentionally condensed, reordered 32-measure sketch with a constructed loop close, light percussion, and a ten-second crossfade. v02 replaces none of it: this version instead provides the complete source sequence, full principal melody, source-form harmony, and natural ending as the baseline from which shorter gameplay loops can be selected.
