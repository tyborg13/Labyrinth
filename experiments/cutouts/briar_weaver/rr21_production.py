"""Verify actual production callbacks, contacts, outcomes and source bindings."""
from rr21_case import CASE, ASSETS
import sys
sys.path.insert(0, str(CASE.parents[3] / 'tools'))
from humanoid_cutout.production_gates import production_errors as progression_errors
from cutout_pipeline.cases import read_json
import numpy as np

POSE_EPSILON = 0.0001 # Existing serialized Bone2D tolerance.


def errors(report, data):
    result = progression_errors(CASE, report, data)
    if read_json(ASSETS / 'humanoid_v2/compiled_motion.json') != data:
        result.append('Production compilation differs from protected case')
    for row in report['frames']:
        for field in ('bones', 'parts'):
            reference = row.get('reference_' + field, {})
            if set(row.get(field, {})) != set(reference) or not reference:
                result.append(row['stage'] + ': missing source/production ' + field + ' inventory')
                continue
            for name, expected in reference.items():
                actual = row[field][name]
                for channel in (('local', 'global') if field == 'bones' else ('transform',)):
                    if not np.allclose(actual[channel], expected[channel], atol=POSE_EPSILON, rtol=0):
                        result.append(row['stage'] + ': production signed pose differs: ' + name + '/' + channel)
    for clip in ('thornwall', 'lash', 'mend'):
        contact = data['clips'][clip]['contact']
        rows = [r for r in report['frames'] if r['stage'] == clip]
        if not rows:
            result.append(clip + ': missing real action')
            continue
        contacts = [r for r in rows if abs(r['snapshot']['phase'] - contact) < 1e-6]
        for row in rows:
            if not row.get('bones') or not row.get('parts'): result.append(clip + ': missing production pose evidence')
            if row['snapshot']['phase'] < contact and row.get('cues'):
                result.append(clip + ': sound before contact')
        cue = 'heal' if clip == 'mend' else 'spell.earth'
        if not contacts or not any(c['cue'] == cue for c in contacts[0].get('cues', [])):
            result.append(clip + ': missing existing sound at exact contact')
        cues = {(c['cue'], c['seconds']) for row in rows for c in row.get('cues', []) if c['cue'] == cue}
        if len(cues) != 1: result.append(clip + ': expected existing sound exactly once')
        if clip == 'mend':
            before = [r for r in rows if r['snapshot']['phase'] < contact]
            if any(r['ally_hp'] != 1 for r in before): result.append('mend: recipient healed before contact')
            if not contacts or contacts[0]['ally_hp'] != 5: result.append('mend: real 4 HP heal missing at contact')
        if clip == 'thornwall':
            if any(r['terrain_count'] != 0 for r in rows if r['snapshot']['phase'] < contact):
                result.append('thornwall: bramble appeared before contact')
            if not contacts or contacts[0]['terrain_count'] != 3: result.append('thornwall: existing three brambles missing at contact')
    return sorted(set(result))


def motion_gates(report, data):
    """Apply the same knee/support gates at the measured production step size."""
    from humanoid_cutout.walk_gates import report as walk_report, planted_support_report, summary
    moves = [r for r in report['frames'] if r['stage'] == 'move']
    if not moves: return {'ok': False, 'errors': ['missing production move evidence']}
    view = moves[0]['snapshot']['facing']
    samples = report.get('walk_samples', {}).get(view)
    if not samples: return {'ok': False, 'errors': ['missing production walk samples']}
    layout = read_json(CASE / f'layouts/{view}.json')
    walk = walk_report(layout, data, samples)
    actions = {}
    for facing in ('front', 'rear'):
        rows = [dict(row, view=facing, clip=row['stage'], phase=row['snapshot']['phase'],
                     frame=index, kind='presented') for index, row in enumerate(report['frames'])
                if row['stage'] in ('thornwall', 'lash', 'mend', 'hit') and row['snapshot']['facing'] == facing]
        if not rows: continue
        actions[facing] = summary(planted_support_report(read_json(CASE / f'layouts/{facing}.json'), {'samples': rows}))
    findings = sorted(set(walk['errors'] + [e for result in actions.values() for e in result['errors']]))
    return {'ok': not findings, 'errors': findings, 'view': view, 'walk': summary(walk), 'supports': actions,
        'measured_step_distance_px': samples['step_distance_px'], 'measured_screen_pixel_scale': samples['screen_pixel_scale'],
        'design_placeholders': {}}


if __name__ == '__main__':
    import argparse
    from pathlib import Path
    from cutout_pipeline.cases import write_json
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    report = read_json(args.input)
    data = read_json(CASE / 'compiled_motion.json')
    implementation_errors = errors(report, data)
    move = motion_gates(report, data)
    write_json(args.input.with_name('gates.json'), {'ok': not implementation_errors and move['ok'],
        'implementation_errors': implementation_errors, 'motion': move, 'native_pixels': report['native_pixels']})
    print('RR21 PRODUCTION CONTACTS/POSES: %s (%d errors)' % ('FAIL' if implementation_errors else 'PASS', len(implementation_errors)))
    print('RR21 PRODUCTION %s MOVE GATES: %s (%d errors)' % (move.get('view', 'missing').upper(), 'PASS' if move['ok'] else 'FAIL', len(move['errors'])))
    for error in implementation_errors + move['errors']: print(error)
    raise SystemExit(int(bool(implementation_errors) or not move['ok']))
