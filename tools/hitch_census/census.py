#!/usr/bin/env python3
"""Serial native hitch collection; launched Godot always uses the task runner."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shlex
import shutil
import signal
import subprocess
import sys
import time

import host_load

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = Path('/private/tmp/labyrinth_codex/perf-109/native')
DEFAULT_TASK_ID = 'perf-109'
MIN_FREE_BYTES = 45_000_000_000
SMOKE_CAP_BYTES = 10_000_000_000
GUARD_POLL_SECONDS = 1.0
SIZE_POLL_SECONDS = 10.0
SMOKE_SECONDS = 900
RUNNER_MARGIN_SECONDS = 90
PREPARE_TIMEOUT_SECONDS = 1800
QUICK_TASK_ID = 'cen-02'
QUICK_DEMO_SECONDS = 480
QUICK_TOUR_SECONDS = 210
QUICK_TOUR_SEED = 83
QUICK_RUNNER_MARGIN_SECONDS = 15
QUICK_DEADLINE_SECONDS = 1770  # Leave 30 seconds for owned-process termination.
RUNNER_TIMEOUT_EXIT = 124
WINDOW_CORNER_POSITION = "24,24"  # Existing visual-probe corner, without resizing.
CEL_REFERENCE_FOLDER = 'spec/peer_benchmark/staged/cel-01'
DECK_WINDOW_OVERRIDE = """; Generated: tools/hitch_census/census.py (Deck pixel load; copy only).
[display]
window/size/mode=0
window/size/window_width_override=1280
window/size/window_height_override=800
window/dpi/allow_hidpi=false
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale=1.15
"""
SOURCE_FOLDERS = ('assets', 'addons', 'data', 'fonts', 'scenes', 'scripts', 'shaders', 'themes', 'tools', 'tests')


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def write_window_override(project):
    if project.resolve() == ROOT.resolve():
        raise RuntimeError('Deck window override belongs only in the census project copy')
    (project / 'override.cfg').write_text(DECK_WINDOW_OVERRIDE)


def read_startup_viewport(directory):
    try:
        return json.loads((directory / 'viewport.json').read_text())
    except (OSError, json.JSONDecodeError):
        # The engine may still be writing, or may have failed before startup.
        return None


def size_bytes(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file() and not p.is_symlink())


def guard(output, cap):
    free = shutil.disk_usage(output).free
    if free < MIN_FREE_BYTES:
        raise RuntimeError(f'free disk {free} bytes is below {MIN_FREE_BYTES}; stopped')
    used = size_bytes(output)
    if used >= cap:
        raise RuntimeError(f'output {used} bytes reached cap {cap}; stopped')


def clone(source, target):
    if platform.system() == 'Darwin':
        subprocess.run(['cp', '-cR', str(source), str(target)], check=True)
    elif source.is_dir():
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def prepare(output, import_cache=None, cel_cache=None, task_id=DEFAULT_TASK_ID):
    output.mkdir(parents=True, exist_ok=True)
    guard(output, SMOKE_CAP_BYTES)
    project = output / 'project'
    if project.exists():
        raise RuntimeError('prepared project already exists; choose a fresh output (no overwrites)')
    project.mkdir()
    for name in (*SOURCE_FOLDERS, 'project.godot'):
        source = ROOT / name
        if source.exists(): clone(source, project / name)
    if import_cache:
        clone(import_cache, project / '.godot')
    elif (ROOT / '.godot').exists():
        clone(ROOT / '.godot', project / '.godot')
    selected_cel_cache = cel_cache or ROOT / 'cel_look_variants'
    if selected_cel_cache.exists(): clone(selected_cel_cache, project / 'cel_look_variants')
    reference = project / CEL_REFERENCE_FOLDER
    reference.parent.mkdir(parents=True, exist_ok=True)
    clone(ROOT / CEL_REFERENCE_FOLDER, reference)
    files = [p for name in (*SOURCE_FOLDERS, 'project.godot', CEL_REFERENCE_FOLDER) for p in
             ((ROOT / name).rglob('*') if (ROOT / name).is_dir() else [ROOT / name]) if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc']
    write_json(output / 'source.json', {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'hashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        'import_cache_source': str(import_cache) if import_cache else None,
        'cel_cache_source': str(selected_cel_cache) if selected_cel_cache.exists() else None,
        'note': 'Frozen source/assets; imported resource cache is not a warmed user shader cache.'})
    write_window_override(project)
    # Intentional import bootstrap in the disposable copy, never an editor parser scan.
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', task_id, '--project', str(project),
               '--timeout', str(PREPARE_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', str(project), '--import']
    with (output / 'prepare.log').open('w') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (output / 'cel-build.log').open('w') as log:
        subprocess.run([sys.executable, 'tools/cel_look.py', 'build', '--if-stale'], cwd=project, stdout=log, stderr=subprocess.STDOUT, check=True)
    guard(output, SMOKE_CAP_BYTES)
    print(f'HITCH PREPARE: PASS project={project}', flush=True)


def cache_inventory(home):
    return {str(p.relative_to(home)): {'bytes': p.stat().st_size, 'mtime_ns': p.stat().st_mtime_ns}
            for p in home.rglob('*') if p.is_file() and any(part in ('shader_cache', 'vulkan', 'metal', 'cache') for part in p.parts)}


def command(args, driver, seed, profile, run_id, directory, trace_mode):
    prefix = []
    if profile == 'background':
        if platform.system() != 'Darwin' or not shutil.which('taskpolicy'):
            raise RuntimeError('background profile requires macOS taskpolicy; refusing a false throttle label')
        prefix = ['taskpolicy', '-c', 'background']
    quick = getattr(args, 'mode', None) == 'quick'
    headless = getattr(args, 'headless_standin', False)
    project = getattr(args, 'project', args.output / 'project')
    display = ['--headless'] if headless else ['--resolution', '1280x800', '--windowed', '--position', WINDOW_CORNER_POSITION]
    margin = QUICK_RUNNER_MARGIN_SECONDS if quick else RUNNER_MARGIN_SECONDS
    cmd = [*prefix, sys.executable, 'tools/godot_task_runner.py', '--task-id', getattr(args, 'task_id', DEFAULT_TASK_ID), '--run-id', run_id,
           '--godot-home-root', str(args.output / 'homes'), '--project', str(project),
           '--timeout', str(args.seconds + margin), '--stream', '--', 'godot', '--path', str(project),
           *display, '--script', 'res://tools/hitch_census/driver.gd', '--',
           f'--output={directory}', f'--driver={driver}', f'--seed={seed}', f'--seconds={args.seconds}']
    if quick: cmd.append('--quick')
    if headless: cmd.append('--headless-smoke')
    if driver == 'whole':
        cmd.append(f'--starting-health={getattr(args, "starting_health", 9999)}')
        if getattr(args, 'allow_voluntary_ends', False): cmd.append('--allow-voluntary-ends')
    if args.first_boss: cmd.append('--first-boss')
    if args.stop_after: cmd.append(f'--stop-after={args.stop_after}')
    return cmd


def run_accounting(directory, returncode, driver=None, quick=False):
    """Completion evidence wins over exit status (including qa-71 shutdown abort)."""
    result_printed = False
    script_error = False
    with (directory / 'godot.log').open(errors='replace') as stream:
        for line in stream:
            result_printed |= line.startswith('HITCH CENSUS RESULT:')
            script_error |= 'SCRIPT ERROR' in line
    receipt_path = directory / 'receipt.json'
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
    measured = result_printed and receipt_path.exists() and not script_error
    result = dict(returncode=returncode, outcome=receipt.get('outcome'), errors=receipt.get('errors', []),
                  result_printed=result_printed, measured=measured, script_error=script_error)
    if driver == 'tour':
        from report import incomplete_tour_reason
        result['tour_failure'] = incomplete_tour_reason(receipt, quick=quick)
        result['measured'] = measured and not result['tour_failure']
    return result


def run_one(args, driver, seed, profile, cache, run_id, trace_mode='on', primer=False):
    guard(args.output, args.disk_cap_gb * 1e9)
    name = f'{args.tag}-{driver}-{seed}-{profile}-{cache}-{trace_mode}-{time.time_ns()}' + ('-primer' if primer else '')
    directory = args.output / 'runs' / name
    directory.mkdir(parents=True, exist_ok=False)
    home = args.output / 'homes' / run_id
    before = cache_inventory(home)
    if cache == 'cold' and home.exists():
        raise RuntimeError('cold HOME must be fresh; refusing to reuse')
    if cache == 'warm' and not home.exists():
        raise RuntimeError('warm HOME requires a completed priming run')
    env = {**os.environ, 'LABYRINTH_HITCH_TRACE': '1' if trace_mode == 'on' else '0',
           'LABYRINTH_CEL_LOOK': 'all', 'SteamDeck': '1', 'LABYRINTH_PROBE_WINDOW': '1', 'LABYRINTH_DEMO': '1' if driver == 'demo' else '0'}
    cmd = command(args, driver, seed, profile, run_id, directory, trace_mode)
    replay_args = ['python3', 'tools/hitch_census/census.py', 'run', '--output', str(args.output),
                   '--task-id', getattr(args, 'task_id', DEFAULT_TASK_ID),
                   '--drivers', driver, '--seed', str(seed), '--seeds', '1', '--cache', cache,
                   '--profiles', profile, '--seconds', str(args.seconds), '--tag', f'replay-{time.time_ns()}']
    if driver == 'whole':
        replay_args += ['--starting-health', str(getattr(args, 'starting_health', 9999))]
        if getattr(args, 'allow_voluntary_ends', False): replay_args.append('--allow-voluntary-ends')
    if args.first_boss: replay_args.append('--first-boss')
    if args.stop_after: replay_args += ['--stop-after', str(args.stop_after)]
    if trace_mode == 'off': replay_args += ['--trace-mode', 'off']
    quick = getattr(args, 'mode', None) == 'quick'
    if quick:
        replay_args = ['python3', 'tools/hitch_census/census.py', 'quick', '--output', str(args.output),
                       '--task-id', args.task_id, '--seconds', str(args.demo_seconds),
                       '--disk-cap-gb', str(args.disk_cap_gb)]
        if args.headless_standin: replay_args.append('--headless-standin')
    metadata = {'driver': driver, 'seed': seed, 'profile': profile, 'cache': cache, 'primer': primer,
                'whole_settings': {'starting_health': getattr(args, 'starting_health', 9999), 'no_embrace_abandonment_voluntary_ends': not getattr(args, 'allow_voluntary_ends', False), 'time_scale': 1.0, 'combat_speed': 'normal', 'fight_decision_limit': 400, 'policy': 'legal_forward_attack_first_v6'} if driver == 'whole' else {},
                'trace_mode': trace_mode, 'viewport': None, 'command': cmd, 'env': {k: env[k] for k in ('LABYRINTH_HITCH_TRACE', 'LABYRINTH_CEL_LOOK', 'SteamDeck', 'LABYRINTH_DEMO', 'LABYRINTH_PROBE_WINDOW')},
                'cache_before': before, 'qos': 'taskpolicy -c background (preference, not pinned cores)' if profile == 'background' else 'inherited normal QoS',
                'replay': 'cd ' + shlex.quote(str(ROOT)) + ' && ' + shlex.join(replay_args)}
    if quick:
        metadata.update(preset='quick', headless_standin=args.headless_standin, seconds_cap=args.seconds, host_load_samples=[])
    write_json(directory / 'run.json', metadata)
    started = time.monotonic()
    with (directory / 'godot.log').open('w') as log:
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        last_size = started
        next_sample = started
        try:
            sampler = host_load.Sampler(process.pid, started) if quick else None
            while process.poll() is None:
                if sampler is not None and time.monotonic() >= next_sample:
                    metadata['host_load_samples'].append(sampler.sample())
                    next_sample = time.monotonic() + host_load.SAMPLE_SECONDS
                    write_json(directory / 'run.json', metadata)
                if metadata['viewport'] is None:
                    viewport = read_startup_viewport(directory)
                    if viewport is not None:
                        metadata['viewport'] = viewport
                        write_json(directory / 'run.json', metadata)
                if shutil.disk_usage(args.output).free < MIN_FREE_BYTES:
                    raise RuntimeError('free disk fell below 45 GB')
                if time.monotonic() - last_size >= SIZE_POLL_SECONDS:
                    guard(args.output, args.disk_cap_gb * 1e9)
                    last_size = time.monotonic()
                time.sleep(GUARD_POLL_SECONDS)
        except BaseException:
            # Runner forwards termination to its isolated Godot process tree.
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=15)
            raise
    metadata.update(viewport=read_startup_viewport(directory), returncode=process.returncode, wall_seconds=time.monotonic() - started, cache_after=cache_inventory(home))
    if quick: metadata['load_condition'] = host_load.condition(metadata['host_load_samples'])
    metadata.update(run_accounting(directory, process.returncode, driver, quick=quick))
    # An overlong frame or load can prevent Godot from reaching its own timer.
    # Keep the timed demo prefix; the reducer still validates its viewport and trace.
    capped_prefix = (quick and driver == 'demo' and not primer and process.returncode == RUNNER_TIMEOUT_EXIT
                     and not metadata['result_printed'] and not metadata['script_error']
                     and not metadata['errors'] and metadata['outcome'] is None and metadata['viewport']
                     and (directory / 'frames.jsonl').is_file())
    if capped_prefix:
        metadata.update(outcome='runner_time_limit', measured=True, partial_trace=True)
    write_json(directory / 'run.json', metadata)
    outcome_suffix = f' outcome={metadata["outcome"]}' if quick else ''
    print(f'HITCH RUN: {name} exit={process.returncode} seconds={metadata["wall_seconds"]:.2f}{outcome_suffix}', flush=True)
    if not capped_prefix and (not metadata['result_printed'] or metadata['script_error']):
        raise RuntimeError(f'failed run (missing RESULT or SCRIPT ERROR): {directory}; see godot.log')
    if driver == 'tour' and metadata['tour_failure']:
        raise RuntimeError(f"{metadata['tour_failure']}: {directory}; see godot.log and receipt.json")
    if quick and driver == 'demo' and (metadata['errors'] or metadata['outcome'] not in ('tharokh_fight_end', 'time_limit', 'runner_time_limit')):
        raise RuntimeError(f"quick demo stopped before Tharokh or its time cap: {directory}; see godot.log and receipt.json")
    guard(args.output, args.disk_cap_gb * 1e9)
    return directory


def validate_prepared(output):
    if not (output / 'source.json').exists(): raise RuntimeError('run prepare first')
    # Refuse silently mixing a stale tool/source freeze with a changed checkout.
    source = json.loads((output / 'source.json').read_text())
    for name, digest in source['hashes'].items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f'source freeze stale: {name}; prepare a new output')
    write_window_override(output / 'project')


def collect(args):
    validate_prepared(args.output)
    for driver in args.drivers:
        seeds = range(args.seed, args.seed + args.seeds) if driver == 'whole' else [7 if driver == 'demo' else args.seed]
        for seed in seeds:
            for profile in args.profiles:
                for trace_mode in (['on', 'off'] if args.trace_mode == 'both' else [args.trace_mode]):
                    run_id = f'{args.task_id}-{args.tag}-{driver}-{seed}-{profile}-{trace_mode}-{time.time_ns()}'
                    run_one(args, driver, seed, profile, 'cold', run_id, trace_mode, primer=args.cache == 'warm')
                    if args.cache in ('warm', 'both'):
                        run_one(args, driver, seed, profile, 'warm', run_id, trace_mode)
    from report import generate
    result = generate(args.output.glob('runs/*/run.json'), args.output / 'catalog')
    print(f'HITCH CENSUS: runs={len(result["runs"])} clusters={len(result["clusters"])} catalog={args.output / "catalog"}', flush=True)


def quick_collect(args):
    from report import generate

    def time_limit(_signal, _frame):
        raise TimeoutError('quick census reached its wall-time deadline')

    started = time.monotonic()
    previous_handler = signal.signal(signal.SIGALRM, time_limit)
    signal.setitimer(signal.ITIMER_REAL, QUICK_DEADLINE_SECONDS)
    try:
        args.output.mkdir(parents=True, exist_ok=True)
        args.project = args.output / 'project'
        if args.headless_standin and not (args.output / 'source.json').exists():
            args.project = ROOT  # Reuse the worktree's imported assets for headless proof.
        else:
            validate_prepared(args.output)
        args.first_boss, args.stop_after = False, 0
        args.demo_seconds = args.seconds = min(args.seconds, QUICK_DEMO_SECONDS)
        args.tag = 'quick'
        batch_id = f'{args.task_id}-quick-{time.time_ns()}'
        normal_home = batch_id + '-normal'
        background_home = batch_id + '-background'
        runs = [run_one(args, 'demo', 7, 'normal', 'cold', normal_home, primer=True)]
        homes = args.output / 'homes'
        clone(homes / normal_home, homes / background_home)
        runs.append(run_one(args, 'demo', 7, 'normal', 'warm', normal_home))
        runs.append(run_one(args, 'demo', 7, 'background', 'warm', background_home))
        args.seconds = QUICK_TOUR_SECONDS
        runs.append(run_one(args, 'tour', QUICK_TOUR_SEED, 'normal', 'cold', batch_id + '-tour'))
        result = generate([directory / 'run.json' for directory in runs], args.output / 'catalog',
                          headless_standin=args.headless_standin)
        if result['rejected']:
            raise RuntimeError(f"quick catalog rejected {len(result['rejected'])} takes; see report.md")
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous_handler)
    print(f'HITCH QUICK: PASS runs={len(runs)} measured={len(runs) - 1} '
          f'seconds={time.monotonic() - started:.2f} catalog={args.output / "catalog"}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('prepare', 'run', 'smoke', 'calibrate', 'quick'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--task-id')
    parser.add_argument('--import-cache', type=Path)
    parser.add_argument('--cel-cache', type=Path, help='optional existing production cel cache, validated/rebuilt by cel_look.py')
    parser.add_argument('--drivers', nargs='+', choices=('whole', 'demo', 'tour', 'calibration'), default=['whole', 'demo', 'tour'])
    parser.add_argument('--seed', type=int, default=83)
    parser.add_argument('--seeds', type=int, default=1)
    parser.add_argument('--seconds', type=float, default=SMOKE_SECONDS)
    parser.add_argument('--cache', choices=('cold', 'warm', 'both'), default='both')
    parser.add_argument('--profiles', nargs='+', choices=('normal', 'background'), default=['normal', 'background'])
    parser.add_argument('--trace-mode', choices=('on', 'off', 'both'), default='on')
    parser.add_argument('--tag', default='campaign')
    parser.add_argument('--starting-health', type=int, default=9999)
    parser.add_argument('--allow-voluntary-ends', action='store_true', help='opt out of whole-driver terminal-control filtering')
    parser.add_argument('--first-boss', action='store_true')
    parser.add_argument('--stop-after', type=int, default=0)
    parser.add_argument('--disk-cap-gb', type=float, default=10.0)
    parser.add_argument('--headless-standin', action='store_true', help='quick only: catalog process-frame intervals')
    args = parser.parse_args()
    args.task_id = args.task_id or (QUICK_TASK_ID if args.mode == 'quick' else DEFAULT_TASK_ID)
    if args.mode == 'quick' and args.output is None:
        parser.error('quick mode requires --output')
    args.output = (args.output or DEFAULT_OUTPUT).resolve()
    if (args.starting_health <= 0 or not math.isfinite(args.seconds) or args.seconds <= 0 or args.seeds < 1
            or args.stop_after < 0 or not math.isfinite(args.disk_cap_gb) or args.disk_cap_gb <= 0):
        parser.error('seconds, seeds and disk cap must be positive; stop-after nonnegative')
    if args.trace_mode != 'on' and args.mode != 'calibrate' and args.drivers != ['calibration']:
        parser.error('trace off is only for calibration')
    if args.headless_standin and args.mode != 'quick':
        parser.error('--headless-standin requires quick mode')
    if args.mode == 'quick' and (platform.system() != 'Darwin' or not shutil.which('taskpolicy')):
        parser.error('quick mode requires macOS taskpolicy for the background take')
    if args.mode == 'smoke':
        args.seeds, args.first_boss = 1, True
        args.seconds = min(args.seconds, SMOKE_SECONDS)
        args.disk_cap_gb = min(args.disk_cap_gb, 10.0)
    if args.mode == 'calibrate':
        args.drivers, args.trace_mode = ['calibration'], 'both'
    try:
        if args.mode == 'prepare': prepare(args.output, args.import_cache, args.cel_cache, args.task_id)
        elif args.mode == 'quick': quick_collect(args)
        else: collect(args)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f'HITCH CENSUS STOP: {error}\n')


if __name__ == '__main__':
    main()
