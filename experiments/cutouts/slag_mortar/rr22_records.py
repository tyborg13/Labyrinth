"""Compact tracked proof inventories; complete evidence stays in ignored logs."""
import argparse
from collections import Counter
from pathlib import Path
from rr22_case import CASE
from cutout_pipeline.cases import digest, read_json, write_json

FULL_SAMPLES = 'proof/logs/samples_full.json'


def compact_samples():
    full = read_json(CASE / FULL_SAMPLES)
    counts = Counter((r['view'], r['clip'], r['kind']) for r in full['samples'])
    result = {k: v for k, v in full.items() if k not in ('samples', 'inputs')}
    result.update(full_samples={'file': str(Path(FULL_SAMPLES).relative_to('proof')), 'sha256': digest(CASE / FULL_SAMPLES)},
                  sample_count=len(full['samples']),
                  inventory=[dict(view=v, clip=c, kind=k, count=n) for (v, c, k), n in sorted(counts.items())])
    write_json(CASE / 'proof/samples.json', result)
    print(f'RR22 COMPACT SAMPLES: PASS ({result["sample_count"]} poses; full evidence in {FULL_SAMPLES})')
    return result


def summary(report):
    from humanoid_cutout.walk_gates import summary as walk_summary
    if 'frames' in report and 'swings' in report:
        return walk_summary(report)
    result = {k: v for k, v in report.items() if k not in ('rows', 'frames')}
    for field in ('rows', 'frames'):
        if field in report: result[field + '_count'] = len(report[field])
    return result


def space_summary(rows):
    """Bounds/counts only; frame-by-frame pocket evidence stays in logs."""
    pockets = [p for row in rows for p in row['air_pockets']]
    counts = Counter((tuple(p['bbox']), p['pixel_count']) for p in pockets)
    return dict(frames_with_passed_space=len(rows), air_pockets_passed=len(pockets),
                maximum_air_pocket_pixels=max((p['pixel_count'] for p in pockets), default=0),
                painted_detached_components_passed=sum(len(r['source_components']) for r in rows),
                pocket_bounds=[dict(bbox=list(b), pixel_count=p, occurrences=n)
                               for (b, p), n in sorted(counts.items())])


def compact_production():
    for name in ('production_logic', 'production_logic_rear'):
        path = CASE / f'proof/logs/{name}/logic_frames.json'
        full = read_json(path)
        counts = Counter(row['stage'] for row in full['frames'])
        contacts = {}
        for clip in ('lob', 'land', 'brace'):
            rows = [r for r in full['frames'] if r['stage'] == clip]
            changed = [r for r in rows if (r['marks'] > 0 if clip == 'lob' else
                       r['player_hp'] < rows[0]['player_hp'] if clip == 'land' else r['enemy_block'] > 0)]
            if changed: contacts[clip] = changed[0]['snapshot']['phase']
        result = {k: v for k, v in full.items() if k not in ('frames', 'inputs')}
        result.update(full_samples={'file': str(path.relative_to(CASE / 'proof')), 'sha256': digest(path)},
                      frame_count=len(full['frames']), stage_counts=dict(counts), outcome_contacts=contacts)
        write_json(CASE / f'proof/{name}/logic_frames.json', result)
        print(f'RR22 COMPACT {name.upper()}: PASS ({result["frame_count"]} frames)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['samples', 'production'])
    args = parser.parse_args()
    if args.command == 'samples': compact_samples()
    else: compact_production()
