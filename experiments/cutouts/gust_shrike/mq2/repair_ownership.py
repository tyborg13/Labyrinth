#!/usr/bin/env python3
"""Case-local rr-02 ownership repair; original RGB/alpha and rest depths survive."""
from __future__ import annotations
import argparse
from collections import defaultdict
from pathlib import Path
import sys
import shutil
from unittest.mock import patch
import numpy as np
from PIL import Image

CASE = Path(__file__).resolve().parent
sys.path[:0] = [str(CASE), str(CASE / 'probes'), str(CASE.parents[3] / 'tools')]
import maquette_cutout as mq
from cutout_pipeline.cases import CutoutError, read_json, write_json, digest
from pipeline import render_registration, create_semantic_masks
import motion_gates as gates
POLICY = CASE / 'recipes/ownership_repair.json'
BASE_CLEAN = mq.clean_ownership


def remove_redundant_hidden(owners, hidden, names, mapping, depth_order):
    """Remove only whole underlays occluded by the SAME rigid transform.

    All visible layers are above all hidden layers. Hidden/hidden coverage
    requires strictly higher rest depth, so this proof has no cyclic removal.
    This is invariant over every affine pose, not just the sampled motion keys.
    """
    original = [mask.copy() for mask in hidden]
    records = []
    for i, name in enumerate(names):
        if not original[i].any(): continue
        same_bone = [j for j, other in enumerate(names) if mapping[other] == mapping[name]]
        coverage = np.isin(owners, same_bone)
        covering = [names[j] for j in same_bone]
        for j in same_bone:
            if depth_order.index(names[j]) > depth_order.index(name): coverage |= original[j]
        if np.all(coverage[original[i]]):
            hidden[i] = np.zeros_like(original[i])
            records.append({'part': name, 'pixels': int(original[i].sum()),
                'hidden_sha256': mq.array_digest(original[i]), 'coverage_sha256': mq.array_digest(coverage),
                'bone': mapping[name], 'same_bone_parts': covering,
                'reason': 'Entire underlay is covered by visible paint or a strictly higher underlay on the identical rigid bone; no pose can expose it'})
    return records


def cleanup(owners, paint, names, solos, view, material, policy):
    # Reuse rr-02's simultaneous complete-part island repair without humanoid
    # material predicates. Then replay individually traced source-pixel moves.
    owners, hidden, report = BASE_CLEAN(owners, paint, names, solos, view, None, policy)
    report['traced_motion_repairs'] = []
    for item in policy.get('traced_moves', []):
        if item['view'] != view: continue
        old, new = names.index(item['from']), names.index(item['to'])
        for x, y in item['points']:
            if item['hidden']:
                if not hidden[old][y, x]: raise CutoutError('Stale hidden island trace')
                hidden[old][y, x] = False
            else:
                if owners[y, x] != old: raise CutoutError('Stale visible island trace')
                owners[y, x] = new
                hidden[old][y, x] = False
        report['traced_motion_repairs'].append(item)
    if policy.get('remove_fully_occluded_same_bone_underlays'):
        report['redundant_hidden_layers'] = remove_redundant_hidden(owners, hidden, names, policy['rigid_groups'], policy['depth_order'][view])
    return owners, hidden, report


def verify_ownership(root):
    """Re-derive repaired ownership/hidden masks from protected Blender + paint."""
    policy = read_json(root / 'recipes/ownership_repair.json')
    spec = mq.case_spec(root)
    names = list(spec['labels'])
    palette = read_json(root / 'source/label_palette.json')
    if policy.get('remove_fully_occluded_same_bone_underlays'):
        if policy['rigid_groups'] != read_json(root / 'recipes/rig.json')['parts'] or any(policy['depth_order'][v] != mq.depth_order(mq.camera_depths(spec, v)) for v in ['front', 'rear']):
            raise CutoutError('Rigid occlusion policy differs from the source anatomy/depths')
    errors = []
    for view in ['front', 'rear']:
        paint = np.array(Image.open(root / f'source/{view}/processed.png').convert('RGBA'))
        transform = render_registration(root / f'source/{view}/raw.png', read_json(root / f'source/{view}/processed.json'))
        label_image = transform.image(Image.open(root / f'source/maquette/{view}_parts.png').convert('RGBA'))
        depths = mq.camera_depths(spec, view)
        labels = mq.decode_labels(label_image, palette, names, depths)
        original, _ = mq.nearest_labels(labels, paint[..., 3] > 0, names, depths)
        solos = {n: np.array(transform.image(Image.open(root / f'source/maquette/{view}_solo_{n}.png').convert('RGBA')))[..., 3] > 128 for n in names}
        owners, hidden, report = cleanup(original, paint, names, solos, view, None, policy)
        if not np.array_equal(owners, np.load(root / f'registered/{view}_owners.npy')):
            errors.append('Source-derived owner repair differs: ' + view)
        if report != read_json(root / f'proof/{view}_ownership_cleanup.json'):
            errors.append('Ownership trace differs: ' + view)
        for name, mask in zip(names, hidden):
            if not np.array_equal(mask, np.load(root / f'registered/{view}_hidden_{name}.npy')):
                errors.append('Source-derived hidden repair differs: ' + view + '/' + name)
    return errors


def rebuild():
    from repair_fills import preserve_manual_paint
    preserve_manual_paint(CASE)
    policy = read_json(POLICY)
    recipe = read_json(CASE / 'recipes/rig.json')
    recipe['ownership_cleanup'] = policy
    spec = mq.case_spec(CASE)
    palette = read_json(CASE / 'source/label_palette.json')
    requests = []
    # This anatomy has no trousers. The shared builder's material hook is
    # disabled locally; its segmentation/rest-depth machinery is unchanged.
    with patch.object(mq, 'registration', render_registration), patch.object(mq, 'clean_ownership', cleanup), patch.object(mq, 'material_reference', return_value=(np.zeros((255, 255), bool), None)):
        for view in ['front', 'rear']:
            for folder in ['segmented', 'hidden']:
                generated = CASE / folder / view
                if generated.exists(): shutil.rmtree(generated)
            result = mq.build_view(CASE, spec, view, palette, recipe, False)
            requests.extend(result['requests'])
            (CASE / f'registered/{view}_trousers.npy').unlink()
    write_json(CASE / 'hidden_requests/index.json', {'requests': requests, 'exposure_basis': 'pending fresh motion samples'})
    create_semantic_masks()
    config = read_json(CASE / 'cutout.json')
    config['sources'] = sorted(set(config['sources']) | {'repair_ownership.py', 'repair_fills.py', 'recipes/ownership_repair.json', 'recipes/value_reference.json'} | {f'proof/{v}_ownership_cleanup.json' for v in ['front', 'rear']})
    write_json(CASE / 'cutout.json', config)
    for folder in ['segmented', 'hidden', 'registered', 'hidden_requests', 'proof']:
        for path in (CASE / folder).rglob('*.png'):
            Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    identity = mq.rest_identity(CASE)
    if not identity['ok']: raise CutoutError('Rest identity changed during ownership repair')
    outputs = {str(p.relative_to(CASE)): digest(p) for p in (CASE / 'hidden').rglob('*.png')}
    write_json(CASE / 'proof/ownership_rebuild_manifest.json', {'rest_identity': identity, 'outputs': outputs})
    return identity


def trace():
    policy = read_json(POLICY)
    config = read_json(CASE / 'cutout.json')
    names = list(read_json(CASE / 'source/spec.json')['labels'])
    mapping = read_json(CASE / 'recipes/rig.json')['parts']
    layouts = {v: read_json(CASE / p) for v, p in config['layouts'].items()}
    owners = {v: np.load(CASE / f'registered/{v}_owners.npy') for v in layouts}
    samples = read_json(CASE / 'proof/motion_samples.json')
    # Transforms depend only on the unchanged joint/motion data. Rebuilt paint
    # nodes retain each original rest depth; use their current names/depths.
    observations = defaultdict(list)
    frames = 0
    for sample in samples['samples']:
        layout = layouts[sample['view']]
        sample = dict(sample, draw_order={p['name']: p['z_index'] for p in layout['parts']})
        pixels, node_ids, source_ids, _, _ = gates.rasterize(CASE, layout, sample, include_sources=True)
        specks = [c for c in mq.components8(pixels[..., 3] > 128)[1:] if c.sum() < policy['speck_max_exclusive_px']]
        frames += bool(specks)
        for piece in specks:
            for node_id in np.unique(node_ids[piece]):
                node = layout['parts'][node_id]
                for source_id in np.unique(source_ids[piece & (node_ids == node_id)]):
                    y, x = divmod(int(source_id) - 1, 255)
                    key = (sample['view'], node['logical_part'], bool(node.get('hidden_material')), x, y)
                    observations[key].append({'clip': sample['clip'], 'frame': sample['frame'], 'pixels': int(piece.sum())})
    additions = []
    for (view, part, hidden, x, y), evidence in sorted(observations.items()):
        owner = owners[view]
        mask = np.zeros(owner.shape, bool); mask[y, x] = True
        adjacent = mq._adjacent(mask.astype(np.int16))
        candidates = [(int(adjacent[owner == i].sum()), i) for i, n in enumerate(names) if mapping[n] != mapping[part]]
        shared, target = max(candidates, key=lambda item: (item[0], -item[1]))
        if not hidden and not shared:
            # These are narrow tips detached by nearest rasterization, not
            # ownership islands. Record explicitly; never delete visible paint.
            continue
        additions.append({'view': view, 'from': part, 'to': names[target] if not hidden else part,
            'hidden': hidden, 'points': [[x, y]], 'shared_border_edges': shared,
            'reason': 'Traced small motion component; move to four-connected rest neighbour on a different rigid part, label-order tie' if not hidden else 'Traced hidden-only island; remove support already covered by the complete visible partition at rest',
            'evidence': evidence})
    policy['traced_moves'].extend(additions)
    write_json(POLICY, policy)
    report = {'failing_frames': frames, 'traced_source_pixels': len(observations), 'new_repairs': len(additions),
              'samples_sha256': digest(CASE / 'proof/motion_samples.json')}
    write_json(CASE / 'proof/ownership_trace_latest.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['rebuild', 'trace'])
    args = parser.parse_args()
    import json
    print(json.dumps(rebuild() if args.command == 'rebuild' else trace(), indent=2))

if __name__ == '__main__': main()
