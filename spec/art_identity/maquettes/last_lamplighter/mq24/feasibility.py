"""Director-rule decision evidence, independent of producer diagnostics.

Fan alternatives are emitted as meshes and measured in the retained camera.
The fist audit uses actual blunt caps, palm triangles and recovered finger
disks. Rigid pose changes cannot change cap/palm separation. No design value
is solved by relaxing a gate or changing an approved dimension.
"""
import argparse
from copy import deepcopy
import json
from pathlib import Path
import numpy as np
from spec.art_identity.maquettes.raster import camera
from spec.art_identity.maquettes.blender.curate_delivery import write
from .oracle import contract
from .hand_construction import build
from .recipe import hand


def fan_sweep(spec):
    c=contract();search=c['feedback2_fan_search'];rule=deepcopy(c['feedback1_rules']['far_hand'])
    H=spec['mq18']['height_m'];basis=np.asarray(camera(spec,'front')[2]);rows=[]
    for step in range(search['first_whole_degree'],search['last_whole_degree']+1):
        candidate=deepcopy(spec);rule['fan_degrees']=[k*step for k in (-1.5,-.5,.5,1.5)]
        built,_=build(candidate,'far',rule);hand(candidate,'far',built)
        tips=np.asarray([next(p['vertices'][-1] for p in candidate['pieces'] if p['id']=='finger_far_'+str(k)) for k in range(4)])
        projected=tips@basis[:2].T/H;gaps=np.linalg.norm(np.diff(projected,axis=0),axis=1)
        rows.append({'step_degrees':step,'front_tip_gaps_over_H':gaps.tolist(),
            'minimum_gap_over_H':float(gaps.min()),'passed':bool(gaps.min()>=search['minimum_gap_over_H'])})
    chosen=next((r['step_degrees'] for r in rows if r['passed']),None)
    return {'rows':rows,'smallest_passing_step_degrees':chosen,
        'contract_selection_matches':chosen==search['selected_step_degrees']}


def fist_bound(spec):
    from .contact import fingertip_palm_gaps
    from .pose_audit import inspect
    c=contract();H=spec['mq18']['height_m'];points={p['id']:np.asarray(p['vertices']) for p in spec['pieces']};faces={p['id']:p['faces'] for p in spec['pieces']}
    gaps=fingertip_palm_gaps(points,faces,H,c['measurement']['ray_epsilon']);maximum=c['near_hand']['maximum_fingertip_palm_distance_over_H']
    return {'scope':'tip/palm gap invariant under every allowed rigid offset and roll; independently sampled disk containment',
        'fingertip_palm_distances_over_H':gaps,'maximum_fingertip_palm_distance_over_H':maximum,
        'closure_is_possible':all(g<=maximum+c['measurement']['metric_tolerance_over_H'] for g in gaps),
        'containment_search':inspect(points,spec['joints'],H,c)}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--spec',type=Path,required=True);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();spec=json.loads(args.spec.read_text());result={'fan':fan_sweep(spec),'fist':fist_bound(spec)};write(args.out,result)
    print('MQ24_FAN_SELECTION: '+str(result['fan']['smallest_passing_step_degrees'])+' degrees; contract_matches='+str(result['fan']['contract_selection_matches']))
    print('MQ24_FIST_CLOSURE: '+('PASS' if result['fist']['closure_is_possible'] else 'FAIL')+'; cap_to_palm_over_H='+str(result['fist']['fingertip_palm_distances_over_H']))
    print('MQ24_INDEPENDENT_POSE_SEARCH: '+str(result['fist']['containment_search']))
    return 0 if result['fan']['contract_selection_matches'] else 1


if __name__=='__main__':raise SystemExit(main())
