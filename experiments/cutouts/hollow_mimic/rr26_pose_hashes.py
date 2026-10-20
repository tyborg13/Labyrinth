"""Before/after pose inventories, with committed-record and replay provenance."""
from collections import defaultdict
import csv
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.bone_evidence import read_report

LOG = ROOT / 'experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f3'
RIGS = {'seer': 'hoarfrost_seer/rr10', 'thrall': 'arc_thrall/rr11',
        'mirror': 'glacial_mirror/rr18', 'mimic': 'hollow_mimic/rr20',
        'weaver': 'briar_weaver/mq9', 'mortar': 'slag_mortar/rr22',
        'capacitor': 'storm_capacitor/mq5'}
INVENTORIES = ('samples', 'authored', 'production_samples', 'production_authored')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def raw_rows(path, inventory):
    """Keep each original object lexeme, including tiny float spellings."""
    source = path.read_text()
    match = re.search('"' + inventory + r'"\s*:\s*\[', source)
    if match is None: return []
    decoder, position, result = json.JSONDecoder(), match.end(), []
    while True:
        while source[position].isspace() or source[position] == ',': position += 1
        if source[position] == ']': return result
        _, end = decoder.raw_decode(source, position)
        result.append(source[position:end])
        position = end


def raw_digest(rows):
    return hashlib.sha256('\n'.join(rows).encode()).hexdigest()


def report():
    baselines = read_json(LOG / 'baseline_manifest.json')
    units, rows = {}, []
    for unit, relative in RIGS.items():
        source = baselines[unit]
        if not source['available']: raise ValueError('Unverified before inventory: ' + unit)
        before_path = LOG / source.get('file', f'before_{unit}.json')
        before = read_json(before_path)
        case = ROOT / 'experiments/cutouts' / relative
        after = read_report(case)
        # read_report above validates the canonical reference before this
        # lexical audit reads bytes; this is not another compact-report reader.
        after_path = case / 'proof/samples.json'
        compact = read_json(after_path)
        if 'full_samples' in compact: after_path = after_path.parent / compact['full_samples']['file']
        if source.get('expected_full_sha256'):
            if hashlib.sha256(before_path.read_bytes()).hexdigest() != source['expected_full_sha256']:
                raise ValueError('Reconstructed record does not match committed hash: ' + unit)
        old = {key: before[key] for key in INVENTORIES if key in before}
        new = {key: after[key] for key in old}
        added = {key: len(after[key]) for key in INVENTORIES if key in after and key not in old}
        if canonical(old) != canonical(new): raise ValueError('Pose records changed: ' + unit)
        raw_before = {key: raw_rows(before_path, key) for key in old}
        raw_after = {key: raw_rows(after_path, key) for key in old}
        if raw_before != raw_after: raise ValueError('Raw pose row bytes changed: ' + unit)
        for key in added:
            original = key.removeprefix('production_')
            if (original not in old or len(after[key]) != len(old[original]) or
                    any(a['bones'] != b['bones'] for a, b in zip(after[key], old[original]))):
                raise ValueError('Additional production poses differ from committed case bones: ' + unit)
        count = sum(len(value) for value in new.values())
        committed_record = source['committed_record_available']
        units[unit] = {'rows': count, 'before_sha256': digest(old), 'after_sha256': digest(new),
            'identical': True, 'before_revision': source['revision'],
            'raw_pose_rows_identical': True,
            'raw_before_sha256': raw_digest([row for key in old for row in raw_before[key]]),
            'raw_after_sha256': raw_digest([row for key in old for row in raw_after[key]]),
            'committed_record_available': committed_record,
            'additional_after_inventories': added,
            'additional_production_bones_match_committed_case': bool(added),
            'before_kind': 'committed record' if committed_record else 'committed-source replay',
            'before_file_sha256': hashlib.sha256(before_path.read_bytes()).hexdigest()}
        for inventory, poses in old.items():
            grouped_old, grouped_new = defaultdict(list), defaultdict(list)
            grouped_raw_old, grouped_raw_new = defaultdict(list), defaultdict(list)
            for target, selected in ((grouped_old, poses), (grouped_new, new[inventory])):
                for pose in selected:
                    kind = pose.get('kind', 'authored' if 'authored' in inventory else 'presented')
                    target[pose['view'], pose['clip'], kind].append(pose)
            for target, selected, raw_values in ((grouped_raw_old, poses, raw_before[inventory]),
                                                (grouped_raw_new, new[inventory], raw_after[inventory])):
                for pose, raw in zip(selected, raw_values):
                    kind = pose.get('kind', 'authored' if 'authored' in inventory else 'presented')
                    target[pose['view'], pose['clip'], kind].append(raw)
            for key in sorted(grouped_old):
                rows.append({'unit': unit, 'view': key[0], 'clip': key[1], 'kind': key[2],
                    'inventory': inventory, 'rows': len(grouped_old[key]),
                    'before_sha256': digest(grouped_old[key]), 'after_sha256': digest(grouped_new[key]),
                    'raw_before_sha256': raw_digest(grouped_raw_old[key]),
                    'raw_after_sha256': raw_digest(grouped_raw_new[key]),
                    'identical': True, 'before_kind': units[unit]['before_kind']})
        print('RR26 POSE IDENTITY %s: PASS (%d rows; raw row bytes identical; %s; %s)' %
              (unit.upper(), count, units[unit]['before_kind'], units[unit]['after_sha256']))
    output = Path(__file__).with_name('rr26_feedback3_pose_hashes.csv')
    with output.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=tuple(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
    result = {'ok': True, 'native_pixels': False, 'units': units, 'raw_pose_rows_identical': True,
        'all_committed_record_baselines': all(row['committed_record_available'] for row in units.values()),
        'scope': 'Canonical and raw JSON bytes of every before-record pose row; input headers and whitespace outside rows excluded; all views/clips/kinds; after-only inventories listed separately',
        'groups': rows}
    write_json(Path(__file__).with_name('rr26_feedback3_pose_hashes.json'), result)
    print('RR26 POSE HASH TABLE: %d view/clip/kind inventories; Mirror committed-record proof remains unavailable' % len(rows))
    return result


if __name__ == '__main__': report()
