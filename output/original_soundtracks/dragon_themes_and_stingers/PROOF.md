# Dragon themes and stingers v01: proof and inspection

**Request.** The owner asked for a distinct boss theme for each of the six
dragons and three stingers: level up, rare reward and boss defeated. The themes
use the family and instrumentation of the approved Thorns in the Dark v02.
Everything is delivered as a reproducible audition package, with no game
integration.

## Verification

`scripts/verify_dragons.py versions/v01 --compare <independent build>` passes.
The full report is `versions/v01/VERIFICATION.json`. It checked:
- **Sources.** 21 source/dependency hashes and 54 output hashes. All nine
  scores regenerate exactly, and MIDI reads back exactly.
- **Structure.** Note bounds, string ranges and monophonic string lanes, with
  at most six simultaneous melodic gates.
- **Audio.** 32 kHz stereo FLAC/Vorbis/MP3 that decodes strictly. Durations,
  loudness, and sample and true-peak headroom.
- **Loops.** The existing 1.5 seam-ratio bound, plus a seam profile. The
  profile shows that each seam's 100 ms level step and 250 ms spectral change
  stay inside the piece's own internal 99th percentile and section boundaries.
- **Stinger tails.** Onset within 10 ms. The final 50 ms is quieter than
  −60 dBFS (measured at −102 dBFS). The decay over the last 600 ms is
  monotonic.
- **Distinctness.** Six different tempos and tonics, none shared with Thorns
  (116 BPM, C). Six different opening lead-interval signatures, none equal to
  Thorns'.
- **Harmony.** Chroma analysis of the rendered audio places the authored chord
  first in 132 of 150 theme bars, and in the top three in 139, with a median
  rank of 1.

| Piece | Length | Integrated (FLAC / Ogg) | Sample / true peak | Ogg seam ratio |
| --- | --- | --- | --- | --- |
| Zekarion | 49.23 s | -20.01 / -19.99 LUFS | -8.1 / -8.1 dB | 0.102 |
| Tharokh | 60.00 s | -20.00 / -19.99 | -7.1 / -7.1 | 0.183 |
| Vyraketh | 55.65 s | -20.00 / -19.99 | -7.8 / -7.8 | 0.157 |
| Vaeloryx | 53.33 s | -20.01 / -20.00 | -8.0 / -8.0 | 0.406 |
| Iskaldra | 56.84 s | -20.00 / -19.99 | -6.7 / -6.7 | 0.074 |
| Noctyrax | 60.00 s | -20.00 / -19.99 | -6.0 / -6.0 | 0.306 |
| Level Up | 3.42 s | -18.0 (momentary max -16.9) | -7.4 / -7.4 | n/a |
| Rare Reward | 2.91 s | -18.0 (momentary max -16.2) | -7.6 / -7.6 | n/a |
| Boss Defeated | 6.77 s | -18.0 (momentary max -15.5) | -5.5 / -5.5 | n/a |

FLAC loop endpoints are exactly continuous: seam delta 0, following the 2 ms
Thorns taper. Before that taper, the circular mix's wrap sample delta is at
most 0.62 × the 99.9th-percentile adjacent-sample delta. In other words, the
loop point is no larger a step than an ordinary pair of neighbouring samples.

**Stem balance.** Measured stem balance follows Thorns v02. Melody leads sit
0.74–1.4 LU over the combined second violin and viola (Thorns is 0.57 LU).
Tharokh's cello lead sits 2.6 LU over its lone viola. The hottest single stem
peaks at −9.6 dBFS after mastering.

**Section loudness.** K-weighted section loudness shows each theme's intended
contrast:
- Zekarion's eye: −1.3 LU.
- Vyraketh's terraces: −21.0 → −19.5 LUFS.
- Vaeloryx's lull: about −2.3 LU.
- Noctyrax's arc: −23.3 → −20.5 → −19.5 → −18.1 → −20.9 LUFS.

**Other checks.** Automated key estimates, from audio chroma and from music21,
report the declared tonic for most themes. The exceptions are modal pieces:
Tharokh's A-with-B♭ shares D minor's pitch set, and Vaeloryx is Dorian. Both
estimates are recorded, not enforced. A tremolo check found envelope modulation
at the intended 10.4 Hz in Zekarion. A click scan found no discontinuities.

## Determinism

**Fresh rebuild.** A second, independent build in a fresh scratch directory
reproduced all 55 generated files byte-for-byte:
- scores, MIDI and render reports
- FLAC, Ogg and MP3
- `SOURCES.json`

**Existing directory.** Re-running the builder against the existing
`versions/v01` refuses and changes nothing.

**Toolchain.** Python 3.12.13, NumPy 2.3.5, mido 1.3.3, music21 10.5.0 and
FFmpeg 8.1.1.

## Inspection

The inspection is the standalone audio: see `versions/v01/AUDITION.md`. A Godot
fixture does not apply before the owner selects pieces and a routing plan.

**Not established.** Numeric and score checks do not establish musical quality,
how realistic the instruments sound, or how the loops are perceived. Those need
the owner's ears.
