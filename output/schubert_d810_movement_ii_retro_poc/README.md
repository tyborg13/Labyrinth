# Schubert D.810 Movement II - Retro POC

This folder is the provenance-first source and audition package. The approved driving-loop Ogg is also copied into the game as non-boss combat music; the immutable source, editable MIDI, lossless render, and every earlier audition remain here.

The approved v03 style is now also captured by `driving_tactical_loop.track.json`. The shared renderer, verifier, deterministic bank generator, new-track scaffold, and production workflow are documented in `spec/classical_soundtrack_pipeline.md` and exposed through `tools/classical_soundtrack.py` plus `$create-labyrinth-classical-track`. All earlier audition artifacts remain unchanged.

## Primary audition files

- `faithful_retro.mid` - five-voice faithful retro arrangement
- `faithful_retro_preview.ogg` - compact reference preview, Ogg Vorbis
- `faithful_retro_preview.flac` - lossless reference from the same procedural render
- `ARRANGEMENT_NOTES.md` - every material transformation and next-version directions
- `LICENSE_SOURCE.md` - source, license, hashes, URLs, and audio provenance

## Version 2: active tactical loop

- `active_tactical_loop.mid` - 4:31 structural A-B-C-B-A loop built from the requested active regions
- `active_tactical_loop_preview.ogg` - 4:29 compact seamless-loop audition render
- `active_tactical_loop_preview.flac` - lossless render of the same loop
- `ACTIVE_TACTICAL_LOOP_NOTES.md` - exact source windows, form, transformations, echo, and seam behavior
- `PROCEDURAL_BANK_PROVENANCE.md` - rights and generation evidence for the five original WAV samples
- `procedural_bank/` - reproducibly generated, looped 16 kHz SNES-inspired instrument WAVs and manifest

Version 2 is additive: its build and verifier assert the hashes of the version-1 MIDI, previews, and combined normalized files so the first audition remains unchanged.

## Version 3: driving tactical loop

- `driving_tactical_loop.mid` - the complete version-2 string material with a separate percussion track and modest violin lift
- `driving_tactical_loop_preview.ogg` - compact 4:29 seamless-loop audition render
- `driving_tactical_loop_preview.flac` - lossless render of the same loop
- `DRIVING_TACTICAL_LOOP_NOTES.md` - exact balance changes, beat design, preservation policy, and audition questions
- `DRIVING_PERCUSSION_PROVENANCE.md` - rights and generation evidence for the three original percussion WAVs
- `procedural_percussion_bank/` - reproducibly generated 16 kHz low drum, muted tom, ash tick, and manifest

Version 3 is also additive. Its verifier locks both prior versions by hash, proves that all 3,212 version-2 string events remain at identical pitches/times/gates, and verifies that percussion is isolated to MIDI channel 10.

## Normalized source outputs

- `normalized/movement_ii_four_parts.musicxml`
- `normalized/movement_ii_four_parts.mid`
- `normalized/parts/` - separate MusicXML and MIDI files for Violin I, Violin II, Viola, and Cello

The unchanged OpenScore source and its license are under `source/`. The public-domain IMSLP reference edition is under `source/reference/`.

## Rebuild

Prerequisites:

- Python 3.12 or newer
- FFmpeg with FLAC plus either `libvorbis` or the native Vorbis encoder

From this POC folder:

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python scripts/build_arrangement.py
.venv/bin/python scripts/verify_outputs.py
```

If the Python 3.12+ executable has a different name, substitute its absolute path in the first command. The current build used Python 3.12.13 and FFmpeg's native Vorbis encoder, and also emitted a lossless FLAC reference. The script replaces FFmpeg's random Ogg stream serial with a fixed value and repairs page checksums so repeated builds are byte-stable on the pinned toolchain. Pass `--skip-audio` to build only MusicXML and MIDI.

`scripts/build_arrangement.py` verifies the immutable source hash before doing any work. `scripts/verify_outputs.py` writes `VERIFICATION_REPORT.json` and fails on source drift, missing parts, hanging/incorrect arranged notes, excess voice count, or invalid preview containers.

Build and verify the active tactical loop separately:

```bash
.venv/bin/python scripts/build_active_tactical_loop.py
.venv/bin/python scripts/verify_active_tactical_loop.py
```

The version-2 build writes only `active_tactical_loop*`, `procedural_bank/`, and its own reports. It does not rebuild or overwrite the faithful first version.

Build and verify the driving percussion draft separately:

```bash
.venv/bin/python scripts/build_driving_tactical_loop.py
.venv/bin/python scripts/verify_driving_tactical_loop.py
```

The version-3 build writes only `driving_tactical_loop*`, `procedural_percussion_bank/`, and its own reports. It reads the version-2 string bank but verifies its hashes and never writes it.

## Courtesy credit

Musical source: OpenScore String Quartets (CC0), score 7397765. Original composition by Franz Schubert (public domain).
