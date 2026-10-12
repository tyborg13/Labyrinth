#!/usr/bin/env python3
"""Deterministically process only hash-approved event paintings and wax seals."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW_ROOT = Path('/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art')
PAINTING_SIZE = (1152, 768)
SEAL_SIZE = (96, 96)
KEY_BACKGROUND_TOLERANCE = 32  # Suppress quantized near-#00FF00 background noise.


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def approved_hashes(path: Path) -> dict[str, str]:
    return {name: digest for digest, name in (line.split() for line in path.read_text().splitlines() if line.strip())}


def painting(image: Image.Image) -> Image.Image:
    return image.convert('RGB').resize(PAINTING_SIZE, Image.Resampling.LANCZOS)


def seal(image: Image.Image) -> Image.Image:
    # Recover coverage against the known pure-green matte, then unmix the
    # matte from edge pixels before resampling. This avoids a green halo.
    rgba = image.convert('RGBA')
    pixels = []
    for r, g, b, _ in rgba.getdata():
        matte = max(0, g - max(r, b))
        alpha = 0 if g >= 255 - KEY_BACKGROUND_TOLERANCE and max(r, b) <= KEY_BACKGROUND_TOLERANCE else 255 - matte
        if alpha == 0:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((min(255, round(r * 255 / alpha)),
                           min(255, max(0, round((g - matte) * 255 / alpha))),
                           min(255, round(b * 255 / alpha)), alpha))
    rgba.putdata(pixels)
    bounds = rgba.getchannel('A').getbbox()
    if bounds is None:
        raise ValueError('Approved seal has no foreground')
    trimmed = rgba.crop(bounds)
    side = max(trimmed.size)
    square = Image.new('RGBA', (side, side))
    square.paste(trimmed, ((side - trimmed.width) // 2, (side - trimmed.height) // 2))
    result = square.resize(SEAL_SIZE, Image.Resampling.LANCZOS)
    # Lanczos can independently overshoot channels by a few levels.
    result.putdata([(r, min(g, max(r, b)), b, a) if a else (0, 0, 0, 0)
                    for r, g, b, a in result.getdata()])
    return result


def process(raw_root: Path = RAW_ROOT, root: Path = ROOT) -> dict:
    catalog = json.loads((root / 'data/events.json').read_text())
    records = []
    for family, directory, transform, ids in (
        ('event_art', 'assets/art/events', painting, catalog['events']),
        ('omen_icons', 'assets/art/icons/omens', seal, catalog['omens']),
    ):
        approved = approved_hashes(root / f'spec/peer_benchmark/staged/{family}/approved_sha256.txt')
        for identity in sorted(ids):
            name = f'{identity}.png' if family == 'event_art' else f'omen_{identity}.png'
            raw = raw_root / family / name
            digest = sha256(raw)
            if approved.get(name) != digest:
                raise ValueError(f'Unapproved source: {raw}')
            output = root / directory / f'{identity}.png'
            output.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(raw) as image:
                transform(image).save(output, format='PNG', optimize=True)
            records.append({'id': identity, 'raw': str(raw), 'raw_sha256': digest,
                            'prompt': f'spec/peer_benchmark/staged/{family}/prompts/{identity}.md',
                            'output': str(output.relative_to(root)), 'output_sha256': sha256(output)})
    manifest = {'processor': 'tools/process_event_art.py', 'pillow_version': Image.__version__, 'assets': records}
    destination = root / 'spec/assets/events'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'hashes.json').write_text(json.dumps(manifest, indent=2) + '\n')
    lines = ['# Approved event and omen art', '',
             'Only the design owner’s approved raw paintings and wax seals are used. Raw files and prompt values are protected.', '',
             'Rebuild: `python3 tools/process_event_art.py`. Paintings: RGB 1152×768, Lanczos, optimized PNG. '
             'Seals: unmix #00FF00, trim alpha bounds, centre in a square, Lanczos to RGBA 96×96, optimized PNG. '
             'No added padding beyond squaring. PNG encoding is pinned by the Pillow version in `hashes.json`.', '',
             'Raw approval inventories: `spec/peer_benchmark/staged/event_art/approved_sha256.txt` and '
             '`spec/peer_benchmark/staged/omen_icons/approved_sha256.txt`. Full raw paths and hashes are in `hashes.json`.', '',
             '| Output | Prompt | Raw SHA-256 | Output SHA-256 |', '| --- | --- | --- | --- |']
    lines.extend(f"| `{r['output']}` | `{r['prompt']}` | `{r['raw_sha256']}` | `{r['output_sha256']}` |" for r in records)
    (destination / 'README.md').write_text('\n'.join(lines) + '\n')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw-root', type=Path, default=RAW_ROOT)
    args = parser.parse_args()
    result = process(args.raw_root)
    print(f"Event art processing: {len(result['assets'])} approved outputs")
