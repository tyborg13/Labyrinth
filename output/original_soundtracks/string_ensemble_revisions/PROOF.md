# String revision proof and inspection

User request: revise Ashen Pursuit and Iron Procession with a more textured violin
lead, less foreground melody, restrained percussion, and an active second-string/
viola middle layer. Preserve mixed articulation and whole-piece flow.

## Delivered evidence

Both tracks pass `verify_strings.py`: frozen sources/artifacts, exact authored
score regeneration, exact MIDI event readback, valid bounds/velocities, monophonic
string lanes, at most six simultaneous melodic gates, strict FLAC/Ogg/MP3 decode,
32 kHz stereo, duration, silence, headroom, loudness and lossless/Ogg loop seams.
The full machine-readable results are in `versions/v01/VERIFICATION.json`.

| Measurement | Ashen Pursuit v03 | Iron Procession v02 |
| --- | --- | --- |
| Duration | 57.60 s | 54.55 s |
| Lossless loudness | -20.00 LUFS | -20.00 LUFS |
| Lead change at matched full-mix loudness | -2.83 LU | -3.00 LU |
| Percussion change at matched full-mix loudness | -0.31 LU | -0.40 LU |
| Lead above combined new middle strings | 0.71 LU | 0.66 LU |
| Second-violin gate coverage | 81.6% | 80.4% |
| Viola gate coverage | 89.0% | 90.0% |
| Ogg seam / p99.9 adjacent sample delta, worst channel | 0.138 | 0.060 |

The lossless endpoint deltas are zero. All exports have true peaks below -8.8
dBTP. The percussion notes are exactly unchanged, and the melody preserves every
onset, duration, velocity and pitch interval with a documented octave increase.
Second violin/viola are authored independent parts, not constant unison doubling.
Both contain detached and touching notes. Instrument loudness measurements are
isolated stems calibrated to the final mix gain; they are not aesthetic ratings.

## Reproducibility and regression checks

- A full independent build to `/private/tmp/umbra-strings-independent-v01`
  reproduced all 13 manifest, score, MIDI, audio and render-report files exactly.
- Attempting a build into the delivered directory was refused before writes;
  all 14 delivered files, including verification, retained their original hashes.
- A deliberately modified temporary score was rejected by authored-score
  comparison. The temporary independent fixture was restored afterward.
- All 77 previously tracked original-soundtrack files match parent commit
  `0dab95b7a8abc61a0b03d545b19849ec7ee04f7f` byte-for-byte.
- Sustained synthesis probes at MIDI A4 (first violin) and A3 (viola) produced
  finite, deterministic output with dominant spectral peaks at 440 and 220 Hz.
  Energy between 1.2 and 5 kHz was respectively 8.1% and 5.4%, confirming retained
  upper partials. These checks do not establish perceived violin realism.

Toolchain: Python 3.12.14, NumPy 2.3.5, mido 1.3.3, FFmpeg 8.1.1. Versions and
input hashes are frozen in SOURCES.json. Rebuild commands are in README.md.

Inspection is the two standalone audio previews with their unchanged parents
available for comparison. A Godot fixture is not applicable because no game
integration, music routing or production assets changed. Actual timbre, musical
blend and loop perception require user listening; no listening judgment is
claimed by the authoring agent or by the technical verifier.
