"""Lancer ownership, rigid spear and native component gates."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.gates import matrix
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion.silhouette import components
from maquette_motion.features import source_pixels

def draw_order_errors(layout, samples):
    view = layout['facing']
    camera, away = ('near', 'far') if view == 'front' else ('far', 'near')
    errors = []
    names = {p['name'] for p in layout['parts']}
    meshes = {m['name']: m for m in layout['joint_meshes']}
    def check(depths, tag):
        if set(depths) != names:
            errors.append(tag + ': incomplete painted depth evidence')
            return
        body = [depths[p['name']] for p in layout['parts']
                if p.get('logical_part',p['name']) in ('torso','pelvis','cape_near','cape_far')]
        for kind in ('arm_', 'hand_'):
            if depths[kind + camera] <= max(body): errors.append(tag + ': camera-side ' + kind + camera + ' below body/cape')
            for side in ('near', 'far'):
                if depths['head'] <= depths[kind + side]: errors.append(tag + ': head below ' + kind + side)
    check({p['name']: meshes.get(p['name'], p)['z_index'] for p in layout['parts']}, view + '/layout')
    rows = [r for r in samples['samples'] if r['view'] == view]
    if not rows: errors.append(view + ': missing draw order samples')
    for row in rows:
        check({n: p.get('z_index') for n, p in row['parts'].items() if 'z_index' in p},
              f'{view}/{row["clip"]}/{row["kind"]}/{row["frame"]}')
    return sorted(set(errors))


def floating_report(rest, frames, policy=None, layers=None):
    """Count every alpha>0 8-connected component, with declared release provenance."""
    baseline = len(components(np.asarray(rest)[..., 3] > 0, 8)[1])
    rows, errors = [], []
    for record, image in frames:
        occupied = np.asarray(image)[..., 3] > 0
        result = policy.report(occupied, layers(record), record['clip'], record['phase']) if policy else None
        count = result['components'] if result else len(components(occupied, 8)[1])
        row = {**record, 'components': count, 'rest_components': baseline,
               'released_components': result['released_components'] if result else []}
        rows.append(row)
        if result:
            errors += [f'{record}: ' + error for error in result['errors']]
        elif count > baseline: errors.append(f'{record}: floating pieces: {count} components > rest {baseline}')
    if not rows: errors.append('missing native component frames')
    return {'errors': errors, 'rest_components': baseline, 'frames': rows}


def native_components(case, capture, manifest):
    from humanoid_cutout.anatomy import load
    from humanoid_cutout.held_release import ComponentPolicy
    reports, errors = {}, []
    anatomy, data = load(case), read_json(case / 'compiled_motion.json')
    inventory = {}
    for row in manifest['pieces']:
        inventory.setdefault((row['view'], row['clip'], row['frame']), []).append(row)
    for view in ('front', 'rear'):
        rest = load_frame(capture / (view + '_rest.png')).convert('RGBA')
        layout = read_json(case / f'layouts/{view}.json')
        parts = {part['name']: part for part in layout['parts']}
        policy = ComponentPolicy(anatomy, data, layout, len(components(np.asarray(rest)[..., 3] > 0, 8)[1]))
        def layers(record):
            result = []
            rows = inventory.get((view, record['clip'], record['frame']), [])
            if len(rows) != len(parts) or {r['name'] for r in rows} != set(parts):
                errors.append(view + ': incomplete native release component layers')
            for row in rows:
                if frame_digest(capture / row['file']) != row['sha256']:
                    errors.append(view + ': native release component layer hash changed')
                result.append((parts[row['name']], np.asarray(load_frame(capture / row['file']).convert('RGBA')), None))
            return result
        def frames():
            for row in manifest['frames']:
                if row['view'] != view: continue
                if frame_digest(capture / row['file']) != row['sha256']:
                    errors.append(view + ': native component frame hash changed')
                    continue
                yield ({k: row[k] for k in ('clip', 'frame', 'phase')}, load_frame(capture / row['file']).convert('RGBA'))
        reports[view] = floating_report(rest, frames(), policy, layers)
        errors += reports[view]['errors']
    return {'errors': errors, 'views': reports, 'native_pixels': True}


def native_draw_order(layout, manifest):
    rows = {}
    for piece in manifest.get('pieces', []):
        if piece['view'] != layout['facing']: continue
        row = rows.setdefault((piece['clip'], piece['frame']), {
            'view': piece['view'], 'clip': piece['clip'], 'kind': 'native',
            'frame': piece['frame'], 'parts': {}})
        row['parts'][piece['name']] = {'z_index': piece['z_index']}
    return draw_order_errors(layout, {'samples': list(rows.values())})


def ownership_errors(case, layout):
    row = layout['pauldrons_ownership']
    errors = []
    if digest(case / row['file']) != row['sha256']: errors.append('pauldron mask changed')
    mask = np.asarray(Image.open(case / row['file'])) > 0
    parts = {p['name']: p for p in layout['parts']}
    paint = np.asarray(Image.open(case / layout['rest_source']))
    torso = source_pixels(case, parts['torso'])
    if not np.array_equal(torso[mask], paint[mask]): errors.append('pauldron pixel missing from torso')
    for name in ('arm_near', 'arm_far'):
        if np.any(source_pixels(case, parts[name])[mask, 3]): errors.append('pauldron pixel on ' + name)
    if parts['torso']['bone'] != 'torso' or any(m['name'] == 'torso' for m in layout['joint_meshes']): errors.append('torso is not rigid')
    if parts['pelvis']['bone'] != 'pelvis': errors.append('belt/pouches not on pelvis')
    return errors


def spear_errors(layout, data, samples):
    errors = []
    spear = next(p for p in layout['parts'] if p['name'] == 'spear')
    if spear['bone'] != 'spear' or layout['joints']['spear']['parent'] != 'hand_far': errors.append('spear hierarchy')
    if any(m['name'] == 'spear' for m in layout['joint_meshes']): errors.append('spear is skinned')
    for row in samples['samples']:
        if row['view'] != layout['facing']: continue
        item = matrix(row['bones']['spear']['global'])
        hand = matrix(row['bones']['hand_far']['global'])
        sprite = matrix(row['parts']['spear']['transform'])
        tolerance = 2 ** .5 if row['kind'] == 'presented' else .0001
        release = data['clips'][row['clip']].get('release_at', {}).get('spear', float('inf'))
        grip = layout['held_items']['spear'].get('source_grip')
        item_grip, hand_grip = item[:2,2], hand[:2,2]
        if grip is not None:
            item_grip = (item @ np.append(np.asarray(grip)-layout['joints']['spear']['position'],1))[:2]
            hand_grip = (hand @ np.append(np.asarray(grip)-layout['joints']['hand_far']['position'],1))[:2]
        if row['phase'] < release and np.linalg.norm(item_grip - hand_grip) > tolerance:
            errors.append(f'{row["view"]}/{row["clip"]}/{row["phase"]}: spear grip detached')
        if not np.allclose(item[:2, :2].T @ item[:2, :2], np.eye(2), atol=.0001): errors.append('spear bone deformed')
        if not np.allclose(sprite[:2, :2], item[:2, :2], atol=.0001): errors.append('spear sprite deformed')
        expected = item @ np.append(np.asarray(spear['offset']) - layout['joints']['spear']['position'], 1)
        if np.linalg.norm(sprite[:2, 2] - expected[:2]) > tolerance: errors.append('spear sprite detached')
    return sorted(set(errors))


def crystal_contact_errors(case, capture, manifest):
    from humanoid_cutout.canvas import for_case
    with for_case(case): return _crystal_contact_errors(case, capture, manifest)


def _crystal_contact_errors(case, capture, manifest):
    """Rigid source feature transported into actual native isolated layers."""
    from maquette_motion import pixels
    errors=[]
    data=read_json(case/'compiled_motion.json')
    for view in data['view_tracks']:
        layout=read_json(case/f'layouts/{view}.json')
        part=next(p for p in layout['parts'] if p['name']=='spear')
        feature=next(f for f in layout['features'] if f['name']=='crystal_spearhead')
        mask=np.asarray(Image.open(case/feature['mask']))>0
        rgba=np.zeros((*mask.shape,4),dtype=np.uint8);rgba[mask]=255
        x0,y0,x1,y1=part['bbox'];source=rgba[y0:y1,x0:x1]
        for clip in ('lunge','jab','cast','pin'):
            frames=[r for r in manifest['frames'] if r['view']==view and r['clip']==clip]
            if not frames: errors.append(view+'/'+clip+': missing crystal contact frame');continue
            row=min(frames,key=lambda r:abs(r['phase']-data['clips'][clip]['contact']))
            layers=[p for p in manifest['pieces'] if (p['view'],p['clip'],p['frame'])==(view,clip,row['frame'])]
            spear=next(p for p in layers if p['name']=='spear')
            tip=pixels.render(source,matrix(spear['transform']))[...,3]>0
            if not tip.any(): errors.append(view+'/'+clip+': empty transported crystal')
            for other in layers:
                if other['name']=='spear' or other['z_index']<=spear['z_index']: continue
                image=np.asarray(load_frame(capture/other['file']).convert('RGBA'))
                if (tip&(image[...,3]>0)).any(): errors.append(view+'/'+clip+': crystal hidden by '+other['name'])
    return errors
