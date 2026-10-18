"""Regenerate feedback-4/5 body fixtures from fixed CPU-posed fills only.

Historical native regression-tuck masks stay untouched. Assertions and gate
calibrations are unchanged. These body masks are explicitly CPU diagnostics,
not replacement GPU evidence.
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.silhouette_gates import posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.features import source_pixels

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'


def main():
    layout = read_json(CASE / 'layouts/front.json')
    model = CpuPose(CASE, layout)
    # Preserve the captured GPU body exactly and add only texels introduced by
    # this fix. Replacing the whole old body with a CPU mesh raster would erase
    # the native sampling that makes the wrist/foot mutations meaningful.
    delta = {}
    for part in layout['parts']:
        full = source_pixels(CASE, part)
        baseline = PROJECT / 'tests/rr10/rr13_f3' / ('front_' + part['name'] + '_before_alpha.png')
        with Image.open(baseline) as image:
            before = np.asarray(image) > 0
        full[before] = 0
        x, y, right, bottom = part['bbox']
        delta[part['name']] = full[y:bottom, x:right]
    poses = {(r['clip'], r['frame']): r for r in read_json(CASE / 'proof/samples.json')['samples']
             if r['view'] == 'front' and r['kind'] == 'presented'}
    source_files = [CASE / 'layouts/front.json', CASE / 'compiled_motion.json']
    source_files += [CASE / p['file'] for p in layout['parts']]
    source_hashes = {str(p.relative_to(CASE)): digest(p) for p in source_files}
    count = 0
    for name in ('feedback4', 'feedback5'):
        folder = PROJECT / 'tests/rr10' / name
        manifest = read_json(folder / 'captures.json')
        for record in manifest['frames']:
            row = poses[record['clip'], record['frame']]
            layers, maps = model.layers(row, delta)
            body = [layer for layer in layers if layer[0]['name'] not in manifest['rigid_tucks']]
            added = posed_owners(body, layout['parts'], row['bones'], PROOF_DEFAULTS['source_offset'])
            original = record['files']['historical_owners']
            if digest(folder / original['file']) != original['sha256']:
                raise ValueError('Changed historical native body')
            with Image.open(folder / original['file']) as image:
                owners = np.asarray(image).copy()
            owners[(owners == 0) & (added > 0)] = added[(owners == 0) & (added > 0)]
            path = folder / record['files']['owners']['file']
            Image.fromarray(owners).save(path)
            record['files']['owners']['sha256'] = digest(path)
            count += 1
        manifest['scope'] = ('rr-13 feedback 3: historical GPU body plus only newly added fixed-fill CPU texels; '
                             'historical seams, rest-hole masks and regression_tuck unchanged; not GPU acceptance')
        manifest['fixed_fill_source_sha256'] = source_hashes
        manifest['cpu_pose_sha256'] = digest(PROJECT / 'tools/humanoid_cutout/cpu_pose.py')
        write_json(folder / 'captures.json', manifest)
    print('RR13 CPU SEAM FIXTURES: regenerated %d poses from fixed fills; regression tucks unchanged' % count)


if __name__ == '__main__':
    main()
