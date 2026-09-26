# Combat set 02: verification and inspection

The user's request is three additional combat auditions, continuing the darker
fantasy palette. Their clarification permits disconnected notes and rests; the
arrangement should flow as a whole. These three scores use explicit mixed gates,
held notes and accompaniment through melodic breaths. They do not use the prior
revision's automatic legato-extension helper. Musical suitability awaits the
user's listening judgment.

## Completed proof

- All three tracks pass exact authored-score regeneration, source/artifact
  hashes, exact MIDI event readback, note bounds, compact ensemble/polyphony,
  varied articulation, strict codec decode, duration, silence, stereo/sample
  rate, loudness, peak headroom and FLAC/Ogg loop-seam checks. Results are in
  `versions/v01/VERIFICATION.json`.
- Iron Procession is 54.55 seconds at 88 BPM; Thorns in the Dark is 49.66 seconds
  at 116 BPM; The Hollow Gate is 53.33 seconds at 72 BPM. All three FLAC references
  measure -20.00 LUFS. Export true peaks remain below -6.98 dBTP.
- The leads contain respectively 52/13, 65/46 and 42/12 detached/touching
  transitions, with both short and held notes. Lead gate coverage is 78–81%.
  Their first 16 pitch-interval sequences differ from one another and from the
  prior Ashen Pursuit opening; this is a local distinctness check, not exhaustive
  melodic novelty screening.
- All lossless seam-to-p99.9 adjacent-sample ratios are below 0.237. The Ogg
  maxima are 1.162, 1.490 and 0.336, within the existing 1.5 check. Native Vorbis
  padding adds less than one millisecond. FLAC is the exact-length reference;
  MP3 is for convenient audition rather than loop-boundary assessment.
- A fresh independent render to
  `/private/tmp/umbra-combat-set-02-independent-final` produced all 19 manifest,
  score, MIDI, audio and render-report files byte-identically.
- An attempted build into the existing delivered directory was refused before
  writes; all 20 delivered files were unchanged. A deliberately altered score
  in the independent fixture was rejected; that fixture was then restored.
- All 51 tracked files in `umbra_three_sketches` match
  `82e078173a27369200252044bb7c7055fc8b5616` byte-for-byte. Neither prior audition
  version nor its renderer was changed.

The toolchain is Python 3.12.14, NumPy 2.3.5, mido 1.3.3 and FFmpeg 8.1.1.
Source hashes and tool versions are recorded in `versions/v01/SOURCES.json`.
Portable rebuild and verification commands are in README.md.

Inspection consists of the three new standalone MP3 auditions, with Ogg and
lossless FLAC available for loop assessment. A playable Godot fixture is not
applicable: this request creates audition candidates, and no game route or
production asset is changed. No subjective listening judgment is claimed by
the authoring agent or by these technical measurements.
