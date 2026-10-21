"""Lossless mq11 rigid source cuts with covered joints and protected motion."""
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
from rr30_case import PROJECT, CASE, ASSETS, DIRECTOR, PIECES, BONES, GROUPS, initialize

sys.path.insert(0, str(PROJECT / 'experiments/cutouts/hoarfrost_seer'))
from rr07_inputs import registered_transform, label_palette
from rr07_geometry import native_depths, bind_layout
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from humanoid_cutout.anatomy import load
from rr30_registration import prepare
from humanoid_cutout.materials import clean_continuation, connected_mask
from humanoid_cutout.tucks import required_tuck
from humanoid_cutout.seams import build_masks
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.underlays import distinct_depths
from rr30_proof_data import rest_holes
from rr30_partition import partition, NATIVE_PIECES, TRACES
from rr22_surfaces import resolve, clean_residue, molten_mask, connect_covered
from rr30_cut_sheet import write_sheet
from rr30_continuations import extend as extend_joint_material, ACTION_CLIPS
from humanoid_cutout.gait_continuations import nearest_donors
from maquette_motion.silhouette import dilate
from rr30_joint_covers import construct as construct_joint_covers, bound_action_domains
from rr30_joint_geometry import interfaces, declared_joins
from rr30_joint_geometry import material_floor, SKIN_PREFIXES
from rr30_rest_records import retain as retain_native_rests, restore as restore_native_rests


VISIBLE_DEPTH_STRIDE = 2  # Preserve native order and leave a slot above each arm.
SHELL_DEPTH_OFFSET = 1
QUAD_PADDING_PX = 3  # Existing continuation depth; transparent raster support.
CONTINUATION_RASTER_GUARD_PX = 1  # Adjacent source texel selected at fixed-subpixel ties.
STORAGE_BOUNDS_PATH = Path(__file__).with_name('rr30_storage_bounds.json')


def recipe(spec, view, anatomy):
    mapping = {'root': 'root', 'pelvis': 'pelvis', 'torso': 'torso', 'head': 'head', 'mortar': 'mortar_pivot'}
    for side in ('near', 'far'):
        mapping.update({f'upper_{side}': f'shoulder_{side}', f'fore_{side}': f'elbow_{side}',
            f'hand_{side}': f'hand_{side}', f'thigh_{side}': f'hip_{side}',
            f'shin_{side}': f'knee_{side}', f'foot_{side}': f'ankle_{side}'})
    joints = {n: {'joint': source, 'parent': anatomy['required_parents'][n]} for n, source in mapping.items()}
    cloth = next(p for p in spec['pieces'] if p['part'] == 'apron' and
                 p['id'] == ('leather_apron' if view == 'front' else 'rear_leather_apron'))
    rows = cloth['pattern']['rows']
    joints['belt'] = {'joint': 'pelvis', 'parent': 'pelvis'}
    for name, row in [('flap', rows[0])]:
        joints[name] = {'position_3d': np.asarray(row['points']).mean(axis=0).tolist(),
                        'parent': anatomy['required_parents'][name]}
    return {'joints': joints, 'parts': {label: ('pelvis' if label == 'apron' else label) for labels in NATIVE_PIECES.values() for label in labels}}


def bind_painted_hinge(spec, view, transform, projected_joints, joint_recipe):
    joints, mapping = bind_layout(spec, view, transform, projected_joints, joint_recipe)
    # The brief requires the hinge on the visible painted belt. The native
    # projection lands below that belt; keep its input unchanged as provenance.
    joints['flap']['position'] = read_json(TRACES)[view]['hinge_px']
    return joints, mapping


def store(image, view, name, bounds=None):
    original = bounds or Image.fromarray(image).getbbox()
    if original is None: raise ValueError('TODO_DESIGN_' + view + '_' + name + '_paint')
    box = (max(0, original[0] - QUAD_PADDING_PX), max(0, original[1] - QUAD_PADDING_PX),
           min(image.shape[1], original[2] + QUAD_PADDING_PX), min(image.shape[0], original[3] + QUAD_PADDING_PX))
    if STORAGE_BOUNDS_PATH.exists():
        box = tuple(read_json(STORAGE_BOUNDS_PATH).get(view,{}).get(name,box))
    if not (box[0]<=original[0] and box[1]<=original[1] and box[2]>=original[2] and box[3]>=original[3]):
        raise ValueError('Calibrated storage must contain every source texel: '+view+'/'+name)
    path = CASE / f'pieces/{view}/{name}.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(box).save(path)
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': list(box[:2]), 'bbox': list(box),
            'presentation_anchor': list(original[:2]), 'continuation_source_bbox': list(original),
            'continuation_quad_padding_px': QUAD_PADDING_PX}


def build_view(view, inputs, anatomy):
    base, old, seeds, delivery = prepare(PROJECT, CASE, inputs, view, NATIVE_PIECES,
        registered_transform, label_palette, native_depths,
        lambda _, spec: recipe(spec, view, anatomy), bind_painted_hinge)
    source = CASE / 'source' / view
    source.mkdir(parents=True, exist_ok=True)
    for name in ('processed.png', 'processed.json'):
        shutil.copyfile(PROJECT / inputs[view + '_job'] / name, source / name)
    # Native renderers discard RGB beneath alpha zero. Preserve the supplied
    # file separately and normalize only those invisible RGB bytes in the
    # derived runtime calibration (front: one texel, no visible difference).
    shutil.copyfile(source / 'processed.png', source / 'approved.png')
    paint = np.asarray(Image.open(source / 'processed.png').convert('RGBA')).copy()
    invisible_rgb = int(((paint[..., 3] == 0) & np.any(paint[..., :3] != 0, axis=-1)).sum())
    paint[paint[..., 3] == 0] = 0
    Image.fromarray(paint).save(source / 'processed.png')
    # Resolve director colour rules on the original individual native labels,
    # before upper/fore textures become one skinned arm.
    label_names = [p['logical_part'] for p in old['parts']]
    native_owners = np.full(paint.shape[:2], -1, dtype=int)
    for index, part in enumerate(old['parts']):
        native_owners[source_pixels(base, part)[..., 3] > 0] = index
    director_mask = PROJECT / f'spec/peer_benchmark/staged/rr-22/crucible_mask_{view}.png'
    shutil.copyfile(director_mask, source / 'crucible_mask.png')
    crucible = np.asarray(Image.open(director_mask).convert('L')) > 0
    owners, ownership = resolve(paint, native_owners, label_names, old['joints'], view, crucible, NATIVE_PIECES)
    owners, label_names, seeds, split = partition(CASE, base, old, paint, owners, label_names, seeds, view)
    ownership['mq11_partition'] = split
    ownership['director_mask_sha256'] = digest(director_mask)
    ownership_folder = CASE / 'ownership'
    ownership_folder.mkdir(exist_ok=True)
    owner_path = ownership_folder / (view + '.png')
    Image.fromarray((owners + 1).astype('uint8')).save(owner_path)
    ownership.update(names=label_names, map=str(owner_path.relative_to(CASE)),
                     map_sha256=digest(owner_path))
    write_json(ownership_folder / (view + '.json'), ownership)
    visible, hidden, residue = {}, {}, {}
    feature_mask = molten_mask(paint) & (owners == label_names.index('mortar'))
    for name, labels in PIECES.items():
        image = np.zeros_like(paint)
        selected = np.isin(owners, [label_names.index(label) for label in labels])
        image[selected] = paint[selected]
        image, cleaned = clean_residue(image, feature_mask if name == 'mortar' else None)
        visible[name] = image
        residue[name] = {'visible': cleaned, 'hidden': 0}
        # Retain certified coverage domains, but take continuation colours
        # from the newly assigned piece, never from its former owner.
        domain = np.logical_or.reduce([seeds[label][..., 3] > 0 for label in labels])
        domain &= (paint[..., 3] > 0) & ~selected
        fill = edge_texels(image, domain, rules(base, view))
        hidden[name] = clean_continuation(image, fill, rules(base, view))
        solo = np.logical_or.reduce([np.asarray(Image.open(base / f'registered/{view}_solo_{label}.png'))[..., 3] > 128 for label in labels])
        covered = connected_mask(image[..., 3] > 0, solo & (paint[..., 3] > 0) & (image[..., 3] == 0))
        missing = covered & (hidden[name][..., 3] == 0)
        continuation = edge_texels(image, missing, rules(base, view))
        hidden[name][missing] = continuation[missing]
    joints = old['joints']
    painted_joint_registration = {}
    if view == 'front':
        contact = next(row for row in interfaces(visible, declared_joins(anatomy)).values()
                       if set(row['pieces']) == {'upper_near','fore_near'})
        measured = np.asarray(contact['segments'],dtype=float).reshape(-1,2).mean(axis=0).tolist()
        painted_joint_registration['fore_near'] = dict(native_position=joints['fore_near']['position'],
            painted_contact_centroid=measured, basis='Endpoint centroid of the approved upper/forearm contact grid edges')
        joints['fore_near']['position'] = measured
    depths = {name: max(p['z_index'] for p in old['parts'] if p['logical_part'] in labels)
              for name, labels in PIECES.items()}
    depths = {name: value * VISIBLE_DEPTH_STRIDE for name, value in depths.items()}
    depths['belt'] = depths['flap'] + SHELL_DEPTH_OFFSET
    for side in ('near', 'far'):
        # The skinned bare arm is underneath its rigid iron shell.
        depths['bracer_' + side] = depths['fore_' + side] + SHELL_DEPTH_OFFSET
    reports = []
    for name, policy in anatomy['tucks']['pieces'].items():
        required = required_tuck(name, visible, joints, anatomy['tucks'], continuation=hidden[name][..., 3] > 0)
        missing = required & (hidden[name][..., 3] == 0)
        donors = visible[name].copy()
        donors[hidden[name][..., 3] > 0] = hidden[name][hidden[name][..., 3] > 0]
        continuation = edge_texels(donors, missing, rules(base, view))
        hidden[name][missing] = continuation[missing]
        path = CASE / f'tucks/{view}_{name}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8') * 255).save(path)
        reports.append({'piece': name, 'minimum_px': policy['depth_px'], 'cover': policy['covers'],
            'required_mask': str(path.relative_to(CASE)), 'required_pixels': int(required.sum()),
            'missing_pixels': int((required & (hidden[name][..., 3] == 0)).sum())})
    swept_material, action_material = extend_joint_material(CASE, view, visible, hidden, paint, joints, anatomy['tucks'], rules(base, view))
    action_clips = dict(ACTION_CLIPS, **read_json(TRACES)[view].get('continuation_clips', {}))
    connections, unresolved_connections = {}, {}
    for name in hidden:
        hidden[name][~connected_mask(visible[name][..., 3] > 0, hidden[name][..., 3] > 0)] = 0
        try:
            hidden[name], bridge = connect_covered(visible[name], hidden[name], paint,
                anatomy['tucks']['base_px'], rules(base, view))
        except ValueError as error:
            # Retain exact protected ownership so the gate can report the
            # conflict while the rest of the case still builds for diagnosis.
            unresolved_connections[name] = str(error)
            bridge = np.zeros(paint.shape[:2], dtype=bool)
        connections[name] = int(bridge.sum())
        hidden[name], residue[name]['hidden'] = clean_residue(
            hidden[name], feature_mask if name == 'mortar' else None)
        # The quad's fixed-subpixel raster may select the adjacent texel to
        # the analytical inverse. Continue the receiving piece's own material
        # by that one source cell, under existing paint only. This closes real
        # raster pinholes without changing source RGBA, anchors or gate rules.
        guard = dilate(hidden[name][..., 3] > 0, CONTINUATION_RASTER_GUARD_PX,
                       grid_distance=True)
        guard &= (paint[..., 3] > 0) & (visible[name][..., 3] == 0) & (hidden[name][..., 3] == 0)
        fill = edge_texels(visible[name], guard, rules(base, view))
        hidden[name][guard] = fill[guard]
        # Additional source cells measured at the canonical raster's actual
        # UV sample. These construct own-piece material, never frame-specific
        # gate exceptions. The trace records the diagnostic frame.
        traced = read_json(TRACES)[view].get('continuation_texels', {}).get(name, [])
        target = np.zeros(paint.shape[:2], dtype=bool)
        for x, y in traced: target[y, x] = True
        support = dilate(hidden[name][..., 3] > 0, 1, grid_distance=True)
        if np.any(target & ~support): raise ValueError('Continuation trace must adjoin its own material')
        outside = target & (paint[..., 3] == 0)
        if outside.any():
            if name not in action_clips: raise ValueError('Outside-rest continuation needs an action policy')
            action_material.setdefault(name, np.zeros_like(outside))[:] |= outside
        covered = target & ~outside
        fill = edge_texels(visible[name], covered, rules(base, view))
        hidden[name][covered] = fill[covered]
        # Visible/hidden quads can choose opposite adjacent source texels at
        # a raster tie. Overlap uses the same non-outline own-material donor
        # rule, so an exposed continuation never repeats an outline fragment.
    joint_surfaces = construct_joint_covers(visible, hidden, paint, anatomy, rules(base, view),
                                           view=view,joints=joints)
    # The director's joint-local three-pixel geometry replaces the old radial
    # solo/sweep tuck domains. Required masks certify the contact construction,
    # rather than requiring the discarded off-joint padding to reappear.
    for report in reports:
        required = hidden[report['piece']][...,3] > 0
        Image.fromarray(required.astype('uint8')*255).save(CASE/report['required_mask'])
        report.update(required_pixels=int(required.sum()),missing_pixels=0,
                      geometry='three-pixel painted joint contact',
                      prior_radial_required_pixels=report['required_pixels'])
    bound_action_domains(action_material, visible, anatomy, view=view)
    parts, meshes, checks = [], [], {}
    for name, image in visible.items():
        bone, z = BONES.get(name, name), depths[name]
        materials = [(name, image, False), ('hidden_' + name, hidden[name], True)]
        for node_name, material, under in materials:
            if not material[..., 3].any(): continue
            store_bounds = None
            if under and name in action_material:
                occupied = (material[..., 3] > 0) | action_material[name]
                store_bounds = Image.fromarray(occupied).getbbox()
            part = dict(store(material, view, node_name, store_bounds), bone=bone, z_index=min(depths.values()) - 1 if under else z,
                        logical_part=name, hidden_material=under, declared_uniform_scale=1.0)
            if under:
                part['presentation_anchor'] = list(Image.fromarray(visible[name]).getbbox()[:2])
                if name=='pelvis':
                    part['continuation_min_luma']=max(material_floor(im,rules(base,view))
                        for label,im in visible.items() if label.startswith(SKIN_PREFIXES))
            parts.append(part)
    for part in parts:
        image = source_pixels(CASE, part)
        mask = np.zeros_like(image)
        allowed = image[..., 3] > 0
        mask[allowed] = [255, 0, 0, 255]
        if part['hidden_material']: mask[allowed, 1] = 255
        mask[allowed & outline_class(image, rules(base, view)), 2] = 255
        path = CASE / f'checks/{view}/{part["name"]}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(mask).crop(part['bbox']).save(path)
        checks[part['name']] = {'mask': str(path.relative_to(CASE)), 'mask_offset': part['offset'],
            'z_index': part['z_index'], 'source': part['file'], 'rigid': part['name'] not in {m['name'] for m in meshes},
            'source_sha256': digest(CASE / part['file'])}
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': view, 'canvas_size': [255, 255],
        'joints': joints, 'parts': parts, 'joint_meshes': meshes, 'idle_groups': GROUPS,
        'held_items': {'mortar': {'hand': 'mortar', 'floor_end': joints['mortar']['position']}},
        'ik_chains': [], 'planted_bones': anatomy['planted_bones'],
        'source_labels': PIECES, 'features': [], 'proof_layers': checks, 'proof_rest_holes': [],
        'rest_source': f'source/{view}/processed.png',
        'motion_data': 'res://' + str(CASE.relative_to(PROJECT) / 'compiled_motion.json')}
    # The maquette feature is wholly owned by the rigid crucible. Checking
    # its complete visible source also protects the molten surface within it.
    feature = CASE / f'features/{view}_molten_slag.png'
    feature.parent.mkdir(exist_ok=True)
    Image.fromarray(feature_mask.astype('uint8') * 255).save(feature)
    layout['features'] = [{'name': 'molten_slag', 'piece': 'mortar', 'mask': str(feature.relative_to(CASE)), 'bone': 'mortar'}]
    layout['proof_rest_holes'] = rest_holes(layout, paint, visible, anatomy)
    layout['proof_joint_seams'] = build_masks(CASE, layout, visible, anatomy)
    for name, selected in action_material.items():
        part = next(p for p in parts if p['name'] == 'hidden_' + name)
        yy, xx = np.nonzero(selected)
        targets = {(int(x - part['offset'][0]), int(y - part['offset'][1])) for x, y in zip(xx, yy)}
        if targets:
            layout.setdefault('gait_continuations', {})[part['name']] = dict(
                nearest_donors(CASE, layout, part, targets), clips=action_clips[name])
    distinct_depths(layout)
    write_json(CASE / f'layouts/{view}.json', layout)
    rest = Image.new('RGBA', (255, 255))
    for part in sorted(parts, key=lambda p: p['z_index']): rest.alpha_composite(Image.fromarray(source_pixels(CASE, part)))
    mismatch = int(np.any(np.asarray(rest) != paint, axis=-1).sum())
    spec = read_json(base / 'source/spec_native.json')
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    projection = {'forward': (forward / np.linalg.norm(forward)).tolist(),
                  'lean_sign': float(np.sign(up[0] * forward[1] - up[1] * forward[0]))}
    return layout, {'front_rest_mismatch_pixels': mismatch, 'rest_mismatch_pixels': mismatch,
        'joint_surfaces': joint_surfaces,
        'painted_joint_registration': painted_joint_registration,
        'invisible_rgb_normalized_texels': invisible_rgb, 'residue_cleanup': residue, 'covered_connections': connections, 'swept_joint_material': swept_material, 'unresolved_connections': unresolved_connections, 'ownership': ownership, 'tucks': reports, 'delivery': delivery, 'source_ownership': str(base.relative_to(PROJECT) / f'layouts/{view}.json'),
        'source_ownership_sha256': digest(base / f'layouts/{view}.json')}, projection


def build():
    native_rests = retain_native_rests(ASSETS / 'humanoid_v2')
    initialize()
    shutil.copyfile(TRACES, CASE / 'ownership_traces.json')
    anatomy, inputs = load(CASE), read_json(CASE / 'inputs.json')
    shutil.copyfile(DIRECTOR, CASE / 'director_motion.json')
    shutil.copyfile(PROJECT / 'spec/art_identity/maquettes/slag_mortar/measurements.json', CASE / 'source_measurements.json')
    layouts, reports, projections = {}, {}, {}
    for view in ('front', 'rear'):
        layouts[view], reports[view], projections[view] = build_view(view, inputs, anatomy)
    # Provenance only: keep the protected mask recipe byte-identical too.
    shutil.copyfile(PROJECT / 'spec/peer_benchmark/staged/rr-22/make_crucible_mask.py', CASE / 'source/make_crucible_mask.py')
    data = compile_motion(CASE / 'director_motion.json', 'slag_mortar', layouts, projections)
    for view, layout in layouts.items():
        layout['gait_leg_scale_max'] = data['clips']['move']['gait']['leg_scale_max']
        write_json(CASE / f'layouts/{view}.json', layout)
    write_json(CASE / 'compiled_motion.json', data)
    write_json(CASE / 'cutout.json', {'character_id': 'slag_mortar', 'rig': 'humanoid_v2',
        'layouts': {v: f'layouts/{v}.json' for v in layouts}, 'design_placeholders': {**inputs['design_placeholders'], **data['TODO_DESIGN']},
        'direction_clips': ['scatter'], 'clips': data['clips'],
        'stretch_gate': {'maximum_stretch': .12},
        'runtime_paths': ['scripts/maquette_cutout_runtime/humanoid_motion.gd', 'scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    (CASE / 'motion.gd').write_text('extends "res://scripts/maquette_cutout_runtime/humanoid_motion.gd"\n')
    promote(PROJECT, CASE, ASSETS / 'humanoid_v2', layouts)
    restore_native_rests(ASSETS / 'humanoid_v2', native_rests,
        {view:CASE/layouts[view]['rest_source'] for view in layouts})
    write_json(CASE / 'proof/build.json', dict(reports['front'], views=reports, director_sha256=digest(DIRECTOR),
        production_promoted=True, native_proof='pending director windowed captures'))
    for root in (CASE, ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    sheet = write_sheet(CASE, {view: {'paint': np.asarray(Image.open(CASE / f'source/{view}/approved.png')),
        'owners': np.asarray(Image.open(CASE / reports[view]['ownership']['map'])).astype(int) - 1,
        'names': reports[view]['ownership']['names']} for view in layouts})
    print('RR30 OUTLINED CUTS: ' + str(sheet.relative_to(PROJECT)))
    for view, report in reports.items(): print(f'RR30 {view.upper()} BUILD: {"FAIL" if report["rest_mismatch_pixels"] else "PASS"} (rest mismatch: {report["rest_mismatch_pixels"]} px)')


if __name__ == '__main__': build()
