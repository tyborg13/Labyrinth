"""Validate real resolver callbacks, contact cues and production/source poses."""
import argparse
from pathlib import Path
import sys
import numpy as np
from rr32_case import PROJECT, CASE, ASSETS
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.production_gates import production_errors
from humanoid_cutout.walk_gates import report as walk_report, planted_support_report, summary

POSE_EPSILON = 0.0001 # Existing serialized Bone2D tolerance.
CUES = {'call_the_wind': 'push.slide', 'gust_bolt': 'spell.air', 'still_air': 'block.gain'}


def errors(report, data):
    result = production_errors(CASE, report, data)
    if read_json(ASSETS / 'humanoid_v2/compiled_motion.json') != data:
        result.append('Production compilation differs from protected case')
    for row in report['frames']:
        for field in ('bones', 'parts'):
            reference = row.get('reference_' + field, {})
            actual = row.get(field, {})
            if set(actual) != set(reference) or not reference:
                result.append(row['stage'] + ': missing source/production ' + field + ' inventory')
                continue
            for name, expected in reference.items():
                for channel in (('local', 'global') if field == 'bones' else ('transform',)):
                    if not np.allclose(actual[name][channel], expected[channel], atol=POSE_EPSILON, rtol=0):
                        result.append(row['stage'] + ': production signed pose differs: ' + name + '/' + channel)
    for clip, cue in CUES.items():
        contact = data['clips'][clip]['contact']
        rows = [r for r in report['frames'] if r['stage'] == clip]
        before = [r for r in rows if r['snapshot']['phase'] < contact - 1e-6]
        contacts = [r for r in rows if abs(r['snapshot']['phase'] - contact) < 1e-6]
        at = contacts[0] if contacts else {}
        if any(any(c['cue'] == cue for c in r['cues']) for r in before): result.append(clip + ': sound before contact')
        if not any(c['cue'] == cue and abs(c['seconds'] - at['seconds']) < POSE_EPSILON for c in at.get('cues', [])):
            result.append(clip + ': existing sound missing at exact contact')
        cues = {(c['cue'], c['seconds']) for r in rows for c in r['cues'] if c['cue'] == cue}
        if len(cues) != 1: result.append(clip + ': expected one existing cue')
        if any(r.get('effect') for r in before): result.append(clip + ': VFX before contact')
        if not at.get('effect'): result.append(clip + ': VFX missing at contact')
        if clip == 'call_the_wind':
            if any(r.get('wind') for r in before): result.append(clip + ': wind state before contact')
            if not at.get('wind') or at['wind'].get('source_id') != 1: result.append(clip + ': existing wind state missing at contact')
        if clip == 'still_air':
            if any(r['actor_block'] != 0 for r in before): result.append(clip + ': block before contact')
            if at.get('actor_block') != 5: result.append(clip + ': existing 5 block missing at contact')
        if clip == 'gust_bolt' and before:
            if any(r['player_hp'] != before[0]['player_hp'] for r in before): result.append(clip + ': damage before contact')
            if at.get('player_hp', before[0]['player_hp']) >= before[0]['player_hp']: result.append(clip + ': real ranged damage missing')
    # Complete terminal pose precedes the existing dissolve in both views.
    deaths = [r for r in report['frames'] if r['stage'] == 'death']
    if not any(r['snapshot']['phase'] >= 1 for r in deaths):
        result.append('death: missing terminal pose')
    if any(r.get('fade_progress', 0) > 0 and r['snapshot']['phase'] < 1 for r in deaths):
        result.append('death: fade started before terminal pose')
    return sorted(set(result))


def motion_gates(report, data):
    views, findings = {}, []
    for view, samples in report.get('walk_samples', {}).items():
        layout = read_json(CASE / f'layouts/{view}.json')
        walk = walk_report(layout, data, samples)
        rows = [dict(row, view=view, clip=row['stage'], phase=row['snapshot']['phase'], frame=i, kind='presented')
                for i, row in enumerate(report['frames']) if row['snapshot']['facing'] == view and row['stage'] in CUES]
        supports = planted_support_report(layout, {'samples': rows})
        views[view] = {'walk': summary(walk), 'supports': summary(supports)}
        findings += walk['errors'] + supports['errors']
    if not views: findings.append('missing production walk samples')
    return {'ok': not findings, 'errors': sorted(set(findings)), 'views': views}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    report = read_json(args.input)
    data = read_json(CASE / 'compiled_motion.json')
    findings, motion = errors(report, data), motion_gates(report, data)
    write_json(args.input.with_name('gates.json'), {'ok': not findings and motion['ok'], 'errors': findings,
                'motion': motion, 'native_pixels': report['native_pixels']})
    print('RR32 PRODUCTION CONTACTS/POSES: %s (%d errors)' % ('FAIL' if findings else 'PASS', len(findings)))
    print('RR32 PRODUCTION WALK/SUPPORTS: %s (%d errors)' % ('PASS' if motion['ok'] else 'FAIL', len(motion['errors'])))
    for error in findings + motion['errors']: print(error)
    raise SystemExit(int(bool(findings) or not motion['ok']))
