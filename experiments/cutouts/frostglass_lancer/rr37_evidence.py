"""Compact committed proof, with hash-bound full transforms in ignored logs."""
from collections import Counter
import argparse
import os
from pathlib import Path
import subprocess
import sys
from rr37_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest, CutoutError
from humanoid_cutout.gates import bindings

FULL_SAMPLES = CASE / 'proof/logs/samples.json'


def compact_samples(case=CASE):
    full_samples = case / 'proof/logs/samples.json'
    data = read_json(full_samples)
    result = {key: value for key, value in data.items() if key != 'samples'}
    counts = Counter((r['view'], r['clip'], r['kind']) for r in data['samples'])
    result['sample_counts'] = [dict(view=v, clip=c, kind=k, count=n)
                               for (v, c, k), n in sorted(counts.items())]
    result['full_samples'] = {'file': str(full_samples.relative_to(case / 'proof')),
                              'sha256': digest(full_samples)}
    write_json(case / 'proof/samples.json', result)
    # Small committed construction fixture, bound to the complete ignored log.
    # Tests read this fixture or generate fresh evidence in a temporary folder.
    selected = []
    compiled = read_json(case / 'compiled_motion.json')
    for view in compiled['view_tracks']:
        for clip, definition in compiled['clips'].items():
            rows = [r for r in data['samples'] if r['view'] == view and r['clip'] == clip and r['kind'] == 'presented']
            phases = [0., definition.get('contact', .5), 1.]
            indices = sorted({min(range(len(rows)), key=lambda i: abs(rows[i]['phase']-phase)) for phase in phases})
            selected.extend(rows[i] for i in indices)
    write_json(case / 'proof/cpu_poses.json', {'native_pixels': False, 'full_samples_sha256': digest(full_samples), 'samples': selected})
    print('RR37 COMPACT SAMPLES: PASS (%d poses; full transforms in ignored logs)' % len(data['samples']))
    return result


def refresh_samples(case=CASE):
    """Review must work without any ignored outputs from a prior checkout."""
    subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-37'), '--stream', '--',
        'godot', '--headless', '--path', '.', '--script', 'tests/rr37/samples.gd', '--',
        '--case', str(case), '--output', str(case / 'proof/logs/samples.json')], cwd=PROJECT, check=True)
    return compact_samples(case)


def native_current(case, capture):
    """Provenance preflight only; native_errors still verifies every pixel."""
    try:
        manifest = read_json(capture / 'frames.json')
    except CutoutError:
        return False
    return (isinstance(manifest, dict) and manifest.get('inputs') == bindings(case) and manifest.get('ok') is True
            and manifest.get('native_pixels') is True and manifest.get('size') == [1920, 1080]
            and manifest.get('ui_scale') == 1 and 'clip_scope' not in manifest)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, default=CASE)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--refresh', action='store_true')
    action.add_argument('--native-current', type=Path)
    args = parser.parse_args()
    if args.native_current is not None:
        current = native_current(args.case, args.native_current)
        print('RR37 NATIVE PROVENANCE: ' + ('CURRENT' if current else 'RECAPTURE REQUIRED (missing, incomplete or stale inputs)'))
        raise SystemExit(0 if current else 1)
    if args.refresh: refresh_samples(args.case)
    else: compact_samples(args.case)
