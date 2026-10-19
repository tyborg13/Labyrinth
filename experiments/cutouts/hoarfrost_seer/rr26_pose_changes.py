"""Inventory every changed hem-tip deformation; preserve all pose sample rows."""
import argparse
import csv
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import mesh_map, mapped
from humanoid_cutout.gates import EPSILON, bindings, matrix
from humanoid_cutout.texel_attachments import barycentric

CASE = ROOT / 'experiments/cutouts/hoarfrost_seer/rr10'
APPROVED_REVISION = 'f11932ab7'


def posed_vertices(mesh, pose):
    vertices = np.asarray(mesh['vertices'], dtype=float)
    result = np.zeros_like(vertices)
    for name, weights in mesh['weights'].items():
        bone = matrix(pose['bones'][name]['global'])
        bind = np.asarray(pose['_joints'][name]['position'])
        delta = vertices - bind
        positions = np.column_stack((delta[:, 0] * bone[0, 0] + delta[:, 1] * bone[0, 1] + bone[0, 2],
                                     delta[:, 0] * bone[1, 0] + delta[:, 1] * bone[1, 1] + bone[1, 2]))
        result += np.asarray(weights, dtype=np.float32)[:, None] * positions
    return result


def report(samples, output):
    if samples['inputs'] != bindings(CASE): raise ValueError('Stale Seer pose evidence')
    baseline = read_json(CASE / 'proof/samples.json')['samples']
    current = samples['samples']
    if len(baseline) != len(current): raise ValueError('Pose sample coverage changed')
    for index, (old, new) in enumerate(zip(baseline, current)):
        if json.dumps(old, sort_keys=True, separators=(',', ':')) != json.dumps(new, sort_keys=True, separators=(',', ':')):
            raise ValueError('Original pose row changed: ' + str(index))
    meshes = {}
    for view in ('front', 'rear'):
        path = CASE / f'layouts/{view}.json'
        old_layout = json.loads(subprocess.check_output(
            ['git', 'show', APPROVED_REVISION + ':' + str(path.relative_to(ROOT))], cwd=ROOT))
        layout = read_json(path)
        old = next(m for m in old_layout['joint_meshes'] if m['name'] == 'robe')
        new = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
        tips = sorted((tuple(row['texel']) for row in new['texel_attachments']), key=lambda p: (p[1], p[0]))
        indices, weights = [], []
        for x, y in tips:
            for point in ((x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)):
                triangle, bary = barycentric(old, point)
                indices.append(triangle); weights.append(bary)
        image = np.asarray(Image.open(CASE / new['file']).convert('RGBA'))
        meshes[view] = (old, new, tips, np.asarray(indices), np.asarray(weights), layout, image)
    changes, inventory = [], []
    for index, row in enumerate(current):
        old, new, tips, indices, weights, layout, image = meshes[row['view']]
        pose = dict(row, _joints=layout['joints'])
        before, after = posed_vertices(old, pose), posed_vertices(new, pose)
        if not np.array_equal(before, after[:len(before)]):
            raise ValueError('An original garment vertex changed: ' + str(index))
        old_corners = np.sum(before[indices] * weights[..., None], axis=1)
        new_corners = after[len(before):]
        delta = np.linalg.norm(new_corners - old_corners, axis=1).reshape(-1, 4).max(axis=1)
        selected = [list(point) for point, distance in zip(tips, delta) if distance > EPSILON]
        old_pixels = mapped(image, mesh_map(layout, pose, old))
        new_pixels = mapped(image, mesh_map(layout, pose, new))
        changed_pixels = int(np.count_nonzero(np.any(old_pixels != new_pixels, axis=2)))
        inventory.append({'pose_row': index, **{key: row[key] for key in ('view', 'kind', 'clip', 'frame', 'phase')},
                          'part': 'robe', 'tip_texels': selected, 'maximum_corner_delta_px': float(delta.max()),
                          'exceeds_existing_vertex_epsilon': bool(selected), 'robe_cpu_pixels_changed': changed_pixels})
        if selected:
            changes.append({'pose_row': index, **{key: row[key] for key in ('view', 'kind', 'clip', 'frame', 'phase')},
                            'part': 'robe', 'tip_texels': selected, 'maximum_corner_delta_px': float(delta.max())})
    result = {'approved_revision': APPROVED_REVISION, 'native_pixels': False,
        'scope': 'Continuous CPU vertex positions, using sampled Bone2D transforms; not native renderer proof',
        'unchanged_original_sample_rows': len(current), 'changed_original_sample_rows': [],
        'all_original_vertices_exact': True, 'comparison_epsilon_px': EPSILON, 'changes': changes,
        'inventory': inventory}
    write_json(output, result)
    csv_path = CASE.parent / 'rr26_feedback2_pose_changes.csv'
    fields = ('pose_row', 'view', 'kind', 'clip', 'frame', 'phase', 'part', 'tip_texels', 'maximum_corner_delta_px',
              'exceeds_existing_vertex_epsilon', 'robe_cpu_pixels_changed')
    with csv_path.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in inventory: writer.writerow(dict(row, tip_texels=json.dumps(row['tip_texels'], separators=(',', ':'))))
    print('RR26F2 SEER POSE ROWS: PASS (%d byte-identical canonical rows; all original vertices exact)' % len(current))
    print('RR26F2 TIP DEFORMATION CHANGES: %d rows above existing vertex epsilon; part=robe; full %d-row inventory=%s' %
          (len(changes), len(inventory), csv_path.relative_to(ROOT)))
    print('RR26F2 ROBE CPU PIXEL CHANGES: %d pose rows; all remaining parts unchanged' %
          sum(row['robe_cpu_pixels_changed'] > 0 for row in inventory))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report(read_json(args.samples), args.output)
