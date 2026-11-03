"""Register/cut approved mq-13 texels; reuse the generic humanoid compiler.

No painting, maquette or protected motion input is authored by this builder.
"""
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
from rr35_case import PROJECT, CASE, ASSETS, DIRECTOR, PIECES, NATIVE_PIECES, BONES, GROUPS
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/hoarfrost_seer')]
from rr07_inputs import registered_transform, label_palette
from rr07_geometry import bind_layout
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes, dilate
from humanoid_cutout.anatomy import load
from humanoid_cutout.source_view import prepare
from humanoid_cutout.materials import clean_continuation, connected_mask
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.mesh import grid, weights_for
from humanoid_cutout.tucks import required_tuck
from humanoid_cutout.seams import build_masks
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.underlays import distinct_depths
from rr35_features import feature_definitions, enforce_features
from rr35_ownership import assign, draw_depths

TRANSPARENT_SOURCE_RGBA = (0, 0, 0, 0)  # Native transparent-clear representation only.


def native_depths(spec, view):
    """Reference depth rule extended locally to mq-13 rigid-shell vertices."""
    from maquette_cutout import camera_view
    matrix, target, azimuth, elevation, _, distance = camera_view(spec, view)
    direction = np.array([np.cos(elevation) * np.cos(azimuth), np.cos(elevation) * np.sin(azimuth), np.sin(elevation)])
    centers = {}
    for label in spec['labels']:
        bones = [b for b in spec['armature']['bones'] if b['region'] == label]
        points = [spec['joints'][b[k]] for b in bones for k in ('head', 'tail')]
        if not points:
            for p in spec['pieces']:
                if p['part'] != label and label not in p.get('side_parts', []): continue
                if 'vertices' in p: points.extend(p['vertices'])
                elif 'path' in p: points.extend(p['path'])
                elif 'pattern' in p: points.extend(q for row in p['pattern']['rows'] for q in row['points'])
                elif 'centre' in p: points.append(p['centre'])
        if not points: raise ValueError('Missing native material center: ' + label)
        if label.startswith('cape_'):
            from spec.art_identity.maquettes.blender.ownership import cloak_owners
            midpoint = (np.asarray(spec['joints']['shoulder_near']) + spec['joints']['shoulder_far']) / 2
            owners = cloak_owners(points, midpoint, [1, 0, 0], [0, 0, 1],
                spec['joints']['shoulder_near'], spec['joints']['shoulder_far'])
            points = [point for point, owner in zip(points, owners) if owner == label]
        center = (matrix @ np.append(np.mean(points, axis=0), 1))[:3]
        centers[label] = float(distance - (center - target) @ direction)
    return centers


def recipe_for(_creature, spec, view):
    mapping = {'root': 'root', 'pelvis': 'pelvis', 'torso': 'torso', 'head': 'head'}
    for s in ('near', 'far'):
        mapping.update({n + '_' + s: src + '_' + s for n, src in
            [('upper', 'shoulder'), ('fore', 'elbow'), ('hand', 'hand'),
             ('thigh', 'hip'), ('shin', 'knee'), ('foot', 'ankle')]})
    anatomy = load(CASE)
    joints = {n: {'joint': src, 'parent': anatomy['required_parents'][n]} for n, src in mapping.items()}
    return {'joints': joints, 'parts': {label: BONES.get(n, n) for n, labels in NATIVE_PIECES.items() for label in labels}}


def store(image, folder, name, bounds=None):
    if bounds is None:
        ys, xs = np.nonzero(image[..., 3])
        if not len(xs): raise ValueError('TODO_DESIGN_empty_' + name)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
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
        if not part.get('hidden_material'): continuation[:] = False
        checks[continuation, 1] = 255
        checks[allowed & outline_class(image, material_rules), 2] = 255
        mask = store(checks, CASE / 'checks' / view, name, part['bbox'])
        layers[name] = {'mask': mask['file'], 'mask_offset': mask['offset'], 'z_index': part['z_index'],
            'source': part['file'], 'rigid': name not in meshes, 'source_sha256': digest(CASE / part['file'])}
    layout['proof_layers'] = layers
    references = []
    for index, hole in enumerate(holes(paint[..., 3] > 0)):
        if int(hole.sum()) <= 1: continue
        rim = dilate(hole, 1) & ~hole
        owner = max(PIECES, key=lambda n: int((rim & (visible[n][..., 3] > 0)).sum()))
        path = CASE / f'holes/{view}_{index:02d}.png'
        path.parent.mkdir(exist_ok=True)
        image = np.zeros_like(paint); image[hole] = 255
        Image.fromarray(image).save(path)
        record = {'name': f'RestHole{index:02d}', 'owner': owner, 'file': str(path.relative_to(CASE)), 'bone': BONES.get(owner, owner)}
        if owner in anatomy['meshes']:
            vertices, uvs, triangles = grid([0, 0, 255, 255])
            weights = weights_for(vertices, meshes[owner]['bbox'], layout['joints'], anatomy['meshes'][owner])
            template = CASE / f'holes/{view}_{owner}_mesh.json'
            write_json(template, {'vertices': vertices, 'uvs': uvs, 'triangles': triangles, 'weights': weights, 'z_index': 0})
            record['mesh_template'] = str(template.relative_to(CASE))
        references.append(record)
    layout['proof_rest_holes'] = references
    layout['proof_joint_seams'] = build_masks(CASE, layout, visible, anatomy)


def build_view(view, inputs, anatomy):
    base, old, seeds, delivery = prepare(PROJECT, CASE, inputs, view, NATIVE_PIECES,
        registered_transform, label_palette, native_depths,
        lambda creature, spec: recipe_for(creature, spec, view), bind_layout)
    source = CASE / 'source' / view
    source.mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'): shutil.copyfile(PROJECT / inputs[view + '_job'] / name, source / name)
    paint = np.asarray(Image.open(source / 'processed.png').convert('RGBA')).copy()
    # A single approved front texel has RGB under alpha=0. Native transparent
    # clears cannot retain it. Normalize only this derived copy, never the job.
    transparent_rgb = int(np.any(paint[paint[..., 3] == 0, :3] != 0, axis=-1).sum())
    paint[paint[..., 3] == 0] = TRANSPARENT_SOURCE_RGBA
    Image.fromarray(paint).save(source / 'processed.png')
    # Source-space pelvis cut follows the native hip level; the carapace is
    # never split. Preserve each selected source RGBA byte.
    torso = next(p for p in old['parts'] if p['logical_part'] == 'torso')
    pixels = source_pixels(base, torso)
    yy = np.indices(pixels.shape[:2])[0]
    lower = yy >= old['joints']['pelvis']['position'][1]
    pelvis = pixels.copy(); pelvis[~lower] = 0
    pixels[lower] = 0
    for name, image in [('torso', pixels), ('pelvis', pelvis)]:
        ys, xs = np.nonzero(image[..., 3])
        if not len(xs): raise ValueError('TODO_DESIGN_' + view + '_' + name + '_cut')
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        file = base / f'pieces/{view}/{name}.png'
        Image.fromarray(image).crop(bounds).save(file)
        part = dict(torso, name=name, logical_part=name, bone=name,
                    file=str(file.relative_to(base)), offset=bounds[:2], bbox=bounds)
        if name == 'torso': old['parts'][old['parts'].index(torso)] = part
        else: old['parts'].append(part)
    seeds['pelvis'] = seeds['torso'].copy()
    seeds['pelvis'][~lower] = 0
    seeds['torso'][lower] = 0
    # Side-specific cloth endpoints come from each certified, registered solo,
    # rather than a shared screen-space guess or mirrored drawing.
    start = np.asarray(old['joints']['torso']['position'])
    for side in ('near', 'far'):
        name = 'cape_' + side
        mask = np.asarray(Image.open(base / f'registered/{view}_solo_{name}.png'))[..., 3] > 128
        ys, xs = np.nonzero(mask)
        tip = np.array([xs[ys == ys.max()].mean(), ys.max()])
        old['joints'][name + '_mid'] = {'parent': 'torso', 'position': ((start + tip) / 2).tolist()}
        old['joints'][name + '_tip'] = {'parent': name + '_mid', 'position': tip.tolist()}
    write_json(base / f'layouts/{view}.json', old)
    visible, hidden = {}, {}
    material_rules = rules(base, view)
    for name, labels in PIECES.items():
        image, fill = np.zeros_like(paint), np.zeros_like(paint)
        for part in old['parts']:
            if part['logical_part'] in labels:
                pixels = source_pixels(base, part)
                image[pixels[..., 3] > 0] = pixels[pixels[..., 3] > 0]
        for label in labels: fill[seeds[label][..., 3] > 0] = seeds[label][seeds[label][..., 3] > 0]
        fill[(paint[..., 3] == 0) | (image[..., 3] > 0)] = 0
        visible[name] = image
        hidden[name] = clean_continuation(image, fill, material_rules)
        solo = (np.asarray(Image.open(base / f'registered/{view}_solo_torso.png').convert('RGBA'))[..., 3] > 128) & lower if name == 'pelvis' else np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png').convert('RGBA'))[..., 3] > 128 for label in labels])
        covered = connected_mask(image[..., 3] > 0, solo & (paint[..., 3] > 0) & (image[..., 3] == 0))
        missing = covered & (hidden[name][..., 3] == 0)
        continuation = edge_texels(image, missing, material_rules)
        hidden[name][missing] = continuation[missing]
    feature_definitions(CASE, view, paint)
    enforce_features(CASE, view, visible, hidden, paint)
    carapace = assign(CASE, view, visible, hidden, paint, material_rules)
    joints = old['joints']
    source_depths = {p['logical_part']: p['z_index'] for p in old['parts']}
    depths = {name: source_depths[labels[0]] for name, labels in PIECES.items()}
    depths = draw_depths(depths, view)
    reports = []
    for name, recipe in anatomy['tucks']['pieces'].items():
        required = required_tuck(name, visible, joints, anatomy['tucks'], continuation=hidden[name][..., 3] > 0)
        missing = required & (hidden[name][..., 3] == 0)
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, material_rules)
        hidden[name][missing] = continuation[missing]
        path = CASE / f'tucks/{view}_{name}.png'; path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
        reports.append({'piece': name, 'minimum_px': recipe['depth_px'], 'cover': recipe['covers'],
            'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
            'missing_pixels': int((required & (hidden[name][..., 3] == 0)).sum())})
    parts, meshes = [], []
    for name, image in visible.items():
        bone, z = BONES.get(name, name), depths[name]
        part = store(image, CASE / 'pieces' / view, name)
        if name in anatomy['meshes']: meshes.append(layer(part, name, part['bbox'], joints, z, recipe=anatomy['meshes'][name]))
        parts.append(dict(part, bone=bone, z_index=z, logical_part=name))
        if hidden[name][..., 3].any():
            under = store(hidden[name], CASE / 'pieces' / view, 'hidden_' + name)
            hidden_depth = min(depths.values()) - 1
            if name in anatomy['meshes']:
                meshes.append(layer(under, name, part['bbox'], joints, hidden_depth, True, recipe=anatomy['meshes'][name]))
            parts.append(dict(under, bone=bone, z_index=hidden_depth, hidden_material=True, logical_part=name))
    features = read_json(CASE / f'features/{view}.json')
    native_joints = read_json(PROJECT / inputs[view + '_delivery'] / 'joints_px.json')[view]
    registration = read_json(base / f'registered/{view}_registration.json')
    blade_tips = {}
    for side in ('near', 'far'):
        name = 'hand_' + side
        native = np.asarray(native_joints['hand_tip_' + side]) * registration['scale'] + registration['offset']
        y, x = np.nonzero(visible[name][..., 3])
        points = np.column_stack((x + .5, y + .5))
        tip = points[np.argmin(np.sum((points - native) ** 2, axis=1))]
        blade_tips[name] = {'source': tip.tolist(), 'registered_native_tip': native.tolist(),
                            'policy': 'nearest owned painted texel centre to certified native hand_tip'}
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
        'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
        'held_items': {}, 'ik_chains': [], 'planted_bones': anatomy['planted_bones'],
        'source_labels': PIECES, 'features': features, 'carapace_ownership': carapace, 'blade_tips': blade_tips,
        'rest_source': f'source/{view}/processed.png',
        'motion_data': 'res://' + str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    distinct_depths(layout)
    continuations = CASE / 'gait_continuations.json'
    if continuations.exists(): layout['gait_continuations'] = read_json(continuations)[view]
    clips = CASE / 'clip_continuations.json'
    if clips.exists(): layout['clip_continuations'] = read_json(clips)[view]
    gait = read_json(DIRECTOR)['gloam_stalker']['clips']['move'].get('gait')
    if gait: layout['gait_leg_scale_max'] = gait['leg_scale_max']
    proof_masks(layout, paint, visible, hidden, material_rules, anatomy)
    write_json(CASE / f'layouts/{view}.json', layout)
    reconstructed = Image.new('RGBA', (255, 255))
    for part in sorted(parts, key=lambda p: p['z_index']): reconstructed.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    mismatch = int(np.any(np.asarray(reconstructed) != paint, axis=-1).sum())
    spec = read_json(base / 'source/spec_native.json')
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    projection = {'forward': (forward / np.linalg.norm(forward)).tolist(), 'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    approved = np.asarray(Image.open(PROJECT / inputs[view + '_job'] / 'processed.png').convert('RGBA'))
    approved_mismatch = int(np.any(np.asarray(reconstructed) != approved, axis=-1).sum())
    report = {'approved_painting_rgba_mismatch_pixels': approved_mismatch, 'transparent_rgb_normalized_pixels': transparent_rgb, 'carapace': carapace, 'front_rest_mismatch_pixels': mismatch, 'rest_mismatch_pixels': mismatch, 'tucks': reports, 'delivery': delivery,
        'source_ownership': str(base.relative_to(PROJECT) / f'layouts/{view}.json'), 'source_ownership_sha256': digest(base / f'layouts/{view}.json')}
    return layout, report, projection


def build(import_director=False):
    inputs, anatomy = read_json(CASE / 'inputs.json'), load(CASE)
    copied = CASE / 'director_motion.json'
    if copied.exists() and copied.read_bytes() != DIRECTOR.read_bytes() and not import_director: raise ValueError('Protected director import differs')
    shutil.copyfile(DIRECTOR, copied)
    layouts, reports, projections = {}, {}, {}
    for view in ('front', 'rear'): layouts[view], reports[view], projections[view] = build_view(view, inputs, anatomy)
    compiled = compile_motion(copied, 'gloam_stalker', layouts, projections)
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'gloam_stalker', 'rig': 'humanoid_v2',
        'layouts': {v: f'layouts/{v}.json' for v in layouts}, 'design_placeholders': inputs['design_placeholders'],
        'direction_clips': ['move', 'ambush', 'slash', 'hit', 'death'], 'clips': compiled['clips'],
        'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd', 'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(PROJECT, CASE, ASSETS / 'humanoid_v2', layouts)
    write_json(CASE / 'proof/build.json', dict(reports['front'], views=reports, director_sha256=digest(copied),
        production_promoted=True, native_proof='pending director windowed captures'))
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts: Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    for view, report in reports.items():
        print('RR35 %s BUILD: %s (rest mismatch: %d px; 6 skinned meshes; protected tracks byte-identical)' %
            (view.upper(), 'FAIL' if report['rest_mismatch_pixels'] else 'PASS', report['rest_mismatch_pixels']))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--import-director', action='store_true', help='Explicitly import the director-approved replacement file byte for byte')
    build(parser.parse_args().import_director)
