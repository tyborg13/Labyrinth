"""Validate the fifth-pass complete anatomy, skinning and rendered attachments.

This checks actual assets, sampled Godot transforms and (when supplied) every
rendered pose. It does not infer artistic quality from finite bone values.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops

from joint_mesh_contract_probe import check_poses, _cross

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
COUNTS = {'idle': 20, 'walk': 24, 'attack': 32, 'block': 36, 'hit': 24}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def component_sizes(image):
    alpha = image.getchannel('A')
    box = alpha.getbbox()
    if box is None:
        return []
    points = {(x, y) for y in range(box[1], box[3]) for x in range(box[0], box[2])
              if alpha.getpixel((x, y)) >= 128}
    sizes = []
    while points:
        seed = points.pop()
        todo, count = [seed], 1
        while todo:
            x, y = todo.pop()
            for dx, dy in [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]:
                point = x + dx, y + dy
                if point in points:
                    points.remove(point)
                    todo.append(point)
                    count += 1
        sizes.append(count)
    return sorted(sizes, reverse=True)


def expanded(part):
    image = Image.new('RGBA', (255, 255))
    image.alpha_composite(Image.open(HERE / part['file']).convert('RGBA'), part['offset'])
    return image


def check_layout(path, pose_dump=None):
    data = json.loads(path.read_text())
    facing = data['facing']
    suffix = '' if facing == 'front' else '_rear'
    baseline = json.loads((HERE / f'references/pass5/baseline_cutout_layout{suffix}.json').read_text())
    baseline_hashes = json.loads((HERE / 'renders/pass4/render_validation.json').read_text())['input_sha256']
    def original_hash(file):
        return baseline_hashes['res://experiments/protagonist_2d/' + file]
    failures, identity, attachments = [], [], []
    if data.get('version') != 5 or not data.get('new_complete_anatomy'):
        failures.append('Expected the fifth-pass complete-anatomy layout')
    if len(data['joints']) != 21 or data['joints']['weapon_r']['parent'] != 'hand_r':
        failures.append('Missing independent sword grip or one of the body bones')
    parts = {p['name']: p for p in data['parts']}
    meshes = {m['replaces_part']: m for m in data['joint_meshes']}
    if len(parts) != len(data['parts']) or len(meshes) != len(data['joint_meshes']) or len(meshes) != 6:
        failures.append('Duplicate or missing part/skin definitions')
    old_parts = {p['name']: p for p in baseline['parts']}
    for name in ['head', 'scarf', 'torso', 'hips']:
        same = (sha(HERE / parts[name]['file']) == original_hash(old_parts[name]['file'])
                and parts[name]['offset'] == old_parts[name]['offset'])
        identity.append({'part': name, 'exact_baseline_pixels_and_registration': same,
                         'sha256': sha(HERE / parts[name]['file'])})
        if not same:
            failures.append('Canonical identity part changed: ' + name)
    if sha(HERE / data['cape_mesh']['file']) != original_hash(baseline['cape_mesh']['file']):
        failures.append('Canonical cloak paint changed')
    if sha(HERE / data['source']) != baseline['source_sha256']:
        failures.append('Identity reference changed')
    for part in data['parts']:
        image = Image.open(HERE / part['file']).convert('RGBA')
        if image.getbbox() is None:
            failures.append('Empty piece: ' + part['name'])
        if part['file'].startswith('assets/pass5/') and part['name'] not in ['weapon_r', 'grip_r']:
            if any(a > 127 and r > g + 12 and b > g + 12 for r, g, b, a in image.getdata()):
                failures.append('Magenta matte remains in ' + part['name'])
    for mesh in meshes.values():
        name = mesh['replaces_part']
        vertices, uvs, weights = mesh['vertices'], mesh['uvs'], mesh['weights']
        if mesh['file'] != parts[name]['file'] or mesh['offset'] != parts[name]['offset']:
            failures.append('Mesh no longer uses its actual editable cutout: ' + name)
        if not vertices or len(vertices) != len(uvs):
            failures.append('Missing geometry or UV count mismatch: ' + name)
        if any(bone not in data['joints'] or len(values) != len(vertices) for bone, values in weights.items()):
            failures.append('Invalid bone/weight array: ' + name)
            continue
        for i, vertex in enumerate(vertices):
            values = [v[i] for v in weights.values()]
            if not all(math.isfinite(v) for v in vertex + uvs[i] + values):
                failures.append('Nonfinite geometry: ' + name)
                break
            if any(v < 0 or v > 1 for v in values) or abs(sum(values) - 1) > 1e-6:
                failures.append('Invalid normalized influences: ' + name)
                break
            if uvs[i] != [vertex[j] - mesh['offset'][j] for j in range(2)]:
                failures.append('UV moves the source pixels at rest: ' + name)
                break
        for triangle in mesh['triangles']:
            if (len(triangle) != 3 or any(type(i) is not int or i < 0 or i >= len(vertices) for i in triangle)
                    or _cross(*(vertices[i] for i in triangle)) <= 0):
                failures.append('Invalid rest face: ' + name)
                break
    # Split upper/lower sleeves share the same paint and interpolated field.
    for side in ['r', 'l']:
        first, second = (meshes[name] for name in ['arm_' + side, 'forearm_' + side])
        a, b = expanded(parts['arm_' + side]), expanded(parts['forearm_' + side])
        shared = ImageChops.multiply(a.getchannel('A'), b.getchannel('A'))
        pixels = sum(v > 0 for v in shared.getdata())
        differences = [xy for xy in [(x, y) for y in range(255) for x in range(255)]
                       if shared.getpixel(xy) and a.getpixel(xy) != b.getpixel(xy)]
        first_lookup = {tuple(v): i for i, v in enumerate(first['vertices'])}
        common, error = 0, 0.0
        for i, vertex in enumerate(second['vertices']):
            other = first_lookup.get(tuple(vertex))
            if other is not None:
                common += 1
                for bone in second['weights']:
                    error = max(error, abs(first['weights'][bone][other] - second['weights'][bone][i]))
        if pixels < 8 or differences or common < 8 or error > 1e-7:
            failures.append('Upper/lower sleeve overlap is not welded: ' + side)
        attachments.append({'joint': 'elbow_' + side, 'shared_painted_pixels': pixels,
                            'different_shared_pixels': len(differences), 'common_vertices': common,
                            'maximum_weight_disagreement': error})
    # Every glove/boot overlaps actual adjoining paint whose vertices are
    # bound to exactly that terminal bone. This proves the collar follows it.
    for terminal, moving in [('hand_r', 'forearm_r'), ('hand_l', 'forearm_l'), ('foot_r', 'thigh_r'), ('foot_l', 'thigh_l')]:
        a, b = expanded(parts[terminal]), expanded(parts[moving])
        shared = ImageChops.multiply(a.getchannel('A'), b.getchannel('A'))
        mesh = meshes[moving]
        rows = {y for y in range(255) for x in range(255) if shared.getpixel((x, y))}
        checked = [i for i, (_, y) in enumerate(mesh['vertices']) if y in rows or y - 1 in rows]
        error = max((1 - mesh['weights'][terminal][i] for i in checked), default=1)
        pixels = sum(v > 0 for v in shared.getdata())
        if pixels < 8 or error > 1e-7:
            failures.append('Glove/boot collar can detach: ' + terminal)
        attachments.append({'joint': terminal, 'shared_painted_pixels': pixels,
                            'checked_vertices': len(checked), 'maximum_nonterminal_weight': error})
    posed = None
    if pose_dump is not None:
        samples = [s for s in pose_dump['samples'] if s['facing'] == facing]
        counts = {clip: sum(s['clip'] == clip for s in samples) for clip in COUNTS}
        if counts != COUNTS:
            failures.append('Missing actual authored pose matrices')
        posed = check_poses(data, samples)
        failures.extend(posed['failures'])
        for name, report in posed['meshes'].items():
            if report['minimum_signed_area_ratio'] <= 0:
                failures.append('Complete skin folds or collapses: ' + name)
    return {'facing': facing, 'layout_sha256': sha(path), 'bone_count': len(data['joints']),
            'mesh_count': len(meshes), 'identity': identity, 'attachments': attachments,
            'posed_area': posed, 'failures': failures, 'passed': not failures}


def check_renders(folder):
    failures, cases = [], []
    for facing in ['front', 'rear']:
        for action, count in COUNTS.items():
            paths = sorted((folder / f'{facing}_{action}').glob('*.png'))
            if len(paths) != count:
                failures.append('Missing rendered poses: ' + facing + '/' + action)
            for path in paths:
                image = Image.open(path).convert('RGBA')
                sizes = component_sizes(image)
                fragments = [n for n in sizes[1:] if n >= 8]
                if image.size != (512, 512) or not sizes or fragments:
                    failures.append('Empty, incorrectly sized or detached rendered part: ' + str(path))
                cases.append({'file': str(path.relative_to(folder)), 'sha256': sha(path),
                              'major_components': sum(n >= 8 for n in sizes),
                              'largest_minor_component': sizes[1] if len(sizes) > 1 else 0})
    return {'scope': '8-connected opaque components of every real rendered pose; tiny pixel-art outline specks below 8 pixels are retained',
            'cases': cases, 'failures': failures, 'passed': not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pose-matrices', type=Path, required=True)
    parser.add_argument('--renders', type=Path)
    parser.add_argument('--output', type=Path, default=HERE / 'renders/joint_mesh_validation.json')
    args = parser.parse_args()
    pose_dump = json.loads(args.pose_matrices.read_text())
    if pose_dump.get('matrix_order') != ['xx', 'xy', 'yx', 'yy', 'ox', 'oy']:
        raise ValueError('Unexpected Godot transform column order')
    stale = []
    for name, expected in pose_dump['input_sha256'].items():
        if sha(PROJECT / name.removeprefix('res://')) != expected:
            stale.append('Pose matrices are stale for ' + name)
    layouts = [check_layout(HERE / name, pose_dump) for name in ['cutout_layout.json', 'cutout_layout_rear.json']]
    renders = check_renders(args.renders) if args.renders else None
    failures = stale + [f for layout in layouts for f in layout['failures']] + (renders['failures'] if renders else [])
    report = {'pass': 5, 'input_sha256': pose_dump['input_sha256'], 'layouts': layouts,
              'rendered_attachments': renders, 'failures': failures, 'passed': not failures}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': not failures, 'failures': failures, 'output': str(args.output)}, indent=2))
    raise SystemExit(0 if not failures else 1)


if __name__ == '__main__':
    main()
