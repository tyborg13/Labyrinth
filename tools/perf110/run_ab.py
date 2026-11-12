#!/usr/bin/env python3
"""Serial, uncommitted file-snapshot A/B; restore the exact candidate on exit."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

from report import summarize

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DECISIONS = 96
RUN_SECONDS = 360
RUN_TIMEOUT_SECONDS = 420
NATIVE_SECONDS = 240
PAIR_ORDER = [(84, 'AB'), (85, 'AB'), (84, 'BA'), (85, 'BA'), (84, 'AB'), (85, 'AB')]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--decisions', type=int, default=DEFAULT_DECISIONS)
    parser.add_argument('--gate-summary', type=Path,
                        help='Reuse an observed passing baseline gate when only candidate B changed')
    parser.add_argument('--resume', action='store_true', help='Keep completed takes with identical source hashes; failed takes get fresh directories')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--capture', action='store_true', help='Owner only: windowed A/B pixel proof')
    mode.add_argument('--native-census', action='store_true', help='Owner only: frozen native A/B census')
    args = parser.parse_args()
    paths = json.loads((args.baseline / 'manifest.json').read_text())
    versions = {'A': {p: (args.baseline / p).read_bytes() for p in paths},
                'B': {p: (ROOT / p).read_bytes() for p in paths}}
    if any(digest(versions['A'][p]) != paths[p] for p in paths):
        raise SystemExit('Baseline does not match its recorded source hashes')
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {label: {p: digest(data) for p, data in files.items()}
                for label, files in versions.items()}
    if args.resume:
        if json.loads((args.output / 'sources.json').read_text()) != manifest:
            raise SystemExit('Resume requires the exact original and candidate source hashes')
    for label, files in versions.items():
        for path, data in files.items():
            target = args.output / 'source' / label / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    (args.output / 'sources.json').write_text(json.dumps(manifest, indent=2))
    env = dict(os.environ, LABYRINTH_HITCH_TRACE='1')

    def install(label):
        for path in paths:
            current = (ROOT / path).read_bytes()
            if current not in (versions['A'][path], versions['B'][path]):
                raise RuntimeError('Unexpected concurrent source edit: ' + path)
        for path, data in versions[label].items():
            (ROOT / path).write_bytes(data)

    def run(script, output, log, seed=84):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'perf-110',
                   '--timeout', str(RUN_TIMEOUT_SECONDS), '--stream', '--', 'godot',
                   '--headless', '--path', '.', '--script', script, '--',
                   '--driver=whole', f'--seed={seed}', f'--stop-after={args.decisions}',
                   f'--seconds={RUN_SECONDS}', f'--output={output}']
        with log.open('w') as stream:
            code = subprocess.call(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        if code:
            raise RuntimeError(f'Godot failed ({code}): {log}')
        result = summarize(output)
        if result['receipt'].get('outcome') != 'replay_point':
            raise RuntimeError('Replay did not reach fixed decision count: ' + str(output))
        (output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
        return result

    def interrupt(signum, frame):
        raise KeyboardInterrupt(f'signal {signum}')

    signal.signal(signal.SIGTERM, interrupt)
    results = json.loads((args.output / 'takes.json').read_text()) if args.resume else []
    try:
        if args.capture or args.native_census:
            for label in ('A', 'B'):
                install(label)
                if args.capture:
                    destination = args.output / label
                    capture_env = dict(os.environ, PERF110_CAPTURE_DIR=str(destination))
                    command = [sys.executable, 'tools/visual_probe_runner.py',
                               'tools/perf110/capture.gd', '--task-id', 'perf-110',
                               '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
                               '--expect-size', '1920x1080', '--proof-contract',
                               'tools/perf110/proof_contract.json', '--result-manifest',
                               str(args.output / (label + '-manifest.json'))]
                else:
                    capture_env = os.environ.copy()
                    command = [sys.executable, 'tools/hitch_census/census.py', 'run',
                               '--output', str(args.output / label), '--drivers', 'whole',
                               '--seed', '84', '--seeds', '2', '--cache', 'warm',
                               '--profiles', 'normal', '--seconds', str(NATIVE_SECONDS),
                               '--stop-after', str(args.decisions), '--tag', 'perf110-' + label,
                               '--disk-cap-gb', '10']
                subprocess.run(command, cwd=ROOT, env=capture_env, check=True)
            return
        install('A')
        if args.gate_summary:
            gate = json.loads(args.gate_summary.read_text())
            recorded = json.loads((args.gate_summary.parent.parent / 'sources.json').read_text())['A']
            if any(manifest['A'].get(p) != value for p, value in recorded.items()):
                raise RuntimeError('Reused gate source hashes differ from baseline A')
            if max(row.get('decision', 0) for row in gate['decisions_without_timing']) != args.decisions:
                raise RuntimeError('Reused gate decision count differs')
            (args.output / 'gate-reference.json').write_text(json.dumps({
                'summary': str(args.gate_summary.resolve()), 'verified_baseline_hashes': recorded}, indent=2))
        else:
            gate_output = args.output / 'gate'
            gate = run('tools/perf110/gate.gd', gate_output, args.output / 'gate.log')
        print('PERF110 BASELINE GATE: ' + ('PASS' if gate['gate_passed'] else 'NOT PASSED'), flush=True)
        if not gate['gate_passed']:
            raise RuntimeError('Gate did not pass; candidate restored without A/B claims')
        for pair, (seed, order) in enumerate(PAIR_ORDER, 1):
            for label in order:
                if any(row['pair'] == pair and row['label'] == label for row in results):
                    print(f'PERF110 TAKE REUSED: pair{pair}-seed{seed}-{label}; exact source hashes matched', flush=True)
                    continue
                install(label)
                name = f'pair{pair}-seed{seed}-{label}'
                retry_index = 1
                while (args.output / name).exists():
                    name = f'pair{pair}-seed{seed}-{label}-retry{retry_index}'
                    retry_index += 1
                print('PERF110 TAKE START: ' + name, flush=True)
                result = run('tools/hitch_census/headless_whole.gd', args.output / name,
                             args.output / (name + '.log'), seed)
                results.append(dict(pair=pair, seed=seed, label=label, directory=name, result=result))
                (args.output / 'takes.json').write_text(json.dumps(results, indent=2) + '\n')
                print(f"PERF110 TAKE DONE: {name} outcome={result['receipt']['outcome']} "
                      f"frames={result['receipt']['trace']['frames']}", flush=True)
    finally:
        install('B')
        print('PERF110 SOURCE RESTORED: candidate B; changes remain uncommitted', flush=True)


if __name__ == '__main__':
    main()
