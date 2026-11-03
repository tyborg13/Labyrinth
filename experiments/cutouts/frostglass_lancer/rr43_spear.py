"""Lancer-only rigid item ownership and all-frame shaft registration gate.

The front trace previously carried two short wood runs on hand_far. Those
runs therefore followed the glove angle, rather than the held item's angle.
Coordinates below are measured cuts on mq14 paint, not new painted pixels.
"""
import numpy as np
from humanoid_cutout.ownership import apply_override
from humanoid_cutout.gates import matrix
from maquette_motion.features import source_pixels

FRONT_GRIP_ROWS = (120, 135)  # Half-open glove occlusion on approved paint.
FRONT_SHAFT_ROWS = (74, 225)
FRONT_SHAFT_AXIS = (28.0, .21)  # x = intercept + slope*y; measured wood centre.
FRONT_SHAFT_HALF_WIDTH = 5.0  # Wood transfer corridor; original grip underlap is retained separately.
TRANSFORM_EPSILON = .0001  # Evidence precision only.
TRANSFER_PARTS = ('spear', 'hidden_spear', 'hand_far', 'hidden_hand_far')


def source_grip(layout):
    """Closest point on the painted shaft axis to the existing hand joint."""
    hand = np.asarray(layout['joints']['hand_far']['position'])
    if layout['facing']=='front':
        point = np.array([FRONT_SHAFT_AXIS[0]+FRONT_SHAFT_AXIS[1]*hand[1],hand[1]])
        ray = np.array([FRONT_SHAFT_AXIS[1],1.])
    else:
        from rr37_surfaces import rear_shaft_axis
        axis = rear_shaft_axis()
        row = int(round(hand[1]))
        point = np.array([float(np.interp(hand[1],np.arange(len(axis)),axis)),hand[1]])
        ray = np.array([(axis[row+1]-axis[row-1])/2,1.])
    return (point+ray*np.dot(hand-point,ray)/np.dot(ray,ray)).tolist()


def front_domain(shape=(255, 255)):
    y, x = np.indices(shape)
    return ((y >= FRONT_SHAFT_ROWS[0]) & (y < FRONT_SHAFT_ROWS[1]) &
            (abs(x - (FRONT_SHAFT_AXIS[0] + FRONT_SHAFT_AXIS[1]*y)) <= FRONT_SHAFT_HALF_WIDTH))


def transfer_domain(paint):
    y, _ = np.indices(paint.shape[:2])
    return front_domain(paint.shape[:2]) & ((y < FRONT_GRIP_ROWS[0]) | (y >= FRONT_GRIP_ROWS[1]))


def own_shaft(view, visible, paint):
    if view != 'front': return
    # Transfer only wood/ink formerly carried by the hand. No arm, cloth,
    # texture colour, source alpha or painted hand texel is changed.
    target = transfer_domain(paint) & (visible['hand_far'][..., 3] > 0)
    apply_override(visible, paint, target, 'spear')


def front_hand_support():
    """Existing three-pixel glove tuck, measured from the re-owned glove."""
    from rr41_underlay import BASELINE
    from rr37_case import CASE
    from cutout_pipeline.cases import read_json
    from maquette_motion.silhouette import dilate
    source = BASELINE/'source'
    layout = read_json(source/'front.json')
    part = next(p for p in layout['parts'] if p['name']=='hand_far')
    image = source_pixels(source,part)
    image[transfer_domain(image)] = 0
    depth = read_json(CASE/'anatomy.json')['tucks']['pieces']['hand_far']['depth_px']
    return dilate(image[...,3]>0,depth,grid_distance=True)


def front_shaft_support():
    """Preserve the approved shaft and its original hidden grip underlap."""
    from rr41_underlay import BASELINE
    from cutout_pipeline.cases import read_json
    layout=read_json(BASELINE/'source/front.json')
    part=next(p for p in layout['parts'] if p['name']=='hidden_spear')
    return front_domain() | (source_pixels(BASELINE/'source',part)[...,3]>0)


def prior_partition(scope):
    """Re-own the previous source/production texels without recolouring them."""
    from rr41_underlay import BASELINE
    from cutout_pipeline.cases import read_json
    root = BASELINE / scope
    layout = read_json(root / 'front.json')
    parts = {p['name']: p for p in layout['parts']}
    images = {name: source_pixels(root, parts[name]) for name in ('spear', 'hand_far')}
    source = BASELINE / 'source'
    source_parts = {p['name']: p for p in read_json(source / 'front.json')['parts']}
    target = transfer_domain(images['hand_far']) & (source_pixels(source, source_parts['hand_far'])[..., 3] > 0)
    images['spear'][target] = images['hand_far'][target]
    images['hand_far'][target] = 0
    images['hidden_spear'] = source_pixels(root,parts['hidden_spear'])
    # The old hand owned wood, so its procedural backing also sampled wood.
    # Retain the glove tuck, not the obsolete wood tail, using genuine glove
    # interior. Otherwise the retired shaft tail becomes a gray hand island.
    from rr37_case import CASE
    from rr37_surfaces import interior
    from maquette_motion.material_palette import rules, luma
    from maquette_motion.bleed import edge_texels
    from PIL import Image
    source_hand = source_pixels(source, source_parts['hand_far'])
    source_hand[target] = 0
    definition = rules(CASE, 'front')
    seed = interior(source_hand, definition)
    seed[luma(seed) < source_parts['hidden_hand_far']['continuation_min_luma']] = 0
    backing = source_pixels(source, source_parts['hidden_hand_far'])
    # Former visible wood also occupied part of the covered glove cuff. Its
    # transfer must retain the existing wrist tuck beneath the arm/shaft.
    from humanoid_cutout.tucks import required_tuck
    visible = {p['name']:source_pixels(source,p) for p in source_parts.values() if not p.get('hidden_material')}
    visible['hand_far'] = source_hand
    visible['spear'][target] = source_pixels(source,source_parts['hand_far'])[target]
    joints = read_json(CASE/'rr43/preservation.json')['source_joints']['front']
    tuck = required_tuck('hand_far',visible,joints,read_json(CASE/'anatomy.json')['tucks'])
    backing = edge_texels(seed, ((backing[...,3]>0) | tuck) & front_hand_support(), definition)
    if scope == 'production':
        from pixel_density import process
        from cutout_pipeline.cases import read_json
        entry = next(e for e in read_json(CASE.parents[3]/'spec/assets/board_pixel_density/registry.json')['entries']
            if e['id']=='frostglass_lancer_cutout')['facings']['front']
        part = source_parts['hidden_hand_far']
        treated = process(Image.fromarray(backing).crop(part['bbox']), entry['mode'], entry['grid'])
        backing[:] = 0
        x0,y0,x1,y1 = part['bbox']
        backing[y0:y1,x0:x1] = np.asarray(treated)
    images['hidden_hand_far'] = backing
    return images


def density_declarations(layout):
    """Preserve the already viewed front's density RGB through the re-cut."""
    from PIL import Image
    from rr37_case import CASE, PROJECT, ASSETS
    from cutout_pipeline.cases import digest
    folder = CASE / 'rr43/production_partition'
    folder.mkdir(parents=True, exist_ok=True)
    empty = folder / 'preserve.png'
    Image.fromarray(np.zeros((255, 255), np.uint8)).save(empty)
    result = {}
    for name, image in prior_partition('production').items():
        part = next(p for p in layout['parts'] if p['name'] == name)
        path = folder / (name + '.png')
        Image.fromarray(image).crop(part['bbox']).save(path)
        target = ASSETS / 'humanoid_v2/front' / path.name
        result[str(target.relative_to(PROJECT))] = {
            'mask': {'path': str(empty.relative_to(PROJECT)), 'sha256': digest(empty)},
            'source_offset': part['offset'],
            'outside': {'path': str(path.relative_to(PROJECT)), 'sha256': digest(path), 'offset': part['offset']}}
    return result


def native_gap_errors(case, capture, manifest):
    """Use actual isolated native pixels; director captures remain mandatory."""
    from cutout_pipeline.cases import read_json
    from humanoid_cutout.native_frames import load_frame
    from humanoid_cutout.canvas import for_case
    from maquette_motion import pixels
    layout = read_json(case/'layouts/front.json')
    main = next(p for p in layout['parts'] if p['name']=='spear')
    core = np.zeros((255,255,4),np.uint8)
    for y in range(*FRONT_SHAFT_ROWS):
        core[y,round(FRONT_SHAFT_AXIS[0]+FRONT_SHAFT_AXIS[1]*y)] = 255
    groups = {}
    for row in manifest['pieces']:
        if row['view']=='front': groups.setdefault((row['clip'],row['frame']),{})[row['name']] = row
    result = []
    with for_case(case):
        for (clip,frame), layers in groups.items():
            transform = matrix(layers['spear']['transform'])
            transform[:2,2] -= transform[:2,:2] @ np.asarray(main['offset'])
            required = pixels.render(core,transform)[...,3]>0
            occupied = np.zeros(required.shape,bool)
            for part in layout['parts']:
                if part['logical_part']=='spear' or part['name']=='hand_far':
                    occupied |= np.asarray(load_frame(capture/layers[part['name']]['file']))[...,3]>0
            missing = int((required & ~occupied).sum())
            if missing: result.append(f'front/{clip}/{frame}: native shaft gap outside hand: {missing}px')
    if not groups: result.append('missing native rigid shaft frames')
    return result


def rigid_item(layout, case=None, visible=None, paint=None, hidden=None, tuck_reports=None):
    main = next(p for p in layout['parts'] if p['name'] == 'spear')
    from rr37_case import CASE
    from cutout_pipeline.cases import read_json
    # Retain the previously viewed snap origin even when the longer source
    # changes its storage crop. This preserves the existing pose registration.
    anchor = read_json(CASE/'rr43/preservation.json')['rigid_item_anchors'][layout['facing']]
    layout['held_items']['spear']['source_grip'] = source_grip(layout)
    if case is not None and layout['facing'] == 'front':
        from PIL import Image
        # Run after existing hidden fills. Re-own unchanged visible wood and
        # rebuild its former glove backing; rr-41 cloth paint stays exact.
        own_shaft('front', visible, paint)
        for part in layout['parts']:
            if part['name'] in ('spear', 'hand_far'):
                Image.fromarray(visible[part['name']]).crop(part['bbox']).save(case / part['file'])
                if 'continuation_donor_uvs' in part:
                    x0, y0 = part['offset']
                    part['continuation_donor_uvs'] = [[x, y] for x, y in part['continuation_donor_uvs']
                        if visible[part['name']][y+y0, x+x0, 3] > 0]
                    if part['name']=='hand_far':
                        # A former interior texel may now sit on the new cut
                        # edge. Recompute the glove's genuine donor clearance.
                        from rr37_surfaces import interior
                        from maquette_motion.material_palette import rules, luma
                        seed=interior(visible['hand_far'],rules(CASE,'front'))
                        seed[luma(seed)<part['continuation_min_luma']]=0
                        yy,xx=np.nonzero(seed[...,3])
                        part['continuation_donor_uvs']=[[int(x-x0),int(y-y0)] for y,x in zip(yy,xx)]
        part = next(p for p in layout['parts'] if p['name']=='hidden_hand_far')
        backing = prior_partition('source')['hidden_hand_far']
        Image.fromarray(backing).crop(part['bbox']).save(case / part['file'])
        if hidden is not None: hidden['hand_far'] = backing
        spear_part = next(p for p in layout['parts'] if p['name']=='hidden_spear')
        spear_backing = prior_partition('source')['hidden_spear']
        Image.fromarray(spear_backing).crop(spear_part['bbox']).save(case/spear_part['file'])
        if hidden is not None: hidden['spear'] = spear_backing
        if visible is not None:
            from humanoid_cutout.tucks import required_tuck
            from PIL import Image
            policy = read_json(CASE/'anatomy.json')['tucks']
            required = required_tuck('hand_far',visible,layout['joints'],policy)
            Image.fromarray(required.astype('uint8')*255).save(CASE/'tucks/front_hand_far.png')
            if tuck_reports is not None:
                report = next(r for r in tuck_reports if r['piece']=='hand_far')
                report['required_pixels'] = int(required.sum())
                report['missing_pixels'] = int((required & (backing[...,3]==0)).sum())
    for part in layout['parts']:
        if part['logical_part'] == 'spear':
            part['bone'] = 'spear'
            part['presentation_anchor'] = anchor.copy()
    if case is not None and layout['facing'] == 'front':
        from humanoid_cutout.gait_continuations import nearest_donors
        parts = {p['name']:p for p in layout['parts']}
        tables = [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values())
        for table in tables:
            for name, recipe in list(table.items()):
                if parts[name]['logical_part'] not in TRANSFER_PARTS: continue
                targets = {(x,y) for x,y,_,_ in recipe['texels']}
                if parts[name]['logical_part']=='hand_far':
                    x0,y0 = parts[name]['offset']
                    support = front_hand_support()
                    targets = {(x,y) for x,y in targets if support[y+y0,x+x0]}
                elif parts[name]['logical_part']=='spear':
                    x0,y0 = parts[name]['offset']
                    support = front_shaft_support()
                    targets = {(x,y) for x,y in targets if support[y+y0,x+x0]}
                # A restored base tuck supersedes the old per-clip repair.
                # Continuation recipes may only add transparent source texels.
                x0,y0 = parts[name]['offset']
                current = source_pixels(case,parts[name])
                targets = {(x,y) for x,y in targets if current[y+y0,x+x0,3]==0}
                rebound = nearest_donors(case, layout, parts[name], targets)
                if 'clips' in recipe: rebound['clips'] = recipe['clips']
                table[name] = rebound


def errors(case, layout, samples):
    """Every sampled frame must transport the complete shaft with one matrix.

    Checks all item layers (including hidden wood and clip continuations),
    rather than only the named upper spear. Independent crop snapping is a
    failure too. Exact source ownership catches a split before motion starts.
    """
    result = []
    parts = {p['name']: p for p in layout['parts']}
    main = parts['spear']
    item = [p for p in layout['parts'] if p['logical_part'] == 'spear']
    meshes = {m['name'] for m in layout['joint_meshes']}
    declared_grip = layout['held_items']['spear'].get('source_grip')
    if declared_grip is None or not np.allclose(declared_grip,source_grip(layout),atol=TRANSFORM_EPSILON,rtol=0):
        result.append('spear: missing or changed painted grip anchor')
    for part in item:
        if part['bone'] != 'spear' or part['name'] in meshes:
            result.append(part['name'] + ': shaft split from rigid spear')
        if part.get('presentation_anchor', part['offset']) != main.get('presentation_anchor', main['offset']):
            result.append(part['name'] + ': shaft snap anchor differs')
        if part['bbox'] != main['bbox']:
            result.append(part['name'] + ': shaft layers do not share one rigid source canvas')
    if layout['facing'] == 'front':
        from PIL import Image
        paint = np.asarray(Image.open(case / layout['rest_source']).convert('RGBA'))
        hand = source_pixels(case, parts['hand_far'])
        if np.any((hand[..., 3] > 0) & transfer_domain(paint)):
            result.append('hand_far: wooden shaft pixels still ride the glove')
        if parts['hand_far']['z_index'] <= main['z_index']:
            result.append('hand_far: grip must be drawn over the shaft')
        expected = prior_partition('production' if (case / 'production_binding.json').exists() else 'source')
        for name in TRANSFER_PARTS:
            if not np.array_equal(source_pixels(case, parts[name]), expected[name]):
                result.append(name + ': approved shaft/glove ownership differs')
        supports={'spear':front_shaft_support(),'hand_far':front_hand_support()}
        tables=[layout.get('gait_continuations',{})]+list(layout.get('clip_continuations',{}).values())
        for table in tables:
            for name,recipe in table.items():
                part=parts[name]
                if part['logical_part'] not in supports: continue
                x0,y0=part['offset'];support=supports[part['logical_part']]
                for x,y,_,_ in recipe['texels']:
                    sx,sy=x+x0,y+y0
                    if not (0<=sx<255 and 0<=sy<255 and support[sy,sx]):
                        result.append(name+': continuation leaves registered shaft/glove support')
                        break
    else:
        from rr37_case import CASE
        from rr37_surfaces import rear_shaft
        from PIL import Image
        from rr43_outline import registration_paint
        paint = registration_paint()
        required = rear_shaft(paint)
        if np.any(required & (source_pixels(case, main)[...,3]==0)):
            result.append('rear spear: wood/outer fringe is still owned by another piece')
    if result: return sorted(set(result))
    rows = [r for r in samples['samples'] if r['view'] == layout['facing'] and r['kind'] == 'presented']
    if not rows: result.append('missing all-frame rigid spear evidence')
    for row in rows:
        reference = matrix(row['parts']['spear']['transform'])
        reference[:2, 2] -= reference[:2, :2] @ np.asarray(main['offset'])
        for part in item:
            transform = matrix(row['parts'][part['name']]['transform'])
            transform[:2, 2] -= transform[:2, :2] @ np.asarray(part['offset'])
            if not np.allclose(transform, reference, atol=TRANSFORM_EPSILON, rtol=0):
                result.append(f'{layout["facing"]}/{row["clip"]}/{row["frame"]}: {part["name"]} off rigid shaft line')
    if layout['facing'] == 'front':
        result += pixel_errors(case, layout, rows)
    return sorted(set(result))


def pixel_errors(case, layout, rows):
    """Rasterize the shaft core, item and occluding hand in every front frame.

    The one-pixel core is measured on the unchanged painting. It is transported
    once through the spear matrix; only the hand itself may occlude that line.
    Clip texture additions are included, so a pose-specific split cannot pass.
    """
    from maquette_motion import pixels
    from humanoid_cutout.canvas import for_case
    from humanoid_cutout.gait_continuations import texture
    parts = {p['name']: p for p in layout['parts']}
    main = parts['spear']
    core = np.zeros((255, 255, 4), np.uint8)
    for y in range(*FRONT_SHAFT_ROWS):
        core[y, round(FRONT_SHAFT_AXIS[0] + FRONT_SHAFT_AXIS[1]*y)] = 255
    cache, result = {}, []
    with for_case(case):
        for row in rows:
            if row['view'] != 'front': continue
            reference = matrix(row['parts']['spear']['transform'])
            reference[:2, 2] -= reference[:2, :2] @ np.asarray(main['offset'])
            required = pixels.render(core, reference)[..., 3] > 0
            occupied = np.zeros(required.shape, bool)
            for part in layout['parts']:
                if part['logical_part'] != 'spear' and part['name'] != 'hand_far': continue
                key = (row['clip'], part['name'])
                if key not in cache:
                    cache[key] = texture(case, layout, part, gait=row['clip']=='move', clip=row['clip'])
                image = pixels.render(cache[key], matrix(row['parts'][part['name']]['transform']))
                occupied |= image[..., 3] > 0
            missing = int((required & ~occupied).sum())
            if missing:
                result.append(f'front/{row["clip"]}/{row["frame"]}: shaft gap outside hand: {missing}px')
    return result
