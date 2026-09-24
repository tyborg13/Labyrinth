# Version 02: connected phrases and darker instrumentation

User feedback: all three melodies are promising; Lanterns Below is the clear
favorite and nearly suitable for quiet rooms. Revise all three, concentrating on
The Turning Key and Ashen Pursuit. The last two have an isolated note/pause lead
and awkward longer gaps. Ashen Pursuit is too chipper or reminiscent of cheerful
science fiction rather than dark fantasy.

## Auditions and musical changes

| Track | Version 02 | Change |
| --- | --- | --- |
| Lanterns Below | 53.33 s / 72 BPM | Original mallet melody, timing, velocities, and synthesis retained. Low replies connect more naturally; pluck 10% quieter and pad 6% stronger. One quiet low answer added at the end of bar 8. |
| The Turning Key | 48 s / 80 BPM | Same melodic pitch sequence one octave lower, carried by a bowed tenor viol. Notes join into four-bar phrases with short breaths. Lower, quieter plucks and occasional upper-viol answers. |
| Ashen Pursuit | 57.60 s / 100 BPM | Lower cello-like lead, connected bowing, a steadier bass, and low war drum/tom instead of the tick/snare backbeat. G minor and E-flat replace the brighter middle. Sparse viol answers at phrase endings. |

These are musical revisions, not just a reverb preset. The final two leads use a
continuous sample cursor and bow envelope within each phrase, so every pitch
change does not restart an attack. Short gain ramps shape note-to-note pressure;
a 12 ms pitch transition avoids a discontinuity without an extended slide.
The Turning Key retains its melody's pitch order; Ashen Pursuit retains its
opening and return pitch order an octave lower, with a revised middle passage.

Lanterns Below deliberately keeps its mallet's original articulation and open
texture. Its low reply has longer gates through bars 7-8 and into the final
turnaround. The main tune and its sound are not rewritten.

All versions target -20 LUFS so a louder mix does not win the comparison. MP3 is
for convenient audition; FLAC is the lossless reference and Ogg is provided for
loop playback. JSON scores and MIDI accompany each audio file in `versions/v02`.
MIDI carries the notes; it does not reproduce the custom sounds in a generic
player. The code is the authoring source of truth.

## Provenance and version preservation

The unchanged `PROVENANCE.md` documents version 01. Version 02 adds the project's
existing procedural `grave_cello_c2.wav` alongside `hollow_viola_c3.wav`, both from
`assets/audio/instruments/classical_dark_fantasy_v1`. The bank manifest and both
sample hashes are frozen in the new `SOURCES.json`. No external recordings,
downloaded music, ripped instruments, or generated-model audio are used.

Version 01's source files, documents, manifests, audio, and MIDI remain unchanged
and independently verifiable. New code is in `scripts/build_v02.py` and
`scripts/compare_v02.py`; the original builder and verifier are reused unchanged.
The classical source gate and game routing are unchanged. User praise of v01 is
taste feedback; this revision does not treat it as publication or integration
approval. Version 02 awaits listening feedback.

## Rebuild and checks

Use the Python 3.12 environment and pinned `requirements.txt` from the first
audition. From the repository root:

```sh
python output/original_soundtracks/umbra_three_sketches/scripts/build_v02.py --output-dir /tmp/umbra-v02-new
python output/original_soundtracks/umbra_three_sketches/scripts/verify.py /tmp/umbra-v02-new --report /tmp/umbra-v02-new/VERIFICATION.json
python output/original_soundtracks/umbra_three_sketches/scripts/compare_v02.py /tmp/umbra-v02-new --report /tmp/umbra-v02-new/COMPARISON.json
```

The destination must not exist. New auditions cannot overwrite old ones.
`verify.py` covers source/artifact hashes, independent MIDI readback, codec
decoding, duration, loudness, sample/true peaks, silence and loop seams.
`compare_v02.py` checks retained melodic material, regenerated score equality,
the requested tempo/percussion changes, and reduced lead gaps. It also reports
mix spectrum changes. Gate and spectral metrics substantiate specific changes;
they are not ratings of beauty, mood, or musical taste.

Inspection: compare the standalone v01 and v02 audio. A Godot fixture is not
applicable before game integration. No listening judgment is claimed by the
technical verifier; actual satisfaction of the aesthetic feedback is for the
user's audition.
