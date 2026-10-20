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
import tempfile
import subprocess
import sys
import time

from cutout_pipeline.cases import read_json
from humanoid_cutout.capture_equivalence import compare, json_bytes
from humanoid_cutout.bone_evidence import read_report
from capture_inventory import CASES, validate, exit_sets
from capture_production import compare_production, manifests, validate_manifest, PRODUCTION_PHASE_FIELD

PROJECT = Path(__file__).resolve().parents[1]
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
        samples = target / 'samples.json'
        commands.append(headless(f'tests/{number}/samples.gd', ['--case', str(case), '--output', str(samples)]))
        commands.append(visual(f'tests/{number}/native_capture.gd', f'tests/{number}/render_contract.json', target / 'native'))
        commands.append(gate_command(case, target, samples, target / 'native', creature, number))
        commands.append(visual(f'tests/{number}/native_capture.gd', f'tests/{number}/idle_contract.json', target / 'idle_native', ['--idle-comparison']))
        for mode, capture, filename in [('review', 'native', 'review.mp4'), ('idle', 'idle_native', 'idle.mp4'), ('sheets', 'native', 'contact_sheets')]:
            commands.append([sys.executable, 'tools/capture_review.py', mode, '--case', str(case),
                             '--capture', str(target / capture), '--output', str(target / filename),
                             '--gate-report', str(target / 'native_gates.json')])
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


def gate_command(case, target, samples, native, creature, number):
    return [sys.executable, 'tools/capture_gate_runner.py', '--case', str(case),
            '--output', str(target), '--samples', str(samples), '--native', str(native),
            '--script', str(PROJECT / f'experiments/cutouts/{creature}/{number}_gates.py')]


def execute(command, env):
    """A completed gate with errors is evidence; a missing report is an error."""
    is_gate = 'tools/capture_gate_runner.py' in command
    result = subprocess.run(command, cwd=PROJECT, env=env, check=not is_gate)
    if is_gate:
        target = Path(command[command.index('--output') + 1])
        prefix = 'production' if '--production' in command else 'native'
        report = read_json(target / (prefix + '_gates.json'))
        if (result.returncode == 0) != report['ok']:
            raise ValueError('Gate process/JSON outcome differs: ' + str(target / (prefix + '_gates.json')))
        (target / (prefix + '_gate_exit.json')).write_text(json.dumps({'exit_code': result.returncode}) + '\n')
    return result


def collect(output, env):
    for name, (creature, number) in CASES.items():
        case = PROJECT / 'experiments/cutouts' / creature / number
        folder = output / name / 'production'
        for view, manifest in manifests(case, folder):
            validate_manifest(manifest, read_json(case / 'compiled_motion.json'), folder / view / 'frames.json')
        execute(production_gate_command(case, folder, folder), env)


def production_gate_command(case, capture, output):
    return [sys.executable, 'tools/capture_gate_runner.py', '--production', '--case', str(case),
            '--native', str(capture), '--output', str(output)]


def complete_legacy_gate_exits(root, env):
    """Recover observed process exits for the director's r0 capture snapshots.

    Run the same canonical gates headlessly against unchanged source bindings,
    with private proof records. Require byte-equivalent JSON to the saved r0
    reports before adding the previously unrecorded exit status. Never infer an
    exit code from ok=true/false, rebind a capture, or touch case proof records.
    """
    for name, (creature, number) in CASES.items():
        target = root / name
        case = PROJECT / 'experiments/cutouts' / creature / number
        if not (target / 'native_gate_exit.json').is_file():
            recover_native_exit(root, target, case, creature, number, env)
        folder = target / 'production'
        status = folder / 'production_gate_exit.json'
        if not status.is_file():
            with tempfile.TemporaryDirectory(prefix='cap01-production-gate-', dir=root.parent) as temporary:
                evaluation = Path(temporary)
                execute(production_gate_command(case, folder, evaluation), env)
                if json_bytes(folder / 'production_gates.json', ()) != json_bytes(evaluation / 'production_gates.json', ()):
                    raise ValueError('Re-evaluated gate JSON differs: ' + str(folder / 'production_gates.json'))
                status.write_bytes((evaluation / 'production_gate_exit.json').read_bytes())


def recover_native_exit(root, target, case, creature, number, env):
    with tempfile.TemporaryDirectory(prefix='cap01-gate-', dir=root.parent) as temporary:
        evaluation = Path(temporary)
        samples = evaluation / 'samples.json'
        try:
            sampled = read_report(case)
        except (OSError, ValueError):
            sampled = {}
        if sampled.get('inputs') == read_json(target / 'native/frames.json').get('inputs'):
            samples.write_text(json.dumps(sampled))
        else:
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', TASK_ID, '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', f'tests/{number}/samples.gd', '--',
                       '--case', str(case), '--output', str(samples)]
            execute(command, env)
        execute(gate_command(case, evaluation, samples, target / 'native', creature, number), env)
        for relative in ('native_gates.json', *(['logs/native_gates_full.json'] if number == 'rr22' else [])):
            if json_bytes(target / relative, (root.resolve(), evaluation.resolve())) != json_bytes(evaluation / relative, (root.resolve(), evaluation.resolve())):
                raise ValueError('Re-evaluated gate JSON differs: ' + str(target / relative))
        (target / 'native_gate_exit.json').write_bytes((evaluation / 'native_gate_exit.json').read_bytes())


def compare_complete(before, after, output):
    captures, reports, reels = validate(before, PROJECT, gate_exits=False, decode_reels=True)
    validate(after, PROJECT, gate_exits=False, decode_reels=True)
    env = dict(os.environ, PYTHONPATH=str(PROJECT / 'tools'), LABYRINTH_TASK_ID=TASK_ID)
    for root in (before, after):
        performance = root / 'capture_performance.json'
        if performance.is_file() and read_json(performance).get('gate_evidence_version') == 3:
            validate(root, PROJECT)
        else:
            complete_legacy_gate_exits(root, env)
        validate(root, PROJECT)
    reports |= exit_sets()
    native = {relative for relative in captures if '/production/' not in relative}
    result = compare(before, after, reports=sorted(reports), reels=sorted(reels), captures=sorted(native))
    result['production'] = {}
    for name, (creature, number) in CASES.items():
        case = PROJECT / 'experiments/cutouts' / creature / number
        production = compare_production(case, before / name / 'production', after / name / 'production',
                                        phase_field=PRODUCTION_PHASE_FIELD)
        result['production'][name] = production
        result['errors'].extend(production['errors'])
    result['ok'] = not result['errors']
    result['gate_exit_codes'] = {relative: read_json(before / relative)['exit_code'] for relative in sorted(exit_sets())}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    return result


def validate_existing(before, output):
    """Reuse captured evidence, repairing only r1's per-folder gate collection."""
    validate(before, PROJECT, gate_exits=False, decode_reels=True, production_reports=False)
    env = dict(os.environ, PYTHONPATH=str(PROJECT / 'tools'), LABYRINTH_TASK_ID=TASK_ID)
    collect(before, env)
    complete_legacy_gate_exits(before, env)
    validate(before, PROJECT, decode_reels=True)
    return write_validation_report(before, output)


def write_validation_report(before, output):
    result = {'ok': True, 'capture': str(before), 'production': {},
              'phase_policy': 'finite [0,1], canonical progression span, exact named contacts',
              'production_match_phase': PRODUCTION_PHASE_FIELD,
              'gate_exit_codes': {relative: read_json(before / relative)['exit_code'] for relative in sorted(exit_sets())}}
    for name, (creature, number) in CASES.items():
        case = PROJECT / 'experiments/cutouts' / creature / number
        data = read_json(case / 'compiled_motion.json')
        result['production'][name] = {view: validate_manifest(manifest, data, before / name / 'production' / view / 'frames.json')
                                      for view, manifest in manifests(case, before / name / 'production')}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['before', 'after', 'benchmark', 'compare', 'validate'])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--encoder-report', type=Path)
    parser.add_argument('--before', type=Path)
    parser.add_argument('--after', type=Path)
    parser.add_argument('--print-commands', action='store_true')
    args = parser.parse_args()
    if args.phase == 'validate':
        if not args.before: parser.error('validate needs --before')
        args.before = args.before.resolve()
        args.output = (args.output or args.before / 'capture_validation.json').resolve()
        try:
            validate_existing(args.before, args.output)
        except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps({'ok': False, 'errors': [str(error)]}, indent=2) + '\n')
            print('CAPTURE VALIDATION: FAIL; ' + str(error))
            return 1
        print('CAPTURE VALIDATION: PASS; ' + str(args.output))
        return 0
    if not args.output: parser.error(args.phase + ' needs --output')
    if args.phase == 'compare':
        if not args.before or not args.after: parser.error('compare needs --before and --after')
        try:
            result = compare_complete(args.before.resolve(), args.after.resolve(), args.output.resolve())
        except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
            result = {'ok': False, 'errors': [str(error)]}
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2) + '\n')
        for error in result.get('errors', []): print(error)
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
        execute(command, env)
        seconds = time.perf_counter() - start
        if any('production_capture.gd' in part for part in command):
            folder = Path(command[command.index('--output') + 1])
            count = len(read_json(folder / 'frames.json')['frames'])
            size = sum(p.stat().st_size for p in folder.rglob('*') if p.is_file())
            timings.append({'capture': str(folder.relative_to(args.output.resolve())), 'seconds': seconds,
                            'GB': size / 1_000_000_000, 'frames_per_second': count / seconds,
                            'frames': count, 'bytes': size})
    collect(args.output, env)
    validate(args.output, PROJECT, decode_reels=True)
    write_validation_report(args.output, args.output / 'capture_validation.json')
    production = {}
    for name in CASES:
        rows = [r for r in timings if r['capture'].startswith(name + '/')]
        seconds, size = sum(r['seconds'] for r in rows), sum(r['bytes'] for r in rows)
        production[name] = {'seconds': seconds, 'GB': size / 1_000_000_000,
                            'target_met': seconds < 480 and size < 1_000_000_000}
    (args.output / 'capture_performance.json').write_text(json.dumps({'phase': args.phase, 'gate_evidence_version': 3, 'runs': timings,
        'per_rig_production': production, 'size_scope': 'all production files, including full references and proof exports'}, indent=2) + '\n')
    if args.phase == 'after' and not all(row['target_met'] for row in production.values()):
        print('CAPTURE DIRECTOR AFTER: FAIL (production time/size target; see capture_performance.json)')
        return 1
    print('CAPTURE DIRECTOR ' + args.phase.upper() + ': PASS; ' + str(args.output))
    return 0


if __name__ == '__main__': raise SystemExit(main())
