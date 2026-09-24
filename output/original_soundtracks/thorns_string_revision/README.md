# Thorns in the Dark: string revision v02

The same violin/viola treatment as the latest Ashen Pursuit and Iron Procession
revisions, adapted to Thorns' faster 116 BPM pulse. Duration remains 49.66 seconds.

The lead keeps every onset, duration, velocity and pitch interval, raised one
octave into violin range. It uses the unchanged procedural bowed-string synth
from `string_ensemble_revisions`: harmonic body resonance, quiet bow friction,
independent vibrato and a low-rate, 12-bit source texture. The first violin uses a
slightly darker 3.2 kHz cutoff for this higher melody.

New second-violin phrases move more slowly under the busy lead. A lower viola
supplies inner harmony and small answering movements. Bars 9–12 thin their
dynamics and lengthen their gestures; the return brings fuller harmony back.
Detached notes, touching phrases and breaths coexist. The old sparse answering
part is replaced, and the pad is thinned to one voice so the texture stays within
six simultaneous melodic gates.

The fast plucked figure, bass, drums, tempo, harmony and form retain their exact
note events. The mixer follows the preceding revisions: first violin targets
4 LU below the old lead before mastering; second violin/viola sit 3/4.5 LU below
it. Bass/pluck target -1 LU relative to their prior stems; pad/drums -1.5 LU.
Final output targets -20 LUFS. Measured matched-mix balances are in render.json.

`versions/v02/01_thorns_in_the_dark_v02/` contains MP3, Ogg, FLAC, MIDI, expanded
score and a render report. The original audition remains in
`../combat_set_02/versions/v01/02_thorns_in_the_dark/`. Use FLAC/Ogg for loop
assessment and MP3 for convenient audition. Instrumental realism, musical blend
and perceived loop continuity remain listening judgments.

## Rebuild

With Python 3.12, FFmpeg and the pinned requirements installed:

```sh
python output/original_soundtracks/thorns_string_revision/scripts/build_thorns.py --output-dir /tmp/umbra-thorns-fresh
python output/original_soundtracks/thorns_string_revision/scripts/verify_thorns.py /tmp/umbra-thorns-fresh --report /tmp/umbra-thorns-fresh/VERIFICATION.json
```

The output directory must not exist. Source/dependency hashes and tool versions
are frozen in SOURCES.json. Full notes are authored in build_thorns.py; generic
MIDI playback supplies different timbres from the custom renderer. All previous
packages remain unchanged, including their builders and manifests.

The renderer wraps release/effect tails over the exact bar-length period and
uses the same two-millisecond endpoint taper as the preceding string revisions.
Inspection is the standalone audio. Game integration and Godot fixtures are not
part of this audition revision.
