#!/usr/bin/env python3
"""Reproduce reviewed sprite/card imports from the surface art provenance manifest.

Generation stays in ImageGen; this only crops/resizes approved source textures to
existing game windows and verifies their source/output hashes. Originals remain
untouched. Run without --apply to check committed outputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'spec/board_surface_refactor/ART_MANIFEST.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def imported_image(source, entry):
    image = Image.open(source)
    if image.mode != 'RGBA' or image.getchannel('A').getextrema()[0] != 0:
        raise ValueError(f'{source.name} has no true transparent background')
    size = tuple(entry['size'])
    if entry['recipe'] == 'fit':
        return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)
    if entry['recipe'] == 'frames':
        # Generated atlases are not guaranteed to have evenly spaced cells.
        # Approved source rectangles preserve whole frames; use one scale per
        # animation so a collapsing creature does not grow to fill its frame.
        cells = [image.crop(tuple(rect)) for rect in entry['source_rects']]
        boxes = [cell.getchannel('A').point(lambda value: 255 if value > 32 else 0).getbbox() for cell in cells]
        scale = entry['standing_height'] / (boxes[0][3] - boxes[0][1])
        final = Image.new('RGBA', size)
        for index, (cell, box) in enumerate(zip(cells, boxes)):
            cell = cell.crop(box)
            cell = cell.resize((round(cell.width * scale), round(cell.height * scale)), Image.Resampling.LANCZOS)
            if cell.width > 255 or cell.height > 255:
                raise ValueError('Approved frame exceeds the existing 255px cell')
            final.alpha_composite(cell, ((index % 4) * 255 + (255 - cell.width) // 2, (index // 4) * 255 + entry['baseline'] - cell.height))
        return final
    box = image.getchannel('A').point(lambda value: 255 if value > 12 else 0).getbbox()
    image = image.crop(box)
    image.thumbnail((size[0] - 4, size[1] - 4), Image.Resampling.LANCZOS)
    final = Image.new('RGBA', size)
    y = size[1] - image.height - 2 if entry['recipe'] == 'bottom' else (size[1] - image.height) // 2
    final.alpha_composite(image, ((size[0] - image.width) // 2, y))
    return final


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, help='Directory containing original ImageGen PNGs')
    parser.add_argument('--apply', action='store_true', help='Recreate game-sized files from verified original sources')
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    for entry in manifest['assets']:
        target = ROOT / entry['target']
        if args.source_dir:
            source = args.source_dir / entry['source']
            if digest(source) != entry['source_sha256']:
                raise ValueError(f'Original source changed: {source}')
            if args.apply:
                imported_image(source, entry).save(target)
        elif args.apply:
            parser.error('--apply requires --source-dir')
        if digest(target) != entry['output_sha256']:
            raise ValueError(f'Reviewed output differs: {target}')
        image = Image.open(target)
        if image.mode != 'RGBA' or list(image.size) != entry['size']:
            raise ValueError(f'Wrong target format: {target}')
    print(f"ART_IMPORT_PASS assets={len(manifest['assets'])}")


if __name__ == '__main__':
    main()
