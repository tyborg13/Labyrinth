# Pictures at an Exhibition - The Old Castle

This workspace contains non-overwriting Escape the Umbra auditions of Mussorgsky's `Il vecchio castello`.

- `source/` preserves both the no-license-conflict CC0 PDMX v9 solo-piano MIDI and the public-domain 1918 Breitkopf & Härtel reference scan byte-for-byte.
- `scripts/build_arrangement.py` reproducibly writes the selected 32-measure v01 reduction and arrangement MIDI.
- `normalized/` contains that selected v01 reduction as MusicXML/MIDI plus its separate piano part; it is not a transcription of the complete movement.
- `track.json` and `versions/v01/` preserve the original shortened loop sketch and all of its independently named audition artifacts.
- `transcription/TRANSCRIPTION_AUDIT.md` records the CC0 movement boundary, 107-measure page map, system anchors, and reduction boundary.
- `scripts/build_full_arrangement.py` reproducibly selects the complete movement and writes the five-line normalized reduction and v02 arrangement MIDI.
- `track.v02.json` and `versions/v02/` describe the complete, approximately 4:28, no-cut v02 audition.

Both versions are audition packages only. Neither is approved or wired into game music routes.
