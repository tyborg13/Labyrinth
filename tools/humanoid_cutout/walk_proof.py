"""walk-01 task proof; explicit invocation, never a permanent suite guard."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

from cutout_pipeline.cases import read_json, write_json
from .gates import bone_errors
from .walk_gates import report as walk_report, summary

ROOT = Path(__file__).resolve().parents[2]
TYPES = ('arc_thrall', 'ashen_reaver', 'briar_weaver', 'chainbound_gaoler',
         'frostglass_lancer', 'gale_herald', 'glacial_mirror', 'gloam_stalker',
         'slag_mortar', 'hoarfrost_seer')
MAX_FRAME_TRAVEL_PX = 8.
FLOAT_TOLERANCE_PX = .0001
REQUIRED_PHASES = (0., .1, .2, .3, .5, .7, .8, 1.)


def canonical_inventory(data, evidence):
    """Bind near-identical midpoint phases across Python/Godot float arithmetic.

    Raw evidence is retained. No pose is invented: every canonical phase must
    have an actual sampled pose within 1e-12. This avoids duplicate midpoint
    identities changing the gate inventory while preserving all geometry.
    """
    rows = [r for r in evidence['samples'] if r['kind'] != 'authored']
    for view, clips in data['view_tracks'].items():
        for clip, tracks in clips.items():
            expected = {0., 1.}
            for drop in data.get('view_held_drops', {}).get(view, {}).get(clip, {}).values():
                expected.update((drop['start'], (drop['start'] + drop['land']) / 2., drop['land']))
            for track in tracks:
                for index, key in enumerate(track['keys']):
                    expected.add(key['at'])
                    if index: expected.add((key['at'] + track['keys'][index - 1]['at']) / 2.)
            actual = [r for r in evidence['samples'] if r['view'] == view and
                      r['clip'] == clip and r['kind'] == 'authored']
            for phase in sorted(expected):
                row = min(actual, key=lambda r: abs(r['phase'] - phase))
                if abs(row['phase'] - phase) > 1e-12:
                    raise ValueError('Missing authored phase: %s/%s/%s' % (view, clip, phase))
                rows.append(dict(row, phase=phase))
    return dict(evidence, samples=rows)


def prove(samples, baseline, motion_dir=None, move_only=False):
    result = {'ok': True, 'native_pixels': False, 'rigs': {}, 'errors': []}
    for creature in TYPES:
        directory = ROOT / 'assets/units' / (creature + '_cutout')
        case = ROOT / read_json(directory / 'integration.json')['case']
        production = directory / 'humanoid_v2'
        motion_path = motion_dir / (creature + '.json') if motion_dir else production / 'compiled_motion.json'
        data = read_json(motion_path)
        if move_only:
            # Scope the existing gates to this task's move clip. Their
            # thresholds, IK checks, stance and knee logic are unchanged.
            data['clips'] = {'move': data['clips']['move']}
            data['view_tracks'] = {view: {'move': clips['move']} for view, clips in data['view_tracks'].items()}
        evidence = canonical_inventory(data, read_json(samples / (creature + '.json')))
        original = json.loads(subprocess.check_output(
            ['git', 'show', baseline + ':' + str((production / 'compiled_motion.json').relative_to(ROOT))]))
        failures, views = [], {}
        # Validate the actual production movement clock before giving those
        # rows to the unchanged walk gates. Retain standalone samples for the
        # general bone/inventory checks and every actual frame for walk checks.
        raw_evidence = read_json(samples / (creature + '.json'))
        movement_rows = raw_evidence['movement_samples']
        movement_count = round(data['clips']['move']['seconds'] * 60)
        for view in data['view_tracks']:
            rows = [r for r in movement_rows if r['view'] == view]
            if ([r['frame'] for r in rows] != list(range(movement_count + 1)) or
                    any(abs(r['phase'] - r['frame'] / movement_count) > 1e-12 or
                        r['kind'] != 'presented' or r['clip'] != 'move' for r in rows)):
                raise ValueError('Incomplete production movement inventory: ' + creature + '/' + view)
        movement = dict(evidence, samples=[r for r in evidence['samples'] if r['kind'] == 'authored'] + movement_rows)
        for view in data['view_tracks']:
            # The offline anatomy remains in its approved source case. Pixel
            # files and motion_data still resolve to the production rig.
            layout = read_json(production / (view + '.json'))
            layout['anatomy'] = read_json(case / 'anatomy.json')
            failures += bone_errors(layout, data, evidence, {
                'compiled_motion.json': hashlib.sha256(motion_path.read_bytes()).hexdigest()}, walk_samples=movement)
            if 'gait' in data['clips']['move']:
                walk = walk_report(layout, data, movement)
                views[view] = summary(walk)
                views[view]['maximum_target_error_px'] = max(
                    (leg['target_error_px'] for frame in walk['frames'] for leg in frame['legs'].values()),
                    default=0.)
                failures += walk['errors']
            for clip in original['clips']:
                if clip != 'move' and original['view_tracks'][view][clip] != read_json(motion_path)['view_tracks'][view][clip]:
                    failures.append(view + '/' + clip + ': non-move tracks changed')
            requested = read_json(samples / (creature + '_' + view + '_phases.json'))['samples']
            if [r['phase'] for r in requested] != list(REQUIRED_PHASES):
                failures.append(view + ': missing required phases')
        maximum = 0.
        for route in evidence['routes']:
            axis = np.array(route['axis'])
            positions = np.array([r['position'] for r in route['frames']])
            changes = np.diff(positions, axis=0)
            maximum = max(maximum, float(np.linalg.norm(changes, axis=1).max()))
            if (changes * np.sign(axis) < -FLOAT_TOLERANCE_PX).any():
                failures.append(str(route['direction']) + ': non-monotonic tile travel')
            for row in route['phases']:
                offset = np.array(row['offset'])
                if (offset * np.sign(axis) < -FLOAT_TOLERANCE_PX).any():
                    failures.append(str(route['direction']) + ': wrong root direction')
                if abs(float(axis[0] * offset[1] - axis[1] * offset[0])) > FLOAT_TOLERANCE_PX:
                    failures.append(str(route['direction']) + ': off-path root')
        if maximum > MAX_FRAME_TRAVEL_PX:
            failures.append('root frame jump %.6f > 8 px' % maximum)
        failures = sorted(set(failures))
        result['rigs'][creature] = {'ok': not failures, 'maximum_frame_travel_px': maximum,
                                    'views': views, 'errors': failures}
        result['errors'] += [creature + ': ' + error for error in failures]
        print('WALK-01 GATES: %s (%s; max frame travel %.6f px; %d errors)' %
              ('FAIL' if failures else 'PASS', creature, maximum, len(failures)))
    result['ok'] = not result['errors']
    write_json(samples / 'walk_proof.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True)
    parser.add_argument('--baseline', default='HEAD')
    parser.add_argument('--motion-dir', type=Path)
    parser.add_argument('--move-only', action='store_true')
    args = parser.parse_args()
    raise SystemExit(0 if prove(args.samples, args.baseline, args.motion_dir, args.move_only)['ok'] else 1)
