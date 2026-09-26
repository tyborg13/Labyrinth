#!/usr/bin/env python3
"""Capture focused native card-completion stalls; compare matched AB/BA blocks."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys

SOURCE_PATHS = (
    'scripts/run_scene.gd', 'scripts/card_widget.gd', 'scripts/hand_fan_container.gd',
    'scripts/deferred_reconciliation_queue.gd',
    'scripts/combat_board_view.gd', 'tests/card_completion_stall_probe.gd',
    'tests/fixtures/card_completion_trace_scene.gd',
    'tests/runtime_frame_performance_benchmark.gd', 'project.godot',
)
MATCHED_SOURCES = ('tests/card_completion_stall_probe.gd',
                   'tests/runtime_frame_performance_benchmark.gd', 'project.godot')
RUNTIME_ROOTS = ('scripts', 'scenes', 'shaders', 'data', 'themes', 'addons', 'fonts', 'assets')
GENERATED_DIRECTORIES = {'.godot', '.git', '__pycache__', '.cache'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def hashes(root):
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() if (root / name).is_file() else None for name in SOURCE_PATHS}


def runtime_hashes(root):
    # Include untracked implementation helpers as well as the tracked runtime.
    # Resource .import sidecars are configuration, not generated cache, and stay.
    output = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--',
         *RUNTIME_ROOTS, 'project.godot'], cwd=root)
    names = sorted({os.fsdecode(name) for name in output.split(b'\0') if name})
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
            if (root / name).is_file() else None for name in names
            if not any(part in GENERATED_DIRECTORIES for part in Path(name).parts)}


def valid_hashes(value):
    return (isinstance(value, dict) and bool(value)
            and all(isinstance(name, str) and isinstance(digest, str)
                    and len(digest) == 64 and all(c in '0123456789abcdef' for c in digest)
                    for name, digest in value.items()))


def capture_failures(report):
    """Revalidate raw evidence; an archived failed process is never accepted."""
    failures = []
    def check(condition, message):
        if not condition:
            failures.append(message)
    check(report.get('schema_version') == 2, 'Missing complete capture binding (schema 2)')
    check(report.get('process_returncode') == 0, 'Probe process failed or exit status is missing')
    check(report.get('result_parse_failures') == [], 'Malformed result marker or missing parse status')
    requested = report.get('requested_repetitions')
    check(type(requested) is int and requested >= 1, 'Invalid requested repetition count')
    sources = report.get('sources', {})
    check(bool(sources) and sources == report.get('sources_after'), 'Focused source mutation or missing hashes')
    runtime = report.get('runtime_sources')
    check(valid_hashes(runtime) and 'project.godot' in runtime,
          'Missing or unreadable recursive runtime source hashes')
    check(runtime == report.get('runtime_sources_after'), 'Runtime source mutation')
    tool = report.get('capture_tool', {})
    check(valid_hashes({'tool': tool.get('sha256')}), 'Missing capture tool hash')
    check(tool.get('sha256') == tool.get('sha256_after'), 'Capture tool changed during capture')
    result = report.get('result', {})
    check(isinstance(result, dict) and bool(result), 'Missing probe result')
    if not isinstance(result, dict):
        return failures
    check(result.get('errors') == [], 'Probe result contains errors or missing error status')
    check(result.get('unfocused_observations') == 0 and result.get('focus_pauses') == 0,
          'Focus interruption or missing focus evidence')
    rows = result.get('repetitions')
    if not isinstance(rows, list) or len(rows) < 2:
        failures.append('No warmup and measured repetitions')
        return failures
    check(type(requested) is int and len(rows) == requested + 1, 'Wrong repetition count')
    nodes = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f'Repetition {index}: malformed record')
            continue
        check(row.get('warmup') is (index == 0), f'Repetition {index}: wrong warmup flag')
        check(row.get('environment_violations') == [], f'Repetition {index}: environment drift or missing evidence')
        after = row.get('after', {})
        check(after.get('orphan_nodes') == 0, f'Repetition {index}: orphan nodes or missing evidence')
        count = after.get('live_scene_nodes')
        check(type(count) is int and count > 0, f'Repetition {index}: invalid scene node count')
        if index > 0:
            nodes.append(count)
        raw = row.get('raw', {})
        ids, intervals = raw.get('frame_ids'), raw.get('frame_interval_ms')
        valid_intervals = (isinstance(intervals, list) and bool(intervals)
                           and all(type(t) in (int, float) and math.isfinite(t) and t >= 0 for t in intervals))
        valid_ids = (isinstance(ids, list) and bool(ids)
                     and all(type(frame) is int for frame in ids)
                     and all(a < b for a, b in zip(ids, ids[1:])))
        check(valid_ids and valid_intervals and len(ids) == len(intervals),
              f'Repetition {index}: invalid frame samples')
        check(valid_ids and row.get('unlock_frame') in ids, f'Repetition {index}: completion frame not sampled')
    check(nodes and all(node == nodes[0] for node in nodes), 'Scene node count changed across measured repetitions')
    return failures


def samples(report):
    rows = []
    for row in report['result']['repetitions']:
        raw = row['raw']
        index = raw['frame_ids'].index(row['unlock_frame'])
        window = raw['frame_interval_ms'][max(0, index - 2):]
        whole = raw['frame_interval_ms']
        rows.append(dict(warmup=row['warmup'], completion_max_ms=max(window),
                         whole_max_ms=max(whole), completion_frames=len(window),
                         over16=sum(t > 16.67 for t in window),
                         over33=sum(t > 1000 / 30 for t in window),
                         over50=sum(t > 50 for t in window),
                         whole_over33=sum(t > 1000 / 30 for t in whole),
                         whole_over50=sum(t > 50 for t in whole)))
    return rows


def capture(args):
    root = args.root.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    require(args.repetitions >= 1, 'Need at least one measured repetition')
    before = hashes(root)
    runtime_before = runtime_hashes(root)
    tool_path = Path(__file__).resolve()
    tool_before = hashlib.sha256(tool_path.read_bytes()).hexdigest()
    manifest = output.with_suffix('.manifest.json')
    log = output.with_suffix('.log')
    command = [sys.executable, 'tools/visual_probe_runner.py', 'tests/card_completion_stall_probe.gd',
               '--task-id', args.task_id, '--no-headless', '--display-driver', 'macos',
               '--audio-driver', 'Dummy', '--rendering-method', 'mobile', '--rendering-driver', 'metal',
               '--timeout', '180', '--min-images', '0', '--result-manifest', str(manifest)]
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('LABYRINTH_RUNTIME_PERF_', 'LABYRINTH_STALL_'))}
    settings = dict(LABYRINTH_RUNTIME_PERF_CAPPED_HAND='1', LABYRINTH_RUNTIME_PERF_HAND_POINTER='1',
                    LABYRINTH_RUNTIME_PERF_REDUCED_MOTION='0',
                    LABYRINTH_RUNTIME_PERF_VIEWPORT_SIZE='1920x1080',
                    LABYRINTH_STALL_TRACE='1' if args.trace else '0',
                    LABYRINTH_STALL_REPETITIONS=str(args.repetitions), LABYRINTH_STALL_CARD=args.card,
                    LABYRINTH_RUNTIME_PERF_SECTIONS='1' if args.trace else '0')
    env.update(settings)
    with log.open('w') as stream:
        process = subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT)
    lines = log.read_text().splitlines()
    marker = 'CARD COMPLETION STALL RESULT: '
    results, parse_failures = [], []
    for line in lines:
        if line.startswith(marker):
            try:
                results.append(json.loads(line[len(marker):]))
            except json.JSONDecodeError as error:
                parse_failures.append(f'Malformed probe result: {error}')
    result = results[-1] if results else {}
    report = dict(schema_version=2, head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                  worktree=str(root), sources=before, sources_after=hashes(root), command=command,
                  runtime_sources=runtime_before, runtime_sources_after=runtime_hashes(root),
                  capture_tool=dict(path=str(tool_path), sha256=tool_before,
                                    sha256_after=hashlib.sha256(tool_path.read_bytes()).hexdigest()),
                  process_returncode=process.returncode, requested_repetitions=args.repetitions,
                  result_parse_failures=parse_failures,
                  environment=settings, platform=platform.platform(), result=result)
    failures = capture_failures(report)
    report.update(capture_valid=not failures, capture_failure_reasons=failures)
    # Preserve evidence even when validation fails.
    output.write_text(json.dumps(report))
    require(not failures, f'{"; ".join(failures)}; inspect {log}')
    print(json.dumps(dict(output=str(output), samples=samples(report))), flush=True)


def distribution(values):
    ordered = sorted(values)
    return dict(median=statistics.median(ordered), p95=ordered[math.ceil(.95 * len(ordered)) - 1],
                maximum=max(ordered), minimum=min(ordered))


def compare(args):
    require(bool(args.base) and len(args.base) == len(args.candidate), 'Need nonempty matching baseline/candidate block counts')
    base_rows, candidate_rows, blocks = [], [], []
    side_bindings = {}
    common_tool_hash = None
    for base_path, candidate_path in zip(args.base, args.candidate):
        base, candidate = (json.loads(p.read_text()) for p in (base_path, candidate_path))
        for side, report in (('base', base), ('candidate', candidate)):
            failures = capture_failures(report)
            require(not failures, f'Invalid {side} capture: {"; ".join(failures)}')
            require(report.get('capture_valid') is True and report.get('capture_failure_reasons') == [],
                    'Capture was not recorded as valid')
            r = report['result']
            require(not r['trace_enabled'] and not r['errors'], 'Only valid clean runs can be compared')
            binding = (report['runtime_sources'], report['sources'])
            if side in side_bindings:
                require(binding == side_bindings[side], f'Mixed {side} sources across blocks')
            else:
                side_bindings[side] = binding
            tool_hash = report['capture_tool']['sha256']
            if common_tool_hash is None:
                common_tool_hash = tool_hash
            require(tool_hash == common_tool_hash, 'Capture tool differs across reports')
        for name in MATCHED_SOURCES:
            require(base['sources'][name] == candidate['sources'][name], f'Unmatched harness: {name}')
        require(base['environment'] == candidate['environment'], 'Unmatched effective environment')
        for key in ('engine', 'renderer', 'os', 'viewport', 'settings'):
            require(base['result'][key] == candidate['result'][key], f'Unmatched {key}')
        br, cr = (x['result']['repetitions'] for x in (base, candidate))
        require(len(br) == len(cr), 'Unmatched repetitions')
        for b, c in zip(br, cr):
            # Isolated storage creates a fresh analytics run/combat identity.
            # Keep it in raw evidence; normalize only this known namespace field.
            for row in (b, c):
                require(row['before_state']['analytics']['combat_id'] == row['after_state']['analytics']['combat_id'], 'Combat identity changed within action')
            for key in ('before_state', 'after_state'):
                states = [json.loads(json.dumps(row[key])) for row in (b, c)]
                for state in states:
                    state['analytics']['combat_id'] = '<isolated-combat>'
                require(states[0] == states[1], f'Unmatched gameplay {key}: {base_path} / {candidate_path}')
            for key in ('warmup', 'card_id', 'targets', 'lock_count'):
                require(b[key] == c[key], f'Unmatched gameplay {key}: {base_path} / {candidate_path}')
            for key in ('step_count', 'total_target_count', 'max_target_count', 'reached_confirmation'):
                require(b['interaction'][key] == c['interaction'][key], f'Unmatched interaction {key}')
            require(not b['environment_violations'] and not c['environment_violations'], 'Environment drift')
            after = c['after']
            require(after['geometric_hand_hit_indices'] == [after['hovered_hand_index']], 'Candidate hover disagrees with geometry')
            require(after['routed_hand_index'] == after['hovered_hand_index'], 'Candidate router disagrees with hover')
        bs, cs = ([row for row in samples(x) if not row['warmup']] for x in (base, candidate))
        base_rows.extend(bs)
        candidate_rows.extend(cs)
        delta = statistics.median(x['completion_max_ms'] for x in bs) - statistics.median(x['completion_max_ms'] for x in cs)
        blocks.append(dict(base=str(base_path), candidate=str(candidate_path), median_reduction_ms=delta))
    def summarize(rows):
        return dict(repetitions=len(rows), completion_max_ms=distribution([r['completion_max_ms'] for r in rows]),
                    whole_max_ms=distribution([r['whole_max_ms'] for r in rows]),
                    **{k: sum(r[k] for r in rows) for k in ('completion_frames', 'over16', 'over33', 'over50', 'whole_over33', 'whole_over50')})
    result = dict(base=summarize(base_rows), candidate=summarize(candidate_rows), blocks=blocks,
                  source_bindings={side: dict(runtime_sources=binding[0], sources=binding[1])
                                   for side, binding in side_bindings.items()},
                  capture_tool_sha256=common_tool_hash)
    failures = []
    if not all(x['median_reduction_ms'] >= args.minimum_reduction_ms for x in blocks):
        failures.append('Material-reduction gate failed in at least one paired block')
    if result['candidate']['whole_max_ms']['p95'] > result['base']['whole_max_ms']['p95']:
        failures.append('Whole-action upper tail regressed')
    if result['candidate']['completion_max_ms']['p95'] > result['base']['completion_max_ms']['p95']:
        failures.append('Completion upper tail regressed')
    for metric in ('over50', 'whole_over50'):
        if result['candidate'][metric] > result['base'][metric]:
            failures.append(f'Severe-frame count regressed: {metric}')
    result.update(accepted=not failures, failure_reasons=failures)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    require(result['accepted'], '; '.join(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    run = commands.add_parser('run')
    run.add_argument('--root', type=Path, default=Path.cwd())
    run.add_argument('--output', type=Path, required=True)
    run.add_argument('--task-id', required=True)
    def positive_repetitions(value):
        parsed = int(value)
        if parsed < 1:
            raise argparse.ArgumentTypeError('repetitions must be at least 1')
        return parsed
    run.add_argument('--repetitions', type=positive_repetitions, default=8)
    run.add_argument('--card', choices=('gust_step', 'shadow_step', 'wildfire_halo'), default='gust_step')
    run.add_argument('--trace', action='store_true')
    run.set_defaults(func=capture)
    paired = commands.add_parser('compare')
    paired.add_argument('--base', type=Path, nargs='+', required=True)
    paired.add_argument('--candidate', type=Path, nargs='+', required=True)
    paired.add_argument('--output', type=Path, required=True)
    paired.add_argument('--minimum-reduction-ms', type=float, default=10)
    paired.set_defaults(func=compare)
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
