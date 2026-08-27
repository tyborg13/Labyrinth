# Arrangement notes - The Old Castle main-menu v03

## Contiguous selection

- v03 uses printed measures 7-68 from the faithful v02 source reduction in their original order.
- In v02 at 72 QPM, those boundaries are 0:15 and 2:50, matching the requested approximate 0:16-2:50 span while retaining the measure-7 melodic pickup.
- The selection is one uninterrupted 62-measure passage. There are no internal cuts, reordered passages, inserted repeats, reharmonizations, or constructed cadence.
- Measures 68 and 7 share the characteristic G-sharp-pedal texture. The structural MIDI keeps measure 7 first; the rendered loop applies one quarter note of equal-power tail/head overlap and rotates that overlap to the loop point.
- v01 and the complete 107-measure v02 audition remain byte-for-byte unchanged.

## Tempo and duration

- The tempo rises from v02's 72 QPM to 84 QPM, a 16.67% increase. This is deliberately below the Schubert combat loop's 92 QPM so the menu gains motion without reading as battle music.
- The structural MIDI lasts 132.857 seconds. The one-quarter-note seam overlap yields a 132.143-second Ogg/FLAC loop.
- Meter, key, source onset ticks, gates, pitch classes, and contiguous formal order otherwise remain unchanged.

## Source-derived string voices

- The five v02 voices are cropped only at the chosen measure boundaries. Their pitches, relative onset ticks, gate durations, velocities, and voice assignments are retained.
- `Veiled Violin / Castle Air` carries the source upper line; `Grave Cello / Troubadour` retains its octave-lower melodic double.
- `Ashen Violin / Inner Voice`, `Hollow Viola / Lower Harmony`, and `Undercrypt Bass / G-sharp Pedal` retain the harmonic outer voices and bass motion from v02.
- The mix slightly shortens releases and dark echo delays for clarity at the quicker tempo. The cello remains the strongest melodic layer, while the upper voices receive enough presence for main-menu listening.

## High-string embellishment

- `Wraithlight Violin / High Embellishment` adds 20 short glints spread across the selection.
- Each glint is a simultaneous, one-octave doubling of a real `Castle Air` melody event at a selected phrase high point. No new pitch class, harmony, countermelody, or off-source rhythm is introduced.
- The glints use the canonical `veiled_violin` procedural sample at low gain, short release, rightward pan, and slightly quicker vibrato. They are intended as occasional spectral highlights, not a continuous sixth line.
- The exact source measure, onset, source pitch, derived pitch, and gate for every glint are recorded in `BUILD_REPORT.json`.

## Restrained 6/8 percussion

- `Funeral Pulse / Menu Percussion` is isolated on MIDI channel 10 (zero-based channel 9) and uses the canonical procedural bank's low war drum, muted bone tom, and ash tick.
- Each 6/8 measure carries four background events: a low drum at the bar line, a quiet ash tick at the end of the first three-eighth group, a muted tom on the second dotted beat, and another quiet ash tick at the end of the bar.
- War-drum weight rises slightly every eight measures; tom weight rises slightly every four. Ash ticks receive a tiny lift only in measures that also contain a high-string glint.
- Velocities remain substantially below the Schubert combat pattern, and the percussion stays dry except for the renderer's three-sample reconstruction filter. It adds forward weight without competing with the melody.

## Timbre, rights, and delivery state

- All strings and percussion use the unchanged `classical_dark_fantasy_v1` procedural bank. No recording, SoundFont, sample pack, ROM/rip, commercial MIDI, modern arrangement, or generated-model audio is used.
- The immutable CC0 PDMX source, public-domain scan, source audit, and full v02 reduction remain the provenance base.
- v03 is an audition only. It is not approved, promoted, or routed to the main menu until the user explicitly selects it.

## Audition questions

1. Does 84 QPM create enough forward movement without losing the somber castle atmosphere?
2. Is the four-hit 6/8 pulse present but backgrounded, or should the low drum/tom move up or down?
3. Do the 20 upper glints add freshness, or should they be sparser, brighter, or placed in different phrases?
