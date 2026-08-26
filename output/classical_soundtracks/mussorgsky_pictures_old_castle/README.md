# Pictures at an Exhibition - The Old Castle

This workspace contains non-overwriting Escape the Umbra auditions of Mussorgsky's `Il vecchio castello`.

- `source/` preserves the public-domain 1918 Breitkopf & Härtel reprint of the 1886 Bessel piano edition byte-for-byte.
- `scripts/build_arrangement.py` reproducibly writes the selected 32-measure v01 reduction and arrangement MIDI.
- `normalized/` contains that selected v01 reduction as MusicXML/MIDI plus its separate piano part; it is not a transcription of the complete movement.
- `track.json` and `versions/v01/` preserve the original shortened loop sketch and all of its independently named audition artifacts.
- `transcription/omr_raw/` freezes the project-generated optical transcription of the three source-score pages containing the movement.
- `scripts/build_full_arrangement.py` reproducibly normalizes those page transcriptions into the complete 106-measure movement and writes the v02 arrangement MIDI.
- `track.v02.json` and `versions/v02/` describe the complete, approximately 4:25, no-cut v02 audition.

Both versions are audition packages only. Neither is approved or wired into game music routes.
