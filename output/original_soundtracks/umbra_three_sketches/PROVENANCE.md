# Original soundtrack audition provenance

These three compositions were authored as explicit symbolic notes and arrangement
code by Codex on 2026-09-24 at the project owner's request, for Escape the Umbra.
They are original audition proposals, not adaptations or transcriptions of an
identified existing composition. No external composition, MIDI, recording,
SoundFont, sample pack, console ROM, ripped game instrument, or audio-generation
model supplied musical/audio input to this experiment.

The authoring source is `scripts/build.py`; the fully expanded editable scores
are the versioned `score.json` files. The source classification is
`original_authored_symbolic_composition`. This record does not label the pieces
as historical public-domain works or invent a source license/clearance record.
No claim of legal exclusivity or exhaustive melodic novelty screening is made.

The bowed pad reuses the project's `hollow_viola_c3.wav` from
`assets/audio/instruments/classical_dark_fantasy_v1`, whose mathematical synthesis
and exact bytes are documented by its existing bank manifest. It is the only
pre-existing sample used. The mallet, reed, pluck, bass, and percussion voices are
generated locally from the equations and fixed random-noise seeds in the build
script. The bank itself and the classical renderer/source gates are unchanged.

`SOURCES.json` freezes the hashes of the authoring, verification and documentation
files, the bank manifest/sample, and reused rendering helpers. Each `render.json`
freezes the expanded score, MIDI, FLAC, Ogg, and MP3 hashes. Python, library and
FFmpeg versions are recorded to make toolchain differences visible.

Status: awaiting user audition. These files are not installed into the game and
have not been approved for production use. New revisions belong in `versions/v02`
or later; do not replace any version the user has heard.
