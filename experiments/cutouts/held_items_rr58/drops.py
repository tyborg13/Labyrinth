"""Paired native drop strips with one shared crop and 3x nearest magnification."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw
from config import DEFAULTS, read_json, write_json, digest


def strips(before, after, output):
    manifests = [read_json(p / 'frames.json') for p in (before, after)]
    if not all(m['native_pixels'] and m['ok'] for m in manifests): raise ValueError('Verified native captures required')
    rig = manifests[0]['rig']
    if manifests[1]['rig'] != rig: raise ValueError('Different rigs')
    frames = [28, 29, 41, 95] if rig == 'chainbound_gaoler' else [20, 21, 33, 101]
    output.mkdir(parents=True, exist_ok=True)
    for view in ('front', 'rear'):
        pairs = []
        for root, manifest in zip((before, after), manifests):
            records = [next(r for r in manifest['frames'] if (r['view'], r['clip'], r['frame']) == (view, 'death', f)) for f in frames]
            for row in records:
                if digest(root / row['file']) != row['sha256']: raise ValueError('Changed native drop frame')
            pairs.append([Image.open(root / r['file']).convert('RGBA') for r in records])
        bounds = [im.getbbox() for images in pairs for im in images]
        box = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
        z, gutter = DEFAULTS['magnification'], DEFAULTS['strip_gutter_px']
        w, h = (box[2]-box[0])*z, (box[3]-box[1])*z
        for state, images in zip(('before', 'after'), pairs):
            sheet = Image.new('RGBA', (w*len(images), h+gutter), tuple(DEFAULTS['proof_background_rgba']))
            draw = ImageDraw.Draw(sheet)
            for i, (im, frame) in enumerate(zip(images, frames)):
                sheet.alpha_composite(im.crop(box).resize((w, h), Image.Resampling.NEAREST), (i*w, gutter))
                draw.text((i*w, 0), f'{rig} {view} {state} {frame}', fill='white')
            sheet.save(output / (view + '_' + state + '_drop_3x_native.png'))
        write_json(output / (view + '_frames.json'), {'native_pixels': True, 'frames': frames, 'shared_crop': box, 'magnification': z})
    print('RR58 NATIVE DROP STRIPS: ' + str(output))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for field in ('before', 'after', 'output'): p.add_argument('--' + field, type=Path, required=True)
    a = p.parse_args(); strips(a.before, a.after, a.output)
