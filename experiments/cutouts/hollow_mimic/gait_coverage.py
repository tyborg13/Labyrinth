"""Compile gait seam coverage from the sampled, projected skin envelope.

CPU geometry is a construction/regression aid, never native acceptance. No
painting, density source, mesh field or non-move texture is rewritten.
"""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.anatomy import load, owner_ids
from cpu_proof import CpuPose
from humanoid_cutout.cpu_pose import sprite_transform
from humanoid_cutout.gait_continuations import nearest_donors
from humanoid_cutout.silhouette_gates import joint_holes, posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import holes, dilate

CASE = PROJECT / 'experiments/cutouts/hollow_mimic/rr20'
MAX_CONSTRUCTION_PASSES = 16  # Construction convergence guard, not playback tuning.
RASTER_COVERAGE_MARGIN_PX = 1  # Cover the native pixel square on both triangle sides.


def pockets(model, pose):
    layers, maps = model.layers(pose)
    seam = np.logical_or.reduce(model.masks(pose, model.layout['proof_joint_seams'], maps))
    owners = posed_owners(layers, model.layout['parts'], pose['bones'],
                          PROOF_DEFAULTS['source_offset'], load(CASE)['ownership'])
    defects = joint_holes(owners > 0, seam, owners, pocket_details=True)
    baseline_holes = None
    if model.layout.get('gait_continuations'):
        baseline = deepcopy(model.layout)
        baseline.pop('gait_continuations')
        original = CpuPose(CASE, baseline).layers(pose)[0]
        baseline_holes = holes(np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in original]))
    masks = []
    for hole in holes(owners > 0):
        y, x = np.nonzero(hole)
        bbox = [int(x.min()), int(y.min()), int(x.max())+1, int(y.max())+1]
        known = any(d['bbox'] == bbox for d in defects)
        # Padding must not close an alpha loop around newly trapped air,
        # even if that pocket's boundary belongs entirely to one garment.
        introduced = (hole.sum() > 1 and baseline_holes is not None and
                      not any((hole & old).any() for old in baseline_holes))
        if introduced and not known:
            defects.append({'bbox': bbox, 'pixel_count': int(hole.sum()), 'new_continuation_pocket': True})
        if known or introduced:
            masks.append(hole)
    return defects, masks, owners, maps


def extend(model, pose, hole, owners, maps):
    ids = owner_ids(load(CASE)['ownership'])
    boundary = owners[dilate(hole, 1) & (owners > 0)]
    garment = next((name for name in ('leg_near', 'leg_far')
                    if any(ids[n+'_'+name[4:]] in boundary for n in ('thigh', 'shin'))), 'torso')
    candidates = sorted([p for p in model.layout['parts'] if p['logical_part'] == garment],
                        key=lambda p: (not p.get('hidden_material', False), p['z_index']))
    target = dilate(hole, RASTER_COVERAGE_MARGIN_PX)
    remaining = hole.copy()
    for part in candidates:
        name = part['name']
        source = model.image(part['file'])
        if name in maps:
            mapping = maps[name]
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
        targets = {tuple(p) for p in uv[missing]}
        old = model.layout.setdefault('gait_continuations', {}).get(name, {}).get('texels', [])
        targets.update((x, y) for x, y, _, _ in old)
        if targets:
            model.layout['gait_continuations'][name] = nearest_donors(CASE, model.layout, part, targets)
        remaining[xy[:, 1], xy[:, 0]] = False
        if not remaining.any(): return
    if remaining.any():
        raise ValueError('Existing skin cannot cover joint pocket: ' + str((pose['view'], pose['frame'], garment)))


def build(samples):
    recipes = {}
    for view in ('front', 'rear'):
        path = CASE / f'layouts/{view}.json'
        layout = read_json(path)
        layout.pop('gait_continuations', None)
        model = CpuPose(CASE, layout)
        poses = [r for r in samples['samples'] if r['view'] == view and r['clip'] == 'move' and r['kind'] == 'presented']
        before = []
        for index in range(MAX_CONSTRUCTION_PASSES):
            count = 0
            for pose in poses:
                defects, masks, owners, maps = pockets(model, pose)
                if index == 0 and defects: before.append({'frame': pose['frame'], 'pockets': defects})
                for hole in masks:
                    extend(model, pose, hole, owners, maps)
                    count += 1
            print(f'GAIT COVERAGE {view}: pass {index + 1}, {count} pockets', flush=True)
            if not count: break
        else: raise ValueError('Gait coverage did not converge')
        recipes[view] = layout.get('gait_continuations', {})
        write_json(CASE / f'proof/logs/gait_coverage/{view}.json', {'native_pixels': False,
                   'before': before, 'texel_counts': {n: len(r['texels']) for n, r in layout.get('gait_continuations', {}).items()}})
    write_json(CASE / 'gait_continuations.proposal.json', recipes)
    print('RR20 GAIT COVERAGE: PROPOSAL ONLY (requires rest-envelope design decision)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path)
    args=parser.parse_args()
    import proof_records
    build(read_json(args.samples) if args.samples else proof_records.samples())
