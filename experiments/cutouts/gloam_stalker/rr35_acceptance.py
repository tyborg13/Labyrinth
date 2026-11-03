"""rr-35's added gates, independent of construction and animation solvers."""
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.gates import matrix
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion.silhouette import components
from maquette_motion.features import source_pixels

SLASH_MINIMUM_REACH_PX = {'front': 16, 'rear': 18}  # Director feedback 2.
SLASH_WINDUP_PHASE = .3  # Protected director wind-up key; travel is report-only.


def carapace_errors(case, layout):
    row = layout['carapace_ownership']
    if digest(case / row['file']) != row['sha256']: return ['carapace mask changed']
    mask = np.asarray(Image.open(case / row['file']))[..., 3] > 0
    errors = []
    torso = next(p for p in layout['parts'] if p['name'] == 'torso')
    if torso['bone'] != 'torso' or any(m['name'] == 'torso' for m in layout['joint_meshes']):
        errors.append('carapace is not rigidly owned by torso')
    paint = np.asarray(Image.open(case / layout['rest_source']))
    actual = source_pixels(case, torso)
    if not np.array_equal(actual[mask], paint[mask]): errors.append('carapace pixels missing from torso')
    for part in layout['parts']:
        if part['name'] == 'torso' or part.get('hidden_material'): continue
        if np.any(source_pixels(case, part)[mask, 3]): errors.append('carapace pixel belongs to ' + part['name'])
    return errors


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
        body = [depths[n] for n in ('torso', 'pelvis', 'cape_near', 'cape_far')]
        for kind in ('arm_', 'hand_'):
            if depths[kind + camera] <= max(body): errors.append(tag + ': camera-side ' + kind + camera + ' below body/cape')
            if depths[kind + away] >= depths['torso']: errors.append(tag + ': non-camera ' + kind + away + ' above torso')
            for side in ('near', 'far'):
                if depths['head'] <= depths[kind + side]: errors.append(tag + ': head below ' + kind + side)
    check({p['name']: meshes.get(p['name'], p)['z_index'] for p in layout['parts']}, view + '/layout')
    rows = [r for r in samples['samples'] if r['view'] == view]
    if not rows: errors.append(view + ': missing draw order samples')
    for row in rows:
        check({n: p.get('z_index') for n, p in row['parts'].items() if 'z_index' in p},
              f'{view}/{row["clip"]}/{row["kind"]}/{row["frame"]}')
    return sorted(set(errors))


def slash_report(layout, data, samples):
    view, name = layout['facing'], 'hand_far'
    part = next(p for p in layout['parts'] if p['name'] == name)
    # Endpoint comes from the certified maquette, registered onto owned paint.
    tip = np.asarray(layout['blade_tips'][name]['source'])
    local = np.append(tip - part['offset'], 1)
    contact = data['clips']['slash']['contact']
    rows = [r for r in samples['samples'] if r['view'] == view and r['clip'] == 'slash' and r['kind'] == 'authored']
    rest = next((r for r in rows if r['phase'] == 0), None)
    at = next((r for r in rows if r['phase'] == contact), None)
    windup = next((r for r in rows if r['phase'] == SLASH_WINDUP_PHASE), None)
    if rest is None or at is None or windup is None:
        return {'errors': [view + ': missing slash rest/wind-up/contact evidence']}
    start = matrix(rest['parts'][name]['transform']) @ local
    end = matrix(at['parts'][name]['transform']) @ local
    distance = float(np.linalg.norm(end[:2] - start[:2]))
    raised = matrix(windup['parts'][name]['transform']) @ local
    travel = float(np.linalg.norm(end[:2] - raised[:2]))
    minimum = SLASH_MINIMUM_REACH_PX[view]
    return {'leading_blade': name, 'source_tip': tip.tolist(), 'contact': contact,
            'rest_tip': start[:2].tolist(), 'contact_tip': end[:2].tolist(), 'distance_px': distance,
            'minimum_px': minimum, 'windup_phase': SLASH_WINDUP_PHASE,
            'windup_tip': raised[:2].tolist(), 'windup_to_contact_travel_px': travel,
            'travel_report_only': True,
            'errors': [] if distance >= minimum else [f'{view}: slash tip reach {distance:.6f} px < {minimum}']}


def floating_report(rest, frames):
    """Count every alpha>0 8-connected component, with no size exemptions."""
    baseline = len(components(np.asarray(rest)[..., 3] > 0, 8)[1])
    rows, errors = [], []
    for record, image in frames:
        count = len(components(np.asarray(image)[..., 3] > 0, 8)[1])
        row = {**record, 'components': count, 'rest_components': baseline}
        rows.append(row)
        if count > baseline: errors.append(f'{record}: floating pieces: {count} components > rest {baseline}')
    if not rows: errors.append('missing native component frames')
    return {'errors': errors, 'rest_components': baseline, 'frames': rows}


def native_components(capture, manifest):
    reports, errors = {}, []
    for view in ('front', 'rear'):
        rest = load_frame(capture / (view + '_rest.png')).convert('RGBA')
        def frames():
            for row in manifest['frames']:
                if row['view'] != view: continue
                if frame_digest(capture / row['file']) != row['sha256']:
                    errors.append(view + ': native component frame hash changed')
                    continue
                yield ({k: row[k] for k in ('clip', 'frame', 'phase')}, load_frame(capture / row['file']).convert('RGBA'))
        reports[view] = floating_report(rest, frames())
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
