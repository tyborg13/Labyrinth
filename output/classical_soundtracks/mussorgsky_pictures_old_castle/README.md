# Pictures at an Exhibition - The Old Castle

This workspace contains non-overwriting Escape the Umbra auditions of Mussorgsky's `Il vecchio castello`.

- `source/` preserves both the no-license-conflict CC0 PDMX v9 solo-piano MIDI and the public-domain 1918 Breitkopf & Härtel reference scan byte-for-byte.
- `scripts/build_arrangement.py` reproducibly writes the selected 32-measure v01 reduction and arrangement MIDI.
- `normalized/` contains that selected v01 reduction as MusicXML/MIDI plus its separate piano part; it is not a transcription of the complete movement.
- `track.json` and `versions/v01/` preserve the original shortened loop sketch and all of its independently named audition artifacts.
- `transcription/TRANSCRIPTION_AUDIT.md` records the CC0 movement boundary, 107-measure page map, system anchors, and reduction boundary.
- `scripts/build_full_arrangement.py` reproducibly selects the complete movement and writes the five-line normalized reduction and v02 arrangement MIDI.
- `track.v02.json` and `versions/v02/` describe the complete, approximately 4:28, no-cut v02 audition.
- `scripts/build_main_menu_loop.py`, `track.v03.json`, and `versions/v03/` preserve a contiguous measures 7-68 main-menu remix at 84 QPM with restrained 6/8 percussion, sparse octave-high glints, and a short loop crossfade.
- `scripts/build_main_menu_loop_v04.py` and `versions/v04/` remove the rejected high-string stabs and bring the original upper voices and v03 percussion slightly forward.
- `scripts/build_main_menu_loop_v05.py` and `versions/v05/` preserve the rejected phrase-aware percussion, low veil, and custom-intro experiment for comparison only.
- `scripts/build_main_menu_loop_v06.py` and `versions/v06/` preserve the approved taste audition: no custom intro, exact v04 percussion, no high-string stabs, and an audible long low-mid Umbra veil.
- `scripts/build_main_menu_loop_v07.py`, `track.v07.json`, and `versions/v07/` preserve v06's MIDI byte-for-byte while adding the frozen encoder, strictly verified 1.3167-second loop crossfade, output hashes, and project-owner approval required for promotion.

v01-v06 remain immutable audition packages. The verified v07 Ogg is promoted byte-for-byte as `assets/audio/music/mussorgsky_old_castle_main_menu.ogg` and routes only to the production main menu for an in-game trial; combat and boss routes are unchanged.
