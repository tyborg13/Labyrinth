"""Read retained director pixels to diagnose rr-15; never certify a fresh rig."""
import argparse
from collections import defaultdict
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.underlays import native_order
from maquette_motion.pixels import changed, render, unpack
from maquette_motion.native_ties import select
from humanoid_cutout.native_frames import load_frame

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
SCRATCH = Path('/private/tmp/labyrinth_codex/rr-15')
FOCUS = ('front', 'idle', 6)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, default=CASE / 'proof/native')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(SCRATCH):
        raise ValueError('Historical audit output must stay under ' + str(SCRATCH))
    manifest = read_json(args.capture / 'frames.json')
    frames = {(r['view'], r['clip'], r['frame']): r for r in manifest['frames']}
    pieces = defaultdict(list)
    for row in manifest['pieces']:
        pieces[row['view'], row['clip'], row['frame']].append(row)
    orders = {view: {name: index for index, name in enumerate(native_order(read_json(CASE / f'layouts/{view}.json')))}
              for view in ('front', 'rear')}
    original_failures, corrected_failures, focus = [], [], {}
    for key, rows in pieces.items():
        layers = [(row, load_frame(args.capture / row['file']).convert('RGBA')) for row in rows]
        original, corrected = Image.new('RGBA', (512, 512)), Image.new('RGBA', (512, 512))
        for row, image in sorted(layers, key=lambda item: item[0]['z_index']):
            original.alpha_composite(image)
        for row, image in sorted(layers, key=lambda item: (item[0]['z_index'], orders[key[0]][item[0]['name']])):
            corrected.alpha_composite(image)
        actual = np.asarray(load_frame(args.capture / frames[key]['file']).convert('RGBA'))
        wrong = changed(actual, np.asarray(original))
        fixed = changed(actual, np.asarray(corrected))
        if wrong.any(): original_failures.append(dict(key=key, pixels=int(wrong.sum())))
        if fixed.any(): corrected_failures.append(dict(key=key, pixels=int(fixed.sum())))
        if key == FOCUS:
            ys, xs = np.nonzero(wrong)
            focus = {'key': key, 'pixels': [[int(x), int(y)] for y, x in zip(ys, xs)],
                'contributors': {r['name']: int((wrong & (np.asarray(image)[..., 3] > 0)).sum())
                    for r, image in layers if (wrong & (np.asarray(image)[..., 3] > 0)).any()},
                'native_rgba': actual[wrong].tolist(), 'incorrect_composite_rgba': np.asarray(original)[wrong].tolist()}
    fixtures = PROJECT / 'tests/rr11/rr15'
    rigid = []
    for row in read_json(fixtures / 'rigid_before.json'):
        actual = np.asarray(load_frame(fixtures / f'rear_{row["clip"]}{row["frame"]}_hidden_tube_native.png').convert('RGBA'))
        source = load_frame(fixtures / 'rear_hidden_tube_before.png').convert('RGBA')
        samples = render(source, unpack(row['transform']), with_ties=True)
        matched, invalid = select(actual, samples)
        rigid.append({'clip': row['clip'], 'frame': row['frame'], 'default_difference_px': int(changed(actual, samples.default).sum()),
            'exact_source_candidate_difference_px': int(changed(actual, matched).sum()), 'invalid_ties': int(invalid.sum())})
    write_json(args.output, {'native_pixels': True, 'fresh_capture': False, 'acceptance': False,
        'scope': 'historical director capture; ordering and source-UV diagnosis only',
        'manifest_sha256': digest(args.capture / 'frames.json'), 'frames': len(frames),
        'original_composite_failures': original_failures, 'native_order_failures': corrected_failures,
        'front_idle6': focus, 'rigid_ties': rigid})
    print('RR15 HISTORICAL COMPOSITE AUDIT: %d original failures; %d with native order (%d frames)' %
        (len(original_failures), len(corrected_failures), len(frames)))
    print('RR15 FRONT IDLE 6: %d differing pixels; %s' % (len(focus['pixels']), focus['contributors']))
    print('RR15 HISTORICAL RIGID TIES: %d default differences; %d exact candidate differences' %
        (sum(r['default_difference_px'] for r in rigid), sum(r['exact_source_candidate_difference_px'] for r in rigid)))
    return int(bool(corrected_failures or any(r['exact_source_candidate_difference_px'] for r in rigid)))


if __name__ == '__main__':
    raise SystemExit(main())
