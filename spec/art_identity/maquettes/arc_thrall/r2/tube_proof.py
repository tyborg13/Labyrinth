"""Independent mesh, native arm-entry and raster width checks for feedback 1."""
from collections import Counter
import argparse
import json
from pathlib import Path
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.source_recipe import path_points
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.raster import project


TUBE_PROOF_DEFAULTS = {'epsilon_m': 1e-8, 'dimension_tolerance_px': .01,
                       'width_tolerance_px': 4, 'width_fractions': [.3, .5, .7],
                       'ray_padding_m': .001, 'raster_step_px': .1}
FIGURE = Path(__file__).resolve().parents[1]


def frame(spec, recipe):
    item = next(p for p in recipe['surfaces'] if p['id'] == 'forearm_sheath')
    elbow, tip = np.asarray(path_points(spec, item))
    direction = (tip - elbow) / np.linalg.norm(tip - elbow)
    a, b = project(spec, [elbow, elbow + direction], 'front')[:, :2]
    rate = np.linalg.norm(b - a)
    return elbow, tip, direction, rate


def geometry_dimensions(spec, recipe):
    elbow, tip, direction, rate = frame(spec, recipe)
    piece = next(p for p in spec['pieces'] if p['id'] == 'forearm_sheath')
    vertices, faces = np.asarray(piece['vertices']), piece['faces']
    t = np.einsum('ij,j->i', vertices - elbow, direction)
    radial = np.linalg.norm(vertices - elbow - t[:, None] * direction, axis=1)
    epsilon = TUBE_PROOF_DEFAULTS['epsilon_m']
    levels = sorted(set(np.round(t, 8)))
    mouth, band_end, cap_base = (float(np.mean(t[np.abs(t - level) < epsilon])) for level in levels[:3])
    at_mouth, at_cap = np.abs(t - mouth) < epsilon, np.abs(t - cap_base) < epsilon
    points = project(spec, vertices, 'front')[:, :2]
    axis = project(spec, [elbow, tip], 'front')[:, :2]
    axis = (axis[1] - axis[0]) / np.linalg.norm(axis[1] - axis[0])
    normal = np.array([-axis[1], axis[0]])
    pixel_unit = 1024 / spec['ortho_scale']
    dimensions = {'mouth_offset_front_px': mouth * rate,
        'shaft_diameter_front_px': float(np.ptp(np.einsum('ij,j->i', points[at_cap], normal))),
        'band_height_front_px': (band_end - mouth) * rate,
        'band_raise_native_px': (radial[at_mouth].max() - radial[at_cap].max()) * pixel_unit,
        'dome_height_front_px': (t.max() - cap_base) * rate,
        'inner_radius_native_px': radial[at_mouth].min() * pixel_unit}
    mouth_faces = [face for face in faces if np.all(at_mouth[face])]
    annular = bool(mouth_faces)
    for face in mouth_faces:
        offsets = vertices[face] - (elbow + mouth * direction)
        centre = offsets.mean(0)
        annular &= bool(np.all(np.einsum('ij,j->i', offsets, centre) > epsilon))
    edges = Counter(tuple(sorted((a, b))) for face in faces for a, b in zip(face, face[1:] + face[:1]))
    band_levels = set(np.round(t[np.abs(radial - radial.max()) < epsilon], 8))
    tolerance = TUBE_PROOF_DEFAULTS['dimension_tolerance_px']
    checks = {'shaft_width': abs(dimensions['shaft_diameter_front_px'] - 68) <= TUBE_PROOF_DEFAULTS['width_tolerance_px'],
        'mouth_offset': abs(dimensions['mouth_offset_front_px'] + 8) <= tolerance,
        'band_height': abs(dimensions['band_height_front_px'] - 12) <= tolerance,
        'band_raise': abs(dimensions['band_raise_native_px'] - 4) <= tolerance,
        'dome_height': abs(dimensions['dome_height_front_px'] - 23.8) <= tolerance,
        'open_annular_mouth': annular,
        'one_band_only': band_levels == {levels[0], levels[1]},
        'closed_shell': all(n == 2 for n in edges.values()) and len(vertices) - len(edges) + len(faces) == 2,
        'distal_tip_unchanged': bool(np.linalg.norm(vertices[t.argmax()] - tip) < epsilon),
        'whole_fore_near_ownership': piece['part'] == 'fore_near' and
            len([p for p in spec['pieces'] if p['part'] == 'fore_near']) == 1}
    return {'passed': all(checks.values()), 'checks': {key: bool(value) for key, value in checks.items()},
            'dimensions': {key: float(value) for key, value in dimensions.items()}}


def raster_widths(spec, recipe, raster, view):
    elbow, tip, direction, _ = frame(spec, recipe)
    a, b = project(spec, [elbow, tip], view)[:, :2]
    # Native joints include the renderer's fixed-scale framing pan.
    pan = np.subtract(raster.joints['elbow_near'], project(spec, elbow, view)[:2])
    a, b = a + pan, b + pan
    axis = (b - a) / np.linalg.norm(b - a)
    normal = np.array([-axis[1], axis[0]])
    owner = raster.names.index('fore_near')
    widths = []
    for fraction in TUBE_PROOF_DEFAULTS['width_fractions']:
        centre = (1 - fraction) * a + fraction * b
        offsets = np.arange(-68, 68, TUBE_PROOF_DEFAULTS['raster_step_px'])
        samples = np.floor(centre + offsets[:, None] * normal).astype(int)
        selected = offsets[raster.owners[samples[:, 1], samples[:, 0]] == owner]
        widths.append(float(np.ptp(selected) + TUBE_PROOF_DEFAULTS['raster_step_px']) if len(selected) else 0)
    return {'widths_native_px': widths,
            'passed': all(abs(width - 68) <= TUBE_PROOF_DEFAULTS['width_tolerance_px'] for width in widths)}


def native_entry(spec, recipe, blend):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    elbow, tip, direction, rate = frame(spec, recipe)
    mouth = elbow - 8 / rate * direction
    tube = bpy.data.objects['forearm_sheath_render']
    points = [list(tube.matrix_world @ v.co) for v in tube.data.vertices]
    tree = BVHTree.FromPolygons(points, [list(p.vertices) for p in tube.data.polygons])
    pad = TUBE_PROOF_DEFAULTS['ray_padding_m']
    hit, _, _, distance = tree.ray_cast(Vector(mouth - pad * direction), Vector(direction))
    expected = np.linalg.norm(tip - mouth) - 1.5 * spec['ortho_scale'] / 256 + pad
    arms = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') == 'upper_near'
            and not o.get('native_source')]
    points, arm_faces = [], []
    for arm in arms:
        used = sorted({i for face in arm.data.polygons for i in face.vertices})
        indices = {i: len(points) + n for n, i in enumerate(used)}
        points.extend(list(arm.matrix_world @ arm.data.vertices[i].co) for i in used)
        arm_faces.extend([indices[i] for i in face.vertices] for face in arm.data.polygons)
    points = np.asarray(points)
    offsets = points - mouth
    t = np.einsum('ij,j->i', offsets, direction)
    radial = np.linalg.norm(offsets - t[:, None] * direction, axis=1)
    inner = (8.5 - 1.5) * spec['ortho_scale'] / 256
    inside = (t > 0) & (radial <= inner + TUBE_PROOF_DEFAULTS['epsilon_m'])
    crossing = any(min(t[i] for i in face) <= 0 < max(t[i] for i in face) for face in arm_faces)
    tucks = {o.name: json.loads(o['socket_tuck_report']) for o in arms if 'socket_tuck_report' in o}
    return {'passed': bool(hit is not None and abs(distance - expected) < pad and inside.any() and crossing),
            'centre_ray_hit_distance_m': distance, 'expected_inner_cap_distance_m': expected,
            'upper_near_vertices_inside_mouth': int(inside.sum()), 'upper_near_crosses_mouth_plane': crossing,
            'upper_near_label': 'upper_near', 'upper_near_axial_range_m': [float(t.min()), float(t.max())],
            'socket_tucks': tucks}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('blend', type=Path)
    parser.add_argument('out', type=Path)
    args = parser.parse_args(argv)
    spec = json.loads(args.spec.read_text())
    recipe = json.loads((FIGURE / 'r2/measurements.json').read_text())
    report = geometry_dimensions(spec, recipe)
    report['spec_hash'] = digest(spec)
    report['native_entry'] = native_entry(spec, recipe, args.blend)
    report['passed'] &= report['native_entry']['passed']
    args.out.write_text(json.dumps(report, indent=2) + '\n')
    print('MQ07_TUBE_ENTRY: ' + ('PASS' if report['passed'] else 'FAIL'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]))
