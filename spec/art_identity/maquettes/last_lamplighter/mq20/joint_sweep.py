"""Director feedback 2: all 32 source-projection combinations, in priority order.

Only the complete lantern and iron legs enter these envelopes. The retained
wrap is used during the sweep so strand 9 can be seated at the final pose.
Full production source/native validation remains a separate required gate.
"""
import json
from copy import deepcopy
from .recipe import FOLDER,compile_spec
from .geometry import lantern_clearance
from spec.art_identity.maquettes.blender.contract import digest


def sweep():
    raw=json.loads((FOLDER/'design_details.json').read_text());details=deepcopy(raw)
    details['TODO_DESIGN_robe_layout']=None
    policy=details['TODO_DESIGN_lantern_leg_clearance_resolution']
    report={'scope':'Source projection of complete lantern and iron legs; cloth excluded from envelopes.',
            'required_minimum_over_H':policy['required_minimum_over_H'],'steps':[],'selected':None}
    fixed=None
    for stance in policy['stance_order']:
        for index in range(round((policy['fist_outward_max_over_L']-policy['fist_outward_start_over_L'])/policy['fist_outward_step_over_L'])+1):
            fist=round(policy['fist_outward_start_over_L']+index*policy['fist_outward_step_over_L'],12)
            spec=compile_spec(details,False,fist_outward_over_L=fist,ankle_span_over_shoulders=stance)
            other={k:v for k,v in spec['pose'].items() if k not in ('ankle_span_over_shoulders','fist_outward_of_hip_over_L')}
            if fixed is None:fixed=other
            if other!=fixed:raise ValueError('Unrequested pose control changed during joint sweep')
            clearance=lantern_clearance(spec,{p['id']:p['vertices'] for p in spec['pieces']},spec['mq18']['height_m'])
            gap=clearance['minimum_over_H'];passed=gap>=policy['required_minimum_over_H']
            row={'stance':stance,'fist_outward_over_L':fist,'minimum_over_H':gap,'passed':passed,
                 'per_leg_piece_over_H':clearance['per_leg_piece_over_H'],'spec_hash':digest(spec)}
            report['steps'].append(row)
            if passed and report['selected'] is None:report['selected']={'stance':stance,'fist_outward_over_L':fist,'mode':'gap'}
            print(f'MQ20_JOINT_STEP: stance={stance:.1f}; fist={fist:.2f} L; gap={gap:.12f} H; '+('PASS' if passed else 'FAIL'),flush=True)
    if report['selected'] is None:
        report['selected']={k:policy['fallback'][k] for k in ('stance','fist_outward_over_L')}
        report['selected']['mode']='depth_overlap'
    report['other_pose_values_unchanged']=True
    return report


if __name__=='__main__':
    result=sweep()
    (FOLDER/'feedback2_joint_sweep.json').write_text(json.dumps(result,indent=2)+'\n')
    print('MQ20_JOINT_SELECTION: '+json.dumps(result['selected']),flush=True)
