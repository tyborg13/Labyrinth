"""Build own-edge gait continuations from sampled seam and component gaps.

CPU raster is a construction aid. Native renderer acceptance remains required.
Only transparent texels in existing draw surfaces are populated in a declared
clip; original textures, skin weights, rest and idle remain untouched.
"""
from collections import Counter
import argparse
import numpy as np
from rr21_case import CASE, ASSETS
from rr21_seams import state
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.anatomy import load, owner_ids
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from humanoid_cutout.gait_continuations import nearest_donors
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import holes, dilate, components

MAX_CONSTRUCTION_PASSES = 16  # Same convergence guard as gait-01.
RASTER_COVERAGE_MARGIN_PX = 1  # Cover both sides of the native pixel square.


def defects(model, pose):
    layers, maps, owners, pockets = state(model, pose)
    masks = []
    for hole in holes(owners > 0):
        y, x = np.nonzero(hole)
        box = [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]
        if any(p['bbox'] == box for p in pockets): masks.append(hole)
    labels, groups = components(owners > 0, 8)
    if groups:
        main = labels == groups[0][0]
        for label, _ in groups[1:]:
            component = labels == label
            # Bridge the shortest separation to the main silhouette. A
            # continuation covers the piece's edge; no detached paint is cut.
            a = np.argwhere(component)
            boundary = main & dilate(~main, 1)
            b = np.argwhere(boundary)
            distance = np.sum((a[:, None] - b[None]) ** 2, axis=2)
            i, j = np.unravel_index(distance.argmin(), distance.shape)
            start, end = a[i], b[j]
            count = int(np.max(np.abs(end - start))) + 1
            line = np.rint(np.linspace(start, end, count)).astype(int)
            gap = component.copy()
            gap[line[:, 0], line[:, 1]] = True
            masks.append(gap)
    return masks, owners, maps


def extend(model, pose, mask, owners, maps):
    ids = owner_ids(load(CASE)['ownership'])
    reverse = {v: k for k, v in ids.items()}
    vocabulary = load(CASE)['ownership']['segments']
    logical = {owner: garment for garment, record in vocabulary.items() for owner in record['owners']}
    boundary = owners[dilate(mask, 1) & (owners > 0)]
    counts = Counter(logical.get(reverse[int(n)], reverse[int(n)]) for n in boundary)
    target = dilate(mask, RASTER_COVERAGE_MARGIN_PX)
    options = []
    for part in model.layout['parts']:
        if part['logical_part'] not in counts: continue
        source = model.image(part['file'])
        if part['name'] in maps:
            mapping = maps[part['name']]
            keep = target[mapping.pixels[:, 1], mapping.pixels[:, 0]]
            xy, uv = mapping.pixels[keep], mapping.texels[keep]
        else:
            y, x = np.nonzero(target)
            xy = np.column_stack((x, y))
            inverse = np.linalg.inv(sprite_transform(model.layout, pose, part))
            local = (xy + .5 - PROOF_DEFAULTS['source_offset']) @ inverse[:2, :2].T + inverse[:2, 2]
            uv = np.floor(local).astype(int)
        u, v = uv.T
        valid = (u >= 0) & (v >= 0) & (u < source.shape[1]) & (v < source.shape[0])
        xy, uv = xy[valid], uv[valid]
        missing = source[uv[:, 1], uv[:, 0], 3] == 0
        covered = int(mask[xy[missing, 1], xy[missing, 0]].sum())
        if covered:
            options.append((covered, counts[part['logical_part']], bool(part.get('hidden_material')), part, uv[missing]))
    if not options: raise ValueError(f'No existing surface covers {pose["view"]}/{pose["frame"]} gap')
    _, _, _, part, uv = max(options, key=lambda r: r[:3])
    targets = {tuple(p) for p in uv}
    table = (model.layout.setdefault('gait_continuations', {}) if pose['clip'] == 'move' else
             model.layout.setdefault('clip_continuations', {}).setdefault(pose['clip'], {}))
    old = table.get(part['name'], {}).get('texels', [])
    targets.update((x, y) for x, y, _, _ in old)
    table[part['name']] = nearest_donors(CASE, model.layout, part, targets)


def build(samples, actions=False):
    recipes = {}
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        field = 'clip_continuations' if actions else 'gait_continuations'
        layout.pop(field, None)
        model = CpuPose(CASE, layout)
        clips = [c for c in read_json(CASE / 'compiled_motion.json')['clips'] if c not in ('move', 'idle')] if actions else ['move']
        before = []
        for clip in clips:
            poses = [p for p in samples['samples'] if p['view'] == view and p['clip'] == clip and p['kind'] == 'presented']
            for index in range(MAX_CONSTRUCTION_PASSES):
                count = 0
                for pose in poses:
                    masks, owners, maps = defects(model, pose)
                    if index == 0 and masks: before.append({'clip': clip, 'frame': pose['frame'], 'gaps': len(masks)})
                    for mask in masks:
                        extend(model, pose, mask, owners, maps)
                        count += 1
                print(f'RR21 {view.upper()} {clip.upper()} COVERAGE: pass {index + 1}, {count} gaps', flush=True)
                if not count: break
            else: raise ValueError('Joint coverage did not converge')
        recipes[view] = layout.get(field, {})
        for part in layout['parts']: part.pop('proof_ownership', None)
        write_json(CASE / f'layouts/{view}.json', layout)
        for folder in (ASSETS / 'humanoid_v2', ASSETS):
            path = folder / (view + '.json')
            production = read_json(path)
            production[field] = recipes[view]
            write_json(path, production)
        write_json(CASE / f'proof/logs/{field}/{view}.json', {'native_pixels': False, 'before': before})
    write_json(CASE / (field + '.json'), recipes)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--actions', action='store_true')
    build(read_json(CASE / 'proof/logs/samples.json'), parser.parse_args().actions)
