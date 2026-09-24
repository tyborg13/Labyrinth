# Version 01 technical proof

Acceptance: three distinct original 45-60 second retro dark-fantasy auditions,
with reproducible authoring source, MIDI, Ogg, lossless reference and convenient
MP3 previews. No production music route or classical-source gate changes.

Executed with Python 3.12.14, NumPy 2.3.5, mido 1.3.3, and the FFmpeg build
recorded in `versions/v01/SOURCES.json`.

- The build completed all three tracks: Lanterns Below 53.3333 s, The Turning Key
  48 s, Ashen Pursuit 53.3333 s.
- `scripts/verify.py versions/v01 --report versions/v01/VERIFICATION.json`
  passed frozen source/output hashes; exact MIDI-event readback; no dangling or
  overlapping same-pitch MIDI notes; duration; stereo/sample-rate; strict FLAC,
  Ogg and MP3 decode; silence; loudness; sample/true peaks; FLAC/Ogg seam checks.
- All lossless references measure -20.00 LUFS. Ogg measures -20.00, -20.00 and
  -19.99 LUFS. MP3 measures -20.26 LUFS for all three. The highest true peak is
  -7.68 dBTP. No silence longer than 0.5 seconds at -60 dB was detected.
- Ogg boundary-step/p99.9-step ratios are 0.240, 0.156, and 0.316, below the
  verifier's 1.5 threshold. Circular note/effect tails keep the exact bar length.
- A fresh build in `/private/tmp/umbra-original-repro-20260924` produced all
  19 source-manifest, score, MIDI, audio and render-report files byte-identically.
- Building into the existing audition directory was rejected before writes;
  every artifact still matched the independent rebuild afterward.
- Adding a newline to the temporary rebuild's score caused verification to fail
  with `Artifact drift`; the temporary score was then restored. Delivered bytes
  were not modified by that negative check.
- `git diff --check` passed.

These checks do not evaluate musical taste. No subjective listening signoff is
claimed. The user will audition the actual audio before any musical revision or
production integration. The independent peer review covers scope, symbolic
composition, synthesis and technical evidence.

Inspection fixture: not applicable in Godot. These are standalone audio
candidates, with no game integration. The three MP3s are the initial inspection
artifacts; Ogg and FLAC are available for loop evaluation. Engine, UI, gameplay
and balance checks are unrelated to this isolated audition.
