"""Reject newly enclosed or split pockets, including one-pixel source air.

The canonical census rejects missing surfaces and joint tears. This stricter
rr-28 delta also ensures a copy does not trap a formerly open background gap.
It compares CPU support with and without recipes; it changes no shared gate.
"""
import argparse
import json

import numpy as np

from rr28_build import RIGS, paths
from rr28_check import model_for
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.cpu_pose import mapped, sprite_transform
from humanoid_cutout.gates import bindings
from humanoid_cutout.source_space import bounds
from maquette_motion import pixels
from maquette_motion.silhouette import holes


def pocket_delta(model, pose):
    layers, maps = model.layers(pose)
    after = np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in layers])
    before = np.zeros_like(after)
    for part, image, _ in layers:
        recipe = model.layout.get('gait_continuations', {}).get(part['name'])
        if recipe is None or pose['clip'] not in recipe['clips']:
            before |= image[..., 3] > 0
            continue
        source = model.image(part['file'])
        original = (mapped(source, maps[part['name']]) if part['name'] in maps else
                    pixels.render(source, sprite_transform(model.layout, pose, part)))
        before |= original[..., 3] > 0
    originals, used, failures = holes(before), set(), []
    for pocket in holes(after):
        matches = [i for i, original in enumerate(originals) if np.all(original[pocket])]
        if len(matches) == 1 and matches[0] not in used:
            used.add(matches[0])
            continue
        reason = 'split existing pocket' if matches else 'newly enclosed background'
        failures.append({'bbox': bounds(pocket), 'pixel_count': int(pocket.sum()),
            'pixels': np.column_stack(np.nonzero(pocket)[::-1]).tolist(), 'reason': reason})
    return failures


def report(name):
    case, _, recipe = paths(name)
    samples, current = read_report(case), bindings(case)
    if not samples['ok'] or samples['errors'] or samples['inputs'] != current:
        raise ValueError('Refresh bound samples before the pocket delta')
    views = {}
    for view in ('front', 'rear'):
        model = model_for(name, case, read_json(case / f'layouts/{view}.json'))
        cache, failures, count = {}, [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented':
                continue
            count += 1
            active = any(pose['clip'] in r['clips'] for r in model.layout.get('gait_continuations', {}).values())
            if not active:
                continue  # No copy changes the source support in this clip.
            # Equal snapped bones can still have different rigid angle-tie transforms.
            key = json.dumps([pose['clip'], pose['bones'], pose['parts']], sort_keys=True)
            if key not in cache:
                cache[key] = pocket_delta(model, pose)
            if cache[key]:
                failures.append({'view': view, 'clip': pose['clip'], 'frame': pose['frame'], 'pockets': cache[key]})
        views[view] = {'ok': not failures, 'frames': count, 'unique_active_poses': len(cache), 'failures': failures}
        print(f'RR28 POCKET DELTA {name.upper()} {view.upper()}: {"PASS" if not failures else "FAIL"} '
              f'({count} frames; {len(failures)} frames with newly enclosed/split pockets, including 1px)', flush=True)
    if bindings(case) != current:
        raise ValueError('Inputs changed during pocket delta')
    result = {'ok': all(r['ok'] for r in views.values()), 'native_pixels': False,
        'scope': 'CPU before/after recipe support, every clip; no newly enclosed or split pocket of any size',
        'inputs': current, 'views': views}
    write_json(recipe / 'pocket_delta.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rig', choices=RIGS, required=True)
    args = parser.parse_args()
    raise SystemExit(int(not report(args.rig)['ok']))
