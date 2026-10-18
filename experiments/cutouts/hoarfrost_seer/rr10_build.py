"""Front-only v2 candidate from rr-07 ownership and verified rr-05 fill seeds.

No paint synthesis, new art, maquette edits or production promotion. Rear inputs
are deliberately named in inputs.json; the obsolete mirrored rear is not read.
"""
from pathlib import Path
import shutil
import sys
import json

import numpy as np
from PIL import Image, ImageFilter

from rr07_inputs import PROJECT, read_json, write_json, digest, projected
from maquette_motion.features import source_pixels
from maquette_motion.support_seeds import approved
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes
from tools.humanoid_cutout.compiler import compile_motion
from tools.humanoid_cutout.mesh import grid, robe_weights, sleeve_weights
from tools.humanoid_cutout.materials import connected_mask, clean_continuation, held_depths
from tools.humanoid_cutout.seams import build_masks
from tools.humanoid_cutout.ownership import read_mask, apply_override
from tools.humanoid_cutout.tucks import TUCK_DEPTHS_PX, TUCK_COVERS, required_tuck

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
ASSETS = PROJECT / 'assets/units/hoarfrost_seer_cutout/humanoid_v2'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-10/motion_tracks.json'
PIECES = {'head': ['head'], 'torso': ['torso', 'collar'],
          'sleeve_near': ['upper_near', 'fore_near'], 'sleeve_far': ['upper_far', 'fore_far'],
          'hand_near': ['hand_near'], 'hand_far': ['hand_far'],
          'staff': ['staff_shaft', 'staff_crystal'], 'robe': ['skirt_near', 'skirt_far'],
          'foot_near': ['foot_near'], 'foot_far': ['foot_far']}
GROUPS = {'upper_body': ['torso', 'head', 'sleeve_near', 'hand_near'],
          'still_staff_arm': ['sleeve_far', 'hand_far', 'staff'],
          'still_lower_body': ['robe', 'foot_near', 'foot_far']}
# Inherit the rr-07 visible material depths. Disjoint source ownership means
# fusion does not change any rest pixel; underlays always precede visible paint.
DEPTH_SOURCE = {'torso': 'collar', 'sleeve_near': 'upper_near',
                'sleeve_far': 'upper_far', 'staff': 'staff_shaft', 'robe': 'skirt_far'}


def copy_protected(source, target):
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists() and source.read_bytes()!=target.read_bytes():
        raise ValueError('Refusing to overwrite a changed protected import: '+str(target))
    if not target.exists(): shutil.copyfile(source,target)


def dilate(mask, pixels):
    return np.asarray(Image.fromarray(mask.astype('uint8') * 255).filter(
        ImageFilter.MaxFilter(pixels * 2 + 1))) > 0


def store(image, folder, name):
    ys, xs = np.nonzero(image[..., 3])
    bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(tuple(bounds)).save(path)
    Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': bounds[:2], 'bbox': bounds}


def build():
    inputs = read_json(CASE / 'inputs.json')
    base = PROJECT / inputs['baseline']
    old = read_json(base / 'layouts/front.json')
    delivery = PROJECT / inputs['front_delivery']
    bound_delivery = {}
    for name in ['joints_px.json', 'front_parts.png'] + ['front_solo_' + n + '.png' for labels in PIECES.values() for n in labels]:
        if digest(delivery / name) != digest(base / 'source/maquette' / name):
            raise ValueError('Front delivery differs from rr-07 ownership registration: ' + name)
        bound_delivery[name] = digest(delivery / name)
    paint_path = PROJECT / inputs['front_job'] / 'processed.png'
    paint = np.asarray(Image.open(paint_path).convert('RGBA'))
    if digest(paint_path) != digest(base / 'source/front/processed.png'):
        raise ValueError('rr-07 ownership no longer belongs to the approved front')
    (CASE / 'source/front').mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(PROJECT / inputs['front_job'] / name, CASE / 'source/front' / name)
    copy_protected(DIRECTOR, CASE / 'director_motion.json')
    visible, hidden = {}, {}
    for name, labels in PIECES.items():
        image = np.zeros_like(paint)
        for part in old['parts']:
            if part.get('logical_part') in labels and not any(part.get(k) for k in
                    ('hidden_material', 'seam_underlay', 'silhouette_backing')):
                layer = source_pixels(base, part)
                image[layer[..., 3] > 0] = layer[layer[..., 3] > 0]
        visible[name] = image
        fill = np.zeros_like(paint)
        for label in labels:
            part = next((p for p in old['parts'] if p.get('hidden_material') and p.get('logical_part') == label), None)
            if part:
                layer = approved(base, 'front', part)
                fill[layer[..., 3] > 0] = layer[layer[..., 3] > 0]
        # Continuations are hidden at rest, within the approved union silhouette.
        native_silhouette = np.zeros(paint.shape[:2],dtype=bool)
        for label in labels:
            native_silhouette |= np.asarray(Image.open(base / f'registered/front_solo_{label}.png').convert('RGBA'))[...,3] > 128
        fill[(paint[..., 3] == 0) | (image[..., 3] > 0) | ~native_silhouette] = 0
        hidden[name] = fill
    rope = dict(inputs['rope_masks']['front'])
    rope_mask = read_mask(CASE, rope, paint.shape[:2])
    underlay = rope['underlay']
    # Preserve the exact former robe ownership as the required cloth surface
    # behind the now rigid rope tails. No colour selector or mask dilation.
    rope_underlay = rope_mask & (visible[underlay][..., 3] > 0)
    previous_owners = apply_override(visible, paint, rope_mask, rope['owner'])
    material_rules = rules(base, 'front')
    cloth = edge_texels(visible[underlay], rope_underlay, material_rules)
    hidden[underlay][rope_underlay] = cloth[rope_underlay]
    required_path = CASE / 'ownership/front_rope_underlay.png'
    required_path.parent.mkdir(exist_ok=True)
    Image.fromarray(rope_underlay.astype('uint8') * 255).save(required_path)
    rope['underlay_required_mask'] = str(required_path.relative_to(CASE))
    for name in PIECES:
        # Maquette clipping split old hidden seeds into unsupported fragments.
        hidden[name][visible[name][..., 3] > 0] = 0
        hidden[name] = clean_continuation(visible[name], hidden[name], material_rules,
                                         replace_all=name == 'robe')
    reconstructed = np.zeros_like(paint)
    count = np.zeros(paint.shape[:2], dtype=int)
    for image in visible.values():
        mask = image[..., 3] > 0
        reconstructed[mask] = image[mask]
        count += mask
    if not np.array_equal(reconstructed, paint) or count.max() != 1:
        raise ValueError('Front source ownership is not a lossless partition')

    joints = {}
    def joint(name, old_name, parent):
        joints[name] = {'position': old['joints'][old_name]['position'], 'parent': parent}
    joint('root', 'root', None)
    joint('pelvis', 'torso', 'root')
    joint('torso', 'torso', 'pelvis')
    joint('head', 'head', 'torso')
    for side in ('near', 'far'):
        joint('upper_' + side, 'upper_' + side, 'torso')
        joint('fore_' + side, 'fore_' + side, 'upper_' + side)
        joint('hand_' + side, 'hand_' + side, 'fore_' + side)
        joint('foot_' + side, 'foot_' + side, 'hem_' + side)
    robe_ys, robe_xs = np.nonzero(visible['robe'][..., 3])
    # The spec places hem anchors at the lower corners on the floor line.
    # Endpoints are measured from the approved robe alpha, not hand fitted.
    floor = int(robe_ys.max()) + 1
    for side, x in (('near', int(robe_xs.max()) + 1), ('far', int(robe_xs.min()))):
        joints['hem_' + side] = {'position': [x, floor], 'parent': 'root'}
    joint('staff', 'hand_far', 'hand_far')
    depths = {p['logical_part']: p['z_index'] for p in old['parts'] if not any(
        p.get(k) for k in ('hidden_material', 'seam_underlay', 'silhouette_backing'))}
    depths = held_depths({name: depths[DEPTH_SOURCE.get(name, name)] for name in PIECES},
                         'front', inputs['held_item_depth'])
    parts, meshes, tuck_report = [], [], []
    tuck_masks = {}
    # rr-05 same-material continuation at the director's per-edge depths.
    # Approved visible paint and protected source inputs remain unchanged.
    for name, cover in TUCK_COVERS.items():
        own = visible[name][..., 3] > 0
        occlusion = None
        if name.startswith(('hand_', 'foot_')) or name == 'robe':
            # A wrist edge can be hidden by the staff as well as the cuff;
            # clipping to the cuff alone cuts away the needed continuation.
            # Keep every extra texel hidden behind an inherited higher layer.
            under_depth = depths[name] if name == 'robe' else max(
                p['z_index'] for p in old['parts'] if p.get('hidden_material') and p.get('logical_part') in PIECES[name])
            occlusion = np.logical_or.reduce([material[...,3]>0 for other,material in visible.items()
                if depths[other] > under_depth and other != name])
        required = required_tuck(name, visible, joints, occlusion, hidden[name][...,3]>0)
        missing = required & (hidden[name][..., 3] == 0)
        tuck_masks[name] = required
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, rules(base, 'front'))
        hidden[name][missing] = continuation[missing]
    # One deterministic cloth field across both old fills and new tucks. This
    # prevents a flat seed band ending in a horizontal seam below the belt.
    hidden['robe'] = clean_continuation(visible['robe'], hidden['robe'], material_rules, replace_all=True)
    for name, image in visible.items():
        bone = 'upper_' + name.split('_')[-1] if name.startswith('sleeve_') else 'pelvis' if name == 'robe' else name
        z = depths[name]
        fill = hidden[name]
        is_mesh = name == 'robe' or name.startswith('sleeve_')
        if is_mesh:
            # A single mesh per garment. Restrict its continuation to source
            # texels occluded by a higher visible layer at rest.
            higher = np.zeros(paint.shape[:2], dtype=bool)
            for other, material in visible.items():
                if depths[other] > z:
                    higher |= material[..., 3] > 0
            combined = image.copy()
            allowed = (fill[..., 3] > 0) & higher
            allowed = connected_mask(image[..., 3] > 0, allowed)
            combined[allowed] = fill[allowed]
            part = store(combined, CASE / 'pieces/front', name)
            vertices, uvs, triangles = grid(part['bbox'])
            if name == 'robe':
                weights = robe_weights(vertices, part['bbox'])
            else:
                side = name.split('_')[-1]
                weights = sleeve_weights(vertices, *[joints[n + side]['position'] for n in
                    ('upper_', 'fore_', 'hand_')], side)
            meshes.append(dict(part, replaces_part=name, z_index=z, vertices=vertices, uvs=uvs,
                               triangles=triangles, weights=weights, grid_px=2))
        else:
            part = store(image, CASE / 'pieces/front', name)
            if (fill[..., 3] > 0).any():
                underlay = store(fill, CASE / 'pieces/front', 'hidden_' + name)
                hidden_depth = max(p['z_index'] for p in old['parts'] if p.get('hidden_material') and p.get('logical_part') in PIECES[name])
                if name == 'staff': hidden_depth = z - 1
                parts.append(dict(underlay, bone=bone, z_index=hidden_depth, hidden_material=True,
                                  logical_part=name, presentation_anchor=part['offset']))
        parts.append(dict(part, bone=bone, z_index=z, logical_part=name))
    for name, cover in TUCK_COVERS.items():
        own = visible[name][..., 3] > 0
        required = tuck_masks[name]
        provided = hidden[name][..., 3] > 0
        missing = required & ~provided
        mask_path = CASE / f'tucks/front_{name}.png'
        mask_path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(mask_path)
        tuck_report.append({'piece': name, 'cover': cover, 'minimum_px': TUCK_DEPTHS_PX[name],
                            'required_mask': str(mask_path.relative_to(CASE)),
                            'missing_pixels': int(missing.sum()), 'required_pixels': int(required.sum())})
    shaft = next(p for p in read_json(base / 'source/spec_native.json')['pieces'] if p['id'] == 'staff_shaft')
    transform = read_json(base / 'registered/front_registration.json')
    native = projected(read_json(base / 'source/spec_native.json'), shaft['path'][0], 'front')
    floor_end = (np.asarray(native) * transform['scale'] + transform['offset']).tolist()
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': 'front', 'canvas_size': [255, 255],
              'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
              'held_items': {'staff': {'hand': 'hand_far', 'floor_end': floor_end}},
              'held_item_depth': inputs['held_item_depth'],
              'continuation_policy': {'robe': 'rr05_visible_cloth_edge_texels'},
              'source_labels': PIECES, 'ownership_overrides': [rope],
              'rest_source': 'source/front/processed.png', 'motion_data': 'res://' +
              str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    layers = {}
    mesh_names = {m['name'] for m in meshes}
    for part in parts:
        name = part['name']
        piece = part['logical_part']
        stored = source_pixels(CASE, part)
        allowed = stored[..., 3] > 0
        # A packed source mask is rendered by the same GPU geometry as paint:
        # R=own silhouette, G=all continuation, B=all outline class. Exposed
        # continuation is allowed, but must never expose an outline fragment.
        checks = np.zeros_like(stored)
        checks[allowed] = [255, 0, 0, 255]
        tuck = (hidden[piece][..., 3] > 0) & allowed
        if not part.get('hidden_material') and name not in mesh_names:
            tuck[:] = False  # Rigid tucks live in their hidden underlay.
        checks[tuck, 1] = 255
        dark = allowed & outline_class(stored, material_rules)
        checks[dark, 2] = 255
        mask = store(checks, CASE / 'checks/front', name)
        layers[name] = {'mask': mask['file'], 'mask_offset': mask['offset'],
                        'z_index': part['z_index'], 'source': part['file'],
                        'rigid': name not in mesh_names,
                        'source_sha256': digest(CASE / part['file'])}
    layout['proof_layers'] = layers
    (CASE / 'features').mkdir(exist_ok=True)
    shutil.copyfile(base / 'features/front_ice_crystal.png', CASE / 'features/front_ice_crystal.png')
    layout['features'] = [{'name': 'ice_crystal', 'piece': 'staff', 'mask': 'features/front_ice_crystal.png'}]
    rest_holes = []
    for index,hole in enumerate(holes(paint[...,3]>0)):
        if int(hole.sum())<=1: continue
        rim=dilate(hole,1)&~hole
        owner=max(PIECES,key=lambda name:int((rim & (visible[name][...,3]>0)).sum()))
        path=CASE/f'holes/front_{index:02d}.png'
        path.parent.mkdir(exist_ok=True)
        image=np.zeros_like(paint); image[hole]=255
        Image.fromarray(image).save(path)
        record={'name':f'RestHole{index:02d}','owner':owner,'file':str(path.relative_to(CASE)),
                'bone':next(p['bone'] for p in parts if p['name']==owner)}
        if owner=='robe' or owner.startswith('sleeve_'):
            vertices,uvs,triangles=grid([0,0,255,255])
            if owner=='robe':
                weights=robe_weights(vertices,next(m['bbox'] for m in meshes if m['name']==owner))
            else:
                side=owner.split('_')[-1]
                weights=sleeve_weights(vertices,*[joints[n+side]['position'] for n in ('upper_','fore_','hand_')],side)
            template=CASE/f'holes/{owner}_mesh.json'
            template.write_text(json.dumps({'vertices':vertices,'uvs':uvs,'triangles':triangles,
                'weights':weights,'z_index':0},separators=(',',':'))+'\n')
            record['mesh_template']=str(template.relative_to(CASE))
        rest_holes.append(record)
    layout['proof_rest_holes']=rest_holes
    layout['proof_joint_seams'] = build_masks(CASE, layout, visible)
    write_json(CASE / 'layouts/front.json', layout)
    projection = read_json(base / 'compiled_motion.json')['projection']['front']
    compiled = compile_motion(DIRECTOR, 'hoarfrost_seer', {'front': layout}, {'front': {
        'forward': projection['forward'], 'lean_sign': projection['parts']['torso']['lean_deg']}})
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'hoarfrost_seer', 'rig': 'humanoid_v2',
        'layouts': {'front': 'layouts/front.json'}, 'design_placeholders': {
        'TODO_DESIGN_mq6_rear_delivery_and_paint': 'Wait for both approved mq6 inputs before promotion.'},
        'clips': compiled['clips'], 'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd',
        'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    # Stage a production-shaped candidate. Existing production registration is
    # held until both approved views exist, avoiding a mixed v1/v2 Seer.
    ASSETS.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(CASE / 'compiled_motion.json', ASSETS / 'compiled_motion.json')
    copy_protected(DIRECTOR, ASSETS / 'director_motion.json')
    staged = dict(layout, motion_data='res://' + str(ASSETS.relative_to(PROJECT) / 'compiled_motion.json'))
    # Until promotion, paint stays in the authoring case. Raw candidate PNGs
    # inside a registered production family would bypass its density adoption.
    # The owning promotion step copies/adopts them after both views pass native.
    for part in staged['parts'] + staged['joint_meshes']:
        if not part['file'].startswith('res://'):
            part['file'] = 'res://' + str(CASE.relative_to(PROJECT) / part['file'])
    for record in layers.values():
        record['mask'] = 'res://' + str(CASE.relative_to(PROJECT) / record['mask'])
    staged['features'] = [dict(f,mask='res://' + str(CASE.relative_to(PROJECT) / f['mask'])) for f in staged['features']]
    staged['proof_rest_holes'] = []
    staged['proof_joint_seams'] = []
    staged['ownership_overrides'] = [dict(rope, file='res://' + str(CASE.relative_to(PROJECT) / rope['file']),
        underlay_required_mask='res://' + str(CASE.relative_to(PROJECT) / rope['underlay_required_mask']))]
    write_json(ASSETS / 'front.json', staged)
    write_json(CASE / 'proof/build.json', {'front_rest_mismatch_pixels': int(np.any(reconstructed != paint, axis=-1).sum()),
        'director_sha256': digest(DIRECTOR), 'tucks': tuck_report,
        'ownership_overrides': [dict(rope, previous_owners=previous_owners,
            underlay_pixels=int(rope_underlay.sum()))],
        'source_ownership': str(base.relative_to(PROJECT) / 'layouts/front.json'),
        'source_ownership_sha256': digest(base / 'layouts/front.json'),
        'hidden_fill_index_sha256': digest(base / 'hidden_fills/index.json'),
        'front_delivery_joints_sha256': digest(PROJECT / inputs['front_delivery'] / 'joints_px.json'),
        'front_delivery': bound_delivery,
        'production_promoted': False, 'rear': inputs['rear_status']})
    for root in (CASE,ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    print('RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)')
    print('RR10 TUCK COVERAGE: %d missing source pixels (see proof/build.json)' % sum(r['missing_pixels'] for r in tuck_report))
    return layout


if __name__ == '__main__':
    build()
