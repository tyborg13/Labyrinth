"""mq-21 opt-in builder. The retained mq-16 recipe/delivery remain historical.

Unspecified player-visible data has no numerical fallback. The director fills
mq21_design.json; portable tests supply explicitly synthetic data in memory.
"""
from copy import deepcopy
import json
import math
import numpy as np
from spec.art_identity.maquettes.blender.contract import validate, todos, digest
from ..source_measurements import FOLDER
from ..recipe import compile_spec as compile_mq16, SOURCE_CALIPERS
from ..forms import capsule, oval
from .mq21_pose import posed_joints, rotation_between
from . import mq21_forms, mq21_grip, mq21_pauldrons
from .mq21_contract import validate_authoring,load as director_contract


def read_design():
    return json.loads((FOLDER/'mq21_pose.json').read_text()),json.loads((FOLDER/'mq21_design.json').read_text())


def require_design(p,d):
    missing=todos(p,'pose')+todos(d,'forms')
    if missing:raise ValueError('Unresolved mq-21 design: '+'; '.join(missing))
    validate_authoring(p,d)
    if type(d['legs']['size_is_radius']) is not bool:raise ValueError('Leg size convention must be explicit')
    for value in (d['helm']['dome_height_over_H'],d['helm']['crest_front_height_over_H'],d['helm']['crest_rear_height_over_H'],d['legs']['calf_bulge_fraction_from_knee']):
        if not 0<float(value)<1:raise ValueError('Fraction must be strictly between zero and one')
    depths=d['back_tabard']['tear_depths_over_H']
    if len(depths)!=4 or any(not .02<=value<=.04 for value in depths):raise ValueError('Four tear depths in 0.02–0.04H required')
    if d['back_tabard']['knee_clearance_over_H']<=0:raise ValueError('Rear hem must end above the knees')
    if not 0<d['legs']['depth_over_width']<=1:raise ValueError('Invalid armour depth ratio')
    if len(d['back_tabard']['tear_positions_across_width'])!=4:raise ValueError('Four torn-point positions required')


def compile_spec(design=None):
    p,provided=read_design();d=deepcopy(provided if design is None else design);require_design(p,d)
    old=compile_mq16();spec=deepcopy(old);H=old['mq16']['height_m'];L=old['mq16']['leg_length_m']
    c=SOURCE_CALIPERS;u=L/c['hip_to_sole_px'];radius=d['legs']['hip_size_over_H']*H/2
    from .mq21_blade_solve import solve
    accepted=director_contract()['accepted_far_arm'];blade_solve=deepcopy(accepted['solve'])
    shoulder=np.asarray(old['joints']['shoulder_far'])+[p['shoulder_forward_over_H']*H,0,
        (p['shoulder_raise_over_H']-blade_solve['far_shoulder_hunch_reduction_over_H'])*H]
    if np.allclose(shoulder,accepted['shoulder_m'],atol=1e-9,rtol=0):
        for name in ('blade_down_degrees','blade_outward_degrees','far_fist_lowering_over_H','far_shoulder_hunch_reduction_over_H'):
            p[name]=blade_solve[name]
    else:p,blade_solve=solve(old,p,d,c,u)
    spec['joints']=posed_joints(old,p,H,d['legs']);spec['pose']=p;spec['pieces']=[]
    spec['mq21']={'forms':d,'reference_height_m':H,'baseline_spec_hash':digest(old),
        'height_definition':'Same body-space H gauge as mq-16; actual crown and crest height also observed.',
        'blade_solve':blade_solve}
    spec['native_spec']='mq21_measurements.json';spec['delivery_reports']=['native_probe.json','mq21_acceptance.json']
    j=spec['joints'];before=old['joints']
    by_id={piece['id']:piece for piece in old['pieces']}
    retained={'cuirass','pelvis_plate','scarf_cowl','strap_a','strap_b','round_strap_buckle','belt','square_belt_buckle','tabard'}
    for name in retained:
        piece=deepcopy(by_id[name]);q=np.asarray(piece['vertices'])
        if name in {'cuirass','strap_a','strap_b','round_strap_buckle','scarf_cowl'}:
            # Transport existing identity geometry with torso lean. The scarf
            # also follows the explicit forward/up shoulder hunch.
            old_slope=math.tan(math.radians(old['pose']['hip_lean_degrees']))
            new_slope=math.tan(math.radians(p['hip_lean_degrees']))
            q[:,0]+=(q[:,2]-j['pelvis'][2])*(new_slope-old_slope)
            if name=='scarf_cowl':q+=np.array([p['shoulder_forward_over_H']*H,0,p['shoulder_raise_over_H']*H])
            else:
                fraction=np.clip((q[:,2]-j['pelvis'][2])/(j['shoulder_near'][2]-j['pelvis'][2]),0,1)
                q[:,1]*=1+(d['arms']['chest_shoulder_width_multiplier']-1)*fraction
        piece['vertices']=q.tolist();spec['pieces'].append(piece)
    for side in ('near','far'):
        for name,start,end,r in (('upper','shoulder','elbow',c['upper_arm_radius_px']),('fore','elbow','hand',c['forearm_radius_px'])):
            radius=r*u*d['arms']['diameter_multiplier']
            spec['pieces'].append(capsule(name+'_plate_'+side,name+'_'+side,start+'_'+side,j[start+'_'+side],j[end+'_'+side],[radius,radius]))
        radius=c['forearm_radius_px']*u*d['arms']['diameter_multiplier']
        spec['pieces'].append(oval('elbow_articulation_'+side,'fore_'+side,'elbow_'+side,j['elbow_'+side],[radius]*3))
        foot=deepcopy(by_id['sabatons_'+side]);foot['vertices']=(np.asarray(foot['vertices'])+np.subtract(j['ankle_'+side],before['ankle_'+side])).tolist();spec['pieces'].append(foot)
        mq21_forms.leg(spec,side,c,u,d)
        if side=='near':
            a=np.subtract(before['hand_near'],before['elbow_near']);b=np.subtract(j['hand_near'],j['elbow_near'])
            turn=rotation_between(a,b)
            for old_piece in old['pieces']:
                if old_piece['part']!='hand_near':continue
                piece=deepcopy(old_piece)
                piece['vertices']=(np.einsum('ij,kj->ik',(np.asarray(piece['vertices'])-before['hand_near'])*d['arms']['gauntlet_multiplier'],turn)+j['hand_near']).tolist()
                spec['pieces'].append(piece)
        mq21_pauldrons.build(spec,side,c,u,d)
    mq21_forms.helm(spec,c,u,d,by_id['cross_visor']);mq21_forms.back_tabard(spec,c,u,d)
    mq21_grip.build(spec,old,c,u,d)
    # Stable order matters for source hashes and independent clean rebuilding.
    spec['pieces'].sort(key=lambda piece:piece['id'])
    spec['proof_camera_registration']='mq-16 cameras unchanged; same scale and exact half-turn; mq-21 capture must prove framing.'
    validate(spec)
    return spec
