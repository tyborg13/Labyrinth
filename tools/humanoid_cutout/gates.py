"""v2 structural, signed-bone and native-pixel gates (no CPU skin oracle)."""
import math
from pathlib import Path

import numpy as np
from PIL import Image

from cutout_pipeline.cases import read_json, write_json, digest
from .gait import evaluate
from .silhouette_gates import detached_metrics, joint_holes, posed_owners
from .anatomy import for_layout, load

EPSILON = 0.0001  # Serialized Bone2D float tolerance, not animation tuning.
FAILURE_CROP_ZOOM = 3


def matrix(values):
    a, b, c, d, x, y = values
    return np.array([[a, c, x], [b, d, y], [0., 0., 1.]])


def angle(values):
    return math.degrees(math.atan2(values[1], values[0]))


def relative_angle(a, b):
    return (angle(a) - angle(b) + 180) % 360 - 180


def view_build(layout, build):
    return build['views'][layout['facing']] if layout['facing'] != 'front' and 'views' in build else build


def structure_errors(layout, build):
    anatomy = for_layout(layout)
    build = view_build(layout, build)
    errors = []
    required = anatomy['required_parents']
    for name, parent in required.items():
        if layout['joints'].get(name, {}).get('parent', 'missing') != parent:
            errors.append('hierarchy: ' + name)
    from .bone_contracts import visible_leg, leg_bend_side
    for side in ('near', 'far'):
        if visible_leg(layout['joints'], side):
            try:
                leg_bend_side(layout, anatomy, side, layout['facing'])
            except ValueError as error:
                errors.append(str(error))
    meshes = {m['name']: m for m in layout.get('joint_meshes', []) if not m.get('hidden_material')}
    if set(meshes) != set(anatomy['meshes']):
        errors.append('cut: required meshes differ: ' + ', '.join(anatomy['meshes']))
    if any(n in layout['joints'] for n in anatomy['forbidden_joints']):
        errors.append('cut: independently moving fused piece')
    if set(layout.get('idle_groups', {})) != set(anatomy['idle_groups']):
        errors.append('idle: exactly three groups required')
    for mesh in layout.get('joint_meshes', []):
        weights = np.asarray(list(mesh['weights'].values()))
        if mesh.get('grid_px') != 2 or not np.isfinite(weights).all() or weights.min() < 0 or not np.allclose(weights.sum(0), 1):
            errors.append('mesh: invalid grid or normalized weights: ' + mesh['name'])
        from .mesh import grid, weights_for
        vertices,uvs,triangles=grid(mesh['bbox'])
        if mesh['vertices']!=vertices or mesh['uvs']!=uvs or mesh['triangles']!=triangles:
            errors.append('mesh: source two-pixel grid differs: '+mesh['name'])
        garment=mesh.get('garment',mesh['name'])
        if mesh.get('hidden_material') and (garment not in meshes or mesh.get('weight_bounds') != meshes[garment]['bbox']):
            errors.append('mesh: hidden layer must share its garment field: '+mesh['name'])
        if garment not in anatomy['meshes']:
            errors.append('mesh: unknown garment: ' + garment)
            continue
        expected=weights_for(vertices,mesh.get('weight_bounds',mesh['bbox']),layout['joints'],anatomy['meshes'][garment])
        if set(mesh['weights'])!=set(expected) or any(not np.allclose(mesh['weights'][name],values,atol=1e-12,rtol=0) for name,values in expected.items()):
            errors.append('mesh: director weight rule differs: '+mesh['name'])
    for tuck in build['tucks']:
        if tuck['minimum_px'] < 3 or tuck['missing_pixels'] or not tuck['required_pixels']:
            errors.append('tuck: insufficient continuation: ' + tuck['piece'])
    if build['front_rest_mismatch_pixels']:
        errors.append('rest: source ownership mismatch')
    depths = {p['name']: p['z_index'] for p in layout['parts']}
    for item, role in anatomy['held_depth_roles'].items():
        body = [depths[n] for n in role['body']]
        policy = role['policy'][layout['facing']]
        if ((policy == 'behind_body' and depths[item] >= min(body)) or
                (policy == 'in_front_of_body' and depths[item] <= max(body))):
            errors.append('held depth: ' + item + ' must be ' + policy)
        grip = role.get('grip')
        if grip is not None and depths[grip] <= depths[item]:
            errors.append('held depth: gripping piece must be in front of ' + item)
    return errors


def source_errors(case, layout, build):
    build = view_build(layout, build)
    from maquette_motion.features import source_pixels
    from .gait_continuations import errors as continuation_errors
    errors = continuation_errors(case, layout)
    images = {p['name']: source_pixels(case,p) for p in layout['parts']}
    continuations = {}
    rest = Image.new('RGBA',(255,255))
    for part in sorted(layout['parts'],key=lambda p:p['z_index']):
        rest.alpha_composite(Image.fromarray(images[part['name']]))
        record = layout['proof_layers'][part['name']]
        # The immutable allowed/tuck masks are separate from the paint asset.
        checks = np.zeros((255,255,4),dtype=np.uint8)
        mask = Image.open(case / record['mask']).convert('RGBA')
        checks_image = Image.fromarray(checks)
        checks_image.paste(mask,tuple(record['mask_offset']))
        checks = np.asarray(checks_image)
        continuations[part['name']] = checks[..., 1] > 0
        if np.any((images[part['name']][...,3]>0) & (checks[...,0]==0)):
            errors.append('piece source outside own silhouette/tuck: '+part['name'])
    approved = np.asarray(Image.open(case / layout['rest_source']).convert('RGBA'))
    if not np.array_equal(np.asarray(rest),approved): errors.append('rest: composed source mismatch')
    from .ownership import partition_errors
    errors += partition_errors(case,layout,build,images,continuations,approved)
    from .occluded_surface import source_errors as occluded_errors
    errors += occluded_errors(case,layout,images,continuations,approved)
    from maquette_motion.material_palette import outline_class, rules
    for part in layout['parts']:
        if part.get('occluded_surface') and dark_slab_blocks(outline_class(images[part['name']], rules(case,layout['facing']))):
            errors.append('dark-slab: occluded donor surface: ' + part['logical_part'])
    for tuck in build['tucks']:
        mask = np.asarray(Image.open(case / tuck['required_mask'])) > 0
        supplied = np.zeros((255,255),dtype=bool)
        for part in layout['parts']:
            if part['logical_part']==tuck['piece']:
                supplied |= images[part['name']][...,3]>0
        if np.any(mask & ~supplied): errors.append('tuck: missing actual texels: '+tuck['piece'])
    for feature in layout['features']:
        mask = np.asarray(Image.open(case / feature['mask'])) > 0
        if not np.array_equal(images[feature['piece']][mask],approved[mask]):
            errors.append('feature integrity: '+feature['name'])
    # A colour can occur in the painting and still form a false horizontal
    # band. Check the exact rr-05 donor field in SOURCE space; meshes remain
    # exempt from every CPU posed raster comparison.
    from maquette_motion.bleed import edge_texels
    from maquette_motion.material_palette import rules
    for name, policy in layout.get('continuation_policy', {}).items():
        if policy != 'rr05_visible_cloth_edge_texels':
            errors.append('unknown cloth continuation policy: ' + name)
            continue
        record=layout['proof_layers'][name]
        checks_image=Image.new('RGBA',(255,255))
        checks_image.paste(Image.open(case/record['mask']).convert('RGBA'),tuple(record['mask_offset']))
        continuation=np.asarray(checks_image)[...,1]>0
        donors=images[name].copy(); donors[continuation]=0
        expected=edge_texels(donors,continuation,rules(case,layout['facing']))
        if np.any(images[name][continuation]!=expected[continuation]):
            errors.append('dark-slab/cloth continuity: non-continuous robe fill: '+name)
    return errors


def bone_errors(layout, data, report, current_bindings):
    from .bone_evidence import evidence_errors
    errors = evidence_errors(data, report, current_bindings, EPSILON)
    if errors:
        return errors
    anatomy = for_layout(layout)
    joints = layout['joints']
    forward = np.asarray(data['projection'][layout['facing']]['forward'])
    step = report['step_distance_px'] / report['screen_pixel_scale']
    for row in report['samples']:
        if row['view'] != layout['facing']: continue
        clip, phase, bones = row['clip'], row['phase'], row['bones']
        tag = '%s/%s/%s' % (row['view'], clip, phase)
        if row['kind'] == 'authored':
            values = {}
            modes = dict(data.get('view_forward_modes', {}).get(row['view'], {}).get(clip, {}))
            for track in data['view_tracks'][row['view']][clip]:
                values.setdefault(track['bone'], {})[track['channel']] = evaluate(track['keys'], phase)
                modes[track['bone']] = track['forward_mode']
            root_progress = values.get('root', {}).get('forward_px', 0.)
            from .bone_contracts import target_chains, fk_world, ik_errors
            gait = 'gait' in data['clips'][clip]
            chains = target_chains(layout, values)
            solved = {chain[key] for chain in chains for key in ('first', 'second', 'target')}
            fk = fk_world(layout, values, modes, forward, step)
            for name, channels in values.items():
                if name in solved or name in layout.get('held_items', {}) or (gait and name == 'pelvis'): continue
                position = np.asarray(joints[name]['position'])
                parent = joints[name]['parent']
                origin = position - (np.asarray(joints[parent]['position']) if parent else 0.)
                amount = channels.get('forward_px', 0.)
                if modes[name] == 'fraction_of_step': amount *= step
                if modes[name] == 'world_step': amount = (amount - root_progress) * step
                expected = origin + forward * amount + [
                    np.sign(joints['root']['position'][0] - position[0]) * channels.get('inward_px', 0.),
                    -channels.get('lift_px', 0.)]
                if not np.allclose(bones[name]['local'][4:], expected, atol=EPSILON, rtol=0):
                    errors.append(tag + ': signed translation: ' + name)
                if abs(angle(bones[name]['local']) - channels.get('lean_deg', 0.)) > EPSILON:
                    errors.append(tag + ': signed rotation: ' + name)
            for chain in chains:
                if gait and chain['target'].startswith('foot_'): continue
                errors += [tag + ': ' + error for error in ik_errors(layout, bones, chain, fk, EPSILON, anatomy)]
            for item in layout.get('held_items', {}):
                expected_angle = values.get(item, {}).get('angle_deg', 0.)
                if abs(angle(bones[item]['global']) - expected_angle) > EPSILON:
                    errors.append(tag + ': world-relative ' + item + ' angle')
        if clip == 'idle':
            for group, definition in anatomy['idle_groups'].items():
                names = definition['bones']
                offsets = []
                for name in names:
                    transform = matrix(bones[name]['global'])
                    if not np.allclose(transform[:2, :2], np.eye(2), atol=EPSILON, rtol=0):
                        errors.append(tag + ': idle rotation/scale: ' + name)
                    offsets.append(transform[:2, 2] - joints[name]['position'])
                if not np.allclose(offsets, offsets[0], atol=EPSILON, rtol=0):
                    errors.append(tag + ': idle group deformed: ' + group)
                if definition['stationary'] and not np.allclose(offsets, 0, atol=EPSILON, rtol=0):
                    errors.append(tag + ': planted idle group moved: ' + group)
                if row['kind'] == 'presented' and not np.allclose(offsets, np.round(offsets), atol=EPSILON, rtol=0):
                    errors.append(tag + ': fractional idle group')
        if clip not in ('move', 'death'):
            from .leg_roles import resolve_bone
            for source_name in anatomy['planted_bones']:
                name = resolve_bone(source_name, anatomy, layout['facing'])
                tolerance = anatomy.get('planted_tolerance_px')
                actual = np.asarray(bones[name]['global'][4:])
                expected = np.asarray(joints[name]['position'])
                failed = (np.linalg.norm(actual - expected) > tolerance + EPSILON if tolerance is not None else
                          not np.allclose(actual, expected, atol=EPSILON, rtol=0))
                if failed:
                    errors.append(tag + ': planted anchor moved: ' + name)
        if abs(angle(bones['torso']['local'])) > (25 if clip == 'death' else 4) + EPSILON:
            errors.append(tag + ': torso lean limit')
        if abs(relative_angle(bones['head']['global'], bones['torso']['global'])) > (20 if clip == 'death' else 6) + EPSILON:
            errors.append(tag + ': head nod limit')
        for item in layout.get('held_items', {}):
            if clip != 'death' and abs(angle(bones[item]['global'])) > 35 + EPSILON:
                errors.append(tag + ': ' + item + ' angle limit')
    if any('gait' in definition for definition in data['clips'].values()):
        from .walk_gates import report as walk_report
        errors += walk_report(layout, data, report)['errors']
    from .action_direction import report as action_direction_report
    errors += action_direction_report(layout, data, report, current_bindings)['errors']
    return sorted(set(errors))


def idle_pixel_errors(rest, frame, offset):
    """Isolated native group images; compare all RGBA, including alpha."""
    dx, dy = [int(round(value)) for value in offset]
    expected = np.zeros_like(rest)
    h, w = rest.shape[:2]
    expected[max(0,dy):min(h,h+dy), max(0,dx):min(w,w+dx)] = rest[max(0,-dy):min(h,h-dy), max(0,-dx):min(w,w-dx)]
    visible=(expected[...,3]>0)|(frame[...,3]>0)
    return int((np.any(expected != frame, axis=-1)&visible).sum())


def idle_group_offset(layout, bones, group, anatomy):
    anchor = anatomy['idle_groups'][group]['bones'][0]
    return np.asarray(bones[anchor]['global'][4:]) - layout['joints'][anchor]['position']


def dark_slab_blocks(mask):
    """The existing 3×3 all-outline slab rule, shared with occluded boots."""
    h, w = mask.shape
    blocks = np.ones((h - 2, w - 2), dtype=bool)
    for y in range(3):
        for x in range(3): blocks &= mask[y:y+h-2, x:x+w-2]
    return int(blocks.sum())


def clean_metrics(layers, outline_rules=None):
    """Inspect isolated native surfaces; no deformation or resampling here."""
    from maquette_motion.silhouette import components, dilate
    from maquette_motion.material_palette import outline_class
    occupied = np.zeros(layers[0][1].shape[:2],dtype=bool)
    visible = np.zeros_like(layers[0][1])
    exposed_dark=np.zeros_like(occupied)
    slab_dark=np.zeros_like(occupied)
    silhouette=np.logical_or.reduce([(checks[...,0]>0)&(checks[...,3]>0) for _,_,checks in layers])
    outside_outline=np.zeros_like(occupied)
    result = {'outside_pixels':0, 'exposed_continuation_pixels':0,
              'exposed_outline_pixels':0, 'dark_slab_blocks':0}
    for row,image,checks in sorted(layers,key=lambda item:item[0]['z_index'],reverse=True):
        paint = image[...,3]>0
        allowed = (checks[...,0]>0) & (checks[...,3]>0)
        result['outside_pixels'] += int((paint & ~allowed).sum())
        exposed = paint & ~occupied
        visible[exposed] = image[exposed]
        continuation = (checks[...,1]>0) & (checks[...,3]>0) & exposed
        outline = outline_class(image, outline_rules) if outline_rules is not None else checks[...,2]>0
        result['exposed_continuation_pixels'] += int(continuation.sum())
        exposed_dark |= continuation & outline
        slab_dark |= (exposed if row.get('occluded_surface') else continuation) & outline
        outside_outline |= exposed & outline & ~dilate(silhouette, 1)
        occupied |= paint
    result['exposed_outline_pixels'] = int(exposed_dark.sum())
    result['outline_outside_pixels'] = int(outside_outline.sum())
    result.update(detached_metrics(visible))
    result['dark_slab_blocks']=dark_slab_blocks(slab_dark)
    labels,groups=components(~occupied)
    edge=set(np.concatenate((labels[0],labels[-1],labels[:,0],labels[:,-1])).tolist())
    result['interior_hole_sizes'] = [size for label,size in groups if label not in edge and size>1]
    return result


def unexplained_holes(occupied, references):
    """One transported native rest hole may explain one deformed component."""
    from maquette_motion.silhouette import holes
    remaining=list(references)
    unexplained=[]
    for hole in holes(occupied):
        size=int(hole.sum())
        if size<=1: continue
        overlaps=[int((hole & old).sum()) for old in remaining]
        if overlaps and max(overlaps): remaining.pop(int(np.argmax(overlaps)))
        else: unexplained.append(size)
    return unexplained


def native_errors(case, capture, failure_output=None, hole_details=None, space_details=None):
    """No image claims without hashed native captures and complete progression."""
    manifest = read_json(capture / 'frames.json')
    anatomy = load(case)
    errors = list(manifest.get('errors', []))
    from .native_exceptions import load as load_exceptions, frame_errors
    try:
        approved = load_exceptions(case)
    except ValueError as error:
        errors.append('invalid native gate exceptions: ' + str(error))
        approved = frozenset()
    if not manifest.get('ok'): errors.append('native capture did not complete successfully')
    if not manifest['native_pixels'] or manifest['size'] != [1920,1080] or manifest['ui_scale'] != 1:
        errors.append('native renderer / 1920x1080 / 100% proof required')
    bound_inputs=bindings(case)
    if manifest['inputs'] != bound_inputs: errors.append('stale native proof inputs')
    data = read_json(case / 'compiled_motion.json')
    from .bone_evidence import evidence_errors, read_report
    sampled = read_report(case)
    errors += evidence_errors(data, sampled, bound_inputs, EPSILON)
    if sampled.get('inputs')!=bound_inputs: errors.append('stale headless pose reference; rerun samples.gd')
    expected_poses={(r['view'],r['clip'],r['frame']):r for r in sampled['samples'] if r['kind']=='presented'}
    layouts={view:read_json(case / f'layouts/{view}.json') for view in data['view_tracks']}
    from .rigid_air import for_case as air_policy_for_case
    air_policies = {view: air_policy_for_case(case, layout, anatomy) for view, layout in layouts.items()}
    from .source_space import PaintedComponents, pocket_report, apply_painted_components
    painted_components = {view: PaintedComponents(case, layout) for view, layout in layouts.items()}
    passed_spaces = []
    for layout in layouts.values():
        errors += source_errors(case,layout,read_json(case/'proof/build.json'))
    native_frames={(r['view'],r['clip'],r['frame']):r for r in manifest['frames']}
    for view in data['view_tracks']:
        rest = np.asarray(Image.open(capture / (view + '_rest.png')).convert('RGBA'))
        source = np.asarray(Image.open(case / layouts[view]['rest_source']).convert('RGBA'))
        if not np.array_equal(rest, source): errors.append(view + ': native rest mismatch')
        for clip, definition in data['clips'].items():
            rows = [r for r in manifest['frames'] if r['view'] == view and r['clip'] == clip]
            if len(rows) != round(definition['seconds'] * 60) or {r['frame'] for r in rows}!=set(range(round(definition['seconds']*60))): errors.append(view + '/' + clip + ': missing frames')
            for row in rows:
                if digest(capture / row['file']) != row['sha256']: errors.append('changed frame: ' + row['file'])
    for clip,definition in data['clips'].items():
        pair_rows=[r for r in manifest.get('pairs',[]) if r['clip']==clip]
        if {r['frame'] for r in pair_rows}!=set(range(round(definition['seconds']*60))): errors.append(clip+': incomplete reel pairs')
        for row in pair_rows:
            if digest(capture / row['file'])!=row['sha256']: errors.append('changed reel pair: '+row['file'])
            if Image.open(capture / row['file']).size!=(1920,1080): errors.append('wrong reel dimensions: '+row['file'])
    idle_rows = manifest.get('idle_groups', [])
    expected_idle = round(data['clips']['idle']['seconds'] * 60) * 3 * len(data['view_tracks'])
    if len(idle_rows) != expected_idle: errors.append('incomplete isolated idle groups')
    for row in idle_rows:
        expected=expected_poses.get((row['view'],'idle',row['frame']))
        if expected is None: errors.append(row['file']+': missing independent idle pose')
        else:
            offset=idle_group_offset(layouts[row['view']],expected['bones'],row['group'],anatomy)
            if not np.allclose(offset,row['offset'],atol=EPSILON,rtol=0): errors.append(row['file']+': idle offset differs from authored group')
        rest = np.asarray(Image.open(capture / row['rest']).convert('RGBA'))
        frame = np.asarray(Image.open(capture / row['file']).convert('RGBA'))
        mismatch = idle_pixel_errors(rest, frame, row['offset'])
        if mismatch: errors.append('%s: idle pixel mismatch: %d' % (row['file'], mismatch))
    if not manifest.get('idle_groups'): errors.append('missing isolated idle group proof')
    # Rigid sprite agreement uses the established rr-05 nearest-source oracle.
    # Skinned meshes are deliberately absent from this comparison.
    from maquette_motion.pixels import render, unpack, native_frame_matches
    layer_frames = {}
    for row in manifest.get('pieces', []):
        layer_frames.setdefault((row['view'],row['clip'],row['frame']), []).append(row)
    if not manifest.get('pieces'): errors.append('missing every-frame clean-piece proof')
    hole_frames={}
    for row in manifest.get('rest_holes',[]):
        if digest(capture / row['file'])!=row['sha256']: errors.append('changed native rest-hole reference: '+row['file'])
        hole_frames.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    seam_frames = {}
    for row in manifest.get('joint_seams', []):
        if digest(capture / row['file']) != row['sha256']: errors.append('changed native joint seam: ' + row['file'])
        seam_frames.setdefault((row['view'],row['clip'],row['frame']), []).append(row)
    from maquette_motion.material_palette import rules
    outline_rules = {view: rules(case,view) for view in layouts}
    for key, rows in layer_frames.items():
        view, clip, frame = key
        layout = layouts[view]
        # Retain one frame of GPU surfaces, not the entire reel in RAM.
        layers=[]
        for row in rows:
            part = next(p for p in layout['parts'] if p['name'] == row['name'])
            if row['source'] != part['file']: errors.append(row['file'] + ': native source differs from layout')
            image=np.asarray(Image.open(capture / row['file']).convert('RGBA'))
            checks=np.asarray(Image.open(capture / row['checks']).convert('RGBA'))
            if row.get('rigid'):
                reference=expected_poses.get(key,{}).get('parts',{}).get(row['name'],{}).get('transform')
                if reference is None or not np.allclose(reference,row['transform'],atol=EPSILON,rtol=0): errors.append(row['file']+': differs from independent pose')
                from .gait_continuations import texture
                source=Image.fromarray(texture(case, layout, part, gait='gait' in data['clips'][clip], clip=clip))
                # Use the established real-source UV tie candidates, just as
                # the rigid shimmer gate does. A default tie direction alone
                # falsely rejects rear Thrall hidden_tube at a 45-degree pose.
                expected=render(source,unpack(row['transform']),(0,0,512,512),with_ties=True)
                if not native_frame_matches(image,expected.default,expected): errors.append(row['file']+': rigid native agreement')
            part = next(p for p in layout['parts'] if p['name'] == row['name'])
            layers.append((dict(row, occluded_surface=part.get('occluded_surface', False)),image,checks))
        if len(layers)!=len(layout['parts']) or {r['name'] for r,_,_ in layers} != {p['name'] for p in layout['parts']}:
            errors.append(str(key) + ': missing isolated pieces')
        metric = clean_metrics(layers, outline_rules[view])
        expected_holes=len(layout.get('proof_rest_holes',[]))
        if len(hole_frames.get(key,[]))!=expected_holes: errors.append(str(key)+': missing GPU rest-hole transport')
        occupied=np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
        references=[np.asarray(Image.open(capture / row['file']).convert('RGBA'))[...,3]>0 for row in hole_frames.get(key,[])]
        if len(seam_frames.get(key, [])) != len(layout.get('proof_joint_seams', [])):
            errors.append(str(key) + ': missing GPU joint-seam transport')
        seam = np.zeros_like(occupied)
        for row in seam_frames.get(key, []):
            seam |= np.asarray(Image.open(capture / row['file']).convert('RGBA'))[...,3] > 0
        pose = expected_poses.get(key)
        air_policy = air_policies[view]
        if pose is None:
            errors.append(str(key) + ': missing independent joint-boundary pose')
            new_holes = []
        else:
            from maquette_motion.pixels import PROOF_DEFAULTS
            owners = posed_owners(layers, layout['parts'], pose['bones'], PROOF_DEFAULTS['source_offset'], anatomy['ownership'])
            if air_policy is None:
                new_holes = joint_holes(occupied, seam, owners, references, pocket_details=True)
                spaces = pocket_report(layers, new_holes)
                new_holes = [{'bbox': r['bbox'], 'pixel_count': r['pixel_count']} for r in spaces['failures']]
            else:
                transforms = {name: part['transform'] for name, part in pose['parts'].items()}
                spaces = air_policy.report(occupied, owners, transforms)
                new_holes = spaces['failures']
            detached = painted_components[view].report(layers, pose)
            metric = apply_painted_components(metric, detached)
            if spaces['air_pockets'] or detached:
                passed_spaces.append({'view': view, 'clip': clip, 'frame': frame,
                    'air_pockets': spaces['air_pockets'], 'painted_detached_components': detached})
        composite = Image.new('RGBA',(512,512))
        for _,image,_ in sorted(layers,key=lambda item:item[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
        if key not in native_frames: errors.append(str(key)+': missing composed native frame')
        else:
            actual=np.asarray(Image.open(capture / native_frames[key]['file']).convert('RGBA'))
            from maquette_motion.pixels import changed
            if changed(actual,np.asarray(composite)).any(): errors.append(str(key)+': native frame differs from isolated GPU pieces')
        rejected = frame_errors(key, metric, new_holes if air_policy is None else [], approved)
        from .material_gates import colour_errors
        rejected += [str(key)+': '+error for error in colour_errors(np.asarray(composite),anatomy.get('material_policy',{}))]
        if air_policy is not None and new_holes:
            rejected.append(str(key) + ': pocket through rigid painted silhouette/tuck')
        errors += rejected
        if hole_details is not None and new_holes and (air_policy is not None or str(key) + ': new joint-seam hole larger than 1px' in rejected):
            hole_details.append({'view': view, 'clip': clip, 'frame': frame,
                                 'pixel_counts': [hole['pixel_count'] for hole in new_holes],
                                 'pockets': new_holes})
        if rejected:
            # Save renderer crops for the director's weight/coverage diagnosis.
            folder = failure_output if failure_output is not None else case / 'proof/native_failures'
            target = folder / ('%s_%s_%04d.png' % key)
            target.parent.mkdir(parents=True,exist_ok=True)
            crop = composite.crop(composite.getbbox())
            crop.resize((crop.width*FAILURE_CROP_ZOOM,crop.height*FAILURE_CROP_ZOOM),Image.Resampling.NEAREST).save(target)
    expected_frames = sum(round(c['seconds'] * 60) for c in data['clips'].values()) * len(data['view_tracks'])
    if len(layer_frames) != expected_frames: errors.append('incomplete clean union/material proof')
    if bindings(case)!=bound_inputs: errors.append('inputs changed during native gate')
    if space_details is not None:
        space_details.extend(passed_spaces)
    write_json(capture / 'source_space_pockets.json', passed_spaces)
    return errors


def bindings(case):
    paths = [p for p in case.rglob('*') if p.is_file() and p.suffix in ('.json','.png')
             and 'proof' not in p.relative_to(case).parts]
    result = {str(p.relative_to(case)): digest(p) for p in paths}
    project = Path(__file__).resolve().parents[2]
    integration = load(case)['integration']
    for folder in integration['binding_folders']:
        for path in (project / folder).rglob('*'):
            if path.is_file() and path.suffix in ('.gd','.py','.json'):
                result['runtime:' + str(path.relative_to(project))] = digest(path)
    if integration['production_root'] is None:
        return result  # Diagnostic anatomy with no production integration.
    production = project / integration['production_root']
    for path in (production / integration['rig_directory']).rglob('*'):
        if path.is_file() and path.suffix in ('.json','.png'):
            result['production:' + str(path.relative_to(project))] = digest(path)
    for name in integration['binding_files']:
        path=production/name
        result['production:' + str(path.relative_to(project))] = digest(path)
    return result
