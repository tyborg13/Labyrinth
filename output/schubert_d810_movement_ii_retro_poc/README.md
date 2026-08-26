# Schubert D.810 Movement II - Retro POC

This folder is a provenance-first audition package. It is not wired into the game and does not replace any existing music asset.

## Primary audition files

- `faithful_retro.mid` - five-voice faithful retro arrangement
- `faithful_retro_preview.ogg` - compact reference preview, Ogg Vorbis
- `faithful_retro_preview.flac` - lossless reference from the same procedural render
- `ARRANGEMENT_NOTES.md` - every material transformation and next-version directions
- `LICENSE_SOURCE.md` - source, license, hashes, URLs, and audio provenance

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

## Courtesy credit

Musical source: OpenScore String Quartets (CC0), score 7397765. Original composition by Franz Schubert (public domain).
