# Version 02 verification and inspection

The original 26 version-01 source, documentation and artifact files match commit
4040f2dce byte-for-byte. Both v01 and v02 pass the unchanged audio/MIDI verifier.
Version 02 uses its own scripts, notes, source manifest and audition directory.

## Completed proof

- All three v02 tracks passed source/artifact hashes, exact MIDI-event readback,
  strict FLAC/Ogg/MP3 decode, duration, silence, stereo/sample rate, loudness,
  sample/true-peak headroom, and FLAC/Ogg loop-seam checks. See
  `versions/v02/VERIFICATION.json`.
- All lossless renders are -20.00 LUFS. Durations are 53.33, 48.00 and 57.60 s.
  Ogg seam/p99.9 ratios are 0.345, 0.062 and 0.116, all below 1.5.
- `compare_v02.py` regenerated the authored scores and matched the delivered
  scores exactly. It confirms the unchanged Lanterns mallet notes/patch, the
  retained Turning Key pitch sequence an octave lower, and the retained Ashen
  Pursuit opening/return pitch sequences an octave lower.
- Average internal lead-gate gaps changed from 0.450 to 0.022 s in The Turning
  Key, and from 0.264 to 0.016 s in Ashen Pursuit. Short, authored phrase-end
  breaths remain. Lanterns' mallet gates remain unchanged.
- Full-mix power-weighted spectral centroids changed from 234.1 to 188.2 Hz
  (Turning Key) and 212.1 to 164.3 Hz (Ashen Pursuit). Lanterns remains 254.9 Hz.
  These metrics describe register/energy changes and do not rate aesthetic mood.
- A fresh render to `/private/tmp/umbra-v02-independent-rebuild` produced all
  19 manifest, score, MIDI, audio and render-report files byte-identically.
- The builder refused the existing v02 directory before writes; all artifact
  bytes remained unchanged. A deliberately modified score in the temporary
  rebuild was rejected with `Artifact drift`, then restored.

Environment is recorded in `versions/v02/SOURCES.json`. Commands use Python
3.12.14, NumPy 2.3.5, mido 1.3.3 and FFmpeg 8.1.1. The exact practical dependency
paths used in this task are the bundled Codex Python runtime and the temporary
`/private/tmp/umbra-original-music-deps` package folder; portable rebuild commands
are in V02_NOTES.md.

Inspection: the three version-02 MP3s, with version 01 retained for comparison.
Lossless FLAC and Ogg are available for loop assessment. An in-game fixture is
not applicable because this is an audition revision with no game integration.
No engine, UI, or balance behavior changed.

The user liked version 01, especially Lanterns Below. Version 02 still needs
user listening feedback. No subjective listening judgment is claimed by these
technical checks or by the authoring agent.
