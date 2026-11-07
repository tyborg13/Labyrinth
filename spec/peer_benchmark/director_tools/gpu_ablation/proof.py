"""Prepare or run isolated sd-12 census arms through the repository runners."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import random
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = Path('/private/tmp/labyrinth_codex/sd-12')
SOURCE = Path('/Users/borgerding/workspace/Labyrinth.worktrees/sd-12')
PROJECT = ROOT / 'project'
TOOLS = ROOT / 'tools'
STATES = ('dragon_idle', 'dragon_action', 'character_gear', 'character_magic', 'character_skills', 'fight_idle')
COMMON_ARMS = ('art_treatment', 'floor_light', 'atmosphere_shade', 'hud_hand', 'static_board_cache')
NATIVE_TIMEOUT_SECONDS = 240
STARTUP_TIMEOUT_SECONDS = 8
ORDER_SEED = 12
LUMA_RANGE = 20
LUMA_STDEV = 3


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def verify_binding():
    provenance = json.loads((ROOT / 'provenance.json').read_text())
    mismatches = []
    for name, expected in provenance['source_hashes'].items():
        for root in (SOURCE, PROJECT):
            path = root / name
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                mismatches.append(str(path))
    if mismatches:
        raise SystemExit('Source binding changed: ' + ', '.join(mismatches[:8]))
    frozen_tools = ROOT / 'tool_hashes.json'
    if frozen_tools.exists():
        for name, expected in json.loads(frozen_tools.read_text()).items():
            path = TOOLS / name
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise SystemExit('Proof tool binding changed: ' + str(path))
    print('SD-12 BINDING: PASS source_files=%d checkout_and_scratch_match' % len(provenance['source_hashes']), flush=True)


def runner(state, arm, output, native=False, discovery=False):
    tail = ['--state=' + state, '--arm=' + arm, '--output-dir=' + str(output)]
    if discovery:
        tail.append('--discover')
    if not native:
        return ['python3', 'tools/godot_task_runner.py', '--task-id', 'sd-12', '--stream', '--', 'godot', '--headless', '--path', str(PROJECT), '--script', str(TOOLS / 'ablation_screens.gd'), '--', *tail]
    contract = TOOLS / ('proof-' + state + '.json')
    return ['python3', 'tools/visual_probe_runner.py', '--project', str(PROJECT), '--task-id', 'sd-12', '--godot', str(TOOLS / 'godot-deck'), '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy', '--rendering-method', 'mobile', '--rendering-driver', 'vulkan', '--attempts', '1', '--timeout', str(NATIVE_TIMEOUT_SECONDS), '--startup-timeout', str(STARTUP_TIMEOUT_SECONDS), '--min-images', '1', '--expect-size', '1280x800', '--proof-contract', str(contract), '--result-manifest', str(output / 'renderer-manifest.json'), str(TOOLS / 'ablation_screens.gd'), '--', *tail]


def plan(run_dir):
    rows = []
    rng = random.Random(ORDER_SEED)
    for state in STATES:
        data = json.loads((ROOT / 'discovery' / state / 'discovery.json').read_text())
        arms = list(COMMON_ARMS) + [arm for arm in data['targets'] if arm.startswith('rig__')]
        if state.startswith('character_'):
            arms.extend(('paper_doll', 'card_strips', 'skill_tree'))
        missing = set(COMMON_ARMS) - set(arms)
        if missing:
            raise SystemExit('Missing required selectors %s: %s' % (state, sorted(missing)))
        rng.shuffle(arms)
        for arm in ['baseline_a', *arms, 'baseline_b']:
            output = run_dir / state / arm
            rows.append({'state': state, 'arm': arm, 'output': str(output), 'command': runner(state, arm, output, native=True)})
    return rows


def prepare_commands(run_dir):
    wrapper = TOOLS / 'godot-deck'
    wrapper.write_text('#!/bin/sh\nexec godot --resolution 1280x800 --windowed "$@"\n')
    wrapper.chmod(0o755)
    for state in STATES:
        save(TOOLS / ('proof-' + state + '.json'), {'min_images': 1, 'expected_sizes': ['1280x800'], 'required_images': [{'pattern': state + '.png', 'width': 1280, 'height': 800, 'regions': [{'rect': [0, 0, 1280, 800], 'min_luma_range': LUMA_RANGE, 'min_luma_stdev': LUMA_STDEV}]}]})
    rows = plan(run_dir)
    save(ROOT / 'native_commands.json', {'run_dir': str(run_dir), 'environment': {'LABYRINTH_CEL_LOOK': 'all'}, 'arms': rows})
    lines = ['# Proof for the design owner', '', 'Prepared only: the worker has no macOS window server. Keep the window visible and unobscured. Every arm is a fresh process against the bound scratch project. Do not run arms concurrently. Vulkan mobile, 1280×800 / 115%, approved cel all, edge smoothing Off, 120 warmup frames, 660 unique main-viewport timestamp frames; actual enemy effect/progress frames pooled over real turns; hand/turn transitions excluded; action capture uses a separate unmeasured replay. Baseline A/B bracket a reproducibly shuffled arm order per state.', '', 'Run everything (refuses existing output; stops on the first failed arm):', '', '```sh', 'cd ' + str(SOURCE) + ' && python3 ' + str(TOOLS / 'proof.py') + ' --native --run-dir ' + shlex.quote(str(run_dir)), '```', '', 'Expanded commands:', '', '```sh']
    lines.extend('cd ' + str(SOURCE) + ' && LABYRINTH_CEL_LOOK=all ' + shlex.join(row['command']) for row in rows)
    lines.append('cd ' + str(SOURCE) + ' && python3 ' + str(TOOLS / 'report.py') + ' --run-dir ' + shlex.quote(str(run_dir)))
    lines.extend(['```', '', 'Capture paths: `<run-dir>/<state>/<arm>/<state>.png`; raw data beside it (`<state>.json`, `index.json`, `runner.log`, `renderer-manifest.json`). Tables: `<run-dir>/tables/{tables.md,arms.csv,top_five.csv,options.md,summary.json}`. No inspection fixture applies: this unit changes no playable or product behavior, and the brief requests no `inspection_fixture.py` command.', '', 'No native or Deck savings are available until these commands finish. Main-viewport marginals do not include offscreen rig render costs; those and the total viewport sum are reported separately. Ablations overlap and are never additive.'])
    (ROOT / 'native-commands.md').write_text('\n'.join(lines) + '\n')
    save(ROOT / 'chosen_defaults.json', {'headless_workers': 2, 'steady_frames': 660, 'warmup_frames': 120, 'headless_fixture_frames': 3, 'context_history_frames': 2048, 'state_timeout_msec': 120000, 'enemy_max_cycles': 100, 'action_warmup_turns': 1, 'snapshot_stride_frames': 60, 'arm_order_seed': ORDER_SEED, 'native_timeout_seconds': NATIVE_TIMEOUT_SECONDS, 'startup_timeout_seconds': STARTUP_TIMEOUT_SECONDS, 'proof_min_luma_range': LUMA_RANGE, 'proof_min_luma_stdev': LUMA_STDEV, 'noise_block_frames': 60, 'noise_rule': 'per metric, max of A/B summary difference and largest deviation of either baseline contiguous-60-frame block summary from pooled baseline summary; empirical band, not confidence interval', 'fixture_policy': 'reuse sd-10 production factories and sd-09 Character fixture; no product tuning choices', 'window_position': [24, 24], 'frame_cap': 0, 'vsync': 'disabled', 'low_processor_usage_mode': False})
    print('SD-12 COMMANDS: PASS states=%d arms=%d contracts=%d native_runs=0' % (len(STATES), len(rows), len(STATES)), flush=True)
    return rows


def execute(command, output, label):
    output.mkdir(parents=True, exist_ok=False)
    with (output / 'runner.log').open('w') as log:
        status = subprocess.run(command, cwd=SOURCE, env=dict(os.environ, LABYRINTH_CEL_LOOK='all'), stdout=log, stderr=subprocess.STDOUT).returncode
    print('SD-12 RUN: %s exit=%d log=%s' % (label, status, output / 'runner.log'), flush=True)
    if status:
        raise SystemExit('Runner failed; no retry: ' + str(output / 'runner.log'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--discover', action='store_true')
    mode.add_argument('--headless', action='store_true')
    mode.add_argument('--native', action='store_true')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--run-dir', type=Path, default=ROOT / 'native-director')
    parser.add_argument('--headless-dir', type=Path, default=ROOT / 'headless-v2')
    parser.add_argument('--headless-workers', type=int, default=2)
    parser.add_argument('--headless-arm', default='')
    parser.add_argument('--headless-state', default='')
    args = parser.parse_args()
    if args.verify or args.native:
        verify_binding()
    if args.discover:
        for state in STATES:
            output = ROOT / 'discovery' / state
            execute(runner(state, 'baseline_a', output, discovery=True), output, 'discovery/' + state)
        return 0
    rows = prepare_commands(args.run_dir)
    if args.headless:
        def one(row):
            output = args.headless_dir / row['state'] / row['arm']
            execute(runner(row['state'], row['arm'], output), output, 'headless/' + row['state'] + '/' + row['arm'])
        # No GPU renderer or shared user:// state in this lane. Native arms
        # always remain serial; independent headless process homes are isolated.
        with ThreadPoolExecutor(max_workers=args.headless_workers) as pool:
            list(pool.map(one, [r for r in rows if (not args.headless_arm or r['arm'] == args.headless_arm) and (not args.headless_state or r['state'] == args.headless_state)]))
    elif args.native:
        if args.run_dir.exists():
            raise SystemExit('Refusing to overwrite evidence: ' + str(args.run_dir))
        status = subprocess.run(['python3', str(PROJECT / 'tools/cel_look.py'), 'status'], cwd=SOURCE).returncode
        if status:
            raise SystemExit('Approved cel pack stale/missing; supply an approved matching pack. No generation/fallback.')
        for row in rows:
            execute(row['command'], Path(row['output']), row['state'] + '/' + row['arm'])
        return subprocess.run(['python3', str(TOOLS / 'report.py'), '--run-dir', str(args.run_dir)], cwd=SOURCE).returncode
    return 0


if __name__ == '__main__':
    sys.exit(main())
