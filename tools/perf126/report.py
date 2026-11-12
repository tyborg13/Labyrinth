#!/usr/bin/env python3
"""Report observed CPU-only loads and New Run transition intervals, without hiding misses."""
import argparse
import json
from pathlib import Path
import statistics


def summarize(directory):
    log = (directory / 'godot.log').read_text()
    loads = [json.loads(line.split('PERF126 LOAD: ', 1)[1]) for line in log.splitlines()
             if line.startswith('PERF126 LOAD: ')]
    with (directory / 'trace/frames.jsonl').open() as stream:
        header = json.loads(next(stream))
        rows = [dict(zip(header['columns'], row)) for line in stream
                if isinstance(row := json.loads(line), list)]
    transition = [row for row in rows if row['context']['screen'] == '']
    # The census uses the current scene's scene_file_path. Its dynamically made
    # MenuRunTransition has no file path, hence exactly this empty screen name.
    texture_frames = {entry['frame'] + 1 for entry in loads
                      if entry['screen'] == 'MenuRunTransition' and entry['path'].endswith('.png')}
    texture_rows = [row for row in transition if row['frame'] in texture_frames]
    return dict(loads=loads, script_errors=log.count('SCRIPT ERROR'),
                transition_peak_ms=max(row['draw_interval_ms'] for row in transition),
                texture_frame_peak_ms=max((row['draw_interval_ms'] for row in texture_rows), default=0),
                loading_wall_ms=sum(row['draw_interval_ms'] for row in transition),
                map_reached='HITCH DEMO MILESTONE: section_map' in log,
                receipt=json.loads((directory / 'trace/receipt.json').read_text()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pairs', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    results = {}
    table = ['| Pair | A peak ms | B peak ms | Gain | B−A loading ms |',
             '|---|---:|---:|---:|---:|']
    gains = []
    for pair in range(1, 4):
        a, b = [summarize(args.pairs / f'pair-{pair}-{label}') for label in 'AB']
        gain = 1 - b['transition_peak_ms'] / a['transition_peak_ms']
        gains.append(gain)
        table.append(f"| {pair} | {a['transition_peak_ms']:.3f} | {b['transition_peak_ms']:.3f} | {gain:.1%} | {b['loading_wall_ms'] - a['loading_wall_ms']:.3f} |")
        results[str(pair)] = {'A': a, 'B': b, 'gain': gain}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'measurements.json').write_text(json.dumps(results, indent=2) + '\n')
    (args.output / 'pairs.md').write_text('\n'.join(table) + '\n')
    entries = ['| Pair/take | Frame | Screen / phase | Operation | Path | ms | Caller stack (file:line) |',
               '|---|---:|---|---|---|---:|---|']
    for pair, takes in results.items():
        for label in 'AB':
            for entry in takes[label]['loads']:
                stack = [f"{item['source']}:{item['line']} ({item['function']})" for item in entry['stack']
                         if '/tools/perf126/' not in item['source'] and item['function'] != '_load_source_image']
                entries.append(f"| {pair}/{label} | {entry['frame']} | {entry['screen']} / {entry['phase']} | {entry['operation']} | {entry['path']} | {entry['us']/1000:.3f} | {' → '.join(stack)} |")
    (args.output / 'loads.md').write_text('\n'.join(entries) + '\n')
    print('\n'.join(table))
    print(f'PERF126 MEDIAN GAIN: {statistics.median(gains):.1%}; gain range={max(gains)-min(gains):.1%}')
    print('PERF126 SCRIPT ERRORS: ' + str(sum(results[pair][label]['script_errors'] for pair in results for label in 'AB')))
    print('PERF126 LOAD THRESHOLD: ' + ('PASS' if all(not results[pair]['B']['loads'] for pair in results) else 'FAIL (see loads.md)'))
    print('PERF126 FRAME THRESHOLD: ' + ('PASS' if all(gain >= .7 for gain in gains) else 'FAIL'))


if __name__ == '__main__':
    main()
