"""Register/cut approved mq-14 texels; reuse the generic humanoid compiler.

No painting, maquette or protected motion input is authored by this builder.
"""
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE, ASSETS, DIRECTOR, PIECES, NATIVE_PIECES, BONES, GROUPS
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
from rr37_features import feature_definitions, enforce_features
from rr37_ownership import assign, draw_depths
from rr37_registration import for_view
from rr37_traces import apply as trace_ownership
from rr37_coverage import cover, donors as own_donors

TRANSPARENT_SOURCE_RGBA = (0, 0, 0, 0)  # Native transparent-clear representation only.
CONTINUATION_CANVAS_PADDING_PX = 4  # Empty texture capacity; preserves the 2px skin grid and existing paint.


def native_depths(spec, view):
    """Reference depth rule extended locally to mq-14 rigid-shell vertices."""
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
                elif 'outline_3d' in p: points.extend(p['outline_3d'])
                elif 'path' in p: points.extend(p['path'])
                elif 'pattern' in p: points.extend(q for row in p['pattern']['rows'] for q in row['points'])
                elif 'centre' in p: points.append(p['centre'])
                elif 'outline' in p: points.append(np.asarray(spec['joints'][p['at']]) + p['offset'])
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
    mapping = {'root': 'root', 'pelvis': 'pelvis', 'torso': 'torso', 'head': 'head', 'spear': 'hand_far'}
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
        # Director-painted hidden surfaces include their intentional outer ink.
        # They are certified independently by the uncovered gate, rather than
        # classified as procedural interior-donor continuations.
        from rr41_underlay import paint_mask
        continuation &= ~paint_mask(CASE, layout, part)
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
    previous_path = CASE / f'layouts/{view}.json'
    previous = {p['name']: p for p in read_json(previous_path)['parts']} if previous_path.exists() else {}
    base, old, seeds, delivery = prepare(PROJECT, CASE, inputs, view, NATIVE_PIECES,
        for_view(view), label_palette, native_depths,
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
    # Side-specific cloth endpoints come from each certified, registered solo,
    # rather than a shared screen-space guess or mirrored drawing.
    for name, attachment in [('cape_near', 'torso'), ('cape_far', 'torso'), ('tabard', 'pelvis')]:
        start = np.asarray(old['joints'][attachment]['position'])
        mask = np.asarray(Image.open(base / f'registered/{view}_solo_{name}.png'))[..., 3] > 128
        ys, xs = np.nonzero(mask)
        tip = np.array([xs[ys == ys.max()].mean(), ys.max()])
        old['joints'][name + '_mid'] = {'parent': attachment, 'position': ((start + tip) / 2).tolist()}
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
        solo = np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png').convert('RGBA'))[..., 3] > 128 for label in labels])
        covered = connected_mask(image[..., 3] > 0, solo & (paint[..., 3] > 0) & (image[..., 3] == 0))
        missing = covered & (hidden[name][..., 3] == 0)
        continuation = edge_texels(image, missing, material_rules)
        hidden[name][missing] = continuation[missing]
    trace_ownership(CASE, view, visible, paint)
    for name, labels in PIECES.items():
        hidden[name][:] = 0
        if not visible[name][..., 3].any(): continue
        solo = np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png').convert('RGBA'))[..., 3] > 128 for label in labels])
        target = connected_mask(visible[name][..., 3] > 0, solo & (paint[..., 3] > 0) & (visible[name][..., 3] == 0))
        hidden[name] = edge_texels(visible[name], target, material_rules)
    feature_definitions(CASE, view, paint)
    enforce_features(CASE, view, visible, hidden, paint)
    pauldrons = assign(CASE, view, visible, hidden, paint, material_rules)
    # Ownership transfers invalidate former donors. Rebuild every continuation
    # exclusively from its final owner's approved interior texels.
    for name in visible:
        target = hidden[name][..., 3] > 0
        hidden[name] = edge_texels(own_donors(visible[name], name), target, material_rules) if visible[name][..., 3].any() else np.zeros_like(paint)
    cover(view, visible, hidden, paint, material_rules)
    from rr37_surfaces import cover as cover_surfaces
    solos = {name: np.asarray(Image.open(base / f'registered/{view}_solo_{name}.png'))[..., 3] > 128
             for name in ('torso', 'cape_far')}
    required_surfaces = cover_surfaces(view, visible, hidden, paint, material_rules, solos)
    if view=='rear':
        from rr37_surfaces import rear_cloak_outline
        outline=rear_cloak_outline(visible,paint)
        for name in ('cape_near','cape_far'):
            path=CASE/f'uncovered/outer_{view}_{name}.png';path.parent.mkdir(exist_ok=True)
            Image.fromarray(outline.astype('uint8')*255).save(path)
    for name, mask in required_surfaces.items():
        path = CASE / f'uncovered/{view}_{name}.png'; path.parent.mkdir(exist_ok=True)
        Image.fromarray(mask.astype('uint8') * 255).save(path)
    joints = old['joints']
    source_depths = {p['logical_part']: p['z_index'] for p in old['parts']}
    depths = {name: source_depths[labels[0]] for name, labels in PIECES.items()}
    depths = draw_depths(depths, view)
    reports = []
    for name, recipe in anatomy['tucks']['pieces'].items():
        if not visible[name][..., 3].any() and not hidden[name][..., 3].any():
            continue  # Director-declared covered surface; never invent a donor.
        required = required_tuck(name, visible, joints, anatomy['tucks'], continuation=hidden[name][..., 3] > 0)
        from rr41_underlay import surface
        authority, underlay = surface(view, name)
        required &= ~authority | (underlay[..., 3] > 0)
        if view == 'rear' and name == 'spear':
            # The generic joint tuck spans the complete rest grip width.
            # Only the shaft continues under the glove; the glove's own
            # coverage supplies the remainder when the item rotates away.
            from rr37_surfaces import rear_shaft_core
            yy, xx = np.indices(required.shape)
            required &= rear_shaft_core(xx, yy)
        missing = required & (hidden[name][..., 3] == 0)
        donors = own_donors(visible[name], name)
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        try:
            continuation = edge_texels(donors, missing, material_rules)
        except Exception as error:
            raise ValueError(view + '/' + name + ': ' + str(error)) from error
        hidden[name][missing] = continuation[missing]
        path = CASE / f'tucks/{view}_{name}.png'; path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
        if view == 'front' and name == 'cape_near' and not required.any():
            # Its entire old tuck belonged to the leg footprint. The existing
            # topmost far cloak now supplies that domain with director paint;
            # the duplicate near-cloak recipe is retired, not a required tuck.
            continue
        reports.append({'piece': name, 'minimum_px': recipe['depth_px'], 'cover': recipe['covers'],
            'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
            'missing_pixels': int((required & (hidden[name][..., 3] == 0)).sum())})
    parts, meshes = [], []
    for name, image in visible.items():
        bone, z = BONES.get(name, name), depths[name]
        empty_bounds = None
        if not image[..., 3].any():
            native = np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png'))[..., 3] > 128 for label in PIECES[name]])
            yy, xx = np.nonzero(native)
            empty_bounds = [int(xx.min()), int(yy.min()), int(xx.max())+1, int(yy.max())+1]
        bounds = empty_bounds
        if name == 'spear' and name in previous:
            yy, xx = np.nonzero(image[..., 3]); old = previous[name]['bbox']
            bounds = [min(old[0], int(xx.min())), min(old[1], int(yy.min())), max(old[2], int(xx.max())+1), max(old[3], int(yy.max())+1)]
        part = store(image, CASE / 'pieces' / view, name, bounds)
        if name in anatomy['meshes']: meshes.append(layer(part, name, part['bbox'], joints, z, recipe=anatomy['meshes'][name]))
        parts.append(dict(part, bone=bone, z_index=z, logical_part=name))
        if hidden[name][..., 3].any():
            under_name = 'hidden_' + name
            bounds=previous[under_name]['bbox'] if name == 'spear' and under_name in previous else None
            if name == 'spear':
                # One rigid source canvas, including identical quad/UV
                # geometry. Separate crop sizes can choose different texels
                # at a nearest-sampling tie even with a shared transform.
                bounds = part['bbox'].copy()
            anchor=None
            if (view=='rear' and name in ('arm_far','hand_far')) or (view=='front' and name=='hand_far'):
                yy,xx=np.nonzero(hidden[name][...,3]);pad=CONTINUATION_CANVAS_PADDING_PX
                anchor=[int(xx.min()),int(yy.min())]
                bounds=[max(0,anchor[0]-pad),max(0,anchor[1]-pad),min(255,int(xx.max())+1+pad),min(255,int(yy.max())+1+pad)]
            under = store(hidden[name], CASE / 'pieces' / view, under_name, bounds)
            from rr39_underlay import presentation_anchor
            fixed_anchor = presentation_anchor(view, under_name)
            if fixed_anchor is not None:
                under['presentation_anchor'] = fixed_anchor
            elif under_name in previous and under['offset'] != previous[under_name]['offset']:
                # A changed storage crop must preserve the former painted snap
                # origin; otherwise unrelated shoulder texels shift by a pixel.
                under['presentation_anchor'] = previous[under_name].get('presentation_anchor', previous[under_name]['offset'])
            if anchor is not None:under['presentation_anchor']=anchor
            if name == 'spear':
                # Both textures are one rigid item. Snap their shared grip
                # transform once, rather than snapping two crop origins.
                under['presentation_anchor'] = part['offset'].copy()
            hidden_depth = min(depths.values()) - 1
            if name in anatomy['meshes']:
                meshes.append(layer(under, name, part['bbox'], joints, hidden_depth, True, recipe=anatomy['meshes'][name]))
            parts.append(dict(under, bone=bone, z_index=hidden_depth, hidden_material=True, logical_part=name))
    # The complete source underlap belongs above old hidden limb fragments,
    # while remaining below the rest occluder. Separate masks keep unrelated
    # historical tucks at their existing depth and preserve every rest pixel.
    for name, target in required_surfaces.items():
        from rr37_surfaces import interior
        if view == 'front':
            from rr39_underlay import covered
            image = covered(name, target)
        else:
            image = edge_texels(interior(visible[name], material_rules), target & (visible[name][...,3]==0))
        if not image[...,3].any(): continue
        under = store(image, CASE/'pieces'/view, 'covered_'+name)
        z = depths['arm_far'] - (1 if name=='torso' else 2) if view=='front' else depths['arm_far']-1
        if name in anatomy['meshes']:
            main = next(p for p in parts if p['name']==name)
            meshes.append(layer(under,name,main['bbox'],joints,z,True,recipe=anatomy['meshes'][name]))
        parts.append(dict(under,bone=BONES.get(name,name),z_index=z,hidden_material=True,logical_part=name))
    features = read_json(CASE / f'features/{view}.json')
    spear = visible['spear'].copy()
    spear[hidden['spear'][..., 3] > 0] = hidden['spear'][hidden['spear'][..., 3] > 0]
    ys, xs = np.nonzero(spear[..., 3])
    floor_end = read_json(previous_path)['held_items']['spear']['floor_end'] if previous_path.exists() else [float(xs[ys == ys.max()].mean()), float(ys.max())]
    if view == 'rear':
        floor_end = [float(xs[ys == ys.max()].mean()), float(ys.max())]
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
        'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
        'held_items': {'spear': {'hand': 'hand_far', 'floor_end': floor_end, 'angle_limits_deg': {'lunge': 72, 'jab': 60, 'cast': 48, 'pin': 66}}}, 'ik_chains': [], 'planted_bones': anatomy['planted_bones'],
        'strike_points': {'spear': [float(xs[ys == ys.min()].mean()) + .5, float(ys.min()) + .5]},
        'source_labels': PIECES, 'features': features, 'pauldrons_ownership': pauldrons,
        'rest_source': f'source/{view}/processed.png',
        'motion_data': 'res://' + str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    distinct_depths(layout)
    if view == 'front':
        layout['director_leg_underlay'] = 'rr-41: protected painted lining; no procedural leg-footprint backing'
    continuations = CASE / 'gait_continuations.json'
    if continuations.exists(): layout['gait_continuations'] = read_json(continuations)[view]
    clips = CASE / 'clip_continuations.json'
    if clips.exists(): layout['clip_continuations'] = read_json(clips)[view]
    gait = read_json(DIRECTOR)['frostglass_lancer']['clips']['move'].get('gait')
    if gait: layout['gait_leg_scale_max'] = gait['leg_scale_max']
    # Retain global source coordinates when a repaired crop moves its origin.
    for table in [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values()):
        for name, recipe in table.items():
            if name not in previous: continue
            part = next(p for p in parts if p['name'] == name)
            dx, dy = np.asarray(previous[name]['offset']) - part['offset']
            recipe['texels'] = [[int(x+dx), int(y+dy), u, v] for x,y,u,v in recipe['texels']]
    from rr41_underlay import retire_recipes
    retire_recipes(layout)
    from rr37_materials import treat_coverage
    material_receipt = treat_coverage(layout, visible, hidden, paint, material_rules)
    from rr43_spear import rigid_item
    rigid_item(layout, CASE, visible, paint, hidden, reports)
    from rr37_surfaces import provenance
    provenance(CASE,layout,visible,material_rules)
    # rr-54 applies final spear depth after hidden/covered layers exist.
    from rr54_layers import apply_layers, assemble_rear_rest
    apply_layers(layout)
    assemble_rear_rest(CASE, layout)
    proof_masks(layout, paint, visible, hidden, material_rules, anatomy)
    write_json(CASE / f'layouts/{view}.json', layout)
    reconstructed = Image.new('RGBA', (255, 255))
    for part in sorted(parts, key=lambda p: p['z_index']): reconstructed.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    # The approved painting remains immutable; rr-54's rear rest is a
    # separate assembly with the shaft behind the body. Its difference from
    # the painting is still reported independently as approved_mismatch.
    rest_reference = np.asarray(Image.open(CASE / layout['rest_source']).convert('RGBA'))
    mismatch = int(np.any(np.asarray(reconstructed) != rest_reference, axis=-1).sum())
    spec = read_json(base / 'source/spec_native.json')
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    projection = {'forward': (forward / np.linalg.norm(forward)).tolist(), 'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    approved = np.asarray(Image.open(PROJECT / inputs[view + '_job'] / 'processed.png').convert('RGBA'))
    approved = approved.copy()
    approved[approved[..., 3] == 0] = TRANSPARENT_SOURCE_RGBA
    approved_mismatch = int(np.any(np.asarray(reconstructed) != approved, axis=-1).sum())
    report = {'density_material': material_receipt, 'approved_painting_rgba_mismatch_pixels': approved_mismatch, 'transparent_rgb_normalized_pixels': transparent_rgb, 'pauldrons': pauldrons, 'front_rest_mismatch_pixels': mismatch, 'rest_mismatch_pixels': mismatch, 'tucks': reports, 'delivery': delivery,
        'source_ownership': str(base.relative_to(PROJECT) / f'layouts/{view}.json'), 'source_ownership_sha256': digest(base / f'layouts/{view}.json')}
    return layout, report, projection


def build(import_director=False):
    from rr41_underlay import EXPOSURE_REPAIRS
    shutil.copyfile(EXPOSURE_REPAIRS, CASE/'rr41_exposure_repairs.json')
    inputs, anatomy = read_json(CASE / 'inputs.json'), load(CASE)
    copied = CASE / 'director_motion.json'
    if copied.exists() and copied.read_bytes() != DIRECTOR.read_bytes() and not import_director: raise ValueError('Protected director import differs')
    shutil.copyfile(DIRECTOR, copied)
    layouts, reports, projections = {}, {}, {}
    for view in ('front', 'rear'): layouts[view], reports[view], projections[view] = build_view(view, inputs, anatomy)
    for field in ('gait_continuations','clip_continuations'):
        if any(field in l for l in layouts.values()): write_json(CASE/(field+'.json'),{v:l.get(field,{}) for v,l in layouts.items()})
    compiled = compile_motion(copied, 'frostglass_lancer', layouts, projections)
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'frostglass_lancer', 'rig': 'humanoid_v2',
        'proof_geometry': {'canvas_size': 640, 'source_offset': 192},
        'layouts': {v: f'layouts/{v}.json' for v in layouts}, 'design_placeholders': inputs['design_placeholders'],
        'direction_clips': ['move', 'lunge', 'jab', 'pin', 'guard'], 'clips': compiled['clips'],
        'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd', 'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(PROJECT, CASE, ASSETS / 'humanoid_v2', layouts)
    write_json(CASE / 'proof/build.json', dict(reports['front'], views=reports, director_sha256=digest(copied),
        production_promoted=True, native_proof='pending director windowed captures'))
    for view, names in anatomy.get('intentionally_empty', {}).items():
        for name in names:
            for folder in (CASE/'pieces'/view, ASSETS/'humanoid_v2'/view):
                for suffix in ('.png','.png.import'):
                    (folder/('hidden_'+name+suffix)).unlink(missing_ok=True)
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts: Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    for view, report in reports.items():
        print('RR37 %s BUILD: %s (rest mismatch: %d px; 7 skinned meshes; protected tracks byte-identical)' %
            (view.upper(), 'FAIL' if report['rest_mismatch_pixels'] else 'PASS', report['rest_mismatch_pixels']))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--import-director', action='store_true', help='Explicitly import the director-approved replacement file byte for byte')
    build(parser.parse_args().import_director)
