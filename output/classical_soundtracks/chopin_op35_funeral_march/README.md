# Chopin Op. 35 — Marche funèbre — retro audition

This workspace preserves a provenance-cleared, full-movement v01 audition of Frédéric Chopin's `Marche funèbre` in Escape the Umbra's restrained 16-bit dark-fantasy palette.

- `source/` preserves the exact CC0 PDMX v9 solo-piano MIDI, its dataset evidence, and a public-domain 1878 solo-piano score scan.
- `scripts/build_arrangement.py` extracts the exact 108-measure third movement, writes stable normalized hand parts, and deterministically creates the six-track audition MIDI.
- `scripts/build_arrangement_v02.py` preserves v01 and builds the user's A → B → C experiment from source measures 85–86, 93–98, and 49–53, with source-derived bridges and the familiar march lead removed.
- `scripts/build_arrangement_v03.py` preserves both earlier auditions, reorders the experiment B → A → C, restores B's non-iconic lead, and keeps the recognizable lead removed only from v2's former intro passage.
- `versions/v01/` retains the audition MIDI, Ogg, FLAC, build report, verification report, and arrangement decisions.
- `versions/v02/` retains the shorter motif-suppressed loop audition and its independent proof.
- `versions/v03/` retains the melody-first reordered audition and its independent proof.
- All three versions are auditions only. None is approved, promoted, or routed to the death screen.

Rebuild from the repository root:

```bash
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py doctor
.venv-classical-soundtrack/bin/python output/classical_soundtracks/chopin_op35_funeral_march/scripts/build_arrangement.py
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py render --config output/classical_soundtracks/chopin_op35_funeral_march/track.json
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py verify --config output/classical_soundtracks/chopin_op35_funeral_march/track.json --report output/classical_soundtracks/chopin_op35_funeral_march/versions/v01/VERIFICATION.json

.venv-classical-soundtrack/bin/python output/classical_soundtracks/chopin_op35_funeral_march/scripts/build_arrangement_v02.py
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py render --config output/classical_soundtracks/chopin_op35_funeral_march/track.v02.json
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py verify --config output/classical_soundtracks/chopin_op35_funeral_march/track.v02.json --report output/classical_soundtracks/chopin_op35_funeral_march/versions/v02/VERIFICATION.json

.venv-classical-soundtrack/bin/python output/classical_soundtracks/chopin_op35_funeral_march/scripts/build_arrangement_v03.py
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py render --config output/classical_soundtracks/chopin_op35_funeral_march/track.v03.json
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py verify --config output/classical_soundtracks/chopin_op35_funeral_march/track.v03.json --report output/classical_soundtracks/chopin_op35_funeral_march/versions/v03/VERIFICATION.json
```
