#!/usr/bin/env python3
"""Prepare a certified real combat save, then validate or capture its pointer movie."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-05b/feedback3-movie')
RUN_ID = 'ptf-05b-feedback3-movie'
FPS = 30
# PNG movie frames cost wall time independently of the reason-only presentation.
CAPTURE_TIMEOUT_SECONDS = 600
FIXTURE_ARGS = [
    '--scenario', 'combat', '--seed', '1105',
    '--hand', 'dull_bolt,pale_spark,shadow_step,hamstring_shot',
    '--player-position', '2:4', '--enemy-types', 'crawler,crawler,crawler',
    '--enemy-positions', '6:4,4:4,1:4', '--terrain', 'wooden_crate@3:4',
    '--terrain-blocks-sight', '--umbra-stage', 'fringe',
    '--summary', 'ptf-05b feedback 3 reasons only: continuous real combat pointer sequence',
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--validate', action='store_true', help='Headless real-scene pointer rehearsal; no captures.')
    mode.add_argument('--capture', action='store_true', help='Windowed PNG movie and still proof; owner-run only.')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, 'tools/inspection_fixture.py', '--task-id', 'ptf-05b',
               '--run-id', RUN_ID, '--manifest', str(OUTPUT / 'fixture.json'), *FIXTURE_ARGS]
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end='', flush=True)
    (OUTPUT / 'fixture.log').write_text(result.stdout)
    if result.returncode:
        return result.returncode
    payloads = [line.removeprefix('INSPECTION_FIXTURE_VERIFIED ') for line in result.stdout.splitlines()
                if line.startswith('INSPECTION_FIXTURE_VERIFIED ')]
    if not payloads:
        raise RuntimeError('Fixture verifier did not supply a certified save path')
    fixture_dir = Path(json.loads(payloads[-1])['save_path']).parent
    if args.prepare_only:
        return 0
    env = dict(os.environ, PTF05_FIXTURE_DIR=str(fixture_dir), LABYRINTH_CEL_LOOK='all')
    if args.validate:
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'ptf-05b', '--stream',
                   '--', 'godot', '--headless', '--path', '.', '--script', 'tools/ptf05/movie.gd',
                   '--', '--validate-only']
    else:
        result = subprocess.run([sys.executable, 'tools/cel_look.py', 'build', '--if-stale'], cwd=ROOT)
        if result.returncode:
            return result.returncode
        # The visual runner supports engine movie flags through an executable wrapper.
        frames = OUTPUT / 'frames'
        frames.mkdir(exist_ok=True)
        wrapper = OUTPUT / 'movie-godot.sh'
        wrapper.write_text('#!/bin/sh\nexec godot --fixed-fps %d --write-movie %s --resolution 1920x1080 --windowed "$@"\n'
                           % (FPS, shlex.quote(str(frames / 'movie.png'))))
        wrapper.chmod(0o755)
        command = [sys.executable, 'tools/visual_probe_runner.py', '--task-id', 'ptf-05b',
                   '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
                   '--godot', str(wrapper), '--timeout', str(CAPTURE_TIMEOUT_SECONDS),
                   '--expect-size', '1920x1080', '--proof-contract', 'tools/ptf05/movie_contract.json',
                   '--result-manifest', str(OUTPUT / 'capture-manifest.json'),
                   'tools/ptf05/movie.gd', '--', '--fixed-fps', str(FPS)]
    print(shlex.join(command), flush=True)
    return subprocess.run(command, cwd=ROOT, env=env).returncode


if __name__ == '__main__':
    raise SystemExit(main())
