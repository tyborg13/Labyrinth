# Combat auditions, second set

Three new original combat pieces, following the user's positive response to the
darker version-02 palette. The user's clarification governs the phrasing:
detached notes and rests are welcome; the whole piece should flow smoothly.
Accordingly, gates are authored note by note. The new compositions do not use the
previous revision's automatic legato-extension helper.

| Piece | Length / tempo | Role and identity |
| --- | --- | --- |
| Iron Procession | 54.55 s / 88 BPM | Measured war march in G minor; low bowed refrain and deliberate drum steps. |
| Thorns in the Dark | 49.66 s / 116 BPM | Urgent combat in C minor; a recurring low pluck figure and quicker viol gestures. |
| The Hollow Gate | 53.33 s / 72 BPM | Ominous siege in B minor; a low cello warning, heavy paired drum strokes, and distant muted mallet replies. |

Each `versions/v01/<track>/` folder includes an MP3 audition, Ogg loop, lossless
FLAC reference, MIDI, expanded `score.json`, and a render/hash report. All three
target -20 LUFS integrated, matching the earlier auditions for comparison.
Use FLAC or Ogg for loop evaluation; MP3 is a convenient listening preview.

## Musical decisions

**Iron Procession** has five four-bar phrases. Its repeated G-B-flat-A-G gesture
gives the march a recognizable center, with a rising reply and a darker C-minor/
A-flat excursion. Detached gestures alternate with held notes; sustained harmony,
bass steps and quiet viol responses maintain direction during breaths.

**Thorns in the Dark** has an eight-bar statement, four-bar thinner response,
four-bar rebuild and eight-bar return. The accompaniment supplies the continuous
motion so the lead can use short gestures and rests. The middle gives the lead
longer arcs; the final descent and low response prepare the return to C minor.
The brighter tick/snare pattern and high chiming lead from the first experiment
are not used.

**The Hollow Gate** uses four four-bar phrases. A low B-D-F-sharp warning moves
through the semitone color of C major and into an F-sharp dominant. Drum/bass
patterns supply combat weight despite the slower tempo. Soft, low-pass-filtered
mallet responses occupy selected phrase endings without taking over the melody.

Each piece uses six instrument parts and at most six simultaneous melodic note
gates (release tails and percussion are additional). This is a 16-bit-era-inspired
palette, not exact console emulation. Actual suitability remains a listening
judgment, not a conclusion from spectrum or gate measurements.

## Rebuild and verification

From the repository root, with Python 3.12 and FFmpeg on the path:

```sh
python3.12 -m venv /tmp/umbra-combat-env
/tmp/umbra-combat-env/bin/pip install -r output/original_soundtracks/combat_set_02/requirements.txt
/tmp/umbra-combat-env/bin/python output/original_soundtracks/combat_set_02/scripts/compose.py --output-dir /tmp/umbra-combat-fresh
/tmp/umbra-combat-env/bin/python output/original_soundtracks/combat_set_02/scripts/verify_combat.py /tmp/umbra-combat-fresh --report /tmp/umbra-combat-fresh/VERIFICATION.json
```

The output directory must not exist. New revisions use a new version directory;
existing auditions cannot be overwritten. All earlier `umbra_three_sketches`
files remain unchanged. The new set reuses that case's reviewed v02 renderer,
v01 synthesis functions, and MIDI/audio verification helpers; source hashes in
`SOURCES.json` record those dependencies. Generic MIDI playback preserves notes
and rhythm, but the included renderer supplies the custom instrument sound.

Verification checks source/output hashes, exact expanded-score regeneration,
MIDI event readback, bounds and polyphony, distinct opening melodic sequences,
mixed detached/connected gestures, codec decode, duration, silence, headroom,
loudness and FLAC/Ogg seams. The score-level checks support the requested
arrangement choices; they are not a substitute for hearing the pieces.

Inspection consists of the three standalone audio auditions. A playable Godot
fixture is not applicable before a track is selected for integration. Game
routing and production assets are outside this audition task.
