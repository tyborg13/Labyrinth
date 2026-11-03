#!/usr/bin/env python3
"""Diagnostic assembly of approved Gaoler pieces, original/cel at exact 2x."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
PROOF_SCALE = 2
PROOF_COLUMNS = 4
PROOF_PADDING = 12
PROOF_CAPTION = 24


def make_sheet(output):
    facing = Path('assets/units/chainbound_gaoler_cutout/humanoid_v2/front')
    paths = sorted((PROJECT / facing).glob('*.png'))
    pairs = []
    for path in paths:
        if path.name == 'rest.png':
            continue
        original = Image.open(path).convert('RGBA')
        cel = Image.open(PROJECT / 'cel_look_variants' / facing / (path.name + '.celpng')).convert('RGBA')
        bbox = original.getbbox() or (0, 0, *original.size)
        a = original.crop(bbox)
        b = cel.crop(bbox)
        pairs.append((path.name, a.resize((a.width * PROOF_SCALE, a.height * PROOF_SCALE), Image.Resampling.NEAREST),
                      b.resize((b.width * PROOF_SCALE, b.height * PROOF_SCALE), Image.Resampling.NEAREST)))
    width = max(a.width + b.width for _, a, b in pairs) + PROOF_PADDING * 3
    height = max(a.height for _, a, _ in pairs) + PROOF_CAPTION + PROOF_PADDING * 2
    sheet = Image.new('RGB', (width * PROOF_COLUMNS, height * ((len(pairs) + PROOF_COLUMNS - 1) // PROOF_COLUMNS)), '#302c2a')
    draw = ImageDraw.Draw(sheet)
    for index, (name, a, b) in enumerate(pairs):
        x, y = index % PROOF_COLUMNS * width, index // PROOF_COLUMNS * height
        draw.text((x + PROOF_PADDING, y + 4), name + ' | original / cel (2x)', fill='white')
        sheet.paste(a, (x + PROOF_PADDING, y + PROOF_CAPTION), a)
        sheet.paste(b, (x + PROOF_PADDING * 2 + a.width, y + PROOF_CAPTION), b)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(f'CEL_CONTACT_SHEET {output} pieces={len(pairs)} scale={PROOF_SCALE}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    make_sheet(parser.parse_args().output)
