"""Both approved v2 views, with frozen front ownership and a native mq-06 rear."""
from pathlib import Path
import shutil
import sys
import json

import numpy as np
from PIL import Image, ImageFilter

from rr07_inputs import PROJECT, read_json, write_json, digest, projected, registered_transform, label_palette
from rr07_geometry import native_depths, recipe_for, bind_layout
from tools.humanoid_cutout.source_view import prepare
from tools.humanoid_cutout.skin_layers import layer as skin_layer
from maquette_motion.features import source_pixels
from maquette_motion.support_seeds import approved
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes
from tools.humanoid_cutout.compiler import compile_motion
from tools.humanoid_cutout.mesh import grid, weights_for
from tools.humanoid_cutout.anatomy import load as load_anatomy
from tools.humanoid_cutout.materials import connected_mask, clean_continuation, held_depths
from tools.humanoid_cutout.seams import build_masks
from tools.humanoid_cutout.ownership import read_mask, apply_override
from tools.humanoid_cutout.occluded_surface import bind as bind_occluded, derive as derive_occluded
from tools.humanoid_cutout.tucks import required_tuck
from tools.humanoid_cutout.covered_surfaces import sleeve_domains, hem_domain
from tools.humanoid_cutout.joint_continuations import domains as joint_domains

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
ANATOMY = load_anatomy(CASE)
TUCKS = ANATOMY['tucks']
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


def store(image, folder, name, empty_bounds=None):
    ys, xs = np.nonzero(image[..., 3])
    if len(xs):
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    elif empty_bounds is not None:
        bounds = empty_bounds
    else:
        raise ValueError('Empty piece without a registered crop: ' + name)
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(tuple(bounds)).save(path)
    Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': bounds[:2], 'bbox': bounds}


def underlay_depth(old, labels, depths):
    inherited = [p['z_index'] for p in old['parts'] if p.get('hidden_material') and p.get('logical_part') in labels]
    return max(inherited) if inherited else min(depths.values()) - 1


def build_view(view, inputs):
    seed_fills = None
    if view == 'front':
        base = PROJECT / inputs['baseline']
        old = read_json(base / 'layouts/front.json')
        delivery = PROJECT / inputs['front_delivery']
        bound_delivery = {}
        for name in ['joints_px.json', 'front_parts.png'] + ['front_solo_' + n + '.png' for labels in PIECES.values() for n in labels]:
            # mq-06 intentionally replaced only the rear half of this shared file.
            same = (read_json(delivery / name)['front'] == read_json(base / 'source/maquette' / name)['front']
                    if name == 'joints_px.json' else digest(delivery / name) == digest(base / 'source/maquette' / name))
            if not same:
                raise ValueError('Front delivery differs from rr-07 ownership registration: ' + name)
            bound_delivery[name] = digest(delivery / name)
        if digest(PROJECT / inputs['front_job'] / 'processed.png') != digest(base / 'source/front/processed.png'):
            raise ValueError('rr-07 ownership no longer belongs to the approved front')
    else:
        base, old, seed_fills, bound_delivery = prepare(PROJECT, CASE, inputs, view, PIECES,
            registered_transform, label_palette, native_depths, recipe_for, bind_layout)
    paint_path = PROJECT / inputs[view + '_job'] / 'processed.png'
    paint = np.asarray(Image.open(paint_path).convert('RGBA'))
    (CASE / ('source/' + view)).mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(PROJECT / inputs[view + '_job'] / name, CASE / 'source' / view / name)
    visible, hidden, solos = {}, {}, {}
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
            if seed_fills is not None:
                layer = seed_fills[label]
                fill[layer[..., 3] > 0] = layer[layer[..., 3] > 0]
            elif part:
                layer = approved(base, view, part)
                fill[layer[..., 3] > 0] = layer[layer[..., 3] > 0]
        # Continuations are hidden at rest, within the approved union silhouette.
        native_silhouette = np.zeros(paint.shape[:2],dtype=bool)
        for label in labels:
            native_silhouette |= np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png').convert('RGBA'))[...,3] > 128
        solos[name] = native_silhouette
        fill[(paint[..., 3] == 0) | (image[..., 3] > 0) | ~native_silhouette] = 0
        hidden[name] = fill
    rope = dict(inputs['rope_masks'][view])
    rope_mask = read_mask(CASE, rope, paint.shape[:2])
    underlay = rope['underlay']
    # Preserve the exact former robe ownership as the required cloth surface
    # behind the now rigid rope tails. No colour selector or mask dilation.
    rope_underlay = rope_mask & (visible[underlay][..., 3] > 0)
    previous_owners = apply_override(visible, paint, rope_mask, rope['owner'])
    material_rules = rules(base, view)
    cloth = edge_texels(visible[underlay], rope_underlay, material_rules)
    hidden[underlay][rope_underlay] = cloth[rope_underlay]
    required_path = CASE / f'ownership/{view}_rope_underlay.png'
    required_path.parent.mkdir(exist_ok=True)
    Image.fromarray(rope_underlay.astype('uint8') * 255).save(required_path)
    rope['underlay_required_mask'] = str(required_path.relative_to(CASE))
    for name in PIECES:
        # Maquette clipping split old hidden seeds into unsupported fragments.
        hidden[name][visible[name][..., 3] > 0] = 0
        hidden[name] = clean_continuation(visible[name], hidden[name], material_rules,
                                         replace_all=name == 'robe')
    occluded, donor_records = {}, []
    for name, recipe in inputs.get('occluded_donors', {}).get(view, {}).items():
        if (visible[name][..., 3] > 0).any():
            raise ValueError('Occluded donor may not replace visible ownership: ' + name)
        record = bind_occluded(CASE, base, old, view, name, recipe)
        occluded[name], record['derivation'] = derive_occluded(CASE, record, paint)
        hidden[name] = occluded[name].copy()
        donor_records.append(record)
    surfaces = dict(visible, **occluded)
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
    near_right = joints['foot_near']['position'][0] > joints['foot_far']['position'][0]
    ends = (int(robe_xs.max()) + 1, int(robe_xs.min())) if near_right else (int(robe_xs.min()), int(robe_xs.max()) + 1)
    for side, x in zip(('near', 'far'), ends):
        joints['hem_' + side] = {'position': [x, floor], 'parent': 'root'}
    joint('staff', 'hand_far', 'hand_far')
    depths = {p['logical_part']: p['z_index'] for p in old['parts'] if not any(
        p.get(k) for k in ('hidden_material', 'seam_underlay', 'silhouette_backing'))}
    depths = held_depths({name: depths[DEPTH_SOURCE.get(name, name)] for name in PIECES},
                         view, ANATOMY['held_depth_roles'])
    parts, meshes, tuck_report = [], [], []
    tuck_masks = {}
    # rr-05 same-material continuation at the director's per-edge depths.
    # Approved visible paint and protected source inputs remain unchanged.
    for name, tuck_recipe in TUCKS['pieces'].items():
        cover = tuck_recipe['covers']
        own = surfaces[name][..., 3] > 0
        occlusion = None
        if name.startswith(('hand_', 'foot_')) or name == 'robe':
            # A wrist edge can be hidden by the staff as well as the cuff;
            # clipping to the cuff alone cuts away the needed continuation.
            # Keep every extra texel hidden behind an inherited higher layer.
            under_depth = depths[name] if name == 'robe' else underlay_depth(old, PIECES[name], depths)
            occlusion = np.logical_or.reduce([material[...,3]>0 for other,material in visible.items()
                if depths[other] > under_depth and other != name])
        tuck_surfaces = surfaces if name in occluded else visible
        required = required_tuck(name, tuck_surfaces, joints, TUCKS, occlusion, hidden[name][...,3]>0)
        missing = required & (hidden[name][..., 3] == 0)
        tuck_masks[name] = required
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, rules(base, view))
        hidden[name][missing] = continuation[missing]
    # rr-13: continue the actual surfaces beneath the entire sleeve and boot
    # footprints, rather than growing only the currently visible cut edge.
    covered = sleeve_domains(visible, solos, ANATOMY['covered_surfaces'])
    covered['hem'] = hem_domain(surfaces, solos['robe'], ANATOMY['covered_surfaces'])
    for domain, required in covered.items():
        name = 'robe' if domain == 'hem' else domain
        missing = required & (hidden[name][..., 3] == 0)
        continuation = edge_texels(visible[name], missing, material_rules)
        hidden[name][missing] = continuation[missing]
        tuck_masks[name] |= required
        path = CASE / f'continuations/{view}_{domain}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
    # Feedback 3: the staff shoulder, rear armpit, waist and head/near-shoulder
    # joins need another existing minimum tuck beneath their rest covers.
    for name, required in joint_domains(visible, hidden,
            read_json(CASE / 'joint_continuations.json').get(view, {}), **ANATOMY['joint_continuations']).items():
        missing = required & (hidden[name][..., 3] == 0)
        continuation = edge_texels(visible[name], missing, material_rules)
        hidden[name][missing] = continuation[missing]
        tuck_masks[name] |= required
        path = CASE / f'continuations/{view}_joint_{name}.png'
        Image.fromarray(required.astype('uint8') * 255).save(path)
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
            part = store(combined, CASE / 'pieces' / view, name)
            meshes.append(skin_layer(part, name, part['bbox'], joints, z, recipe=ANATOMY['meshes'][name]))
            # A hidden hem continuation underneath a boot cannot share the
            # visible robe's depth. It uses the SAME garment weight field in
            # a covered draw layer, just as rigid rr-05 underlays do.
            lower = fill.copy()
            lower[allowed] = 0
            if (lower[..., 3] > 0).any():
                underlay = store(lower, CASE / 'pieces' / view, 'hidden_' + name)
                hidden_depth = underlay_depth(old, PIECES[name], depths)
                meshes.append(skin_layer(underlay, name, part['bbox'], joints, hidden_depth, True, recipe=ANATOMY['meshes'][name]))
                parts.append(dict(underlay, bone=bone, z_index=hidden_depth, hidden_material=True, logical_part=name))
        else:
            empty_bounds = next((p['bbox'] for p in old['parts'] if p.get('logical_part') == name), None)
            part = store(image, CASE / 'pieces' / view, name, empty_bounds)
            if (fill[..., 3] > 0).any():
                underlay = store(fill, CASE / 'pieces' / view, 'hidden_' + name)
                hidden_depth = underlay_depth(old, PIECES[name], depths)
                if name == 'staff': hidden_depth = z - 1
                parts.append(dict(underlay, bone=bone, z_index=hidden_depth, hidden_material=True,
                                  logical_part=name, presentation_anchor=part['offset']))
                if name in occluded: parts[-1]['occluded_surface'] = True
        parts.append(dict(part, bone=bone, z_index=z, logical_part=name))
    for name, tuck_recipe in TUCKS['pieces'].items():
        cover = tuck_recipe['covers']
        own = visible[name][..., 3] > 0
        required = tuck_masks[name]
        provided = hidden[name][..., 3] > 0
        missing = required & ~provided
        mask_path = CASE / f'tucks/{view}_{name}.png'
        mask_path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(mask_path)
        if not own.any() and not provided.any(): continue  # Explicit fully occluded source placeholder.
        tuck_report.append({'piece': name, 'cover': cover, 'minimum_px': tuck_recipe['depth_px'],
                            'required_mask': str(mask_path.relative_to(CASE)),
                            'missing_pixels': int(missing.sum()), 'required_pixels': int(required.sum())})
    shaft = next(p for p in read_json(base / 'source/spec_native.json')['pieces'] if p['id'] == 'staff_shaft')
    transform = read_json(base / f'registered/{view}_registration.json')
    native = projected(read_json(base / 'source/spec_native.json'), shaft['path'][0], view)
    floor_end = (np.asarray(native) * transform['scale'] + transform['offset']).tolist()
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
              'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
              'held_items': {'staff': {'hand': 'hand_far', 'floor_end': floor_end}},
              'held_item_depth': inputs['held_item_depth'],
              'continuation_policy': {'robe': 'rr05_visible_cloth_edge_texels'},
              'source_labels': PIECES, 'ownership_overrides': [rope],
              'covered_surface_masks': {name: f'continuations/{view}_{name}.png' for name in covered},
              'rest_source': 'source/' + view + '/processed.png', 'motion_data': 'res://' +
              str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    if donor_records: layout['occluded_surfaces'] = donor_records
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
        if piece in occluded: tuck &= occluded[piece][..., 3] == 0
        if not part.get('hidden_material') and name not in mesh_names:
            tuck[:] = False  # Rigid tucks live in their hidden underlay.
        checks[tuck, 1] = 255
        dark = allowed & outline_class(stored, material_rules)
        checks[dark, 2] = 255
        mask = store(checks, CASE / 'checks' / view, name, part['bbox'])
        layers[name] = {'mask': mask['file'], 'mask_offset': mask['offset'],
                        'z_index': part['z_index'], 'source': part['file'],
                        'rigid': name not in mesh_names,
                        'source_sha256': digest(CASE / part['file'])}
    layout['proof_layers'] = layers
    (CASE / 'features').mkdir(exist_ok=True)
    feature_path = CASE / f'features/{view}_ice_crystal.png'
    if view == 'front':
        shutil.copyfile(base / 'features/front_ice_crystal.png', feature_path)
    else:
        crystal = next(p for p in old['parts'] if p['logical_part'] == 'staff_crystal')
        Image.fromarray((source_pixels(base, crystal)[..., 3] > 0).astype('uint8') * 255).save(feature_path)
    layout['features'] = [{'name': 'ice_crystal', 'piece': 'staff', 'mask': str(feature_path.relative_to(CASE))}]
    rest_holes = []
    for index,hole in enumerate(holes(paint[...,3]>0)):
        if int(hole.sum())<=1: continue
        rim=dilate(hole,1)&~hole
        owner=max(PIECES,key=lambda name:int((rim & (visible[name][...,3]>0)).sum()))
        path=CASE/f'holes/{view}_{index:02d}.png'
        path.parent.mkdir(exist_ok=True)
        image=np.zeros_like(paint); image[hole]=255
        Image.fromarray(image).save(path)
        record={'name':f'RestHole{index:02d}','owner':owner,'file':str(path.relative_to(CASE)),
                'bone':next(p['bone'] for p in parts if p['name']==owner)}
        if owner=='robe' or owner.startswith('sleeve_'):
            vertices,uvs,triangles=grid([0,0,255,255])
            weights=weights_for(vertices,next(m['bbox'] for m in meshes if m['name']==owner),joints,ANATOMY['meshes'][owner])
            template=CASE/f'holes/{view}_{owner}_mesh.json'
            template.write_text(json.dumps({'vertices':vertices,'uvs':uvs,'triangles':triangles,
                'weights':weights,'z_index':0},separators=(',',':'))+'\n')
            record['mesh_template']=str(template.relative_to(CASE))
        rest_holes.append(record)
    layout['proof_rest_holes']=rest_holes
    layout['proof_joint_seams'] = build_masks(CASE, layout, surfaces, ANATOMY)
    write_json(CASE / f'layouts/{view}.json', layout)
    report = {'front_rest_mismatch_pixels': int(np.any(reconstructed != paint, axis=-1).sum()),
        'rest_mismatch_pixels': int(np.any(reconstructed != paint, axis=-1).sum()),
        'tucks': tuck_report, 'ownership_overrides': [dict(rope, previous_owners=previous_owners,
            underlay_pixels=int(rope_underlay.sum()))],
        'source_ownership': str(base.relative_to(PROJECT) / f'layouts/{view}.json'),
        'source_ownership_sha256': digest(base / f'layouts/{view}.json'), 'delivery': bound_delivery}
    if view == 'front':
        projection = read_json(base / 'compiled_motion.json')['projection'][view]
        projection = {'forward': projection['forward'], 'lean_sign': projection['parts']['torso']['lean_deg']}
    else:
        spec = read_json(base / 'source/spec_native.json')
        origin = np.asarray(projected(spec, [0, 0, 0], view))
        up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
        forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
        projection = {'forward': (forward / np.linalg.norm(forward)).tolist(),
                      'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    return layout, report, projection


def build():
    inputs = read_json(CASE / 'inputs.json')
    copy_protected(DIRECTOR, CASE / 'director_motion.json')
    layouts, reports, projections = {}, {}, {}
    for view in ('front', 'rear'):
        layouts[view], reports[view], projections[view] = build_view(view, inputs)
        from rr26_underlaps import apply as edge_underlaps
        layouts[view] = edge_underlaps(layouts[view])
        write_json(CASE / f'layouts/{view}.json', layouts[view])
    compiled = compile_motion(DIRECTOR, 'hoarfrost_seer', layouts, projections)
    write_json(CASE / 'compiled_motion.json', compiled)
    write_json(CASE / 'cutout.json', {'character_id': 'hoarfrost_seer', 'rig': 'humanoid_v2',
        'layouts': {v: f'layouts/{v}.json' for v in layouts}, 'design_placeholders': inputs.get('design_placeholders', {}),
        'clips': compiled['clips'], 'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd',
        'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    # Native rest recording remains an explicit director step after promotion.
    from tools.humanoid_cutout.promotion import promote
    promote(PROJECT, CASE, ASSETS, layouts)
    report = dict(reports['front'], views=reports, director_sha256=digest(DIRECTOR), production_promoted=True,
        front_delivery=reports['front']['delivery'],
        front_delivery_joints_sha256=reports['front']['delivery']['joints_px.json'],
        hidden_fill_index_sha256=digest(PROJECT / inputs['baseline'] / 'hidden_fills/index.json'), rear='ready',
        rr13_design_placeholders={})
    write_json(CASE / 'proof/build.json', report)
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    for view in layouts:
        print('RR10 %s BUILD: PASS (rest mismatch: %d px; 3 joint_meshes; protected tracks byte-identical)' %
              (view.upper(), reports[view]['rest_mismatch_pixels']))
    print('RR10 TUCK COVERAGE: %d missing source pixels (both views; see proof/build.json)' %
          sum(r['missing_pixels'] for report in reports.values() for r in report['tucks']))
    return layouts


if __name__ == '__main__':
    build()
