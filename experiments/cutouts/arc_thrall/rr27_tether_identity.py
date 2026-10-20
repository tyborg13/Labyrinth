"""Exact motion/pose pins authorized by the director's rr-27 feedback 2.

Only the two rear Tether channels and their pose rows may change. Historical
pins are retained; every other raw row stays byte-identical, including order.
"""
from copy import deepcopy
import hashlib
import json
import subprocess

from rr27_build import PROJECT, CASE, ASSETS, RECIPE
from cutout_pipeline.cases import read_json, write_json, digest

BEFORE_REVISION = '64f394c7e1793b4899e7063cbfef90acf3c64331'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
PIN = RECIPE / 'rear_tether_feedback2_pin.json'
# Director rr-27 feedback 2: exact keys, not inferred tuning.
CHANNELS = {
    'tube_tip.forward_px': [[0,0],[.2,0],[.35,65],[.8,65],[.9,0],[1,0]],
    'tube_tip.lift_px': [[0,0],[.2,90],[.35,153],[.8,153],[.9,90],[1,0]]
}
MOTION_PATHS = (
    'spec/peer_benchmark/staged/rr-11/motion_tracks.json',
    'experiments/cutouts/arc_thrall/rr11/director_motion.json',
    'experiments/cutouts/arc_thrall/rr11/compiled_motion.json',
    'assets/units/arc_thrall_cutout/humanoid_v2/director_motion.json',
    'assets/units/arc_thrall_cutout/humanoid_v2/compiled_motion.json'
)


def before_bytes(relative):
    return subprocess.check_output(['git','show',BEFORE_REVISION+':'+relative],cwd=PROJECT)


def motion_is_exact(relative, original):
    if relative not in MOTION_PATHS:
        return False
    expected = deepcopy(json.loads(original))
    if 'view_tracks' in expected:
        expected['director_sha256'] = digest(DIRECTOR)
        expected['view_tracks']['rear']['tether'] = expected_tracks(expected['view_tracks']['rear']['tether'])
    else:
        expected['arc_thrall']['clips']['tether']['view_keys']['rear'] = CHANNELS
    return read_json(PROJECT / relative) == expected


def expected_tracks(original):
    tracks=deepcopy(original)
    for track in tracks:
        if track['source'] in CHANNELS:
            track['keys']=[{'at':p,'value':v,'interpolation':'smoothstep'} for p,v in CHANNELS[track['source']]]
    return tracks


def scope_errors():
    errors = [relative for relative in MOTION_PATHS if not motion_is_exact(relative,before_bytes(relative))]
    for base in (CASE,ASSETS/'humanoid_v2'):
        if (base/'director_motion.json').read_bytes() != DIRECTOR.read_bytes():
            errors.append(str(base/'director_motion.json')+': director import bytes differ')
    return errors


def rear_tether(row):
    return row['view']=='rear' and row['clip']=='tether'


def hash_rows(rows):
    return hashlib.sha256('\n'.join(rows).encode()).hexdigest()


def row_key(row):
    return (row['view'],row['clip'],row['kind'],row['frame'],row['phase'])


def compare(before, after):
    from rr27_check import raw_rows
    inventories,changed,added,removed,errors = {},[],[],[],[]
    for inventory in ('samples','authored','production_samples','production_authored'):
        old,new = raw_rows(before,inventory),raw_rows(after,inventory)
        if not old:
            continue
        old_data,new_data = [json.loads(r) for r in old],[json.loads(r) for r in new]
        old_fixed = [raw for raw,row in zip(old,old_data) if not rear_tether(row)]
        new_fixed = [raw for raw,row in zip(new,new_data) if not rear_tether(row)]
        old_tether = {row_key(row):raw for raw,row in zip(old,old_data) if rear_tether(row)}
        new_tether = {row_key(row):raw for raw,row in zip(new,new_data) if rear_tether(row)}
        if old_fixed!=new_fixed:
            errors.append(inventory+': row bytes outside rear/tether changed')
        for target,keys in ((changed,old_tether.keys() & new_tether.keys()),
                            (added,new_tether.keys()-old_tether.keys()),
                            (removed,old_tether.keys()-new_tether.keys())):
            for key in sorted(keys):
                if target is changed and old_tether[key]==new_tether[key]:
                    continue
                target.append(dict(zip(('view','clip','kind','frame','phase'),key),inventory=inventory))
        inventories[inventory] = {'before_rows':len(old),'after_rows':len(new),
            'unchanged_scope_rows':len(new_fixed),'unchanged_scope_byte_identical':old_fixed==new_fixed,
            'before_unchanged_sha256':hash_rows(old_fixed),'after_unchanged_sha256':hash_rows(new_fixed),
            'rear_tether_rows':len(new_tether),
            'rear_tether_raw_sha256':hash_rows([raw for raw,row in zip(new,new_data) if rear_tether(row)])}
    return {'ok':not errors,'errors':errors,'inventories':inventories,
        'changed_pose_rows':changed,'added_pose_rows':added,'removed_pose_rows':removed}


def pose_report(after):
    relative = str((CASE/'proof/samples.json').relative_to(PROJECT))
    result = compare(before_bytes(relative).decode(),after)
    if not PIN.is_file():
        result['errors'].append('Missing explicitly recorded feedback-2 rear Tether pin')
    else:
        pin = read_json(PIN)
        if pin['director_sha256']!=digest(DIRECTOR) or pin['compiled_sha256']!=digest(CASE/'compiled_motion.json'):
            result['errors'].append('Feedback-2 motion differs from the approved pin')
        for name,row in result['inventories'].items():
            expected = pin['inventories'][name]
            if any(row[k]!=expected[k] for k in ('rear_tether_rows','rear_tether_raw_sha256')):
                result['errors'].append(name+': rear Tether raw pose rows differ from feedback-2 pin')
    result['errors'] += scope_errors()
    result['ok'] = not result['errors']
    return result


def record_pin():
    errors = scope_errors()
    if errors:
        raise ValueError('Unapproved motion delta: '+str(errors))
    relative = str((CASE/'proof/samples.json').relative_to(PROJECT))
    result = compare(before_bytes(relative).decode(),(PROJECT/relative).read_text())
    if not result['ok']:
        raise ValueError(result['errors'])
    write_json(PIN,{'authority':'Director rr-27 feedback 2: apply (0,90), A hold 65/153; only rear tether pose rows may change',
        'before_revision':BEFORE_REVISION,'channels':CHANNELS,
        'director_sha256':digest(DIRECTOR),'compiled_sha256':digest(CASE/'compiled_motion.json'),**result})
    print('RR27 FEEDBACK 2 POSE PIN: RECORDED (%d changed; %d added; %d removed; rear tether only)' %
          tuple(len(result[k]) for k in ('changed_pose_rows','added_pose_rows','removed_pose_rows')))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record-pose-pin',action='store_true')
    args=parser.parse_args()
    if args.record_pose_pin:
        record_pin()
    else:
        report=pose_report((CASE/'proof/samples.json').read_text())
        print('RR27 FEEDBACK 2 POSE IDENTITY: '+('PASS' if report['ok'] else 'FAIL'))
        for error in report['errors']:print(error)
        raise SystemExit(int(not report['ok']))
