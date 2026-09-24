# Three original Escape the Umbra auditions

Version 01 is a taste test of original, restrained 16-bit-era dark-fantasy music.
These are complete short loops with authored melodies and contrasting sections.
They share instruments but test different roles; the target is an evocative
background texture, with room for gameplay sounds. No game music routing changes.

| Audition | Length | Character |
| --- | --- | --- |
| Lanterns Below | 53.33 seconds, 72 BPM | Spacious mallet motif, low reed replies, slowly changing harmony. Exploration. |
| The Turning Key | 48 seconds, 80 BPM | Plucked 3+3+2 accents, questioning reed phrases, restrained taps. Planning. |
| Ashen Pursuit | 53.33 seconds, 108 BPM | Syncopated bass, short reed calls, muted drums, thinner middle passage. Combat. |

Each folder in `versions/v01` contains `preview.mp3` for convenient audition,
`preview.ogg` for loop audition, `preview.flac` as the lossless reference,
`arrangement.mid` for note editing/import, `score.json` for the exact event list,
and `render.json` for render settings/measurements and artifact hashes.

All three target -20 LUFS integrated with at least 4 dB sample-peak headroom
before encoding. For the comparison, leave the player volume unchanged. Listen
to at least two consecutive loops when assessing repetition and transitions.
MP3 is a convenience preview; use FLAC or Ogg when assessing the loop boundary.
General MIDI playback preserves notes and timing but does not reproduce these
custom instruments; the score and builder reproduce the intended sound.

## Musical choices

**Lanterns Below:** sixteen bars in D minor, four four-bar phrases. The opening
D-A-F-E contour returns with a G-minor variation. Lower replies and rests keep
the texture open. The final A7 leads back into D minor. No percussion.

**The Turning Key:** sixteen bars in E minor. A recurring plucked figure leaves
gaps around the reed. C-major and A-minor colors answer the opening E minor;
B7 supplies a restrained pull back to the beginning. The second half lifts the
melody before returning to its lower register.

**Ashen Pursuit:** twenty-four bars in D minor. Eight-bar pursuit, four-bar
breath, four-bar rebuild, eight-bar varied return. The bass supplies motion;
the middle removes the backbeat and halves the bass activity. Small tom pickups
mark transitions. It shares a D-A-F-E motif with Lanterns Below.

The palette is inspired by sample-based 16-bit-era games, not constrained to an
exact SNES hardware voice count or DSP emulation. Soft synthesized mallet, reed,
pluck and bass contrast with the existing procedural viola pad. Percussion uses
mathematical membrane sweeps and seeded noise. These are not orchestra mockups.

## Rebuild and verification

From the repository root, with Python 3.12 and FFmpeg available:

```sh
python3.12 -m venv /tmp/umbra-music-venv
/tmp/umbra-music-venv/bin/pip install -r output/original_soundtracks/umbra_three_sketches/requirements.txt
/tmp/umbra-music-venv/bin/python output/original_soundtracks/umbra_three_sketches/scripts/build.py --output-dir /tmp/umbra-new-audition
/tmp/umbra-music-venv/bin/python output/original_soundtracks/umbra_three_sketches/scripts/verify.py /tmp/umbra-new-audition --report /tmp/umbra-new-audition/VERIFICATION.json
```

The destination must not exist. Auditions are immutable: a new render uses a new
directory, and musical revisions use a new version. The original-composition
experiment does not pass itself through the classical adaptation source gate.

Loop construction wraps complete note releases and effect tails to the start,
keeping every bar's duration intact. The verifier reads MIDI events back and
compares them with the score, checks frozen input/output hashes, strict codec
decoding, decoded durations, loudness, true/sample peaks, long silences, and FLAC/
Ogg seam discontinuities. These are technical checks, not a substitute for a
listening judgment. User taste review remains pending.

Inspection is the three standalone audio files. A Godot inspection fixture is
not applicable because the audition is not integrated into the game. No engine
or visual checks are required for this isolated music experiment.

Useful next directions after listening: develop the strongest melody into a
90-second loop; soften or brighten the shared instrument palette; or reduce
melodic activity for quieter background use. Choose from the auditions before
further musical iteration.
