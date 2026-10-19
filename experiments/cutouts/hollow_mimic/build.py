"""Lossless mq-09 ownership, covered continuations, shared v2 skin and promotion.

Visible ownership comes from the two unchanged approved paintings. Director
feedback 1 cleans chroma-key residue only in the derived presentation. The
maquette's categorical parts, solos and joints determine ownership and pivots.
"""
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
from case import ROOT, CASE, ASSETS, DIRECTOR, VIEWS, PIECES, BONES, GROUPS, PARENTS, read_json, write_json, digest, initialize

# Existing read-only registration helpers. No historical builder is executed.
sys.path.insert(0, str(ROOT / 'experiments/cutouts/hoarfrost_seer'))
from rr07_inputs import registered_transform, label_palette
from rr07_geometry import native_depths, bind_layout
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes, dilate
from humanoid_cutout.anatomy import load
from humanoid_cutout.source_view import prepare
from humanoid_cutout.materials import clean_continuation
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.tucks import required_tuck
from humanoid_cutout.seams import build_masks
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.mesh import grid, weights_for
from humanoid_cutout.underlays import distinct_depths
from residue import clean_piece, feature_mask

PROOF_FEATURE_CHROMA_MARGIN = 20  # Proof mask extraction only; never changes paint.


def recipe_for(_creature, _spec):
    mapping = {name: name for name in ('root', 'pelvis', 'torso', 'head')}
    for side in ('near', 'far'):
        mapping.update({name + '_' + side: joint + '_' + side for name, joint in
            [('upper', 'shoulder'), ('fore', 'elbow'), ('hand', 'hand'),
             ('thigh', 'hip'), ('shin', 'knee'), ('foot', 'ankle')]})
    return {'joints': {name: {'joint': source, 'parent': PARENTS[name]} for name, source in mapping.items()},
            'parts': {label: BONES[name] for name, labels in PIECES.items() for label in labels}}


def store(image, folder, name, bounds=None):
    if bounds is None:
        ys, xs = np.nonzero(image[..., 3])
        if not len(xs): raise ValueError('Empty piece: ' + name)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': bounds[:2], 'bbox': bounds}


def proof_masks(layout, paint, visible, hidden, material_rules, anatomy):
    view = layout['facing']
    meshes = {m['name']: m for m in layout['joint_meshes']}
    checks = {}
    for part in layout['parts']:
        name, piece = part['name'], part['logical_part']
        image = source_pixels(CASE, part)
        allowed = image[..., 3] > 0
        mask = np.zeros_like(image)
        mask[allowed] = [255, 0, 0, 255]
        continuation = (hidden[piece][..., 3] > 0) & allowed
        mask[continuation, 1] = 255
        mask[allowed & outline_class(image, material_rules), 2] = 255
        record = store(mask, CASE / 'checks' / view, name, part['bbox'])
        checks[name] = {'mask': record['file'], 'mask_offset': record['offset'],
            'z_index': part['z_index'], 'source': part['file'], 'rigid': name not in meshes,
            'source_sha256': digest(CASE / part['file'])}
    layout['proof_layers'] = checks
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
        record = {'name': f'RestHole{index:02d}', 'owner': owner, 'file': str(path.relative_to(CASE)), 'bone': BONES[owner]}
        if owner in anatomy['meshes']:
            vertices, uvs, triangles = grid([0, 0, 255, 255])
            template = CASE / f'holes/{view}_{owner}_mesh.json'
            write_json(template, {'vertices': vertices, 'uvs': uvs, 'triangles': triangles,
                'weights': weights_for(vertices, meshes[owner]['bbox'], layout['joints'], anatomy['meshes'][owner]), 'z_index': 0})
            record['mesh_template'] = str(template.relative_to(CASE))
        rest_holes.append(record)
    layout['proof_rest_holes'] = rest_holes
    layout['proof_joint_seams'] = build_masks(CASE, layout, visible, anatomy)


def build_view(view, inputs, anatomy):
    base, original, seeds, delivery = prepare(ROOT, CASE, inputs, view, PIECES,
        registered_transform, label_palette, native_depths, recipe_for, bind_layout)
    source = CASE / 'source' / view
    source.mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(ROOT / inputs[view + '_job'] / name, source / name)
    paint = np.asarray(Image.open(source / 'processed.png').convert('RGBA'))
    visible, hidden = {}, {}
    material_rules = rules(base, view)
    for name, labels in PIECES.items():
        image, fill = np.zeros_like(paint), np.zeros_like(paint)
        for part in original['parts']:
            if part['logical_part'] in labels:
                pixels = source_pixels(base, part)
                image[pixels[..., 3] > 0] = pixels[pixels[..., 3] > 0]
        for label in labels:
            fill[seeds[label][..., 3] > 0] = seeds[label][seeds[label][..., 3] > 0]
        fill[(paint[..., 3] == 0) | (image[..., 3] > 0)] = 0
        visible[name] = image
        hidden[name] = clean_continuation(image, fill, material_rules)
    joints = original['joints']
    reports = []
    for name, recipe in anatomy['tucks']['pieces'].items():
        required = required_tuck(name, visible, joints, anatomy['tucks'], continuation=hidden[name][..., 3] > 0)
        missing = required & (hidden[name][..., 3] == 0)
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, material_rules)
        hidden[name][missing] = continuation[missing]
        path = CASE / f'tucks/{view}_{name}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
        reports.append({'piece': name, 'minimum_px': recipe['depth_px'], 'cover': recipe['covers'],
            'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
            'missing_pixels': int((required & (hidden[name][..., 3] == 0)).sum())})
    depths = {name: max(p['z_index'] for p in original['parts'] if p['logical_part'] in labels)
              for name, labels in PIECES.items()}
    # Preserve exact ownership evidence before the director-authorized RGB
    # derivation. Protected source snapshots and baseline pieces never change.
    source_rest = Image.new('RGBA', (255, 255))
    for name in sorted(visible, key=lambda n: depths[n]):
        source_rest.alpha_composite(Image.fromarray(visible[name]))
    source_mismatch = int(np.any(np.asarray(source_rest) != paint, axis=-1).sum())
    features = []
    if view == 'front':
        rgb = paint[..., :3].astype(int)
        crack = (paint[..., 3] > 0) & (rgb[..., 0] > rgb[..., 1] + PROOF_FEATURE_CHROMA_MARGIN) & (rgb[..., 2] > rgb[..., 1] + PROOF_FEATURE_CHROMA_MARGIN)
        if np.any(crack & (visible['head'][..., 3] == 0)):
            raise ValueError('Violet crack ownership escapes head')
        path = CASE / 'features/front_violet_crack.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(crack.astype('uint8') * 255).save(path)
        native_path = CASE / 'features/front_violet_crack_native.png'
        native_mask = np.zeros_like(paint)
        native_mask[crack] = 255
        Image.fromarray(native_mask).save(native_path)
        features.append({'name': 'violet_crack', 'piece': 'head', 'mask': str(path.relative_to(CASE)),
            'native_mask': {'name': 'FeatureVioletCrack', 'bone': 'head', 'file': str(native_path.relative_to(CASE))}})
    cleanup = {}
    for name in visible:
        source_folder = CASE / 'residue_source' / view
        source_folder.mkdir(parents=True, exist_ok=True)
        for kind, image in (('visible', visible[name]), ('hidden', hidden[name])):
            Image.fromarray(image).save(source_folder / f'{name}_{kind}.png')
        exemption = feature_mask(CASE, {'canvas_size': [255, 255], 'features': features}, name)
        visible[name], hidden[name], cleanup[name] = clean_piece(visible[name], hidden[name], exemption)
    parts, meshes = [], []
    for name, image in visible.items():
        part = store(image, CASE / 'pieces' / view, name)
        part.update(bone=BONES[name], z_index=depths[name], logical_part=name)
        if name in anatomy['meshes']:
            meshes.append(layer(part, name, part['bbox'], joints, depths[name], recipe=anatomy['meshes'][name]))
        parts.append(part)
        if hidden[name][..., 3].any():
            under = store(hidden[name], CASE / 'pieces' / view, name + '_hidden')
            under.update(bone=BONES[name], z_index=-1, logical_part=name, hidden_material=True)
            if name in anatomy['meshes']:
                meshes.append(layer(under, name, part['bbox'], joints, -1, True, recipe=anatomy['meshes'][name]))
            else:
                # Visible and continuation use one presentation anchor.
                under['presentation_anchor'] = part['offset']
            parts.append(under)
    for feature in features:
        owner = next(p for p in parts if p['name'] == feature['piece'])
        feature['native_mask']['presentation_anchor'] = owner.get('presentation_anchor', owner['offset'])
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
        'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
        'held_items': {}, 'planted_bones': anatomy['planted_bones'], 'planted_during_death': True, 'leg_roles': anatomy['leg_roles'][view],
        'source_labels': PIECES, 'features': features, 'rest_source': f'presentation/{view}/rest.png',
        'motion_data': 'res://' + str(CASE.relative_to(ROOT) / 'compiled_motion.json')}
    distinct_depths(layout)
    proof_masks(layout, paint, visible, hidden, material_rules, anatomy)
    rest = Image.new('RGBA', (255, 255))
    for part in sorted(parts, key=lambda p: p['z_index']): rest.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    rest_path = CASE / layout['rest_source']
    rest_path.parent.mkdir(parents=True, exist_ok=True)
    rest.save(rest_path)
    write_json(CASE / f'layouts/{view}.json', layout)
    presentation_changes = int(np.any(np.asarray(rest) != paint, axis=-1).sum())
    spec = read_json(base / 'source/spec_native.json')
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    projection = {'forward': (forward / np.linalg.norm(forward)).tolist(),
                  'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    report = {'front_rest_mismatch_pixels': source_mismatch, 'rest_mismatch_pixels': source_mismatch, 'tucks': reports,
        'residue_cleanup': cleanup, 'presentation_changed_pixels': presentation_changes,
        'delivery': delivery, 'source_ownership': str(base.relative_to(ROOT) / f'layouts/{view}.json'),
        'source_ownership_sha256': digest(base / f'layouts/{view}.json')}
    return layout, report, projection


def build():
    initialize()
    copied = CASE / 'director_motion.json'
    if copied.exists() and copied.read_bytes() != DIRECTOR.read_bytes(): raise ValueError('Protected director import differs')
    shutil.copyfile(DIRECTOR, copied)
    anatomy, inputs = load(CASE), read_json(CASE / 'inputs.json')
    layouts, reports, projections = {}, {}, {}
    for view in VIEWS: layouts[view], reports[view], projections[view] = build_view(view, inputs, anatomy)
    compiled = compile_motion(copied, 'hollow_mimic', layouts, projections)
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'hollow_mimic', 'rig': 'humanoid_v2',
        'layouts': {v: f'layouts/{v}.json' for v in VIEWS}, 'design_placeholders': inputs['design_placeholders'],
        'clips': compiled['clips'], 'direction_clips': ['bolt', 'mirror'],
        'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd',
                          'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(ROOT, CASE, ASSETS, layouts)
    write_json(CASE / 'proof/build.json', dict(reports['front'], views=reports, director_sha256=digest(copied),
        production_promoted=True, native_proof='pending director windowed captures'))
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    for view in VIEWS: print(f'RR20 {view.upper()} BUILD: ' + ('PASS' if not reports[view]['rest_mismatch_pixels'] else 'FAIL') + f' (source identity mismatch: {reports[view]["rest_mismatch_pixels"]} px; presentation residue cleanup: {reports[view]["presentation_changed_pixels"]} px; 4 skinned limbs)')


if __name__ == '__main__': build()
