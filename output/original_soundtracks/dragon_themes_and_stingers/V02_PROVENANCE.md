# Provenance: v02

**Authorship.** Noctyrax takes A and B and the three v02 stingers are original
symbolic compositions. The coding agent (Claude) authored them for Escape the
Umbra after the project owner's audition of v01. The source of truth is
`scripts/v02/scores_dragons_v02.py`. The complete expanded note events are in
each `score.json` and `arrangement.mid`.

**The deliberate self-quotation.** Both takes quote the project's own Thorns in
the Dark, as v01 Noctyrax did. They use its opening melody and pluck figure,
transposed and with a flattened second. That reference is recorded in each
score's `identity`. Thorns' parent score is hash-locked in `SOURCES.json`. No
other existing work is quoted or transcribed.

**Instruments.** All sound is procedural or project-generated:
- The new choir, brass, taiko, timpani and bell in
  `scripts/v02/instruments_dragons_v02.py` are mathematical. They use additive
  wavetables and modal resonators, with deterministically seeded vibrato, drift
  and noise.
- The strings, pad, bass and pluck are the unchanged approved synthesis from
  `string_ensemble_revisions` and `umbra_three_sketches`. Those packages also
  supply the project's generated canonical viola sample for the pad.
- The hall is a seeded decaying-noise impulse response.

**Exclusions.** No external recording, sample, SoundFont, score, MIDI file,
ROM/rip or audio-generation model supplied musical or instrumental input.

**v01 is unchanged.** v02 imports the v01 scripts read-only. All v01 sources
and outputs are hash-checked by the v02 verifier.

**Toolchain.** Python 3.12.13, NumPy 2.3.5, mido 1.3.3 and FFmpeg 8.1.1 (native
Vorbis, FLAC, libmp3lame). music21 10.5.0 is installed, but only v01's
verifier uses it. Exact hashes and versions are frozen in
`versions/v02/SOURCES.json`.

**Classification.** `original_authored_symbolic_composition`.

**Status.** Awaiting user audition. No production routing or approval record
has changed.
