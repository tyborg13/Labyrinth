"""Source-proportioned plate knight on the approved CC0 humanoid armature.

The source calipers are construction measurements of the supplied art, not a
new painting or an old-pose fit target. Exact pose controls are director data.
"""
from copy import deepcopy
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.closed_loft import loft
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.raster import camera
from .source_measurements import FOLDER, PROJECT, verify
from .forms import oval,capsule,cord,closed_sheet,union,shell,TOPOLOGY
from .falchion import build_falchion
from .pauldrons import build_pauldrons
from spec.art_identity.maquettes.blender.contract import digest

# Pixel calipers traced on the protected 255px current front. Silhouette
# contour stations retain the helm, flared plate and ragged cloth identities.
SOURCE_CALIPERS = {
    'hip_to_sole_px':97,'ankle_height_px':15,'hip_span_px':43,
    'shoulder_span_px':65,'waist_above_hip_px':25,'neck_above_waist_px':53,
    'shoulder_below_neck_px':14,'helm_height_px':49,'helm_radius_px':19,
    'torso_depth_radius_px':19,'torso_width_radius_px':30,
    'belt_height_px':10,'belt_buckle_width_px':12,'belt_buckle_height_px':10,
    'belt_buckle_wire_px':1.5,'scarf_height_px':18,'scarf_top_radius_px':21,
    'scarf_shoulder_radius_px':41,'strap_width_px':5,'strap_buckle_radius_px':5,
    'upper_arm_radius_px':9,'forearm_radius_px':8,'hand_radius_px':10,
    'hand_half_height_px':10,'thigh_radius_px':12,'shin_radius_px':10,
    'knee_radius_px':12,'knee_depth_px':4,'foot_length_px':42,'foot_width_px':26,
    'pauldron_radius_px':20,'pauldron_shell_thickness_px':2,
    'grip_radius_px':3,'grip_half_length_px':13,'guard_half_width_px':12,
    'pommel_radius_px':5,'blade_half_thickness_px':1.5,'glowing_edge_radius_px':.7,
    'visor_horizontal_half_width_px':11,'visor_vertical_height_px':22,'visor_width_px':2,
    'visor_colour_sample_px':[142,40],
    'tabard_rows_px':[[0,0,15],[23,0,14],[43,0,13],[62,0,12]],
    'tabard_hem_depth_px':[64,58,66,55,63,54,65],
    'tabard_thickness_px':1,
    'helm_stations':[[0,.88],[.08,1],[.72,1],[.84,.88],[1,.06]],
    'cuirass_stations':[[0,.84],[.12,.88],[.65,1],[.92,.88],[1,.64]],
    'finger_radius_px':2.3,'finger_span_px':16}
NUMERICAL_DEFAULTS = {'leg_length_gauge_m':1.,'epsilon':1e-9,'source_canvas_scale':4}


def knee(hip,ankle,ratio,bend):
    delta=np.subtract(ankle,hip);distance=np.linalg.norm(delta)
    lower=distance/math.sqrt(ratio**2+1+2*ratio*math.cos(math.radians(bend)))
    upper=lower*ratio;axis=delta/distance
    along=(upper**2-lower**2+distance**2)/(2*distance)
    forward=np.array([1.,0,0])-axis*axis[0];forward/=np.linalg.norm(forward)
    return np.asarray(hip)+axis*along+forward*math.sqrt(max(0,upper**2-along**2))


def elbow(shoulder,hand,upper,lower):
    delta=np.subtract(hand,shoulder);distance=np.linalg.norm(delta)
    if not abs(upper-lower)<distance<upper+lower:
        raise ValueError('Far hand unreachable at source arm lengths')
    axis=delta/distance;along=(upper**2-lower**2+distance**2)/(2*distance)
    # Elbow falls behind the forward fist, maintaining a low held weapon.
    bend=np.array([-1.,0,0])-axis*(-axis[0]);bend/=np.linalg.norm(bend)
    return np.asarray(shoulder)+axis*along+bend*math.sqrt(max(0,upper**2-along**2))


def director_pose():
    pose=json.loads((FOLDER/'director_pose.json').read_text())
    feedback=json.loads((FOLDER/'director_feedback2.json').read_text())
    pose['blade_down_degrees']=feedback['falchion']['axis_down_degrees']
    pose.pop('blade_tip_clearance_over_height',None)
    return pose


def compile_spec():
    author=json.loads((FOLDER/'authoring.json').read_text())
    p=director_pose()
    source=json.loads((FOLDER/'source_measurements.json').read_text());verify(source)
    baseline=board_spec(json.loads((FOLDER.parent/'frostglass_lancer/spec_r3.json').read_text()))
    c=SOURCE_CALIPERS;L=NUMERICAL_DEFAULTS['leg_length_gauge_m'];u=L/c['hip_to_sole_px']
    # The approved spec retains its original measurement provenance. Obsolete
    # construction values in that record are metadata, never live controls.
    record=json.loads((FOLDER/'source_caliper_record.json').read_text())
    if any(record.get(name)!=value for name,value in c.items()):
        raise ValueError('Active source caliper differs from approved record')
    W=c['shoulder_span_px']*u;hipW=c['hip_span_px']*u
    waist=L+c['waist_above_hip_px']*u;neck=waist+c['neck_above_waist_px']*u
    shoulder_z=neck-c['shoulder_below_neck_px']*u;H=neck+c['helm_height_px']*u
    slope=math.tan(math.radians(p['hip_lean_degrees']))
    centre_x=lambda z:(z-waist)*slope
    # Canonical §3 shoulder bar: level in Z; its horizontal shear enforces
    # the board projection. All other pose distances remain body X/Y/Z.
    shear=(.5-p['shoulder_rise_per_span'])/(.5+p['shoulder_rise_per_span'])
    j={'root':[0,0,0],'pelvis':[0,0,waist],
       'torso':[centre_x((neck+waist)/2),0,(neck+waist)/2],
       'head':[centre_x(neck),0,neck],'head_tip':[centre_x(neck),0,H]}
    sj=source['views']['front']['joints_px']
    foot_bbox=source['views']['front']['parts']['foot_near']['bbox_px']
    old_ankle=[(foot_bbox[0]+foot_bbox[2])/2,(foot_bbox[1]+foot_bbox[3])/2]
    ratio=np.linalg.norm(np.subtract(sj['knee_near'],sj['hip_near']))/np.linalg.norm(np.subtract(old_ankle,sj['knee_near']))
    upper_source=np.linalg.norm(np.subtract(sj['elbow_near'],sj['shoulder_near']))*u
    lower_source=np.linalg.norm(np.subtract(sj['hand_near'],sj['elbow_near']))*u
    near_bend=math.radians(p['near_elbow_bend_degrees'])
    arm_scale=(shoulder_z-L)/(upper_source+lower_source*math.cos(near_bend))
    for side,sign in [('near',1),('far',-1)]:
        shoulder=np.array([centre_x(shoulder_z)-sign*shear*W/2,sign*W/2,shoulder_z])
        hip=np.array([-sign*shear*hipW/2,sign*hipW/2,L])
        ankle=np.array([sign*p['near_step_over_leg_length']*L/2,sign*p['foot_span_over_shoulder_span']*W/2,c['ankle_height_px']*u])
        kn=knee(hip,ankle,ratio,p['knee_bend_degrees'])
        j.update({'shoulder_'+side:shoulder.tolist(),'hip_'+side:hip.tolist(),
                  'knee_'+side:kn.tolist(),'ankle_'+side:ankle.tolist(),
                  'foot_tip_'+side:(ankle+[c['foot_length_px']*u/2,0,-ankle[2]/2]).tolist()})
        if side=='near':
            el=shoulder+[0,0,-upper_source*arm_scale]
            hand=el+np.array([lower_source*arm_scale*math.sin(near_bend),0,-lower_source*arm_scale*math.cos(near_bend)])
        else:
            hand=hip+[p['far_hand_forward_over_leg_length']*L,-p['far_hand_outward_over_leg_length']*L,0]
            el=elbow(shoulder,hand,upper_source,lower_source)
        j['elbow_'+side]=el.tolist();j['hand_'+side]=hand.tolist()
        j['hand_tip_'+side]=(hand+[0,0,-c['hand_half_height_px']*u]).tolist()
    spec=deepcopy(author)
    spec.update(version=2,pose=p,base=deepcopy(baseline['base']),armature=deepcopy(baseline['armature']),
        simulation=deepcopy(baseline['simulation']),joints=j,pieces=[],ortho_scale=H,target=[0,0,H/2],
        delivery_reports=['native_probe.json','mq16_acceptance.json'],native_spec='measurements.json',
        source_calipers=record,source_caliper_units='protected current-art pixels; normalized to measured hip-to-sole L',
        native_features={},mq16={'leg_length_m':L,'height_m':H,'sole_plane_z':0},
        director_feedback2=json.loads((FOLDER/'director_feedback2.json').read_text()))
    spec['base'].pop('covered_above_z',None)
    spec['base']['covered_regions']=[n for n in spec['labels'] if n not in {'pauldron_near','pauldron_far','belt','tabard','falchion'}]
    for item in (spec['base'],spec['armature'],spec['simulation']):item.pop('proposed',None)
    build_forms(spec,u)
    # Feedback 2 preserves the accepted camera and every unaffected form.
    locked=json.loads((FOLDER/'feedback1_preservation.json').read_text())
    for key,value in locked['camera'].items():spec[key]=deepcopy(value)
    if spec['joints']!=locked['joints']:raise ValueError('Accepted joints changed')
    for key in ('base','armature','labels','simulation'):
        if digest(spec[key])!=locked[key+'_digest']:raise ValueError('Accepted '+key+' changed')
    fixed={piece['id']:digest(piece) for piece in spec['pieces'] if piece['part'] not in {'falchion','pauldron_near','pauldron_far'}}
    if fixed!=locked['fixed_piece_digests']:raise ValueError('Accepted body geometry/material changed')
    spec['proof_camera_registration']='Director-approved feedback-1 camera preserved exactly; identity/diag(-1,-1,1), common scale and 45/30 board angles.'
    validate(spec)
    return spec


def build_forms(spec,u):
    c=SOURCE_CALIPERS;j=spec['joints'];pieces=spec['pieces'];p=spec['pose']
    waist=j['pelvis'][2];neck=j['head'][2];H=spec['mq16']['height_m'];L=spec['mq16']['leg_length_m']
    slope=math.tan(math.radians(p['hip_lean_degrees']))
    x_at=lambda z:(z-waist)*slope
    helm_r=c['helm_radius_px']*u;helm_h=c['helm_height_px']*u
    sections=[[j['head'][0],0,neck+t*helm_h,helm_r*r,helm_r*r] for t,r in c['helm_stations']]
    v,f,flat=loft({'sections':sections,'samples':TOPOLOGY['ring_samples']})
    pieces.append(shell('great_helm','head','head',v,f,flat))
    sections=[[x_at(waist+t*(neck-waist)),0,waist+t*(neck-waist),c['torso_depth_radius_px']*u*r,c['torso_width_radius_px']*u*r]
              for t,r in c['cuirass_stations']]
    v,f,flat=loft({'sections':sections,'samples':TOPOLOGY['ring_samples']})
    pieces.append(shell('cuirass','torso','torso',v,f,flat))
    pieces.append(oval('pelvis_plate','pelvis','pelvis',[0,0,(waist+L)/2],
        [c['torso_depth_radius_px']*u,c['torso_width_radius_px']*u,(waist-L)/2]))
    # Cowl envelope extends over both native shoulder joints; all its faces
    # remain torso-owned. Closed periodic rings make genuine cloth volume.
    shoulder_z=j['shoulder_near'][2]
    rings=[]
    for z,rx,ry in [(neck+c['scarf_height_px']*u/2,c['scarf_top_radius_px']*u,c['scarf_top_radius_px']*u),
                     (neck,c['scarf_top_radius_px']*u,c['scarf_top_radius_px']*u),
                     (shoulder_z-c['scarf_height_px']*u/2,c['torso_depth_radius_px']*u,c['scarf_shoulder_radius_px']*u),
                     (shoulder_z-c['scarf_height_px']*u/2,helm_r,helm_r),
                     (neck+c['scarf_height_px']*u/2,helm_r,helm_r)]:
        rings.append([x_at(z),0,z,rx,ry])
    # Remove duplicate seam station; periodic loft closes the collar tube.
    v,f,flat=loft({'sections':rings,'samples':TOPOLOGY['ring_samples'],'periodic':True})
    shear=(.5-p['shoulder_rise_per_span'])/(.5+p['shoulder_rise_per_span'])
    v=[[x-shear*y,y,z] for x,y,z in v]
    pieces.append(shell('scarf_cowl','torso','torso',v,f,flat))
    # Cross visor: actual geometry seated on the cylindrical front (+X).
    visor_z=neck+helm_h*.58;half=c['visor_width_px']*u/2
    visor=[];epsilon=NUMERICAL_DEFAULTS['epsilon']*1000
    arc=np.linspace(-math.pi/2,math.pi/2,TOPOLOGY['ring_samples']//2+1)
    face_x=lambda y:j['head'][0]+np.interp(y,helm_r*np.sin(arc),helm_r*np.cos(arc))+epsilon
    wide=c['visor_horizontal_half_width_px']*u
    ys=sorted(set([-wide,wide]+[float(y) for y in helm_r*np.sin(arc) if -wide<y<wide]))
    # Thin, closed surface inlays follow the actual faceted cylinder. They
    # provide the full dark cross without a raised wire visible from behind.
    visor.append(closed_sheet('visor_horizontal','head','head',
        [[[face_x(y),y,visor_z+z] for y in ys] for z in (-half,half)],epsilon*2,[1,0,0]))
    visor.append(closed_sheet('visor_vertical','head','head',
        [[[face_x(y),y,z] for y in (-half,0,half)]
         for z in (visor_z-c['visor_vertical_height_px']*u,visor_z+half)],epsilon*2,[1,0,0]))
    visor_piece=union('cross_visor','head','head',visor)
    sample=Image.open(PROJECT/'assets/units/ashen_reaver.png').convert('RGB').getpixel(tuple(c['visor_colour_sample_px']))
    srgb=np.asarray(sample,float)/255
    visor_piece['clay_colour']=np.where(srgb<=.04045,srgb/12.92,((srgb+.055)/1.055)**2.4).tolist()
    pieces.append(visor_piece)
    # Leather cross straps sit on the cuirass front; the round buckle belongs
    # to torso. No strap or scarf ownership is transferred to an arm.
    strap_z=(waist+neck)/2
    stations=np.asarray(c['cuirass_stations'])
    def cuirass_front(y,z):
        factor=float(np.interp((z-waist)/(neck-waist),stations[:,0],stations[:,1]))
        rx,ry=c['torso_depth_radius_px']*u*factor,c['torso_width_radius_px']*u*factor
        return x_at(z)+float(np.interp(y,ry*np.sin(arc),rx*np.cos(arc)))
    front_x=cuirass_front(0,strap_z)
    half_width=c['torso_width_radius_px']*u
    for identifier,sign in [('strap_a',1),('strap_b',-1)]:
        rows=[]
        for t in np.linspace(0,1,13):
            z=neck-c['scarf_height_px']*u-t*(neck-c['scarf_height_px']*u-waist)
            y=sign*half_width*.75*(1-2*t)
            rows.append([[cuirass_front(y+delta,z)+u,y+delta,z] for delta in (-c['strap_width_px']*u/2,c['strap_width_px']*u/2)])
        pieces.append(closed_sheet(identifier,'torso','torso',rows,u,[1,0,0]))
    pieces.append(oval('round_strap_buckle','torso','torso',[front_x+c['strap_width_px']*u/2,0,strap_z],
        [c['strap_width_px']*u/2,c['strap_buckle_radius_px']*u,c['strap_buckle_radius_px']*u]))
    # Broad belt has rounded cross section and a square buckle as in source.
    belt_rows=[]
    for angle in np.linspace(0,2*math.pi,TOPOLOGY['ring_samples'],endpoint=False):
        belt_rows.append([0,0,waist+c['belt_height_px']*u/2*math.sin(angle),
            c['torso_depth_radius_px']*u+u*math.cos(angle),c['torso_width_radius_px']*u+u*math.cos(angle)])
    v,f,flat=loft({'sections':belt_rows,'samples':TOPOLOGY['ring_samples'],'periodic':True})
    pieces.append(shell('belt','belt','pelvis',v,f,flat))
    bx=c['torso_depth_radius_px']*u+c['belt_buckle_wire_px']*u
    bw=c['belt_buckle_width_px']*u/2;bh=c['belt_buckle_height_px']*u/2
    pieces.append(cord('square_belt_buckle','belt','pelvis',[[bx,-bw,waist-bh],[bx,bw,waist-bh],
        [bx,bw,waist+bh],[bx,-bw,waist+bh],[bx,-bw,waist-bh]],c['belt_buckle_wire_px']*u))
    # A rounded drape sheet under the belt, with the source's ragged red panel.
    rows=[]
    n=len(c['tabard_hem_depth_px'])
    for depth,_,half in c['tabard_rows_px']:
        row=[]
        for k,t in enumerate(np.linspace(-1,1,n)):
            z=waist-depth*u
            if depth==c['tabard_rows_px'][-1][0]:z=waist-c['tabard_hem_depth_px'][k]*u
            row.append([c['torso_depth_radius_px']*u+u*(1-t*t),t*half*u,z])
        rows.append(row)
    pieces.append(closed_sheet('tabard','tabard','pelvis',rows,c['tabard_thickness_px']*u,[1,0,0]))
    for side,sign in [('near',1),('far',-1)]:
        for name,a,b,r in [('upper','shoulder','elbow',c['upper_arm_radius_px']),
                           ('fore','elbow','hand',c['forearm_radius_px']),
                           ('thigh','hip','knee',c['thigh_radius_px']),
                           ('shin','knee','ankle',c['shin_radius_px'])]:
            pieces.append(capsule(name+'_plate_'+side,name+'_'+side,a+'_'+side,j[a+'_'+side],j[b+'_'+side],[r*u,r*u]))
        for joint,owner,r in [('elbow','fore',c['forearm_radius_px']),('knee','shin',c['shin_radius_px']),
                              ('ankle','shin',c['shin_radius_px'])]:
            pieces.append(oval(joint+'_articulation_'+side,owner+'_'+side,joint+'_'+side,j[joint+'_'+side],[r*u]*3))
        pieces.append(oval('round_knee_'+side,'shin_'+side,'knee_'+side,
            np.asarray(j['knee_'+side])+[c['thigh_radius_px']*u,0,0],
            [c['knee_depth_px']*u,c['knee_radius_px']*u,c['knee_radius_px']*u]))
        ankle=np.asarray(j['ankle_'+side]);h=ankle[2]
        pieces.append(oval('sabatons_'+side,'foot_'+side,'ankle_'+side,ankle+[c['foot_length_px']*u/4,0,-h/2],
            [c['foot_length_px']*u/2,c['foot_width_px']*u/2,h/2]))
        build_pauldrons(spec,side,u,c)
        hand=np.asarray(j['hand_'+side]);r=c['hand_radius_px']*u
        pieces.append(oval('gauntlet_'+side,'hand_'+side,'hand_'+side,hand,[r,r,c['hand_half_height_px']*u]))
        for finger in range(4):
            y=(finger/3-.5)*c['finger_span_px']*u
            points=[hand+[r*.4,y,r*.6],hand+[r,y,0],hand+[r*.3,y,-r*.7],hand+[-r*.3,y,-r*.4]]
            pieces.append(cord('finger_'+side+'_'+str(finger),'hand_'+side,'hand_'+side,points,c['finger_radius_px']*u))
        pieces.append(cord('thumb_'+side,'hand_'+side,'hand_'+side,
            [hand+[r*.2,sign*r,r*.5],hand+[r*.95,sign*r*.35,r*.2],hand+[r*.6,-sign*r*.25,0]],c['finger_radius_px']*u))
    build_falchion(spec,u,c)
    for name,objects in [('cross_visor',['cross_visor']),('round_strap_buckle',['round_strap_buckle']),
                         ('glowing_edge',['glowing_edge'])]:
        feature=deepcopy(spec['features'][name]);feature['objects']=objects;spec['native_features'][name]=feature



if __name__=='__main__':
    result=compile_spec();write(FOLDER/'measurements.json',result)
    print('MQ16_NATIVE_SPEC: PASS; pieces='+str(len(result['pieces'])))
