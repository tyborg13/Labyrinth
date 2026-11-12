#!/usr/bin/env python3
"""Run ux-11's identical release/candidate real-scene proof, then compare Deck numbers.

No Git writes. The release project is a disposable git-archive snapshot. Import
artifacts are copied from this worktree (never shared writable directories).
Use --headless for logic/geometry only; --windowed is the owner's renderer run.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

PROJECT = Path(__file__).resolve().parents[2]
RELEASE = 'c9121c833'
OUTPUT_DEFAULT = Path('/private/tmp/labyrinth_codex/ux-11')
CAPTURE_TIMEOUT_SECONDS = 120  # Nine captures plus real scene entry/hand settles.
FIXTURE_SEED = 83
FIXTURE_HAND = 'dull_bolt,quick_stab,brace,patch_up,guarded_step'
FIXTURE_PLAYER_POSITION = '2:4'
FIXTURE_ENEMY_TYPE = 'harrier'
FIXTURE_ENEMY_POSITION = '4:4'


def run(command, project=PROJECT, log=None):
    print('COMMAND:', ' '.join(map(str, command)), flush=True)
    result = subprocess.run(list(map(str, command)), cwd=project, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            env=dict(os.environ, LABYRINTH_CEL_LOOK='all'))
    if log:
        Path(log).write_text(result.stdout)
    print(result.stdout, end='', flush=True)
    if result.returncode:
        raise RuntimeError(f'Command exited {result.returncode}; see {log}')
    return result.stdout


def prepare_release(output):
    """Extract committed release bytes, using neither a checkout nor a worktree."""
    target = output / 'release-project'
    marker = target / '.ux11-release'
    if marker.exists():
        if marker.read_text().strip() != RELEASE:
            raise RuntimeError('Release snapshot marker does not match')
        copy_cel_variants(target)
        return target
    if target.exists():
        raise RuntimeError(f'Refusing to reuse incomplete snapshot: {target}')
    target.mkdir()
    process = subprocess.Popen(['git', 'archive', '--format=tar', RELEASE],
                               cwd=PROJECT, stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
            archive.extractall(target)  # Trusted local Git tree; compatible with Python 3.9.
    finally:
        process.stdout.close()
    if process.wait():
        raise RuntimeError('git archive failed')
    # The imported textures/fonts are from this exact base; copy with macOS's
    # clone-capable cp so the baseline cannot modify candidate cache files.
    if (PROJECT / '.godot').exists():
        run(['cp', '-cR' if sys.platform == 'darwin' else '-a',
             PROJECT / '.godot', target / '.godot'], log=output / 'copy-import-cache.log')
    marker.write_text(RELEASE + '\n')
    copy_cel_variants(target)
    return target


def copy_cel_variants(target):
    # These approved, already-built assets are ignored by Git. Use the same
    # bytes for both builds; this proof must never generate or restyle art.
    source = PROJECT / 'cel_look_variants'
    destination = target / 'cel_look_variants'
    if not (source / 'manifest.json').is_file():
        raise RuntimeError('The approved cel_look_variants cache is required')
    if not destination.exists():
        shutil.copytree(source, destination)
    if (source / 'manifest.json').read_bytes() != (destination / 'manifest.json').read_bytes():
        raise RuntimeError('Release and candidate cel manifests differ')


def compare(output, mode):
    reports = {label: json.loads((output / f'{label}-{mode}' / 'measurements.json').read_text())
               for label in ('release', 'candidate')}
    for label, report in reports.items():
        if not report['ok'] or len(report['rows']) != 9 or report['renderer'] != (mode == 'windowed'):
            raise RuntimeError(f'Incomplete or failed {label} report')
    before = {r['state']: r for r in reports['release']['rows'] if r['size'] == '1280x800'}
    after = {r['state']: r for r in reports['candidate']['rows'] if r['size'] == '1280x800'}
    if before != after:
        differences = {state: {key: [before[state][key], after[state][key]]
                               for key in before[state] if before[state][key] != after[state][key]}
                       for state in before if before[state] != after[state]}
        (output / f'compact-differences-{mode}.json').write_text(json.dumps(differences, indent=2) + '\n')
        raise RuntimeError(f'1280x800 differs from release: {differences}')
    lines = [f'# ux-11 {mode} measurements', '',
             'Headless geometry is not renderer proof.' if mode == 'headless' else 'Exact SubViewport renders, cel look, 100% UI scale.', '',
             '| Build | Size | State | Hand top y | Visible cards | Tile width | Fit rect (x,y,w,h) | Drawn top y | Drawn bottom y | Bound below hand |',
             '|---|---|---|---:|---:|---:|---|---:|---:|---|']
    for label, report in reports.items():
        for row in report['rows']:
            lines.append('| ' + ' | '.join(str(value) for value in (
                label, row['size'], row['state'], row['hand_top_y'], row['visible_card_count'],
                row['tile_width'], row['fit_rect'], row['drawn_top_y'], row['drawn_bottom_y'],
                row['bound_below_hand'])) + ' |')
    lines += ['', 'UX11 COMPACT COMPARISON: PASS (all reported values exactly equal release in all three 1280x800 states)', '']
    (output / f'comparison-{mode}.md').write_text('\n'.join(lines))
    print(lines[-2])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--headless', action='store_true')
    modes.add_argument('--windowed', action='store_true')
    parser.add_argument('--output-dir', type=Path, default=OUTPUT_DEFAULT)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    mode = 'headless' if args.headless else 'windowed'
    # This is the exact inspection-fixture command used for both builds.
    fixture_log = run([sys.executable, 'tools/inspection_fixture.py', '--task-id', 'ux-11',
                       '--run-id', 'ux-11-proof-fixture', '--scenario', 'combat',
                       '--seed', FIXTURE_SEED, '--hand', FIXTURE_HAND,
                       '--player-position', FIXTURE_PLAYER_POSITION,
                       '--enemy-types', FIXTURE_ENEMY_TYPE, '--enemy-positions', FIXTURE_ENEMY_POSITION,
                       '--manifest', output / 'inspection-fixture.json'], log=output / f'fixture-{mode}.log')
    verified = re.search(r'^INSPECTION_FIXTURE_VERIFIED (.+)$', fixture_log, re.MULTILINE)
    if not verified:
        raise RuntimeError('No verified inspection fixture payload')
    save_path = json.loads(verified[1])['save_path']
    release_project = prepare_release(output)
    capture_dir = release_project / 'tools/ux11'
    capture_dir.mkdir(parents=True, exist_ok=True)
    for name in ('capture.gd', 'capture.gd.uid'):
        source = PROJECT / 'tools/ux11' / name
        if source.exists():
            shutil.copy2(source, capture_dir / name)
    for label, project in (('release', release_project), ('candidate', PROJECT)):
        destination = output / f'{label}-{mode}'
        if destination.exists():
            raise RuntimeError(f'Proof output must be fresh; move aside {destination}')
        script_args = ['--fixture-save', save_path, '--output-dir', destination]
        if label == 'candidate':
            script_args += ['--candidate']
        if args.headless:
            command = [sys.executable, PROJECT / 'tools/godot_task_runner.py', '--task-id', 'ux-11',
                       '--project', project, '--stream', '--', 'godot', '--headless', '--path', project,
                       '--script', 'tools/ux11/capture.gd', '--', *script_args, '--headless-check']
        else:
            command = [sys.executable, PROJECT / 'tools/visual_probe_runner.py', '--task-id', 'ux-11',
                       '--project', project, '--no-headless', '--display-driver', 'macos',
                       '--audio-driver', 'Dummy', '--timeout', CAPTURE_TIMEOUT_SECONDS,
                       '--expect-size', '1920x1080', '--expect-size', '1920x1200', '--expect-size', '1280x800',
                       '--proof-contract', PROJECT / 'tools/ux11/proof_contract.json',
                       '--result-manifest', output / f'{label}-renderer.json',
                       'tools/ux11/capture.gd', '--', *script_args]
        run(command, project=project, log=output / f'{label}-{mode}.log')
    compare(output, mode)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'UX11 PROOF FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
