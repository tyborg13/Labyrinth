#!/usr/bin/env python3
"""Join instance input observations to census redraw fields; never infer draws."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

KEYS = (
    'builtin:Polygon2D', 'res://scripts/segmented_health_bar.gd',
    'res://scripts/ui_tooltip_control.gd', 'res://scripts/board_surface_ice_layer.gd',
    'builtin:Node2D', 'res://scripts/enemy_shadow_dissolve_effect.gd',
)
PROCESS_THRESHOLD_MS = 50.0
ORDINARY_GATE_FRACTION = 0.50
SLOW_GATE_FRACTION = 0.30


def summarize(directory):
    directory = Path(directory)
    frames = {}
    with (directory / 'frames.jsonl').open() as source:
        header = json.loads(next(source))
        for line in source:
            row = dict(zip(header['columns'], json.loads(line)))
            if row.get('redraw_frame') != row['frame'] - (not header['native']):
                continue
            # process_wall_ms is the measured headless callback bucket, not the
            # once-a-second TIME_PROCESS rolling peak or total frame interval.
            process_ms = row.get('process_wall_ms')
            if (process_ms is None or not row.get('complete_interval')
                    or row.get('context', {}).get('phase') == 'startup'):
                continue
            frames[row['redraw_frame']] = row
    result = {}
    for bucket, slow in [('ordinary', False), ('slow', True)]:
        selected = {frame: row for frame, row in frames.items()
                    if (row['process_wall_ms'] > PROCESS_THRESHOLD_MS) == slow}
        counts, with_draw, polygons, milliseconds = Counter(), Counter(), Counter(), Counter()
        for row in selected.values():
            for key in KEYS:
                count = row.get('redraws', {}).get(key, 0)
                counts[key] += count
                with_draw[key] += bool(count)
                milliseconds[key] += row.get('redraw_ms_estimate', {}).get(key, 0)
            polygons.update(row.get('redraw_polygons', {}).get('builtin:Polygon2D', {}))
        inputs, unchanged, invisible, redundant = Counter(), Counter(), Counter(), Counter()
        nodes = defaultdict(lambda: dict(draws=0, unchanged=0, invisible=0, frames=set()))
        if (directory / 'draw-inputs.jsonl').exists():
            for line in (directory / 'draw-inputs.jsonl').read_text().splitlines():
                entry = json.loads(line)
                if entry['frame'] not in selected:
                    continue
                key = entry['key']
                # The first observer omitted native Control transform/clip/rect
                # inputs for empty tooltip hosts. Do not authorize any of their
                # legacy "unchanged" observations; retain only alpha-occlusion.
                same = entry['unchanged'] and (key != 'res://scripts/ui_tooltip_control.gd'
                                              or entry.get('inputs_version', 1) >= 2)
                inputs[key] += 1
                unchanged[key] += same
                invisible[key] += entry['invisible']
                redundant[key] += same or entry['invisible']
                node = nodes[(entry['instance'], entry['path'], key)]
                node['draws'] += 1
                node['unchanged'] += same
                node['invisible'] += entry['invisible']
                node['frames'].add(entry['frame'])
        # Mismatched or absent observations cannot authorize production edits.
        matched = dict(counts) == {key: inputs[key] for key in KEYS}
        total = sum(counts.values())
        result[bucket] = dict(frames=len(selected), redraws=dict(counts),
                             frames_with_redraw=dict(with_draw), unchanged=dict(unchanged),
                             invisible=dict(invisible), redundant=dict(redundant),
                             total=total, per_frame=total / len(selected) if selected else None,
                             redundant_fraction=sum(redundant.values()) / total if total else None,
                             input_observations_match_census=matched,
                             polygon_totals=dict(polygons), redraw_ms_estimate=dict(milliseconds),
                             nodes=[dict(instance=k[0], path=k[1], key=k[2], **v,
                                         frames_with_redraw=len(v['frames']))
                                    for k, v in nodes.items()])
        for node in result[bucket]['nodes']:
            node['frames'] = sorted(node['frames'])
    receipt = json.loads((directory / 'receipt.json').read_text()) if (directory / 'receipt.json').exists() else {}
    result['receipt'] = receipt
    decisions = []
    for line in (directory / 'decisions.jsonl').read_text().splitlines():
        entry = json.loads(line)
        entry.pop('frame', None)
        decisions.append(entry)
    result['decisions_without_timing'] = decisions
    # A timed-out/failed/incomplete replay cannot pass the optimization gate.
    complete = receipt.get('outcome') == 'replay_point' and not receipt.get('errors')
    result['gate_passed'] = complete and any(
        result[b]['input_observations_match_census'] and
        (result[b]['redundant_fraction'] or 0) >= threshold
        for b, threshold in [('ordinary', ORDINARY_GATE_FRACTION), ('slow', SLOW_GATE_FRACTION)])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.directory)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PERF110 GATE: ' + ('PASS' if result['gate_passed'] else 'NOT PASSED'))
    for bucket in ('ordinary', 'slow'):
        row = result[bucket]
        print(f"{bucket}: frames={row['frames']} redraws={row['total']} "
              f"redundant_fraction={row['redundant_fraction']} "
              f"observations_match={row['input_observations_match_census']}")


if __name__ == '__main__':
    main()
