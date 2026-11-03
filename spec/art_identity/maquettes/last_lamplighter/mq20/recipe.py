"""Revision-specific compiler. Never rewrite the design owner's mq-18 data."""
from copy import deepcopy
import argparse
import json
import math
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.raster import camera
from ..recipe import compile_spec as compile_mq18, FOLDER as BASE, PROJECT
from ..body import build as body
from ..accessories import cage,belt
from .pose import solve

FOLDER=Path(__file__).resolve().parent
# Semantic maps are proof-only; these colours never become character paint.
PROOF_LABELS={'pauldron_near':[.9,.7,.3],'pauldron_far':[.3,.7,.9]}
CAPTURE_SIZE=1088


def head_axes(pose):
    pitch=math.radians(pose['hip_lean_degrees']+pose['head_additional_pitch_degrees'])
    return np.array([[math.cos(pitch),0,-math.sin(pitch)],[0,1,0],[math.sin(pitch),0,math.cos(pitch)]])


def retained_head(baseline,joints,pose):
    old=head_axes(baseline['pose']);new=head_axes(pose);pieces=[]
    for original in baseline['pieces']:
        if original['part'] not in ('head','hood'):continue
        piece=deepcopy(original)
        local=np.einsum('nj,kj->nk',np.asarray(piece['vertices'])-baseline['joints']['head'],old)
        piece['vertices']=(np.asarray(joints['head'])+np.einsum('nj,jk->nk',local,new)).tolist();pieces.append(piece)
    return pieces


def design_values(raw):
    values={};pending=[]
    for key,value in raw.items():
        if key=='authority':continue
        if key.startswith('TODO_DESIGN_'):
            if value is None:pending.append(key)
            else:values[key.removeprefix('TODO_DESIGN_')]=value
        else:raise ValueError('Unknown design detail: '+key)
    required={'pauldron_surface','pauldron_placement','lantern_grip','robe_layout'}
    supplied=set(values)|{k.removeprefix('TODO_DESIGN_') for k in pending}
    if supplied-{'lantern_leg_clearance_resolution'}!=required:
        raise ValueError('Design detail schema is incomplete')
    return values,pending


def compile_spec(details=None,require_resolved=True,*,fist_outward_over_L=None,ankle_span_over_shoulders=None):
    directives=json.loads((FOLDER/'directives.json').read_text())
    details=details if details is not None else json.loads((FOLDER/'design_details.json').read_text())
    values,pending=design_values(details)
    if require_resolved and pending:raise ValueError('Unresolved design: '+', '.join(pending))
    baseline=compile_mq18();spec=deepcopy(baseline);spec['pieces']=[];spec['native_features']={}
    spec['pose'].update(directives['pose']);spec['pose'].pop('knee_bend_degrees')
    if fist_outward_over_L is not None:
        policy=values.get('lantern_leg_clearance_resolution')
        if policy is None:raise ValueError('Fist sweep requires director clearance policy')
        start=policy['fist_outward_start_over_L'];step=policy['fist_outward_step_over_L'];end=policy['fist_outward_max_over_L']
        position=(fist_outward_over_L-start)/step
        if not start<=fist_outward_over_L<=end or abs(position-round(position))>1e-8:
            raise ValueError('Fist sweep is outside director-authorized steps')
        spec['pose']['fist_outward_of_hip_over_L']=fist_outward_over_L
    if ankle_span_over_shoulders is not None:
        policy=values.get('lantern_leg_clearance_resolution',{})
        if ankle_span_over_shoulders not in policy.get('stance_order',[]):
            raise ValueError('Stance is outside director-authorized steps')
        spec['pose']['ankle_span_over_shoulders']=ankle_span_over_shoulders
    spec['dimensions'].update(directives['dimensions'])
    for key in ('lamp_width_over_H','lamp_height_over_H','lamp_depth_over_H','lamp_outward_degrees','panes_per_face'):
        spec['dimensions'].pop(key)
    spec['labels'].pop('lamp_house');spec['labels'].update(deepcopy(PROOF_LABELS))
    spec['base']['covered_regions']=list(spec['labels'])
    H=spec['mq18']['height_m'];L=spec['mq18']['leg_length_m'];u=spec['mq18']['source_unit_m_per_px']
    spec['joints'],shear=solve(spec['source_calipers'],spec['pose'],H,L,u,spec['dimensions'])
    # Rotating the retained hood lowers its crown. Recover H from that actual
    # rigid geometry, then solve H-relative controls against the new height.
    # Rebuilding a taller hood merely to keep the old crown Z changes its volume.
    head=retained_head(baseline,spec['joints'],spec['pose'])
    H=max(max(v[2] for v in q['vertices']) for q in head if q['part']=='hood')
    spec['mq18']['height_m']=H
    spec['joints'],shear=solve(spec['source_calipers'],spec['pose'],H,L,u,spec['dimensions'])
    spec['mq18'].pop('lamp_local_axes',None);spec['mq18']['shoulder_shear']=shear
    for name in ('pole_near_root','pole_near_tip'):
        spec['armature']['rest_joints'][name]=deepcopy(spec['joints'][name])
    spec['mq20']={'design_pending':pending,'design_values':values,'revision':'mq-20'}
    body(spec,u)
    spec['pieces'][:]=[q for q in spec['pieces'] if q['part'] not in ('head','hood')]
    spec['pieces']+=retained_head(baseline,spec['joints'],spec['pose'])
    # Far claws alone gain the new length; the closed near grip is rebuilt
    # around the owner-specified top ring below. All other iron is inherited.
    from .lantern import replace_grip,build as lantern
    replace_grip(spec,values.get('lantern_grip'))
    cage(spec,u);belt(spec,u);lantern(spec,u,values.get('lantern_grip'))
    from .pauldrons import build as pauldrons
    pauldrons(spec,values.get('pauldron_surface'),values.get('pauldron_placement'))
    from .robe import replace as robe
    robe(spec,values.get('robe_layout'))
    spec['delivery_reports']=['native_probe.json','mq20_acceptance.json']
    # Same inherited registration and true turn, measured from body geometry.
    _,_,basis,_=camera(spec)
    # The requested comparison uses one physical scale for mq-18 and mq-20.
    # Re-fitting each figure to 237 body pixels would hide size differences.
    spec['mq20']['capture_size_px']=CAPTURE_SIZE
    spec['ortho_scale']=baseline['ortho_scale']*CAPTURE_SIZE/1024
    vertices=np.concatenate([np.asarray(p['vertices']) for p in spec['pieces']])
    for view,matrix in [('front',np.eye(4)),('rear',np.diag([-1.,-1.,1.,1.]))]:
        xy=np.einsum('nj,kj->nk',np.einsum('nj,kj->nk',vertices,matrix[:3,:3]),basis[:2]);centre=(xy.min(0)+xy.max(0))/2
        spec['view_transforms'][view]={'object_to_world':matrix.tolist(),'target':(basis[0]*centre[0]+basis[1]*centre[1]).tolist(),
            'azimuth_deg':45,'elevation_deg':30,'ortho_scale':spec['ortho_scale']}
    if not pending:validate(spec)
    return spec


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--draft',action='store_true',help='Partial geometry only; never a deliverable')
    args=parser.parse_args();spec=compile_spec(require_resolved=not args.draft);write(args.out,spec)
    print('MQ20_COMPILE: '+('DRAFT; unresolved='+str(spec['mq20']['design_pending']) if spec['mq20']['design_pending'] else 'PASS'))


if __name__=='__main__':main()
