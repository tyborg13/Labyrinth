# Thorns in the Dark v02: proof and inspection

The user confirmed Thorns in the Dark as the requested next violin-ensemble
revision. It follows the recent Ashen Pursuit and Iron Procession treatment while
retaining its quicker pulse and allowing detached notes and rests.

`verify_thorns.py` passes all 17 source hashes, delivered artifact hashes, exact
authored-score regeneration and MIDI readback, bounds/velocities, string ranges,
monophonic string lanes, no hanging notes, and a maximum of six melodic gates.
It confirms the unchanged melody timing/intervals/velocity with a one-octave
increase, and exactly unchanged percussion, bass, pluck, tempo, harmony and form.

The new second violin has 66 notes, covers 82.9% of the loop with note gates and
uses its own rhythm. The viola has 50 notes and 89.5% gate coverage. Both have
moving pitches, touching transitions and detached gestures. These checks establish
an active independent middle layer, not aesthetic merit or formal counterpoint.

| Technical measurement | Result |
| --- | --- |
| Length | 49.6552 seconds |
| Lossless loudness | -20.00 LUFS |
| Lead change at matched overall loudness | -2.83 LU |
| Percussion change at matched overall loudness | -0.35 LU |
| Lead above combined second violin and viola | 0.57 LU |
| FLAC seam discontinuity | 0 |
| Ogg seam / p99.9 adjacent-sample delta | 0.111 worst channel |
| Highest true peak across exports | -9.05 dBTP |

FLAC, Ogg and MP3 pass strict decoding, duration, 32 kHz stereo, long-silence,
loudness and headroom checks. FLAC and Ogg pass the existing 1.5 seam-ratio bound.
The renderer refuses non-finite or clipping measurement inputs, supporting the
reported stem-loudness calibration. The exact prior bowed-string synth is reused.

A fresh independent build in `/private/tmp/umbra-thorns-strings-independent-final-v02`
reproduced all seven generated source-manifest/score/MIDI/audio/render-report files
byte-identically. Existing-directory refusal preserved all eight delivered files,
including verification. A deliberately modified temporary score was rejected;
the independent fixture was restored afterward.

All 98 prior original-soundtrack files are byte-identical to parent commit
`72d8c25af9dda42cf81f4d79b5e7f2df6f692b86`. No earlier builder, manifest, instrument
bank or production route changed. Toolchain: Python 3.12.14, NumPy 2.3.5,
mido 1.3.3, FFmpeg 8.1.1. Portable build commands are in README.md.

Inspection is the standalone revised audio with the original retained for
comparison. A Godot fixture is not applicable without game integration. Actual
violin character, musical blend and loop perception require user listening;
no subjective hearing claim is made by the authoring agent or numeric checks.
