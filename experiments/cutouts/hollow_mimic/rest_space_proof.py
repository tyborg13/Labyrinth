"""All-frame cross-rig CPU census of the shared source-space rule.

Read-only on reference rigs. The director's native captures remain required;
these estimates and every passed pocket's bounds go to rr-20's ignored logs.
"""
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image

from case import ROOT, CASE, read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings
from humanoid_cutout.source_space import DetachedSource, pocket_report as pockets, gate_errors as frame_errors
from humanoid_cutout.native_exceptions import load as exceptions, METRIC_RULES
from maquette_motion import pixels

RIGS = {'seer': 'hoarfrost_seer/rr10', 'thrall': 'arc_thrall/rr11',
        'mirror': 'glacial_mirror/rr18', 'mimic': 'hollow_mimic/rr20',
        'capacitor': 'storm_capacitor/mq5', 'weaver': 'briar_weaver/mq9', 'mortar': 'slag_mortar/rr22'}
PROGRESS_INTERVAL_FRAMES = 100


class CapacitorPose:
    """Adapt existing rigid samples; preserve the approved glow table's RGB.

    Capacitor has no humanoid paint/tuck transport contract. Its own pixel
    gate checks that surface; this census checks only detached provenance.
    """
    def __init__(self, case, layout):
        sys.path.insert(0, str(ROOT / 'experiments/cutouts/storm_capacitor'))
        from rr17_contract import channels, held_phase
        self.channels, self.held_phase = channels, held_phase
        self.layout = layout
        self.sources = {part['name']: np.asarray(Image.open(case / part['file']).convert('RGBA'))
                        for part in layout['parts']}
        self.glows = {key: np.asarray(Image.open(case / path).convert('RGBA'))
                      for key, path in layout['glow_textures'].items()}

    def layers(self, pose):
        level = str(int(self.channels(pose['clip'], self.held_phase(pose['clip'], pose['phase'])).get('column.glow', 0)))
        layers = []
        for part in self.layout['parts']:
            source = self.glows[level] if part['name'] == 'column' else self.sources[part['name']]
            image = pixels.render(source, pixels.unpack(pose['parts'][part['name']]['transform']))
            layers.append((part, image, np.zeros_like(image)))
        return layers, {}


def census(name, samples):
    case = ROOT / 'experiments/cutouts' / RIGS[name]
    if name == 'capacitor':
        from maquette_motion.gates import input_bindings as capacitor_bindings
        current_bindings = capacitor_bindings
    else:
        current_bindings = bindings
    current = current_bindings(case)
    if samples['inputs'] != current: raise ValueError('Stale cross-rig pose evidence')
    # Retain historical files, but the canonical source-space gate does not
    # let their frame entries supply missing source provenance or surfaces.
    approved = exceptions(case)
    views = {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        if name == 'mortar':
            sys.path.insert(0, str(ROOT / 'experiments/cutouts/slag_mortar'))
            from rr22_cpu import CoveragePose
            model = CoveragePose(case, layout)
        else:
            model = CapacitorPose(case, layout) if name == 'capacitor' else CpuPose(case, layout)
        detached = DetachedSource(case, layout)
        failures, records, retained_exceptions, count = [], [], [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose.get('kind', 'presented') != 'presented': continue
            layers, _ = model.layers(pose)
            space = {'failures': [], 'air_pockets': []} if name == 'capacitor' else pockets(layers)
            transforms = {key: part['transform'] for key, part in pose['parts'].items()}
            source = detached.report(layers, transforms)
            if space['air_pockets'] or space['failures'] or source['source_components'] or source['unmatched_components']:
                records.append({'clip': pose['clip'], 'frame': pose['frame'], **space,
                                'source_components': source['source_components'],
                                'unmatched_components': source['unmatched_components']})
            if space['failures'] or source['metrics']['stray_components']:
                metric = dict.fromkeys(METRIC_RULES, 0) | source['metrics']
                signatures = [{key: hole[key] for key in ('bbox', 'pixel_count')} for hole in space['failures']]
                errors = frame_errors((view, pose['clip'], pose['frame']), metric, signatures, approved)
                record = {'clip': pose['clip'], 'frame': pose['frame'], 'holes': space['failures'],
                          'detached': source['metrics'], 'unmatched_components': source['unmatched_components'],
                          'errors': errors}
                (failures if errors else retained_exceptions).append(record)
            count += 1
            if count % PROGRESS_INTERVAL_FRAMES == 0:
                print(f'RR20 REST SPACE {name}/{view}: {count} frames; {len(failures)} failing', flush=True)
        views[view] = {'ok': not failures, 'frames': count, 'failures': failures, 'rest_space': records,
                       'retained_legacy_exception_frames': retained_exceptions,
                       'air_pocket_count': sum(len(row['air_pockets']) for row in records),
                       'approved_detached_component_count': sum(len(row['source_components']) for row in records)}
    if current_bindings(case) != current: raise ValueError('Reference rig inputs changed during census')
    result = {'ok': all(row['ok'] for row in views.values()), 'native_pixels': False,
              'scope': 'CPU estimate; no native acceptance', 'inputs': current, 'views': views}
    write_json(CASE / f'proof/logs/rest_space/{name}.json', result)
    for view, row in views.items():
        print('RR20 REST SPACE %s %s: %s (%d frames; %d air pockets; %d failing frames)' %
              (name.upper(), view.upper(), 'PASS' if row['ok'] else 'FAIL', row['frames'],
               row['air_pocket_count'], len(row['failures'])), flush=True)
    return result


def summary():
    """Keep compact counts and exact hash-bound per-rig diagnostics."""
    reports, views = {}, {}
    for name in RIGS:
        path = CASE / f'proof/logs/rest_space/{name}.json'
        report = read_json(path)
        reports[name] = {'file': str(path.relative_to(CASE / 'proof')), 'sha256': digest(path)}
        views[name] = {}
        for view, row in report['views'].items():
            unmatched = sum(len(frame['unmatched_components']) for frame in row['rest_space'])
            views[name][view] = {'ok': row['ok'], 'frames': row['frames'],
                'unmatched_detached_components': unmatched, 'air_pockets': row['air_pocket_count'],
                'approved_detached_components': row['approved_detached_component_count'],
                'failures': row['failures']}
            print(f'RR26 STRICT CENSUS {name.upper()} {view.upper()}: {unmatched} unmatched / {row["frames"]} frames')
    result = {'ok': all(v['ok'] for rig in views.values() for v in rig.values()),
        'native_pixels': False, 'scope': 'Seven-rig strict CPU census; native acceptance pending director',
        'views': views, 'rig_records': {name: {'full_samples': reference} for name, reference in reports.items()}}
    import proof_records
    proof_records.write('rest_space_summary', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rig', choices=RIGS)
    parser.add_argument('--samples', type=Path)
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    if args.summary:
        result = summary()
    else:
        if not args.rig or not args.samples: parser.error('--rig and --samples are required for a census')
        result = census(args.rig, read_json(args.samples))
    raise SystemExit(int(not result['ok']))
