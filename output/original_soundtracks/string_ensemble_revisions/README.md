# String ensemble revisions

Two new auditions responding to the request for a more violin-like lead, less
foreground melody, and an active string layer between melody and percussion.

| Piece | Track revision | Duration | Parent |
| --- | --- | --- | --- |
| Ashen Pursuit | v03 | 57.60 s | umbra_three_sketches v02 |
| Iron Procession | v02 | 54.55 s | combat_set_02 v01 |

This paired audition package is `versions/v01`. Individual track revision numbers
are included in folder names and scores. Every earlier audition stays unchanged.
Each folder contains MP3, Ogg, lossless FLAC, editable MIDI, the full expanded
score and a render report. All previews target -20 LUFS for fair comparison.

## What changed

- Both main melodies retain every onset, duration, velocity and pitch interval,
  raised one octave into violin range. Tempo, harmonic sequence and form remain.
- A new local procedural string voice combines bowed harmonic excitation, broad
  body resonances, quiet bow friction, small pitch/pressure variation and delayed
  vibrato. Independent vibrato rates separate the two violins and viola. A 16 kHz,
  12-bit source texture is reconstructed at 32 kHz; this evokes a sampled retro
  string rather than reproducing a console or claiming acoustic realism.
- The first violin is calibrated 4 LU below the prior lead before final mastering.
  Second violin and viola are 3 and 4.5 LU below the first violin. Their combined
  middle layer carries harmony and independent movement without constant unison
  doubling. Measured final balances are recorded per track.
- Ashen Pursuit uses answering violin phrases over a steadier viola line. Its
  quieter middle retains longer arcs, and the return adds higher harmony.
- Iron Procession uses broader second-violin responses and lower viola movement;
  its return opens into higher harmony before the dominant turnaround.
- The old sparse answering part is replaced. The pad retains one inner voice,
  leaving room for the viola; at most six melodic note gates sound at once.
- Bass/pluck are reduced 1 LU and pad/percussion 1.5 LU before final mastering.
  Percussion notes are unchanged. This is a string-arrangement revision, with
  detached notes and rests retained rather than forcing everything into legato.

The rendered timbre and blend still need the user's ears. Synthesized bow texture
is feasible here; these auditions do not claim the realism of recorded violins.

## Rebuild

Use Python 3.12, FFmpeg (native Vorbis and libmp3lame), and `requirements.txt`:

```sh
python3.12 -m venv /tmp/umbra-strings-env
/tmp/umbra-strings-env/bin/pip install -r output/original_soundtracks/string_ensemble_revisions/requirements.txt
/tmp/umbra-strings-env/bin/python output/original_soundtracks/string_ensemble_revisions/scripts/build_strings.py --output-dir /tmp/umbra-strings-fresh
/tmp/umbra-strings-env/bin/python output/original_soundtracks/string_ensemble_revisions/scripts/verify_strings.py /tmp/umbra-strings-fresh --report /tmp/umbra-strings-fresh/VERIFICATION.json
```

The destination must not exist. Source hashes include the parent scores, synth,
renderer dependencies, verification code and documentation. Generic MIDI players
preserve the arrangement, but the supplied renderer defines the actual sound.

Release tails, effects and filtering wrap around an exact bar-length period.
A two-millisecond taper at each endpoint suppresses sample/codec boundary clicks;
it does not alter musical timing. Use FLAC or Ogg to assess repeated playback.
MP3 is for convenient audition. Integration and in-game fixtures are outside
this standalone revision request.
