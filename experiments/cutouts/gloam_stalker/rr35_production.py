"""Current production progression, real contact payloads and source poses."""
from pathlib import Path
import argparse
import sys
import numpy as np
from rr35_case import PROJECT, CASE, ASSETS
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.production_gates import production_errors
from humanoid_cutout.walk_gates import report as walk_report, summary

EPSILON = 0.0001


def errors(report, data):
    result = production_errors(CASE, report, data)
    if read_json(ASSETS / 'humanoid_v2/compiled_motion.json') != data: result.append('production compilation differs')
    for row in report['frames']:
        for field in ('bones', 'parts'):
            expected = row.get('reference_' + field, {})
            if not expected or set(expected) != set(row.get(field, {})):
                result.append(row['stage'] + ': incomplete source/production ' + field)
                continue
            for name in expected:
                for channel in (('local', 'global') if field == 'bones' else ('transform',)):
                    if not np.allclose(expected[name][channel], row[field][name][channel], atol=EPSILON, rtol=0):
                        result.append(row['stage'] + ': source/production pose differs: ' + name)
    for clip in ('fade', 'ambush', 'slash'):
        rows = [r for r in report['frames'] if r['stage'] == clip]
        contact = data['clips'][clip]['contact']
        at = [r for r in rows if abs(r['snapshot']['phase'] - contact) < 1e-6]
        before = [r for r in rows if r['snapshot']['phase'] < contact]
        if clip == 'fade':
            if any(r['effect'].get('kind') == 'blink' for r in before): result.append('fade: Blink before contact')
            if not at or at[0]['effect'].get('kind') != 'blink': result.append('fade: existing Blink missing at contact')
            if before and any(r['veiled'] for r in before): result.append('fade: Veil applied before Blink contact')
        else:
            if before and any(r['player_hp'] != before[0]['player_hp'] for r in before): result.append(clip + ': damage before contact')
            if not at or not before or at[0]['player_hp'] >= before[0]['player_hp']: result.append(clip + ': real melee damage missing at contact')
            if any(r['effect'].get('kind') == 'melee' for r in before): result.append(clip + ': melee effect before contact')
        if clip in ('ambush', 'slash'):
            impact = 'hit.blade.heavy' if clip == 'ambush' else 'spell.shadow'
            if any(any(c['cue'] == impact for c in row['cues']) for row in before): result.append(clip + ': impact cue before contact')
            if not at or sum(c['cue'] == impact for c in at[0]['cues']) != 1: result.append(clip + ': existing impact cue missing or duplicated at contact')
    moves = [r for r in report.get('movement_frames', []) if r['intent'] == 'slash']
    if not moves or not any(r['phase'] >= 1 for r in moves): result.append('slash: missing real per-step move playback')
    return sorted(set(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    manifest = read_json(args.input)
    data = read_json(CASE / 'compiled_motion.json')
    findings = errors(manifest, data)
    walks = {view: summary(walk_report(read_json(CASE / f'layouts/{view}.json'), data, samples))
        for view, samples in manifest.get('walk_samples', {}).items()}
    write_json(args.input.with_name('gates.json'), {'ok': not findings, 'errors': findings, 'walk': walks, 'native_pixels': manifest['native_pixels']})
    print('RR35 PRODUCTION CONTACTS/POSES: %s (%d errors)' % ('FAIL' if findings else 'PASS', len(findings)))
    for error in findings: print(error)
    raise SystemExit(int(bool(findings)))
