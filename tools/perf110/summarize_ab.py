#!/usr/bin/env python3
"""Emit literal paired acceptance results, including every failed threshold."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import re


def decision_choices(value):
    """Keep semantic selectors; anonymous Godot node suffixes are process-local."""
    if isinstance(value, dict):
        return {key: (re.sub(r'(@[A-Za-z0-9_]+@)\d+', r'\1<instance>', item)
                      if key == 'path' and isinstance(item, str) else decision_choices(item))
                for key, item in value.items()}
    if isinstance(value, list):
        return [decision_choices(item) for item in value]
    return value


def reduction(before, after):
    return 1 - after / before if before else None


def metrics(result):
    ordinary, slow = result['ordinary'], result['slow']
    return dict(frames=ordinary['frames'], redraws=ordinary['per_frame'],
                polygons=ordinary['polygon_totals'].get('internal_polygons', 0) / ordinary['frames'],
                slow_frames=slow['frames'], slow_ms=sum(slow['redraw_ms_estimate'].values()))


def pooled_metrics(takes):
    ordinary_frames = sum(t['result']['ordinary']['frames'] for t in takes)
    return dict(redraws=sum(t['result']['ordinary']['total'] for t in takes) / ordinary_frames,
                polygons=sum(t['result']['ordinary']['polygon_totals'].get('internal_polygons', 0)
                             for t in takes) / ordinary_frames,
                slow_ms=sum(sum(t['result']['slow']['redraw_ms_estimate'].values()) for t in takes))


def owned_redraw_rate(takes):
    return sum(sum(count for key, count in t['result']['ordinary']['redraws'].items()
                   if key != 'builtin:Node2D') for t in takes) / sum(
                       t['result']['ordinary']['frames'] for t in takes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    takes = json.loads((args.directory / 'takes.json').read_text())
    state_path = args.directory / 'state_comparison.json'
    states = json.loads(state_path.read_text())['pairs'] if state_path.exists() else {}
    pairs = defaultdict(dict)
    lines = ['# perf-110 interleaved measurements', '',
             'All runs: headless census, seed 84 or 85, 96 decisions; startup excluded. ',
             'Ordinary/slow use measured `process_wall_ms <=50 / >50`; ',
             '`redraw_ms_estimate` is a signal-gap estimate, not exclusive redraw CPU.', '',
             '| Pair | Seed | Variant | Ordinary frames | Target redraws/frame | Polygon internal polygons/frame | Slow frames | Slow summed redraw ms estimate |',
             '|---|---|---|---:|---:|---:|---:|---:|']
    for take in takes:
        pairs[take['pair']][take['label']] = take
        row = metrics(take['result'])
        lines.append(f"| {take['pair']} | {take['seed']} | {take['label']} | {row['frames']} | {row['redraws']:.6f} | {row['polygons']:.6f} | {row['slow_frames']} | {row['slow_ms']:.3f} |")
    lines += ['', '| Pair | Redraw reduction ≥60% | Polygon reduction ≥60% | Slow estimate reduction ≥50% | Choices / normalized saved state |',
              '|---|---:|---:|---:|---|']
    results = []
    for number, pair in sorted(pairs.items()):
        a, b = pair['A']['result'], pair['B']['result']
        ma, mb = metrics(a), metrics(b)
        values = [reduction(ma[field], mb[field]) for field in ('redraws', 'polygons', 'slow_ms')]
        raw_decisions_equal = a['decisions_without_timing'] == b['decisions_without_timing']
        decisions_equal = (decision_choices(a['decisions_without_timing']) == decision_choices(b['decisions_without_timing']) and
                     a['receipt']['outcome'] == b['receipt']['outcome'] and
                     a['receipt']['coverage'] == b['receipt']['coverage'])
        saves_equal = states.get(str(number), {}).get('normalized_save_equal')
        identical = decisions_equal and saves_equal is True
        thresholds = (0.60, 0.60, 0.50)
        accepted = all(v is not None and v >= threshold for v, threshold in zip(values, thresholds)) and identical
        results.append(dict(pair=number, seed=pair['A']['seed'], redraw_reduction=values[0],
                            polygon_reduction=values[1], slow_ms_reduction=values[2],
                            raw_logs_without_frames_identical=raw_decisions_equal,
                            decision_choices_identical=decisions_equal, save_state_identical=saves_equal,
                            decisions_and_outcomes_identical=identical, accepted=accepted))
        cells = ['unmeasured' if v is None else f'{v:.2%} ({"PASS" if v >= t else "FAIL"})'
                 for v, t in zip(values, thresholds)]
        lines.append(f'| {number} | ' + ' | '.join(cells) + f' | {"identical" if identical else "DIFFERENT"} |')
    seed_results = []
    lines += ['', 'Pooled per-seed comparison (sum counts / sum ordinary frames across the three takes; sum slow estimates):', '',
              '| Seed | All six: redraw reduction ≥60% | Polygon reduction ≥60% | Slow estimate reduction ≥50% | Five owned classes: redraw reduction (supplemental) |',
              '|---|---:|---:|---:|---:|']
    for seed in sorted({take['seed'] for take in takes}):
        a = pooled_metrics([t for t in takes if t['seed'] == seed and t['label'] == 'A'])
        b = pooled_metrics([t for t in takes if t['seed'] == seed and t['label'] == 'B'])
        values = [reduction(a[field], b[field]) for field in ('redraws', 'polygons', 'slow_ms')]
        seed_ok = all(value is not None and value >= threshold
                      for value, threshold in zip(values, (0.60, 0.60, 0.50)))
        owned_reduction = reduction(
            owned_redraw_rate([t for t in takes if t['seed'] == seed and t['label'] == 'A']),
            owned_redraw_rate([t for t in takes if t['seed'] == seed and t['label'] == 'B']))
        seed_results.append(dict(seed=seed, A=a, B=b, reductions=values,
                                 owned_class_redraw_reduction=owned_reduction, accepted=seed_ok))
        lines.append(f'| {seed} | ' + ' | '.join(f'{value:.2%}' if value is not None else 'unmeasured' for value in values) + f' | {owned_reduction:.2%} |')
    strict_pairs = len(results) == 6 and all(row['accepted'] for row in results)
    accepted = (len(results) == 6 and len(seed_results) == 2 and
                all(row['accepted'] for row in seed_results) and
                all(row['decisions_and_outcomes_identical'] for row in results))
    lines += ['', 'Acceptance: ' + ('PASS' if accepted else 'NOT MET') + '.', '',
              'Acceptance includes builtin:Node2D. The supplemental five-class figure excludes only that aggregate bucket, whose dominant observed population is fire tongues outside the owned scripts; it does not replace the acceptance figure. ',
              'Decision comparison removes frame timing and normalizes only anonymous Godot node numeric suffixes in UI paths. Named selectors (such as Choice1), actions, arguments, text and signals remain exact. Raw logs and their equality flag are retained. ',
              'Replay outcomes and complete coverage dictionaries are compared exactly. ',
              'Saved Variant state is compared directly after excluding wall-clock run duration and normalizing analytics run identity plus its combat-id prefix; the combat ordinal and all other fields remain exact. Raw identity differences and both durations are retained in state_comparison.json. ',
              'These are partial-run outcomes at the fixed decision boundary, not terminal run victories.', '']
    (args.directory / 'comparison.json').write_text(json.dumps(dict(accepted=accepted,
        every_pair_meets_thresholds=strict_pairs, seeds=seed_results, pairs=results), indent=2) + '\n')
    (args.directory / 'comparison.md').write_text('\n'.join(lines))
    print('PERF110 INTERLEAVED ACCEPTANCE: ' + ('PASS' if accepted else 'NOT MET'))
    for row in results: print(json.dumps(row, sort_keys=True))


if __name__ == '__main__':
    main()
