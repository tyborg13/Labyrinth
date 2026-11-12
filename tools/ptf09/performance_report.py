"""Summarize measured paired samples without setting a new performance budget."""
import json
from pathlib import Path
import statistics
import sys


def stats(values):
    values = sorted(values)
    return (statistics.median(values), values[min(len(values)-1, int(len(values)*.99))])


def main():
    path = Path(sys.argv[1])
    data = json.loads(path.read_text())
    print('PTF09 PERF: order A/B, B/A, A/B; baseline ' + data['baseline_head'])
    for metric in ('hover_usec', 'frame_wall_usec', 'runtime_cpu_usec'):
        if metric not in data['results'][0]:
            continue
        for side in ('A', 'B'):
            values = [v for row in data['results'] if row['side'] == side for v in row[metric]]
            median, p99 = stats(values)
            print(f'{side} {metric}: median={median:.1f} p99={p99:.1f} n={len(values)}')
    print('Headless samples measure CPU only; renderer/GPU acceptance requires native proof.')


if __name__ == '__main__':
    main()
