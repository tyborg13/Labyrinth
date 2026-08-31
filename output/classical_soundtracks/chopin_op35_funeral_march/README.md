# Chopin Op. 35 — Marche funèbre — retro audition

This workspace preserves a provenance-cleared, full-movement v01 audition of Frédéric Chopin's `Marche funèbre` in Escape the Umbra's restrained 16-bit dark-fantasy palette.

- `source/` preserves the exact CC0 PDMX v9 solo-piano MIDI, its dataset evidence, and a public-domain 1878 solo-piano score scan.
- `scripts/build_arrangement.py` extracts the exact 108-measure third movement, writes stable normalized hand parts, and deterministically creates the six-track audition MIDI.
- `versions/v01/` retains the audition MIDI, Ogg, FLAC, build report, verification report, and arrangement decisions.
- v01 is an audition only. It is not approved, promoted, sliced, or routed to the death screen.

Rebuild from the repository root:

```bash
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py doctor
.venv-classical-soundtrack/bin/python output/classical_soundtracks/chopin_op35_funeral_march/scripts/build_arrangement.py
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py render --config output/classical_soundtracks/chopin_op35_funeral_march/track.json
.venv-classical-soundtrack/bin/python tools/classical_soundtrack.py verify --config output/classical_soundtracks/chopin_op35_funeral_march/track.json --report output/classical_soundtracks/chopin_op35_funeral_march/versions/v01/VERIFICATION.json
```
