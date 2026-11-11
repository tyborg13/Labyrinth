#!/usr/bin/env python3
"""Render reproducible ptf-01 encounter and shape-check measurements."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
from statistics import mean, median

OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-01')


def stats(rows, variant):
    values = [r[variant] for r in rows]
    return (f"{mean(r['count'] for r in values):.2f} | {max(r['count'] for r in values)} | "
            f"{mean(r['hp'] for r in values):.2f} | {max(r['hp'] for r in values)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    parser.add_argument('--skip-shape', action='store_true')
    args = parser.parse_args()
    output = args.output_dir
    data = json.loads((output / 'encounter_curve.json').read_text())
    text = ['# ptf-01 encounter curve', '',
            '300 seeds (1–300), three sections, uniformly random legal route choices. '
            'Old and new share each generated map, route, room element, biome, entrance and seed; '
            'each maintains its own actual composition history. This isolates encounter scaling. '
            'Production graph, mystery resolution, encounter expansion, placement and depth-scaled HP are used. '
            'Room completion is synthetic; this is not a win-rate simulation. '
            'No guided tutorial is enabled, matching direct RunEngine/run_curve simulations; '
            'tutorial counting is checked separately by the focused checks. '
            'Bosses are excluded from k and these tables. Unchanged specials/Guardians count toward k. '
            'Both all-fight and standard-only rows are shown in each section table.', '',
            'Old means the original depth tier, unrestricted seeded expansion and global cap 7, '
            'through the proof-only baseline generator. New means min(depth tier, fight-number tier), '
            'tier ceilings 3/5/6 and fight caps 3/3/4/5/5/6 (final value continues), fitting token expansion and seeded re-rolls. Enemy stats and special rosters are unchanged.', '']
    for section in range(1, 4):
        text += [f'## Section {section}', '',
                 '| k | Cohort | N | Old mean units | Old max units | Old mean HP | Old max HP | New mean units | New max units | New mean HP | New max HP |',
                 '|---:|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
        rows = [r for r in data['records'] if r['section'] == section]
        groups = defaultdict(list)
        for row in rows:
            groups[row['k']].append(row)
        for k, all_rows in sorted(groups.items()):
            for cohort, selected in [('all', all_rows), ('standard', [r for r in all_rows if r['kind'] == 'combat'])]:
                if selected:
                    text.append(f'| {k} | {cohort} | {len(selected)} | {stats(selected, "old")} | {stats(selected, "new")} |')
        text.append('')
    text += ['## Tester-shaped cases', '',
             'Controlled k/depth reproductions on the first generated Section I node at step 4 or 7, '
             'converted to standard combat while retaining its coord and element. No prior table history; '
             'these test the specified k/depth shapes, not a replay of an unavailable tester save. '
             'k=2, step=4 uses depth band 2; k=3, step=7 uses depth band 3.', '',
             '| Seed | k | Step | Element | Biome | Tier | Composition | Units | HP |',
             '|---:|---:|---:|:---|:---|---:|:---|---:|---:|']
    for row in sorted(data['tester_cases'], key=lambda r: (r['k'], r['seed'])):
        new = row['new']
        text.append(f"| {row['seed']} | {row['k']} | {row['step']} | {row['element']} | {row['biome']} | {new['tier']} | {', '.join(new['units'])} | {new['count']} | {new['hp']} |")
    if args.skip_shape:
        text += ['', 'run_curve shape check skipped this round, as requested.', '']
        (output / 'result.md').write_text('\n'.join(text))
        print(f"PTF01 REPORT: {output / 'result.md'} curve_records={len(data['records'])} shape=skipped")
        return
    text += ['', '## run_curve Section I shape check', '',
             'Uses tools/run_curve.py score generation and frozen-policy verification, and subclasses '
             'tools/run_curve.gd only to select the baseline/new room generator and stop after '
             'Section I’s dragon reward. Existing best-policy route, card, merchant, event and '
             'combat choices are retained. HP carries over through production transitions. '
             'Runs are interleaved old/new per seed 1–30 in up to three workers, sharing a 2,400-second wall deadline. '
             'This is a bot shape check, not a player clear rate.', '']
    by_seed = {}
    for shape_path in [output / 'shape.jsonl', *sorted(output.glob('shape-*.jsonl'))]:
        if not shape_path.exists():
            continue
        for line in shape_path.read_text().splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            key = (row['seed'], row['variant'])
            if key in by_seed:
                assert by_seed[key] == row, f"Conflicting duplicate seed: {key}"
            by_seed[key] = row
    records = [by_seed[key] for key in sorted(by_seed, key=lambda key: (key[0], 0 if key[1] == 'old' else 1))]
    (output / 'shape_unique.jsonl').write_text(''.join(json.dumps(row, sort_keys=True) + '\n' for row in records))
    text += ['| Variant | Completed N | Section I clear rate | Median room reached |', '|:---|---:|---:|---:|']
    for variant in ['old', 'new']:
        rows = [r for r in records if r['variant'] == variant]
        if rows:
            text.append(f"| {variant} | {len(rows)} | {sum(r['section_clear'] for r in rows)}/{len(rows)} ({mean(r['section_clear'] for r in rows):.1%}) | {median(r['room_reached'] for r in rows):g} |")
        else:
            text.append(f'| {variant} | 0 | unavailable | unavailable |')
    text += ['', 'Room reached is the number of entered rooms after the start node, including noncombat rooms and the boss. '
             'Only flushed complete runs are counted. Raw measurements and logs are alongside this report.', '']
    (output / 'result.md').write_text('\n'.join(text))
    print(f"PTF01 REPORT: {output / 'result.md'} curve_records={len(data['records'])} shape_records={len(records)}")


if __name__ == '__main__':
    main()
