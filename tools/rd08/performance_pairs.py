"""Owner-only native whole-foundation frame cost, interleaved A/B, B/A, A/B."""
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-08')
BASE = OUTPUT / 'base-14a369b61'
ORDER = ['A', 'B', 'B', 'A', 'A', 'B']


def quantile(values, fraction):
    ordered = sorted(values)
    offset = (len(ordered) - 1) * fraction
    low = int(offset)
    return ordered[low] + (ordered[min(low + 1, len(ordered) - 1)] - ordered[low]) * (offset - low)


def report():
    results, pairs = [], []
    for index, side in enumerate(ORDER):
        row = json.loads((OUTPUT / f'performance/{index + 1}-{side}.json').read_text())
        assert not row['check_only'] and row['renderer'] != 'headless' and row['samples'] == 180
        results.append(row)
    for start in range(0, len(ORDER), 2):
        a = results[start if ORDER[start] == 'A' else start + 1]
        b = results[start if ORDER[start] == 'B' else start + 1]
        metrics = {}
        for key in ['frame_usec', 'engine_usec', 'render_cpu_usec', 'render_gpu_usec']:
            metrics[key] = {
                'base_median_ms': statistics.median(a[key]) / 1000,
                'foundation_median_ms': statistics.median(b[key]) / 1000,
                'base_p99_ms': quantile(a[key], .99) / 1000,
                'foundation_p99_ms': quantile(b[key], .99) / 1000,
                'added_median_ms': (statistics.median(b[key]) - statistics.median(a[key])) / 1000,
                'added_p99_ms': (quantile(b[key], .99) - quantile(a[key], .99)) / 1000,
            }
        pairs.append(metrics)
        print(f'RD08 NATIVE PAIR {start // 2 + 1} {ORDER[start]}/{ORDER[start + 1]}: ' + json.dumps(metrics))
    (OUTPUT / 'performance/report.json').write_text(json.dumps({'baseline': '14a369b61', 'order': ORDER, 'pairs': pairs}, indent=2) + '\n')


def main():
    if '--report-only' in sys.argv:
        report()
        return
    assert (BASE / '.rd08-baseline').read_text().strip().startswith('14a369b61')
    for index, side in enumerate(ORDER):
        project = BASE if side == 'A' else ROOT
        sample_id = f'{index + 1}-{side}'
        command = [sys.executable, str(ROOT / 'tools/visual_probe_runner.py'), 'tools/rd08/performance.gd',
                   '--project', str(project), '--task-id', 'rd-08', '--godot', str(project / 'tools/rd08/native_capture.sh'),
                   '--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
                   '--rendering-driver', 'metal', '--rendering-method', 'mobile', '--fallback-rendering-driver', 'metal',
                   '--timeout', '300', '--expect-size', '1920x1080',
                   '--proof-contract', str(ROOT / 'tools/rd08/performance_contract.json'),
                   '--result-manifest', str(OUTPUT / f'performance/native-{sample_id}.json'), '--', '--sample-id', sample_id]
        print('Running native sample ' + sample_id, flush=True)
        subprocess.run(command, cwd=project, env={**os.environ, 'LABYRINTH_CEL_LOOK': 'all'}, check=True)
    report()


if __name__ == '__main__':
    main()
