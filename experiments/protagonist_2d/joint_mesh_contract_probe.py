"""Validate generated joint skins against the actual rigid cutout assets.

The endpoint check examines every source pixel duplicated by two pieces and
all mesh-cell vertices that can interpolate it. A weight of exactly one on
the rigid endpoint bone proves that those pixels move with that piece for
ANY bone pose. Identical topology and weights likewise prove the upper/lower
mesh overlap stays welded. This complements renderer inspection of silhouettes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops

from mesh_assets import FAMILIES


HERE = Path(__file__).resolve().parent


def _hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _opaque_faces(mesh):
    """Ignore transparent triangles; test texel centers inside each rest face."""
    with Image.open(HERE / mesh['file']) as opened:
        alpha = opened.getchannel('A')
    ox, oy = mesh['offset']
    result = []
    for indices in mesh['triangles']:
        a, b, c = [mesh['vertices'][index] for index in indices]
        visible = False
        for y in range(math.floor(min(a[1], b[1], c[1])), math.ceil(max(a[1], b[1], c[1]))):
            for x in range(math.floor(min(a[0], b[0], c[0])), math.ceil(max(a[0], b[0], c[0]))):
                point = (x + 0.5, y + 0.5)
                if (0 <= x - ox < alpha.width and 0 <= y - oy < alpha.height
                        and alpha.getpixel((x - ox, y - oy))
                        and min(_cross(a, b, point), _cross(b, c, point), _cross(c, a, point)) >= -1e-8):
                    visible = True
                    break
            if visible:
                break
        if visible:
            result.append((indices, _cross(a, b, c)))
    return result


def check_poses(data, samples):
    """Measure skinning before rasterization using Godot's sampled transforms.

    A compressed knee can self-overlap naturally, so leg inversions are reported
    for renderer inspection. Sleeve foldovers were an observed visual defect
    and fail this check. This measures opaque texture faces; it does not claim
    that a face hidden by a later draw layer was visible in the final image.
    """
    entries = data.get('joint_meshes', [])
    reports = {}
    families = {}
    faces = {}
    failures = []
    for mesh in entries:
        faces[mesh['name']] = _opaque_faces(mesh)
        families.setdefault(mesh['family'], []).append(mesh)
        reports[mesh['name']] = {
            'family': mesh['family'], 'opaque_rest_triangles': len(faces[mesh['name']]),
            'ignored_transparent_triangles': len(mesh['triangles']) - len(faces[mesh['name']]),
            'minimum_signed_area_ratio': math.inf, 'reversed_triangle_samples': 0,
            'frames_with_reversed_triangles': [], 'worst_pose': None,
        }
    for sample in samples:
        for meshes in families.values():
            base = meshes[0]
            vertices = base['vertices']
            deformed = []
            for index, (x, y) in enumerate(vertices):
                dx = dy = 0.0
                for name, weights in base['weights'].items():
                    xx, xy, yx, yy, tx, ty = sample['bones'][name]
                    weight = weights[index]
                    dx += weight * (xx * x + yx * y + tx)
                    dy += weight * (xy * x + yy * y + ty)
                deformed.append((dx, dy))
            for mesh in meshes:
                report = reports[mesh['name']]
                frame_reversals = 0
                for indices, rest_area in faces[mesh['name']]:
                    a, b, c = [deformed[index] for index in indices]
                    ratio = _cross(a, b, c) / rest_area
                    if ratio < report['minimum_signed_area_ratio']:
                        report['minimum_signed_area_ratio'] = ratio
                        report['worst_pose'] = {'clip': sample['clip'], 'frame': sample['frame'],
                                                'phase': sample['phase'], 'triangle': indices}
                    if ratio < -1e-7:
                        frame_reversals += 1
                report['reversed_triangle_samples'] += frame_reversals
                if frame_reversals:
                    report['frames_with_reversed_triangles'].append(
                        {'clip': sample['clip'], 'frame': sample['frame'], 'count': frame_reversals})
    for name, report in reports.items():
        if not math.isfinite(report['minimum_signed_area_ratio']):
            failures.append(name + ': no finite posed face areas')
        if report['family'].startswith('arm_') and report['minimum_signed_area_ratio'] <= 0.0:
            failures.append(name + ': sleeve contains a collapsed or reversed opaque triangle')
        report['renderer_inspection_required'] = report['reversed_triangle_samples'] > 0
    return {'sampled_frames': len(samples),
            'scope': 'opaque texture triangles before draw-order occlusion; leg foldovers require renderer inspection',
            'meshes': reports, 'failures': failures, 'passed': not failures}


def check_layout(path, pose_dump=None):
    data = json.loads(path.read_text())
    failures = []
    parts = {part['name']: part for part in data['parts']}
    meshes = {mesh['replaces_part']: mesh for mesh in data.get('joint_meshes', [])}
    masks = {}
    textures = {}
    size = tuple(data['canvas_size'])
    for name, part in parts.items():
        with Image.open(HERE / part['file']) as opened:
            image = opened.convert('RGBA')
        full = Image.new('RGBA', size)
        full.paste(image, tuple(part['offset']))
        textures[name] = full
        masks[name] = full.getchannel('A')
    reports = []
    if len(meshes) != len(data.get('joint_meshes', [])):
        failures.append('Duplicate replacement part in joint_meshes')
    for mesh in meshes.values():
        name = mesh['name']
        vertices, uvs = mesh['vertices'], mesh['uvs']
        weights, triangles = mesh['weights'], mesh['triangles']
        if not vertices or len(uvs) != len(vertices):
            failures.append(name + ': missing vertices or mismatched UV count')
            continue
        if any(not all(math.isfinite(value) for value in point) for point in vertices + uvs):
            failures.append(name + ': nonfinite vertex or UV')
        if any(bone not in data['joints'] for bone in weights):
            failures.append(name + ': unknown bone')
        if any(len(values) != len(vertices) for values in weights.values()):
            failures.append(name + ': mismatched weight count')
            continue
        for index in range(len(vertices)):
            values = [values[index] for values in weights.values()]
            if (any(not math.isfinite(value) or value < 0.0 or value > 1.0 for value in values)
                    or abs(sum(values) - 1.0) > 1e-6):
                failures.append(f'{name}: invalid or unnormalized vertex {index}')
                break
        for triangle in triangles:
            if len(triangle) != 3 or any(type(index) is not int or index < 0 or index >= len(vertices)
                                         for index in triangle):
                failures.append(name + ': invalid triangle indices')
                break
            a, b, c = [vertices[index] for index in triangle]
            area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            if area <= 0:
                failures.append(name + ': zero-area or reversed rest triangle')
                break
        offset = mesh['offset']
        if any(uv != [point[0] - offset[0], point[1] - offset[1]]
               for point, uv in zip(vertices, uvs)):
            failures.append(name + ': UV mapping does not preserve source pixels at rest')
        with Image.open(HERE / mesh['file']) as opened:
            actual = opened.convert('RGBA')
        expected = textures[mesh['replaces_part']].crop(tuple(mesh['bbox']))
        if actual.size != expected.size or actual.tobytes() != expected.tobytes():
            failures.append(name + ': mesh texture differs from its rigid source cutout')
        if mesh['z_index'] != parts[mesh['replaces_part']]['z_index']:
            failures.append(name + ': original draw order changed')
    for family, parent, upper, lower, terminal in FAMILIES:
        if any(name not in parts for name in (parent, upper, lower, terminal)):
            continue
        if any(name not in meshes for name in (upper, lower)):
            failures.append(family + ': visible limb lacks both joint meshes')
            continue
        if parent in meshes or terminal in meshes:
            failures.append(family + ': body, boot, hand or weapon is no longer rigid')
        first, second = meshes[upper], meshes[lower]
        shared_data_equal = all(first[key] == second[key] for key in ('vertices', 'uvs', 'triangles', 'weights', 'bbox'))
        if not shared_data_equal:
            failures.append(family + ': adjoining mesh topology or weights differ')
        endpoints = []
        for rigid, moving in ((parent, upper), (terminal, lower)):
            shared = ImageChops.multiply(masks[rigid], masks[moving])
            bounds = shared.getbbox()
            mesh = meshes[moving]
            influence = mesh['weights'].get(parts[rigid]['bone'], [])
            lookup = {tuple(point): index for index, point in enumerate(mesh['vertices'])}
            step = mesh['joint_bands']['grid_step']
            checked = set()
            pixel_count = 0
            if bounds:
                for y in range(bounds[1], bounds[3]):
                    for x in range(bounds[0], bounds[2]):
                        if not shared.getpixel((x, y)):
                            continue
                        pixel_count += 1
                        gx, gy = (x // step) * step, (y // step) * step
                        for dx, dy in ((0, 0), (step, 0), (0, step), (step, step)):
                            index = lookup.get((gx + dx, gy + dy))
                            if index is None:
                                failures.append(family + ': shared pixel lies outside the mesh')
                            else:
                                checked.add(index)
            maximum = max((1.0 - influence[index] if index < len(influence) else 1.0 for index in checked), default=0.0)
            if maximum > 1e-7:
                failures.append(f'{family}: {rigid} overlap can separate (influence error {maximum})')
            endpoints.append({'rigid_part': rigid, 'shared_source_pixels': pixel_count,
                              'checked_cell_vertices': len(checked),
                              'maximum_nonrigid_influence': maximum,
                              'coverage_note': 'source overlap verified' if pixel_count else 'no source overlap; inspect occlusion visually'})
        reports.append({'family': family, 'shared_mesh_data_equal': shared_data_equal,
                        'endpoints': endpoints})
    posed = None
    if pose_dump is not None:
        samples = [sample for sample in pose_dump['samples'] if sample['facing'] == data['facing']]
        if not samples:
            failures.append('Pose dump contains no frames for this facing')
        else:
            posed = check_poses(data, samples)
            failures.extend(posed['failures'])
    return {'facing': data['facing'], 'layout_sha256': _hash(path),
            'mesh_count': len(meshes),
            'vertex_count': sum(len(mesh['vertices']) for mesh in meshes.values()),
            'triangle_count': sum(len(mesh['triangles']) for mesh in meshes.values()),
            'families': reports, 'posed_area': posed,
            'failures': failures, 'passed': not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=HERE / 'renders/joint_mesh_validation.json')
    parser.add_argument('--pose-matrices', type=Path,
                        help='Optional LABYRINTH_CUTOUT_POSE_MATRICES output from motion_contract_probe.gd')
    args = parser.parse_args()
    pose_dump = None
    if args.pose_matrices:
        pose_dump = json.loads(args.pose_matrices.read_text())
        if pose_dump['matrix_order'] != ['xx', 'xy', 'yx', 'yy', 'ox', 'oy']:
            raise ValueError('Unexpected Godot transform column order')
        for name in ('cutout_motion.gd', 'cutout_layout.json', 'cutout_layout_rear.json'):
            expected = pose_dump['input_sha256'].get('res://experiments/protagonist_2d/' + name)
            if expected != _hash(HERE / name):
                raise ValueError('Stale pose matrices; regenerate after changing ' + name)
    results = [check_layout(HERE / name, pose_dump) for name in ('cutout_layout.json', 'cutout_layout_rear.json')]
    report = {'version': 1, 'proof': 'generated mesh data and pose-independent overlap weld invariants',
              'builder_sha256': _hash(HERE / 'mesh_assets.py'), 'facings': results,
              'pose_matrices_sha256': _hash(args.pose_matrices) if args.pose_matrices else None,
              'passed': all(result['passed'] for result in results)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': report['passed'], 'report': str(args.output),
                      'facings': [{'facing': result['facing'], 'meshes': result['mesh_count'],
                                   'posed_frames': result['posed_area']['sampled_frames'] if result['posed_area'] else 0,
                                   'failures': result['failures']} for result in results]}, indent=2))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
