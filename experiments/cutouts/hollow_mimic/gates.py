"""rr-20 gates: certified source, real Bone2D evidence and native GPU pieces."""
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from case import ROOT, CASE, ASSETS, DIRECTOR, VIEWS, read_json, write_json, digest
sys.path.insert(0, str(ROOT / 'experiments/cutouts/arc_thrall'))
from rr11_knees import PRESENTED_TARGET_TOLERANCE_PX
from humanoid_cutout.walk_gates import report as knee_report
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.compiler import compile_motion
from maquette_motion.compiler import evaluate
from maquette_motion.features import source_pixels
from residue import count as green_pixels, feature_mask, clean_piece
import proof_records
from continuations import derivation_errors as continuation_errors

EPSILON = 0.0001  # Existing serialized Bone2D tolerance.


def protected_errors():
    errors = []
    for name, expected in read_json(CASE / 'protected_inputs.json').items():
        if digest(ROOT / name) != expected: errors.append('Protected/baseline bytes changed: ' + name)
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('Protected director copy changed')
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in VIEWS}
    data = read_json(CASE / 'compiled_motion.json')
    if compile_motion(DIRECTOR, 'hollow_mimic', layouts, data['projection']) != data: errors.append('Compiled director channels differ')
    if read_json(ASSETS / 'compiled_motion.json') != data: errors.append('Production director channels differ')
    return errors


def residue_derivation_errors(layout):
    """Reproduce only the authorized RGB changes from retained piece donors."""
    errors = []
    for name in layout['source_labels']:
        source = CASE / 'residue_source' / layout['facing']
        visible, hidden = [np.asarray(Image.open(source / f'{name}_{kind}.png').convert('RGBA')) for kind in ('visible', 'hidden')]
        expected = clean_piece(visible, hidden, feature_mask(CASE, layout, name))[:2]
        for is_hidden, pixels in zip((False, True), expected):
            actual = np.zeros_like(pixels)
            for part in layout['parts']:
                if part['logical_part'] == name and bool(part.get('hidden_material')) == is_hidden:
                    image = source_pixels(CASE, part)
                    actual[image[..., 3] > 0] = image[image[..., 3] > 0]
            if not np.array_equal(actual, pixels):
                errors.append(f'{layout["facing"]}/{name}: residue derivation differs ({"hidden" if is_hidden else "visible"})')
    return errors


def supports(layout, data, samples):
    """Stride stance is world planted; both boots plant during body actions."""
    from humanoid_cutout.anatomy import for_layout
    anatomy = for_layout(layout)
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    errors, rows, previous, overreach, boot_shifts = [], [], {}, [], []
    for sample in samples['samples']:
        if sample['view'] != view: continue
        clip, phase = sample['clip'], sample['phase']
        if clip == 'move': continue  # Both-leg stance is checked by shared walk gates.
        feet = ['foot_near', 'foot_far']
        for foot in feet:
            rest = np.asarray(layout['joints'][foot]['position'])
            target = rest.copy()
            clamped = False
            if clip == 'death':
                # Protected death raises the pelvis 1px at .15. A nearly
                # straight leg cannot keep that boot on the floor without
                # stretching. Retain the keys and report the unclamped reach,
                # exactly as the dense reach gate does for authored flings.
                from humanoid_cutout.action_direction import pose_values
                from humanoid_cutout.bone_contracts import fk_world
                values, modes = pose_values(data, view, clip, sample.get('direction_phase', phase))
                fk = fk_world(layout, values, modes, forward, step)
                hip = fk[foot.replace('foot_', 'thigh_')][:2, 2]
                a, b, c = [np.asarray(layout['joints'][foot.replace('foot_', n)]['position']) for n in ('thigh_', 'shin_', 'foot_')]
                length = np.linalg.norm(b - a) + np.linalg.norm(c - b)
                ray = target - hip
                if np.linalg.norm(ray) > length + EPSILON:
                    overreach.append({'foot': foot, 'phase': phase, 'kind': sample['kind'], 'excess_px': float(np.linalg.norm(ray) - length)})
                    target = hip + ray / np.linalg.norm(ray) * length
                    clamped = True
            actual = np.asarray(sample['bones'][foot]['global'][4:])
            presented = rest + np.rint(actual - rest) if sample['kind'] == 'presented' else actual
            if clip == 'death' and sample['kind'] == 'presented':
                boot_shifts.append(float(np.linalg.norm(presented - rest)))
            distance = float(np.linalg.norm(presented - target))
            limit = PRESENTED_TARGET_TOLERANCE_PX if sample['kind'] == 'presented' else anatomy['planted_tolerance_px'] + EPSILON
            if distance > limit: errors.append(f'{view}/{clip}/{foot}/{sample["kind"]}/{phase}: support target error {distance:.6f}')
            key = (clip, foot)
            if sample['kind'] == 'presented':
                last = previous.get(key)
                if last and not clamped and not last['clamped'] and sample['frame'] == last['frame'] + 1 and not np.array_equal(presented, last['presented']):
                    errors.append(f'{view}/{clip}/{foot}/frame {sample["frame"]}: support slid')
                previous[key] = {'frame': sample['frame'], 'presented': presented, 'clamped': clamped}
            rows.append({'clip': clip, 'foot': foot, 'kind': sample['kind'], 'frame': sample['frame'], 'target_error_px': distance})
    for clip in data['clips']:
        if clip == 'move': continue
        if not any(r['clip'] == clip and r['kind'] == 'presented' for r in rows): errors.append(view + '/' + clip + ': missing support evidence')
    return {'ok': not errors, 'errors': errors, 'rows': rows, 'overreach': overreach,
            'death_boot_clamp': {'director_accepted': True, 'maximum_presented_shift_px': max(boot_shifts, default=0.)},
            'maximum_target_error_px': max((r['target_error_px'] for r in rows), default=None)}


def headless(samples):
    errors = protected_errors()
    data, build, current = read_json(CASE/'compiled_motion.json'), read_json(CASE/'proof/build.json'), bindings(CASE)
    reports = {}
    for view in VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        cut = structure_errors(layout, build) + source_errors(CASE, layout, build) + residue_derivation_errors(layout) + continuation_errors(layout)
        for part in layout['parts']:
            if green_pixels(source_pixels(CASE, part), feature_mask(CASE, layout, part['logical_part'])):
                cut.append(view + '/' + part['name'] + ': chroma-key residue')
        if green_pixels(Image.open(CASE / layout['rest_source']).convert('RGBA'), feature_mask(CASE, layout)):
            cut.append(view + ': chroma-key residue in presentation rest')
        prod = read_json(ASSETS / (view + '.json'))
        for part in prod['parts']:
            if green_pixels(source_pixels(ASSETS, part), feature_mask(CASE, layout, part['logical_part'])):
                cut.append(view + '/' + part['name'] + ': production chroma-key residue')
        if green_pixels(Image.open(ASSETS / prod['rest_source']).convert('RGBA'), feature_mask(CASE, layout)):
            cut.append(view + ': chroma-key residue in production rest')
        bones = bone_errors(layout, data, samples, current)
        direction = direction_report(layout, data, samples, current, require_presented=True)
        reach = reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])
        knees, support = knee_report(layout, data, samples), supports(layout, data, samples)
        errors += cut + bones + direction['errors'] + reach['errors'] + knees['errors'] + support['errors']
        reports[view] = {'source_errors': cut, 'bone_errors': bones,
            'direction': {k: v for k, v in direction.items() if k != 'rows'}, 'reach': reach, 'knees': knees, 'supports': support}
    return {'ok': not errors, 'errors': sorted(set(errors)), 'native_pixels': False,
            'native_pending': 'director must run density/rest/native/idle/production/review', 'views': reports}


def native_residue_errors(capture, manifest, layouts):
    errors, used = [], set()
    masks = {}
    for row in manifest.get('feature_masks', []):
        key = (row['view'], row['clip'], row['frame'], row['name'])
        if key in masks: errors.append(str(key) + ': duplicate feature mask')
        masks[key] = row
    for row in manifest['frames']:
        image = Image.open(capture / row['file']).convert('RGBA')
        exempt = np.zeros((image.height, image.width), dtype=bool)
        for feature in layouts[row['view']].get('features', []):
            key = (row['view'], row['clip'], row['frame'], feature['name'])
            record = masks.get(key)
            if record is None:
                errors.append(str(key) + ': missing native feature mask')
                continue
            used.add(key)
            if digest(capture / record['file']) != record['sha256']:
                errors.append(str(key) + ': changed native feature mask')
                continue
            mask = Image.open(capture / record['file']).convert('RGBA')
            if mask.size != image.size:
                errors.append(str(key) + ': feature mask dimensions differ')
                continue
            exempt |= np.asarray(mask)[..., 3] > 0
        if green_pixels(image, exempt):
            errors.append(f'{row["view"]}/{row["clip"]}/{row["frame"]}: presented chroma-key residue')
    if set(masks) - used: errors.append('Unexpected native feature masks')
    return errors


def native(capture):
    spaces = []
    errors = native_errors(CASE, capture, failure_output=CASE/'proof/logs/native_failures', samples=proof_records.samples(), space_details=spaces)
    manifest = read_json(capture / 'frames.json')
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in VIEWS}
    errors += native_residue_errors(capture, manifest, layouts)
    return {'ok': not errors, 'errors': errors, 'native_pixels': True, 'rest_space': spaces,
            'pocket_failures': [{key:row[key] for key in ('view','clip','frame','failures')}
                                for row in spaces if row['failures']],
            'air_pocket_count':sum(len(row['air_pockets']) for row in spaces),
            'approved_detached_component_count':sum(len(row.get('source_components',[])) for row in spaces)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    result = native(args.native) if args.native else headless(proof_records.samples())
    proof_records.write('native_gates' if args.native else 'gates', result)
    print('RR20 %s GATES: %s (%d errors; both views)' % ('NATIVE' if args.native else 'SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH', 'PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for view, report in result.get('views', {}).items():
        print('RR20 %s SWING KNEES: %s (%d swings; minimum peak %.3f degrees)' % (view.upper(), 'PASS' if report['knees']['ok'] else 'FAIL', len(report['knees']['swings']), report['knees']['minimum_peak_bend_deg']))
        print('RR20 %s WALK: %s (6 swings; maximum fit %.3f px; maximum total drop %.3f px)' % (view.upper(), 'PASS' if report['knees']['ok'] else 'FAIL', report['knees']['maximum_fit_px'], report['knees']['maximum_total_pelvis_drop_px']))
        print('RR20 %s REACH: %s (%d paths; 1000 intervals; %d overreach reports)' % (view.upper(), 'PASS' if report['reach']['ok'] else 'FAIL', len(report['reach']['paths']), len(report['reach']['overreach'])))
        print('RR20 %s DEATH BOOT CLAMP: ACCEPTED (maximum presented shift %.0f px; motion unchanged)' % (view.upper(), report['supports']['death_boot_clamp']['maximum_presented_shift_px']))
    for error in result['errors'][:25]: print(error)
    return int(not result['ok'])


if __name__ == '__main__': raise SystemExit(main())
