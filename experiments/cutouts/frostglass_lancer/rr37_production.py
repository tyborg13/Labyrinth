"""Real resolver outcomes begin at the protected contact; source poses agree."""
import argparse
from pathlib import Path
import numpy as np
from rr37_case import CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.production_gates import production_errors

POSE_EPSILON = .0001
CONTACT_EPSILON = .000001
ACTION_KINDS = {'lunge':'aoe','jab':'melee','cast':'ranged','pin':'ranged','guard':'block'}
MOVING_INTENTS = {'lunge','jab','guard'}


def errors(report, data):
    result = production_errors(CASE, report, data)
    if read_json(ASSETS / 'humanoid_v2/compiled_motion.json') != data: result.append('production compilation differs')
    for row in report['frames']:
        for field in ('bones','parts'):
            expected = row.get('reference_'+field,{})
            if not expected or set(expected) != set(row.get(field,{})):
                result.append(row['stage']+': incomplete source/production '+field); continue
            for name in expected:
                for channel in (('local','global') if field == 'bones' else ('transform',)):
                    if not np.allclose(expected[name][channel],row[field][name][channel],atol=POSE_EPSILON,rtol=0):
                        result.append(row['stage']+': source/production pose differs: '+name)
    for clip, kind in ACTION_KINDS.items():
        contact = data['clips'][clip]['contact']
        rows = [r for r in report['frames'] if r['stage'] == clip]
        before = [r for r in rows if r['snapshot']['phase'] < contact]
        at = [r for r in rows if abs(r['snapshot']['phase']-contact) < CONTACT_EPSILON]
        if not before or not at: result.append(clip+': missing pre/contact outcome evidence'); continue
        if any(r['effect'].get('kind') == kind for r in before): result.append(clip+': effect before contact')
        if kind == 'block':
            if any(r['actor_block'] != before[0]['actor_block'] for r in before): result.append(clip+': block before contact')
            if at[0]['actor_block'] <= before[0]['actor_block']: result.append(clip+': existing block missing at contact')
        else:
            if any(r['player_hp'] != before[0]['player_hp'] for r in before): result.append(clip+': damage before contact')
            if at[0]['player_hp'] >= before[0]['player_hp']: result.append(clip+': real damage missing at contact')
            if at[0]['effect'].get('kind') != kind: result.append(clip+': existing effect missing at contact')
            socket = at[0].get('socket_proof', {})
            if not socket or socket.get('board_delta_px', float('inf')) > 2.0:
                result.append(clip+': projectile/trail socket differs from drawn spear tip')
    for clip in MOVING_INTENTS:
        moves = [r for r in report.get('movement_frames',[]) if r['intent'] == clip]
        if not moves or not any(r['phase'] >= 1 for r in moves): result.append(clip+': missing real per-step move playback')
    return sorted(set(result))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,required=True);args=parser.parse_args()
    report=read_json(args.input);findings=errors(report,read_json(CASE/'compiled_motion.json'))
    write_json(args.input.with_name('gates.json'),{'ok':not findings,'errors':findings,'native_pixels':report['native_pixels']})
    print('RR37 PRODUCTION CONTACTS/POSES: %s (%d errors)' % ('FAIL' if findings else 'PASS',len(findings)))
    for error in findings: print(error)
    raise SystemExit(bool(findings))
