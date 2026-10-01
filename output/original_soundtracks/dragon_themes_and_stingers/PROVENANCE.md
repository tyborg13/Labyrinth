# Provenance

**Authorship.** The six dragon themes and three stingers were composed by the
coding agent (Claude) at the project owner's request, as explicit symbolic
note sequences, harmonies and arrangements for Escape the Umbra. They are new
compositions. None transcribes or remixes an identified existing work. The
source of truth is `scripts/dragon_scores.py`. The complete note events are
retained in each expanded `score.json` and `arrangement.mid`.

**The one deliberate reference.** Noctyrax, the Last Eclipse, quotes the
project's own original Thorns in the Dark in distorted form. The melody is
augmented, transposed and given a Phrygian flattened second, and it reuses the
Thorns pluck figure. That self-reference is documented in its score
`identity`. Thorns' parent score is hash-locked in `SOURCES.json`.

**Instruments.** All instrument input is procedural or project-generated:
- Violin, viola and cello-register lanes use the unchanged bowed-string additive
  synth from `string_ensemble_revisions/scripts/bowed_strings.py`: harmonics,
  body resonances and deterministically seeded bow noise. This package adds a
  tempo-locked amplitude tremolo.
- Pad, bass, pluck, bell (`lantern_mallet`) and drums use the unchanged
  equations and seeded noise in `umbra_three_sketches/scripts/build.py` and
  `build_v02.py`. The pad reads the project's mathematically generated canonical
  `hollow_viola_c3.wav` from `classical_dark_fantasy_v1`, whose bank manifest
  records that synthesis.
- The stingers' hall tail is a seeded, decaying-noise impulse response
  generated in `scripts/build.py`.

**Exclusions.** No external recording, score, MIDI file, SoundFont, sample
pack, ROM/rip or audio-generation model supplied musical or instrumental
input. The canonical bank and all earlier audition packages remain unchanged.

**Toolchain.** Python 3.12.13, NumPy 2.3.5, mido 1.3.3 and FFmpeg 8.1.1 (native
Vorbis, FLAC, libmp3lame). The verifier's symbolic key estimate uses
music21 10.5.0. Exact source and dependency hashes and tool versions are frozen
in `versions/v01/SOURCES.json`. Delivered artifact hashes are in each
`render.json` and in `SOURCES.json`.

**Classification.** `original_authored_symbolic_composition`. No historical
composer, public-domain transcription, exhaustive novelty or exclusivity claim
is made.

**Status.** Awaiting user audition. No production routing, asset or approval
record has changed.
