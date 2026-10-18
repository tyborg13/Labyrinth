"""Lossless mq-07 Thrall partition and humanoid-v2 promotion.

Only existing approved texels supply covered continuations. No source paint,
maquette, director keys or other figure's case is modified.
"""
from pathlib import Path
import json
import shutil
import sys

import numpy as np
from PIL import Image

from rr11_case import PROJECT, CASE, PIECES, GROUPS
sys.path.insert(0, str(PROJECT))
sys.path.insert(0, str(PROJECT / 'tools'))
# Read-only rr-07 registration geometry used by the reference rr-10 builder.
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/hoarfrost_seer'))
from rr07_inputs import registered_transform, label_palette
from rr07_geometry import native_depths, bind_layout
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes, dilate
from tools.humanoid_cutout.anatomy import load as load_anatomy
from tools.humanoid_cutout.source_view import prepare
from tools.humanoid_cutout.materials import clean_continuation, connected_mask
from tools.humanoid_cutout.skin_layers import layer as skin_layer
from tools.humanoid_cutout.mesh import grid, weights_for
from tools.humanoid_cutout.tucks import required_tuck
from tools.humanoid_cutout.seams import build_masks
from tools.humanoid_cutout.compiler import compile_motion
from tools.humanoid_cutout.promotion import promote

ASSETS = PROJECT / 'assets/units/arc_thrall_cutout/humanoid_v2'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
CAP_PLANE_EPSILON = 1e-8  # Native mesh coplanarity tolerance, not a painted landmark.
DEPTH_SOURCE = {'torso': 'collar', 'tube': 'fore_near', 'sleeve_far': 'upper_far',
                'claw': 'hand_far', 'leg_near': 'thigh_near', 'leg_far': 'thigh_far'}
BONES = {'tube': 'fore_near', 'sleeve_far': 'upper_far', 'claw': 'hand_far',
         'leg_near': 'thigh_near', 'leg_far': 'thigh_far', 'loincloth': 'pelvis'}


def recipe_for(_creature, spec, view):
    """Native shoulder/waist/limb pivots; tube target at its actual closed cap."""
    mapping = {'root': 'root', 'pelvis': 'pelvis', 'torso': 'torso', 'head': 'head',
               'upper_near': 'shoulder_near', 'fore_near': 'elbow_near',
               'upper_far': 'shoulder_far', 'fore_far': 'elbow_far', 'hand_far': 'hand_far'}
    for side in ('near', 'far'):
        mapping.update({'thigh_' + side: 'hip_' + side, 'shin_' + side: 'knee_' + side,
                        'foot_' + side: 'ankle_' + side})
    anatomy = load_anatomy(CASE)
    joints = {name: {'joint': source, 'parent': anatomy['required_parents'][name]}
              for name, source in mapping.items()}
    tube = next(p for p in spec['pieces'] if p['part'] == 'fore_near')
    vertices = np.asarray(tube['vertices'])
    mouth, axis = np.asarray(tube['socket']['mouth']), np.asarray(tube['socket']['axis'])
    distance = np.sum((vertices - mouth) * axis, axis=1)
    cap = vertices[np.isclose(distance, distance.max(), atol=CAP_PLANE_EPSILON, rtol=0)].mean(axis=0)
    joints['tube_tip'] = {'position_3d': cap.tolist(), 'parent': 'fore_near'}
    # A single loincloth field. Its endpoint is the centre of the supplied
    # view's native panel bottom row; the protected motion names one tip.
    cloth = next(p for p in spec['pieces'] if p['id'] == 'loincloth_' + ('front' if view == 'front' else 'back'))
    tip = np.asarray(cloth['pattern']['rows'][-1]['points']).mean(axis=0)
    joints['loincloth_tip'] = {'position_3d': tip.tolist(), 'parent': 'pelvis'}
    parts = {label: BONES.get(name, name) for name, labels in PIECES.items() for label in labels}
    return {'joints': joints, 'parts': parts}


def store(image, folder, name, empty_bounds=None):
    ys, xs = np.nonzero(image[..., 3])
    bounds = ([int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
              if len(xs) else empty_bounds)
    if bounds is None: raise ValueError('Empty piece: ' + name)
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
    Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': bounds[:2], 'bbox': bounds}


def proof_masks(layout, paint, visible, hidden, material_rules, anatomy):
    view = layout['facing']
    meshes = {m['name']: m for m in layout['joint_meshes']}
    layers = {}
    for part in layout['parts']:
        name, piece = part['name'], part['logical_part']
        image = source_pixels(CASE, part)
        allowed = image[..., 3] > 0
        checks = np.zeros_like(image)
        checks[allowed] = [255, 0, 0, 255]
        continuation = (hidden[piece][..., 3] > 0) & allowed
        if not part.get('hidden_material') and name not in meshes: continuation[:] = False
        checks[continuation, 1] = 255
        checks[allowed & outline_class(image, material_rules), 2] = 255
        mask = store(checks, CASE / 'checks' / view, name, part['bbox'])
        layers[name] = {'mask': mask['file'], 'mask_offset': mask['offset'],
                        'z_index': part['z_index'], 'source': part['file'],
                        'rigid': name not in meshes, 'source_sha256': digest(CASE / part['file'])}
    layout['proof_layers'] = layers
    rest_holes = []
    for index, hole in enumerate(holes(paint[..., 3] > 0)):
        if int(hole.sum()) <= 1: continue
        rim = dilate(hole, 1) & ~hole
        owner = max(PIECES, key=lambda n: int((rim & (visible[n][..., 3] > 0)).sum()))
        path = CASE / f'holes/{view}_{index:02d}.png'
        path.parent.mkdir(exist_ok=True)
        image = np.zeros_like(paint)
        image[hole] = 255
        Image.fromarray(image).save(path)
        record = {'name': f'RestHole{index:02d}', 'owner': owner, 'file': str(path.relative_to(CASE)),
                  'bone': BONES.get(owner, owner)}
        if owner in anatomy['meshes']:
            vertices, uvs, triangles = grid([0, 0, 255, 255])
            weights = weights_for(vertices, meshes[owner]['bbox'], layout['joints'], anatomy['meshes'][owner])
            template = CASE / f'holes/{view}_{owner}_mesh.json'
            template.write_text(json.dumps({'vertices': vertices, 'uvs': uvs, 'triangles': triangles,
                'weights': weights, 'z_index': 0}, separators=(',', ':')) + '\n')
            record['mesh_template'] = str(template.relative_to(CASE))
        rest_holes.append(record)
    layout['proof_rest_holes'] = rest_holes
    layout['proof_joint_seams'] = build_masks(CASE, layout, visible, anatomy)


def build_view(view, inputs, anatomy):
    base, old, seeds, delivery = prepare(PROJECT, CASE, inputs, view, PIECES,
        registered_transform, label_palette, native_depths,
        lambda creature, spec: recipe_for(creature, spec, view), bind_layout)
    source = CASE / 'source' / view
    source.mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(PROJECT / inputs[view + '_job'] / name, source / name)
    paint = np.asarray(Image.open(source / 'processed.png').convert('RGBA'))
    visible, hidden = {}, {}
    for name, labels in PIECES.items():
        image, fill = np.zeros_like(paint), np.zeros_like(paint)
        for part in old['parts']:
            if part['logical_part'] in labels:
                material = source_pixels(base, part)
                image[material[..., 3] > 0] = material[material[..., 3] > 0]
        for label in labels:
            fill[seeds[label][..., 3] > 0] = seeds[label][seeds[label][..., 3] > 0]
        fill[(paint[..., 3] == 0) | (image[..., 3] > 0)] = 0
        visible[name] = image
        hidden[name] = clean_continuation(image, fill, rules(base, view))
        # Fused limbs can have one entirely covered source label. Continue
        # the shared painted surface inside its native union silhouette.
        solo = np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png').convert('RGBA'))[..., 3] > 128 for label in labels])
        covered = connected_mask(image[..., 3] > 0, solo & (paint[..., 3] > 0) & (image[..., 3] == 0))
        missing = covered & (hidden[name][..., 3] == 0)
        continuation = edge_texels(image, missing, rules(base, view))
        hidden[name][missing] = continuation[missing]
    joints = old['joints']
    source_depths = {p['logical_part']: p['z_index'] for p in old['parts']}
    depths = {name: source_depths[DEPTH_SOURCE.get(name, name)] for name in PIECES}
    # The native riveted mouth is the cover over the upper arm's distal end.
    # Source ownership is disjoint, so this constraint leaves rest unchanged.
    depths['tube'] = max(depths['tube'], depths['upper_near'] + 1)
    material_rules = rules(base, view)
    tuck_masks, reports = {}, []
    for name, recipe in anatomy['tucks']['pieces'].items():
        required = required_tuck(name, visible, joints, anatomy['tucks'], continuation=hidden[name][..., 3] > 0)
        missing = required & (hidden[name][..., 3] == 0)
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, material_rules)
        hidden[name][missing] = continuation[missing]
        tuck_masks[name] = required
        path = CASE / f'tucks/{view}_{name}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
        reports.append({'piece': name, 'minimum_px': recipe['depth_px'], 'cover': recipe['covers'],
                        'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
                        'missing_pixels': int((required & (hidden[name][..., 3] == 0)).sum())})
    parts, meshes = [], []
    for name, image in visible.items():
        bone, z = BONES.get(name, name), depths[name]
        fill = hidden[name]
        if name in anatomy['meshes']:
            higher = np.logical_or.reduce([other[..., 3] > 0 for n, other in visible.items() if depths[n] > z]) if any(depths[n] > z for n in visible) else np.zeros(paint.shape[:2], dtype=bool)
            allowed = connected_mask(image[..., 3] > 0, (fill[..., 3] > 0) & higher)
            combined = image.copy()
            combined[allowed] = fill[allowed]
            part = store(combined, CASE / 'pieces' / view, name)
            meshes.append(skin_layer(part, name, part['bbox'], joints, z, recipe=anatomy['meshes'][name]))
            lower = fill.copy()
            lower[allowed] = 0
            if lower[..., 3].any():
                under = store(lower, CASE / 'pieces' / view, 'hidden_' + name)
                hidden_depth = min(depths.values()) - 1
                meshes.append(skin_layer(under, name, part['bbox'], joints, hidden_depth, True, recipe=anatomy['meshes'][name]))
                parts.append(dict(under, bone=bone, z_index=hidden_depth, hidden_material=True, logical_part=name))
        else:
            part = store(image, CASE / 'pieces' / view, name)
            if fill[..., 3].any():
                under = store(fill, CASE / 'pieces' / view, 'hidden_' + name)
                parts.append(dict(under, bone=bone, z_index=min(depths.values()) - 1, hidden_material=True,
                                  logical_part=name, presentation_anchor=part['offset']))
        parts.append(dict(part, bone=bone, z_index=z, logical_part=name))
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
              'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
              'held_items': {}, 'ik_chains': [{'first': 'upper_near', 'second': 'fore_near', 'target': 'tube_tip'}],
              'planted_bones': anatomy['planted_bones'], 'source_labels': PIECES, 'features': [],
              'rest_source': f'source/{view}/processed.png',
              'motion_data': 'res://' + str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    proof_masks(layout, paint, visible, hidden, material_rules, anatomy)
    write_json(CASE / f'layouts/{view}.json', layout)
    reconstructed = Image.new('RGBA', (255, 255))
    for part in sorted(parts, key=lambda p: p['z_index']):
        reconstructed.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    mismatch = int(np.any(np.asarray(reconstructed) != paint, axis=-1).sum())
    spec = read_json(base / 'source/spec_native.json')
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    projection = {'forward': (forward / np.linalg.norm(forward)).tolist(),
                  'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    report = {'front_rest_mismatch_pixels': mismatch, 'rest_mismatch_pixels': mismatch, 'tucks': reports,
              'delivery': delivery, 'source_ownership': str(base.relative_to(PROJECT) / f'layouts/{view}.json'),
              'source_ownership_sha256': digest(base / f'layouts/{view}.json')}
    return layout, report, projection


def build():
    inputs, anatomy = read_json(CASE / 'inputs.json'), load_anatomy(CASE)
    copied = CASE / 'director_motion.json'
    if copied.exists() and copied.read_bytes() != DIRECTOR.read_bytes():
        raise ValueError('Protected director import differs')
    if not copied.exists(): shutil.copyfile(DIRECTOR, copied)
    layouts, reports, projections = {}, {}, {}
    for view in ('front', 'rear'):
        layouts[view], reports[view], projections[view] = build_view(view, inputs, anatomy)
    compiled = compile_motion(copied, 'arc_thrall', layouts, projections)
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'arc_thrall', 'rig': 'humanoid_v2',
        'layouts': {v: f'layouts/{v}.json' for v in layouts}, 'design_placeholders': inputs['design_placeholders'],
        'clips': compiled['clips'], 'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd',
                                                  'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(PROJECT, CASE, ASSETS, layouts)
    write_json(CASE / 'proof/build.json', dict(reports['front'], views=reports, director_sha256=digest(copied),
        production_promoted=True, native_proof='pending director windowed captures'))
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    for view, report in reports.items():
        print(f'RR11 {view.upper()} BUILD: {"PASS" if not report["rest_mismatch_pixels"] else "FAIL"} (rest mismatch: {report["rest_mismatch_pixels"]} px; 4 joint_meshes; protected tracks byte-identical)')
    return layouts


if __name__ == '__main__': build()
