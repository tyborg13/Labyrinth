#!/usr/bin/env python3
"""Director-only cap-01 before/after sequences with isolated capture outputs.

Before uses the unchanged full-PNG save path in the new writers; after changes
only storage. Both therefore bind exactly the same renderer, paint and gates.
No checkout switching, art regeneration, density rebakes or gate exceptions.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

from cutout_pipeline.cases import read_json
from humanoid_cutout.capture_equivalence import compare
from humanoid_cutout.production_gates import production_errors

PROJECT = Path(__file__).resolve().parents[1]
CASES = {'seer': ('hoarfrost_seer', 'rr10'), 'mortar': ('slag_mortar', 'rr22')}
CAPTURE_TIMEOUT_SECONDS = 3600  # Existing Seer native proof budget.
PRODUCTION_TIMEOUT_SECONDS = 3600  # Before baseline can take 30–50 minutes.
TASK_ID = 'cap-01'


def command_plan(output, phase, encoder_report=None):
    storage = ['--legacy-full-frames'] if phase == 'before' else ['--capture-encoding-file', str(encoder_report)] if encoder_report else []
    commands = []
    for name, (creature, number) in CASES.items():
        case = PROJECT / 'experiments/cutouts' / creature / number
        target = output / name
        def headless(script, arguments):
            return [sys.executable, 'tools/godot_task_runner.py', '--task-id', TASK_ID, '--stream', '--',
                    'godot', '--headless', '--path', '.', '--script', script, '--', *arguments]
        def visual(script, contract, destination, arguments=(), timeout=CAPTURE_TIMEOUT_SECONDS):
            return [sys.executable, 'tools/visual_probe_runner.py', '--task-id', TASK_ID, '--no-headless',
                    '--display-driver', 'macos', '--audio-driver', 'Dummy', '--timeout', str(timeout),
                    '--expect-size', '1920x1080', '--proof-contract', contract,
                    '--result-manifest', str(destination.parent / (destination.name + '-result.json')),
                    script, '--', '--case', str(case), '--output', str(destination), *arguments, *storage]
        samples = case / ('proof/samples.json' if name == 'seer' else 'proof/logs/samples_full.json')
        commands.append(headless(f'tests/{number}/samples.gd', ['--case', str(case), '--output', str(samples)]))
        if name == 'mortar':
            commands.append([sys.executable, f'experiments/cutouts/{creature}/{number}_records.py', 'samples'])
        commands.append(visual(f'tests/{number}/native_capture.gd', f'tests/{number}/render_contract.json', target / 'native'))
        commands.append([sys.executable, f'experiments/cutouts/{creature}/{number}_gates.py', '--native', str(target / 'native')])
        commands.append(visual(f'tests/{number}/native_capture.gd', f'tests/{number}/idle_contract.json', target / 'idle_native', ['--idle-comparison']))
        for mode, capture, filename in [('review', 'native', 'review.mp4'), ('idle', 'idle_native', 'idle.mp4'), ('sheets', 'native', 'contact_sheets')]:
            commands.append([sys.executable, '-m', 'humanoid_cutout.proof', mode, '--case', str(case),
                             '--capture', str(target / capture), '--output', str(target / filename)])
        for view in (('front', 'rear') if name == 'mortar' else ('front',)):
            commands.append(visual(f'tests/{number}/production_capture.gd', f'tests/{number}/production_contract.json',
                                   target / 'production' / view, ['--type', creature] + (['--opposite'] if view == 'rear' else []), PRODUCTION_TIMEOUT_SECONDS))
        if name == 'mortar':
            commands.append(visual('tests/gait01/move_capture.gd', 'tests/gait01/move_contract.json', target / 'gait_move_native'))
            commands.append([sys.executable, '-m', 'humanoid_cutout.move_sheet', '--case', str(case),
                             '--capture', str(target / 'gait_move_native'), '--output', str(target / 'gait_move_sheet.png')])
    return commands


def benchmark_plan(before, output):
    crop_plan = output.parent / (output.stem + '-crop-plan')
    return [
        [sys.executable, 'tools/godot_task_runner.py', '--task-id', TASK_ID, '--stream', '--',
         'godot', '--headless', '--path', '.', '--script', 'tests/rr10/production_capture.gd', '--',
         '--type', 'hoarfrost_seer', '--output', str(crop_plan), '--logic-only', '--validate-crop'],
        [sys.executable, 'tools/godot_task_runner.py', '--task-id', TASK_ID,
         '--timeout', str(PRODUCTION_TIMEOUT_SECONDS), '--stream', '--',
         'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/encoding_benchmark.gd', '--',
         '--capture', str(before / 'seer/production/front'), '--crop-plan', str(crop_plan / 'logic_frames.json'),
         '--output', str(output)]]


def collect(output):
    for name, (creature, number) in CASES.items():
        case = PROJECT / 'experiments/cutouts' / creature / number
        target = output / name
        for relative in ('native_gates.json', 'logs/native_gates_full.json'):
            source = case / 'proof' / relative
            if source.is_file():
                destination = target / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
        compiled = read_json(case / 'compiled_motion.json')
        for folder in sorted((target / 'production').iterdir()):
            if not folder.is_dir(): continue
            manifest = read_json(folder / 'frames.json')
            errors = production_errors(case, manifest, compiled)
            report = {'ok': not errors, 'errors': errors}
            (folder / 'production_gates.json').write_text(json.dumps(report, indent=2) + '\n')
            if errors: raise ValueError('Production gates failed: ' + str(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['before', 'after', 'benchmark', 'compare'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--encoder-report', type=Path)
    parser.add_argument('--before', type=Path)
    parser.add_argument('--after', type=Path)
    parser.add_argument('--print-commands', action='store_true')
    args = parser.parse_args()
    if args.phase == 'compare':
        if not args.before or not args.after: parser.error('compare needs --before and --after')
        def reports(root):
            return {str(p.relative_to(root)) for p in root.rglob('*.json')
                    if 'gates' in p.stem or p.name == 'source_space_pockets.json'}
        old, new = reports(args.before), reports(args.after)
        if old != new: raise ValueError('Gate report sets differ: ' + str(old ^ new))
        if not old: raise ValueError('No gate reports found')
        captures = {str(p.parent.relative_to(args.before)) for p in args.before.rglob('frames.json')}
        after_captures = {str(p.parent.relative_to(args.after)) for p in args.after.rglob('frames.json')}
        reels = {str(p.relative_to(args.before)) for p in args.before.rglob('*.mp4')}
        after_reels = {str(p.relative_to(args.after)) for p in args.after.rglob('*.mp4')}
        if captures != after_captures or reels != after_reels:
            raise ValueError('Capture or reel sets differ')
        result = compare(args.before, args.after, reports=sorted(old), reels=sorted(reels), captures=sorted(captures))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + '\n')
        print('CAPTURE EQUIVALENCE: ' + ('PASS' if result['ok'] else 'FAIL'))
        return int(not result['ok'])
    if args.phase == 'benchmark' and not args.before:
        parser.error('benchmark needs --before')
    commands = benchmark_plan(args.before.resolve(), args.output.resolve()) if args.phase == 'benchmark' else command_plan(args.output.resolve(), args.phase, args.encoder_report)
    if args.print_commands:
        for command in commands: print('cd ' + shlex.quote(str(PROJECT)) + ' && ' + shlex.join(command))
        return 0
    if args.phase == 'benchmark':
        for command in commands:
            subprocess.run(command, cwd=PROJECT, check=True)
        return 0
    if args.output.exists(): raise ValueError('Capture destination must be new: ' + str(args.output))
    args.output.mkdir(parents=True)
    env = dict(os.environ, PYTHONPATH=str(PROJECT / 'tools'), LABYRINTH_TASK_ID=TASK_ID)
    timings = []
    for command in commands:
        start = time.perf_counter()
        subprocess.run(command, cwd=PROJECT, env=env, check=True)
        seconds = time.perf_counter() - start
        if any('production_capture.gd' in part for part in command):
            folder = Path(command[command.index('--output') + 1])
            count = len(read_json(folder / 'frames.json')['frames'])
            size = sum(p.stat().st_size for p in folder.rglob('*') if p.is_file())
            timings.append({'capture': str(folder.relative_to(args.output.resolve())), 'seconds': seconds,
                            'GB': size / 1_000_000_000, 'frames_per_second': count / seconds,
                            'frames': count, 'bytes': size})
    collect(args.output)
    production = {}
    for name in CASES:
        rows = [r for r in timings if r['capture'].startswith(name + '/')]
        seconds, size = sum(r['seconds'] for r in rows), sum(r['bytes'] for r in rows)
        production[name] = {'seconds': seconds, 'GB': size / 1_000_000_000,
                            'target_met': seconds < 480 and size < 1_000_000_000}
    (args.output / 'capture_performance.json').write_text(json.dumps({'phase': args.phase, 'runs': timings,
        'per_rig_production': production, 'size_scope': 'all production files, including full references and proof exports'}, indent=2) + '\n')
    if args.phase == 'after' and not all(row['target_met'] for row in production.values()):
        print('CAPTURE DIRECTOR AFTER: FAIL (production time/size target; see capture_performance.json)')
        return 1
    print('CAPTURE DIRECTOR ' + args.phase.upper() + ': PASS; ' + str(args.output))
    return 0


if __name__ == '__main__': raise SystemExit(main())
