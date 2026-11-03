"""Six geometric defects; the oracle is unchanged during every mutation."""
from copy import deepcopy
import numpy as np
from .oracle import baseline,contract,digit_path

MUTATION_DEFAULTS={'ring_displacement_over_H':.2}


def target_gate(name,result):
    if name=='plate_readded':return result['checks']['no_pauldrons']
    if name=='two_fingers_fused':return next(r['passed'] for r in result['rows'] if r['name']=='fan_0')
    if name=='finger_shortened_20_percent':return next(r['passed'] for r in result['rows'] if r['name']=='finger_far_0_length')
    if name=='curl_zero':return next(r['passed'] for r in result['rows'] if r['name']=='finger_far_0_knuckle_1')
    if name=='ring_outside_fist':return result['checks']['retained_geometry']
    if name=='arm_scaled_2_percent':return next(r['passed'] for r in result['rows'] if r['name']=='upper_plate_near_length_ratio')
    raise ValueError('Unknown target gate: '+name)


def mutate(name,points,faces,owners,H):
    points=deepcopy(points);faces=deepcopy(faces);owners=deepcopy(owners);c=contract()
    if name=='plate_readded':
        plate=next(p for p in baseline()['pieces'] if p['id']=='pauldron_near_panel')
        points[plate['id']]=np.asarray(plate['vertices']);faces[plate['id']]=plate['faces'];owners[plate['id']]={'part':plate['part'],'rig_bone':'torso'}
    elif name=='two_fingers_fused':
        points['finger_far_1']=np.asarray(points['finger_far_0']).copy()
    elif name=='finger_shortened_20_percent':
        p=np.asarray(points['finger_far_0']);root=p[:c['measurement']['sweep_samples']].mean(0)
        points['finger_far_0']=root+(p-root)*.8
    elif name=='curl_zero':
        p=np.asarray(points['finger_far_0']).copy();path,_=digit_path(p,3,True,c['measurement']['sweep_samples'])
        direction=path[1]-path[0];direction/=np.linalg.norm(direction);straight=np.vstack((path[0],path[0]+np.cumsum(np.linalg.norm(np.diff(path,axis=0),axis=1))[:,None]*direction))
        samples=c['measurement']['sweep_samples']
        for k in range(3):p[k*samples:(k+1)*samples]+=straight[k]-path[k]
        p[-1]=straight[-1];points['finger_far_0']=p
    elif name=='ring_outside_fist':points['grip_ring']=np.asarray(points['grip_ring'])+[MUTATION_DEFAULTS['ring_displacement_over_H']*H,0,0]
    elif name=='arm_scaled_2_percent':
        p=np.asarray(points['upper_plate_near']);origin=p[:c['measurement']['limb_ring_samples']].mean(0)
        points['upper_plate_near']=origin+(p-origin)*1.02
    else:raise ValueError('Unknown mq-24 mutation: '+name)
    return points,faces,owners


def run(points,faces,joints,owners,observe):
    original=observe(points,faces,joints,owners)
    if not original['passed']:raise ValueError('Native mutation proof requires a passing independent baseline')
    rows=[]
    for name in contract()['mutations']:
        p,f,o=mutate(name,points,faces,owners,original['height_m']);result=observe(p,f,joints,o)
        rows.append({'mutation':name,'caught':not result['passed'],'failed_checks':[k for k,v in result['checks'].items() if not v],
            'failed_rows':[r['name'] for r in result['rows'] if not r['passed']]})
    return {'passed':all(r['caught'] for r in rows),'caught':sum(r['caught'] for r in rows),'survived':sum(not r['caught'] for r in rows),'rows':rows}
