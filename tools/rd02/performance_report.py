"""Each interleaved pair is reported independently; headless cannot pass GPU cost."""
import argparse
import json
from pathlib import Path
import statistics

MEDIAN_LIMIT_MS = 0.6
P99_LIMIT_MS = 1.5


def percentile(values, fraction):
    ordered = sorted(values)
    offset = (len(ordered) - 1) * fraction
    low = int(offset)
    return ordered[low] + (ordered[min(low + 1, len(ordered) - 1)] - ordered[low]) * (offset - low)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('samples', type=Path)
    args = parser.parse_args()
    data = json.loads(args.samples.read_text())
    passed = data['renderer'] != 'headless' and not data['failures'] and len(data['results']) == 6
    assert data['order'] == ['A', 'B', 'B', 'A', 'A', 'B']
    passed &= all(row.get('active') == 2 and row.get('outlined_units') == 8 for row in data['results'])
    for pair, start in enumerate(range(0, len(data["results"]) - 1, 2), 1):
        rows = {row['side']: row for row in data['results'][start:start + 2]}
        delta = {key: (statistics.median(rows['B'][key]) - statistics.median(rows['A'][key]),
                       percentile(rows['B'][key], .99) - percentile(rows['A'][key], .99))
                 for key in ['frame_usec', 'runtime_cpu_usec', 'render_cpu_usec', 'render_gpu_usec'] if rows['A'][key] and rows['B'][key]}
        median, p99 = delta['frame_usec']
        pair_pass = median / 1000 <= MEDIAN_LIMIT_MS and p99 / 1000 <= P99_LIMIT_MS
        passed &= pair_pass
        label = 'HEADLESS ONLY' if data['renderer'] == 'headless' else 'PASS' if pair_pass else 'FAIL'
        print(f'RD02 PAIR {pair} {"/".join(data["order"][start:start+2])}: added frame median={median / 1000:.3f} ms p99={p99 / 1000:.3f} ms; {label}; {delta}')
    if data['renderer'] != 'headless' and not passed:
        print('TODO_DESIGN_outline_cost: measured native pairs exceed the gate or the required workload failed; keep live-pose technique, no fallback')
    print('RD02 COST: ' + ('UNVERIFIED (headless)' if data['renderer'] == 'headless' else 'PASS' if passed else 'FAIL'))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
