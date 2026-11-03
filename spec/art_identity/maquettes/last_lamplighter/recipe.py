"""Last Lamplighter: canonical Blender-native specification, no raster painting."""
from copy import deepcopy
import json
from pathlib import Path
import numpy as np
from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.raster import camera
from .pose import solve,NUMERICAL_DEFAULTS

FOLDER=Path(__file__).resolve().parent
PROJECT=FOLDER.parents[3]


def compile_spec():
    c=json.loads((FOLDER/'source_measurements.json').read_text())
    p=json.loads((FOLDER/'director_pose.json').read_text());d=json.loads((FOLDER/'dimensions.json').read_text())
    baseline=board_spec(json.loads((FOLDER.parent/'frostglass_lancer/spec_r3.json').read_text()))
    palette=json.loads((FOLDER.parent/'chainbound_gaoler/measurements.json').read_text())['labels']
    names=['head','torso','pelvis']+[n+'_'+s for s in ('near','far') for n in ('upper','fore','hand','thigh','shin','foot')]
    labels={n:deepcopy(palette[n]) for n in names}
    labels.update(hood=[.45,.15,.65],mantle=[.6,.3,.8],lamp_house=[.9,.7,.3],cage=[.75,.5,.15],
                  belt=[.35,.22,.1],robe=[.95,.5,.6],lantern=[.8,.7,.9])
    L=NUMERICAL_DEFAULTS['leg_length_gauge_m'];u=L/(c['sole_y']-c['hip_y']);H=c['brief_drawn_height_px']*u
    j,shear=solve(c,p,H,L,u,d)
    spec={'id':'last_lamplighter','version':2,'labels':labels,'joints':j,'pieces':[],
        'base':deepcopy(baseline['base']),'armature':deepcopy(baseline['armature']),
        'simulation':deepcopy(baseline['simulation']),'ortho_scale':H,'target':[0,0,H/2],
        'delivery_reports':['native_probe.json','mq18_acceptance.json'],'pose':p,'dimensions':d,'source_calipers':c,
        'native_features':{},'mq18':{'height_m':H,'leg_length_m':L,'source_drawn_height_px':237,
                                  'source_unit_m_per_px':u,'shoulder_shear':shear}}
    spec['base'].pop('covered_above_z',None);spec['base']['covered_regions']=list(labels)
    for item in (spec['base'],spec['armature'],spec['simulation']):item.pop('proposed',None)
    for bone in spec['armature']['bones']:bone['scale']=[1,1]
    # Actual native pole control: the revised outward bend is sagittally
    # degenerate, so its 20-degree pole cannot be inferred from three points.
    import math
    root=np.asarray(j['shoulder_near']);pole=math.radians(p['near_pole_outward_degrees'])
    j['pole_near_root']=root.tolist()
    j['pole_near_tip']=(root+np.array([0,math.sin(pole),-math.cos(pole)])*L*NUMERICAL_DEFAULTS['pole_control_gauge_over_L']).tolist()
    for key in ('pole_near_root','pole_near_tip'):spec['armature']['rest_joints'][key]=deepcopy(j[key])
    spec['armature']['bones'].append({'name':'near_arm_pole','head':'pole_near_root','tail':'pole_near_tip',
        'parent':'torso','region':'upper_near','scale':[1,1],'roll':0,'role':'ik_pole_control'})
    from .body import build
    from .accessories import build as accessories
    build(spec,u);accessories(spec,u)
    _,_,basis,_=camera(spec)
    # Hood crown and sole define the explicit 237px body registration.
    body=np.concatenate([np.asarray(x['vertices']) for x in spec['pieces'] if x['part'] not in ('lamp_house','lantern')])
    screen=np.einsum('nj,kj->nk',body,basis[:2])
    spec['ortho_scale']=float(np.ptp(screen[:,1])*256/237)
    vertices=np.concatenate([np.asarray(x['vertices']) for x in spec['pieces']])
    spec['view_transforms']={}
    for view,matrix in [('front',np.eye(4)),('rear',np.diag([-1.,-1.,1.,1.]))]:
        xy=np.einsum('nj,kj->nk',np.einsum('nj,kj->nk',vertices,matrix[:3,:3]),basis[:2]);centre=(xy.min(0)+xy.max(0))/2
        target=basis[0]*centre[0]+basis[1]*centre[1]
        spec['view_transforms'][view]={'object_to_world':matrix.tolist(),'target':target.tolist(),
            'azimuth_deg':45,'elevation_deg':30,'ortho_scale':spec['ortho_scale']}
    spec['proof_registration']='237px sole-to-hood at 4x; common board camera and scale. Bounds translations only.'
    validate(spec)
    return spec


if __name__=='__main__':
    spec=compile_spec();write(FOLDER/'measurements.json',spec)
    print('MQ18_NATIVE_SPEC: PASS; pieces='+str(len(spec['pieces'])))
