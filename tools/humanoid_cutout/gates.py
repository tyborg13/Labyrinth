"""v2 structural, signed-bone and native-pixel gates (no CPU skin oracle)."""
import math
from pathlib import Path

import numpy as np
from PIL import Image

from cutout_pipeline.cases import read_json, digest
from maquette_motion.compiler import evaluate
from .silhouette_gates import detached_metrics, joint_holes, posed_owners

EPSILON = 0.0001  # Serialized Bone2D float tolerance, not animation tuning.
FAILURE_CROP_ZOOM = 3
GROUP_BONES = {
    'upper_body': ('torso', 'head', 'upper_near', 'fore_near', 'hand_near'),
    'still_staff_arm': ('upper_far', 'fore_far', 'hand_far', 'staff'),
    'still_lower_body': ('root', 'pelvis', 'hem_near', 'hem_far', 'foot_near', 'foot_far')}


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
    build = view_build(layout, build)
    errors = []
    required = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
                'hem_near': 'root', 'hem_far': 'root', 'foot_near': 'hem_near',
                'foot_far': 'hem_far', 'staff': 'hand_far'}
    for name, parent in required.items():
        if layout['joints'].get(name, {}).get('parent', 'missing') != parent:
            errors.append('hierarchy: ' + name)
    meshes = {m['name']: m for m in layout.get('joint_meshes', []) if not m.get('hidden_material')}
    if set(meshes) != {'robe', 'sleeve_near', 'sleeve_far'}:
        errors.append('cut: exactly one robe and two sleeve meshes required')
    if any(n in layout['joints'] for n in ('collar', 'skirt_near', 'skirt_far', 'staff_crystal')):
        errors.append('cut: independently moving fused piece')
    if set(layout.get('idle_groups', {})) != set(GROUP_BONES):
        errors.append('idle: exactly three groups required')
    for mesh in layout.get('joint_meshes', []):
        weights = np.asarray(list(mesh['weights'].values()))
        if mesh.get('grid_px') != 2 or not np.isfinite(weights).all() or weights.min() < 0 or not np.allclose(weights.sum(0), 1):
            errors.append('mesh: invalid grid or normalized weights: ' + mesh['name'])
        from .mesh import grid, robe_weights, sleeve_weights
        vertices,uvs,triangles=grid(mesh['bbox'])
        if mesh['vertices']!=vertices or mesh['uvs']!=uvs or mesh['triangles']!=triangles:
            errors.append('mesh: source two-pixel grid differs: '+mesh['name'])
        garment=mesh.get('garment',mesh['name'])
        if mesh.get('hidden_material') and (garment not in meshes or mesh.get('weight_bounds') != meshes[garment]['bbox']):
            errors.append('mesh: hidden layer must share its garment field: '+mesh['name'])
        if garment=='robe': expected=robe_weights(vertices,mesh.get('weight_bounds',mesh['bbox']), layout['joints']['hem_near']['position'][0] > layout['joints']['hem_far']['position'][0])
        else:
            side=garment.split('_')[-1]
            expected=sleeve_weights(vertices,*[layout['joints'][n+side]['position'] for n in ('upper_','fore_','hand_')],side)
        if set(mesh['weights'])!=set(expected) or any(not np.allclose(mesh['weights'][name],values,atol=1e-12,rtol=0) for name,values in expected.items()):
            errors.append('mesh: director weight rule differs: '+mesh['name'])
    for tuck in build['tucks']:
        if tuck['minimum_px'] < 3 or tuck['missing_pixels'] or not tuck['required_pixels']:
            errors.append('tuck: insufficient continuation: ' + tuck['piece'])
    if build['front_rest_mismatch_pixels']:
        errors.append('rest: source ownership mismatch')
    policy = layout.get('held_item_depth', {})
    if policy != {'front': 'behind_body', 'rear': 'in_front_of_body'}:
        errors.append('held depth: front far side / rear near side required')
    depths = {p['name']: p['z_index'] for p in layout['parts']}
    body = [depths[n] for n in ('torso','sleeve_near','sleeve_far','robe')]
    if layout['facing'] == 'front' and depths['staff'] >= min(body):
        errors.append('held depth: front staff must be behind body')
    if layout['facing'] == 'rear' and depths['staff'] <= max(body):
        errors.append('held depth: rear staff must be in front of body')
    if depths['hand_far'] <= depths['staff']:
        errors.append('held depth: gripping hand must be in front of staff')
    return errors


def source_errors(case, layout, build):
    build = view_build(layout, build)
    from maquette_motion.features import source_pixels
    errors = []
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


def bone_errors(layout, data, report):
    errors = []
    if report['compiled_sha256'] != data.get('_sha256', report['compiled_sha256']):
        errors.append('stale compiled motion')
    joints = layout['joints']
    forward = np.asarray(data['projection'][layout['facing']]['forward'])
    step = report['step_distance_px'] / report['screen_pixel_scale']
    for row in report['samples']:
        if row['view'] != layout['facing']: continue
        clip, phase, bones = row['clip'], row['phase'], row['bones']
        tag = '%s/%s/%s' % (row['view'], clip, phase)
        if row['kind'] == 'authored':
            values, modes = {}, {}
            for track in data['view_tracks'][row['view']][clip]:
                values.setdefault(track['bone'], {})[track['channel']] = evaluate(track['keys'], phase)
                modes[track['bone']] = track['forward_mode']
            root_progress = values.get('root', {}).get('forward_px', 0.)
            for name, channels in values.items():
                if name.startswith('hand_') or name == 'staff': continue
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
            for side in ('near', 'far'):
                upper, fore, hand = ['%s_%s' % (n, side) for n in ('upper', 'fore', 'hand')]
                if hand not in values: continue
                a, b, c = [np.asarray(bones[n]['global'][4:]) for n in (upper, fore, hand)]
                ra, rb, rc = [np.asarray(joints[n]['position']) for n in (upper, fore, hand)]
                if not np.allclose([np.linalg.norm(b-a), np.linalg.norm(c-b)],
                                   [np.linalg.norm(rb-ra), np.linalg.norm(rc-rb)], atol=EPSILON, rtol=0):
                    errors.append(tag + ': IK length: ' + side)
                def cross(u, v): return u[0] * v[1] - u[1] * v[0]
                if cross(c-a, b-a) * cross(rc-ra, rb-ra) < -EPSILON:
                    errors.append(tag + ': IK changed rest bend side: ' + side)
                torso = matrix(bones['torso']['global'])
                delta = values[hand]
                target_local = rc - np.asarray(joints['torso']['position'])
                target_local = target_local + forward * delta.get('forward_px', 0.) + [
                    np.sign(joints['root']['position'][0] - rc[0]) * delta.get('inward_px', 0.), -delta.get('lift_px', 0.)]
                target = (torso @ [*target_local, 1])[:2]
                ray = target - a
                distance = min(max(np.linalg.norm(ray), abs(np.linalg.norm(rb-ra)-np.linalg.norm(rc-rb)) + 1e-6),
                               np.linalg.norm(rb-ra) + np.linalg.norm(rc-rb) - 1e-6)
                expected = a + ray / np.linalg.norm(ray) * distance
                if not np.allclose(c, expected, atol=EPSILON, rtol=0):
                    errors.append(tag + ': signed hand target: ' + side)
            expected_angle = values.get('staff', {}).get('angle_deg', 0.)
            if abs(angle(bones['staff']['global']) - expected_angle) > EPSILON:
                errors.append(tag + ': world-relative staff angle')
        if clip == 'idle':
            for group, names in GROUP_BONES.items():
                offsets = []
                for name in names:
                    transform = matrix(bones[name]['global'])
                    if not np.allclose(transform[:2, :2], np.eye(2), atol=EPSILON, rtol=0):
                        errors.append(tag + ': idle rotation/scale: ' + name)
                    offsets.append(transform[:2, 2] - joints[name]['position'])
                if not np.allclose(offsets, offsets[0], atol=EPSILON, rtol=0):
                    errors.append(tag + ': idle group deformed: ' + group)
                if group != 'upper_body' and not np.allclose(offsets, 0, atol=EPSILON, rtol=0):
                    errors.append(tag + ': planted idle group moved: ' + group)
                if row['kind'] == 'presented' and not np.allclose(offsets, np.round(offsets), atol=EPSILON, rtol=0):
                    errors.append(tag + ': fractional idle group')
        if clip not in ('move', 'death'):
            for name in ('hem_near', 'hem_far', 'foot_near', 'foot_far'):
                if not np.allclose(bones[name]['global'][4:], joints[name]['position'], atol=EPSILON, rtol=0):
                    errors.append(tag + ': planted anchor moved: ' + name)
        if abs(angle(bones['torso']['local'])) > (25 if clip == 'death' else 4) + EPSILON:
            errors.append(tag + ': torso lean limit')
        if abs(relative_angle(bones['head']['global'], bones['torso']['global'])) > (20 if clip == 'death' else 6) + EPSILON:
            errors.append(tag + ': head nod limit')
        if clip != 'death' and abs(angle(bones['staff']['global'])) > 35 + EPSILON:
            errors.append(tag + ': staff angle limit')
    return sorted(set(errors))


def idle_pixel_errors(rest, frame, offset):
    """Isolated native group images; compare all RGBA, including alpha."""
    dx, dy = [int(round(value)) for value in offset]
    expected = np.zeros_like(rest)
    h, w = rest.shape[:2]
    expected[max(0,dy):min(h,h+dy), max(0,dx):min(w,w+dx)] = rest[max(0,-dy):min(h,h-dy), max(0,-dx):min(w,w-dx)]
    visible=(expected[...,3]>0)|(frame[...,3]>0)
    return int((np.any(expected != frame, axis=-1)&visible).sum())


def clean_metrics(layers, outline_rules=None):
    """Inspect isolated native surfaces; no deformation or resampling here."""
    from maquette_motion.silhouette import components, dilate
    from maquette_motion.material_palette import outline_class
    occupied = np.zeros(layers[0][1].shape[:2],dtype=bool)
    visible = np.zeros_like(layers[0][1])
    exposed_dark=np.zeros_like(occupied)
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
        outside_outline |= exposed & outline & ~dilate(silhouette, 1)
        occupied |= paint
    result['exposed_outline_pixels'] = int(exposed_dark.sum())
    result['outline_outside_pixels'] = int(outside_outline.sum())
    result.update(detached_metrics(visible))
    h,w=exposed_dark.shape
    blocks=np.ones((h-2,w-2),dtype=bool)
    for y in range(3):
        for x in range(3): blocks &= exposed_dark[y:y+h-2,x:x+w-2]
    result['dark_slab_blocks']=int(blocks.sum())
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


def native_errors(case, capture, failure_output=None):
    """No image claims without hashed native captures and complete progression."""
    manifest = read_json(capture / 'frames.json')
    errors = list(manifest.get('errors', []))
    if not manifest.get('ok'): errors.append('native capture did not complete successfully')
    if not manifest['native_pixels'] or manifest['size'] != [1920,1080] or manifest['ui_scale'] != 1:
        errors.append('native renderer / 1920x1080 / 100% proof required')
    bound_inputs=bindings(case)
    if manifest['inputs'] != bound_inputs: errors.append('stale native proof inputs')
    data = read_json(case / 'compiled_motion.json')
    sampled=read_json(case/'proof/samples.json')
    if sampled.get('inputs')!=bound_inputs: errors.append('stale headless pose reference; rerun samples.gd')
    expected_poses={(r['view'],r['clip'],r['frame']):r for r in sampled['samples'] if r['kind']=='presented'}
    layouts={view:read_json(case / f'layouts/{view}.json') for view in data['view_tracks']}
    for layout in layouts.values():
        errors += source_errors(case,layout,read_json(case/'proof/build.json'))
    native_frames={(r['view'],r['clip'],r['frame']):r for r in manifest['frames']}
    for view in data['view_tracks']:
        rest = np.asarray(Image.open(capture / (view + '_rest.png')).convert('RGBA'))
        source = np.asarray(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
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
            bone='torso' if row['group']=='upper_body' else 'root'
            offset=np.asarray(expected['bones'][bone]['global'][4:])-layouts[row['view']]['joints'][bone]['position']
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
            image=np.asarray(Image.open(capture / row['file']).convert('RGBA'))
            checks=np.asarray(Image.open(capture / row['checks']).convert('RGBA'))
            if row.get('rigid'):
                reference=expected_poses.get(key,{}).get('parts',{}).get(row['name'],{}).get('transform')
                if reference is None or not np.allclose(reference,row['transform'],atol=EPSILON,rtol=0): errors.append(row['file']+': differs from independent pose')
                source=Image.open(case / row['source']).convert('RGBA')
                expected=render(source,unpack(row['transform']),(0,0,512,512))
                if not native_frame_matches(image,expected): errors.append(row['file']+': rigid native agreement')
            layers.append((row,image,checks))
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
        if pose is None:
            errors.append(str(key) + ': missing independent joint-boundary pose')
            new_holes = []
        else:
            from maquette_motion.pixels import PROOF_DEFAULTS
            owners = posed_owners(layers, layout['parts'], pose['bones'], PROOF_DEFAULTS['source_offset'])
            new_holes = joint_holes(occupied, seam, owners, references)
        composite = Image.new('RGBA',(512,512))
        for _,image,_ in sorted(layers,key=lambda item:item[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
        if key not in native_frames: errors.append(str(key)+': missing composed native frame')
        else:
            actual=np.asarray(Image.open(capture / native_frames[key]['file']).convert('RGBA'))
            from maquette_motion.pixels import changed
            if changed(actual,np.asarray(composite)).any(): errors.append(str(key)+': native frame differs from isolated GPU pieces')
        if metric['outside_pixels']: errors.append(str(key) + ': outside own silhouette/tuck')
        if metric['exposed_outline_pixels']: errors.append(str(key) + ': outline in exposed continuation')
        if metric['dark_slab_blocks']: errors.append(str(key) + ': exposed dark slab')
        if metric['stray_components']: errors.append(str(key) + ': detached opaque component outside outline exemption')
        if metric['outline_outside_pixels']: errors.append(str(key) + ': outline more than 1px outside posed silhouettes')
        if new_holes: errors.append(str(key) + ': new joint-seam hole larger than 1px')
        if any(metric[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks',
                                   'stray_components','outline_outside_pixels')) or new_holes:
            # Save renderer crops for the director's weight/coverage diagnosis.
            folder = failure_output if failure_output is not None else case / 'proof/native_failures'
            target = folder / ('%s_%s_%04d.png' % key)
            target.parent.mkdir(parents=True,exist_ok=True)
            crop = composite.crop(composite.getbbox())
            crop.resize((crop.width*FAILURE_CROP_ZOOM,crop.height*FAILURE_CROP_ZOOM),Image.Resampling.NEAREST).save(target)
    expected_frames = sum(round(c['seconds'] * 60) for c in data['clips'].values()) * len(data['view_tracks'])
    if len(layer_frames) != expected_frames: errors.append('incomplete clean union/material proof')
    if bindings(case)!=bound_inputs: errors.append('inputs changed during native gate')
    return errors


def bindings(case):
    paths = [p for p in case.rglob('*') if p.is_file() and p.suffix in ('.json','.png')
             and 'proof' not in p.relative_to(case).parts]
    result = {str(p.relative_to(case)): digest(p) for p in paths}
    project = Path(__file__).resolve().parents[2]
    for folder in ('tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10'):
        for path in (project / folder).rglob('*'):
            if path.is_file() and path.suffix in ('.gd','.py','.json'):
                result['runtime:' + str(path.relative_to(project))] = digest(path)
    production = project / 'assets/units/hoarfrost_seer_cutout'
    for path in (production / 'humanoid_v2').rglob('*'):
        if path.is_file() and path.suffix in ('.json','.png'):
            result['production:' + str(path.relative_to(project))] = digest(path)
    for name in ('rig.gd','renderer.gd','actions.gd'):
        path=production/name
        result['production:' + str(path.relative_to(project))] = digest(path)
    return result
