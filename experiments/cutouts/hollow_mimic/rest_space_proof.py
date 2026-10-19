"""All-frame cross-rig CPU census of the shared source-space rule.

Read-only on reference rigs. The director's native captures remain required;
these estimates and every passed pocket's bounds go to rr-20's ignored logs.
"""
import argparse
from pathlib import Path

from case import ROOT, CASE, read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings
from humanoid_cutout.rest_space import DetachedSource, pockets
from humanoid_cutout.native_exceptions import load as exceptions, frame_errors, METRIC_RULES

RIGS = {'seer': 'hoarfrost_seer/rr10', 'thrall': 'arc_thrall/rr11',
        'mirror': 'glacial_mirror/rr18'}
PROGRESS_INTERVAL_FRAMES = 100


def census(name, samples):
    case = ROOT / 'experiments/cutouts' / RIGS[name]
    current = bindings(case)
    if samples['inputs'] != current: raise ValueError('Stale cross-rig pose evidence')
    approved = exceptions(case)  # Existing director exceptions remain untouched.
    views = {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        model = CpuPose(case, layout)
        detached = DetachedSource(case, layout)
        failures, records, retained_exceptions, count = [], [], [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented': continue
            layers, _ = model.layers(pose)
            space = pockets(layers)
            transforms = {key: part['transform'] for key, part in pose['parts'].items()}
            source = detached.report(layers, transforms)
            if space['air_pockets'] or space['failures'] or source['source_components']:
                records.append({'clip': pose['clip'], 'frame': pose['frame'], **space,
                                'source_components': source['source_components']})
            if space['failures'] or source['metrics']['stray_components']:
                metric = dict.fromkeys(METRIC_RULES, 0) | source['metrics']
                signatures = [{key: hole[key] for key in ('bbox', 'pixel_count')} for hole in space['failures']]
                errors = frame_errors((view, pose['clip'], pose['frame']), metric, signatures, approved)
                record = {'clip': pose['clip'], 'frame': pose['frame'], 'holes': space['failures'],
                          'detached': source['metrics'], 'errors': errors}
                (failures if errors else retained_exceptions).append(record)
            count += 1
            if count % PROGRESS_INTERVAL_FRAMES == 0:
                print(f'RR20 REST SPACE {name}/{view}: {count} frames; {len(failures)} failing', flush=True)
        views[view] = {'ok': not failures, 'frames': count, 'failures': failures, 'rest_space': records,
                       'retained_legacy_exception_frames': retained_exceptions,
                       'air_pocket_count': sum(len(row['air_pockets']) for row in records),
                       'approved_detached_component_count': sum(len(row['source_components']) for row in records)}
    if bindings(case) != current: raise ValueError('Reference rig inputs changed during census')
    result = {'ok': all(row['ok'] for row in views.values()), 'native_pixels': False,
              'scope': 'CPU estimate; no native acceptance', 'inputs': current, 'views': views}
    write_json(CASE / f'proof/logs/rest_space/{name}.json', result)
    for view, row in views.items():
        print('RR20 REST SPACE %s %s: %s (%d frames; %d air pockets; %d failing frames)' %
              (name.upper(), view.upper(), 'PASS' if row['ok'] else 'FAIL', row['frames'],
               row['air_pocket_count'], len(row['failures'])), flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rig', choices=RIGS, required=True)
    parser.add_argument('--samples', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(int(not census(args.rig, read_json(args.samples))['ok']))
