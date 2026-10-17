#!/usr/bin/env python3
"""Director-only Blender captures and old/new solo-mask gates.

Use --print-only in the worker sandbox. No window-server/Blender attempt is
made there. All output is isolated; approved jobs and specs are read-only.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[3]
PROOF_DEFAULTS = {'baseline_ref': '61b0c2f0ba8793db3499038de3d959b1a6f220d4',
                  'blender': '/Applications/Blender.app/Contents/MacOS/Blender',
                  'output': '/private/tmp/labyrinth_codex/mq-02/director'}
HUMANOIDS = ('chainbound_gaoler', 'frostglass_lancer', 'lightning_wisp', 'shale_bloomer')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blender', default=PROOF_DEFAULTS['blender'])
    parser.add_argument('--out', type=Path, default=Path(PROOF_DEFAULTS['output']))
    parser.add_argument('--baseline-ref', default=PROOF_DEFAULTS['baseline_ref'])
    parser.add_argument('--print-only', action='store_true')
    args = parser.parse_args()
    base = Path('spec/art_identity/maquettes')
    commands = []
    for name in HUMANOIDS:
        for version, builder in [('legacy', args.out / 'legacy_humanoid.py'), ('shared', base / 'humanoid.py')]:
            commands.append([args.blender, '-b', '--factory-startup', '-P', str(builder), '--', str(base / name / 'spec.json'), str(args.out / name / version)])
    for version, builder in [('legacy', args.out / 'legacy_shrike.py'), ('shared', base / 'gust_shrike.py')]:
        commands.append([args.blender, '-b', '--factory-startup', '-P', str(builder), '--', str(args.out / 'gust_shrike' / version)])
    commands.append([args.blender, '-b', '--factory-startup', '-P', str(base / 'humanoid.py'), '--', str(base / 'frostglass_lancer/spec_r2.json'), str(args.out / 'lancer_r2')])
    for name in (*HUMANOIDS, 'gust_shrike'):
        spec = args.out / 'gust_shrike/shared/spec.json' if name == 'gust_shrike' else base / name / 'spec.json'
        commands.append([sys.executable, 'tools/maquette_fit.py', 'compare', '--spec', str(spec), '--baseline', str(args.out / name / 'legacy'), '--candidate', str(args.out / name / 'shared'), '--out', str(args.out / name / 'comparison'), '--require-gate'])
        commands.append([sys.executable, 'tools/maquette_fit.py', 'compare', '--spec', str(spec), '--baseline', str(args.out / name / 'shared'), '--out', str(args.out / name / 'raster_comparison'), '--require-gate'])
    for command in commands:
        print('FRONT_YAW=0 ' + shlex.join(command), flush=True)
    if args.print_only:
        return 0
    args.out.mkdir(parents=True, exist_ok=True)
    for filename, original in [('legacy_humanoid.py', 'humanoid.py'), ('legacy_shrike.py', 'gust_shrike.py')]:
        source = subprocess.run(['git', 'show', f'{args.baseline_ref}:{base / original}'], cwd=PROJECT, check=True, capture_output=True).stdout
        (args.out / filename).write_bytes(source)
    environment = dict(os.environ, FRONT_YAW='0')
    statuses = []
    for command in commands:
        process = subprocess.run(command, cwd=PROJECT, env=environment)
        statuses.append({'command': command, 'returncode': process.returncode})
        # Capture failures stop immediately; comparison failures are collected.
        if process.returncode and command[0] == args.blender:
            break
    (args.out / 'director_results.json').write_text(json.dumps(statuses, indent=2) + '\n')
    passed = len(statuses) == len(commands) and all(not entry['returncode'] for entry in statuses)
    print('MAQUETTE_DIRECTOR_PROOF: ' + ('PASS' if passed else 'FAIL'))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
