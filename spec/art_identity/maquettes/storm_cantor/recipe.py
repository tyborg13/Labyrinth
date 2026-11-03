"""Measured source envelopes on one CC0 armature; exact director pose in metres.

The source art supplies construction calipers. Camera registration and topology
are proof controls. No existing figure or shared builder input is modified.
"""
from copy import deepcopy
import json
import math
from pathlib import Path

import numpy as np

from spec.art_identity.maquettes.blender.closed_loft import loft, sweep
from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.raster import camera
from .forms import oval, capsule, cord, closed_sheet, union, shell, TOPOLOGY
from .volume_targets import targets

FOLDER = Path(__file__).resolve().parent
PROJECT = FOLDER.parents[3]
NUMERICAL_DEFAULTS = {'leg_length_gauge_m': 1., 'epsilon': 1e-9,
                      'canvas_px': 1024, 'source_canvas_px': 255}


def compile_spec():
    c = json.loads((FOLDER/'source_measurements.json').read_text())
    p = json.loads((FOLDER/'director_pose.json').read_text())
    dimensions=targets(FOLDER)
    # The new mouth size explicitly supersedes the historical pose's extra
    # dimension. Its hook and every armature joint remain approved inputs.
    p['bell_mouth_over_H']=dimensions['bell_mouth']
    baseline = board_spec(json.loads((FOLDER.parent/'frostglass_lancer/spec_r3.json').read_text()))
    palette = json.loads((FOLDER.parent/'chainbound_gaoler/measurements.json').read_text())['labels']
    labels = {n: deepcopy(palette[n]) for n in ('head','torso','pelvis','upper_near','fore_near','hand_near',
        'upper_far','fore_far','hand_far','thigh_near','shin_near','foot_near','thigh_far','shin_far','foot_far')}
    # Diagnostic ownership colours only; no material/paint choices.
    labels.update(pauldron_near=[.9,.7,.3], pauldron_far=[.65,.45,.15], bell=[.9,.6,.05],
                  sash=[.35,.22,.1], tabard=[.95,.5,.6], cloak=[.95,.55,.1], staff=[.8,.7,.9])
    L = NUMERICAL_DEFAULTS['leg_length_gauge_m']; u = L/(c['sole_y']-c['hip_y'])
    H = (c['sole_y']-c['taller_tine_y'])*u
    # The common §3 level shoulder bar has the required board projection.
    # This horizontal shear does not introduce a hip/spine lean or a Z offset.
    shear = (.5-p['shoulder_rise_per_projected_span'])/(.5+p['shoulder_rise_per_projected_span'])
    approved=json.loads((FOLDER/'approved_pose.json').read_text())
    j=deepcopy(approved['joints'])
    spec = {'id':'storm_cantor','version':2,'labels':labels,'joints':j,'pieces':[],
            'base':deepcopy(baseline['base']),'armature':deepcopy(baseline['armature']),
            'simulation':deepcopy(baseline['simulation']), 'ortho_scale':H,'target':[0,0,H/2],
            'delivery_reports':['native_probe.json','mq17_acceptance.json'],
            'pose':p,'source_calipers':c,'native_features':{},
            'mq17':{'height_m':H,'leg_length_m':L,'source_drawn_height_px':c['sole_y']-c['taller_tine_y'],
                    'source_unit_m_per_px':u,'sole_plane_z':0,'shoulder_shear':shear}}
    spec['base'].pop('covered_above_z',None)
    spec['base']['covered_regions']=list(labels)
    # Keep the actual approved CC0 body and its bound armature editable. Plate
    # and cloth envelopes cover its render faces; the old hand pose is unused.
    for item in (spec['base'],spec['armature'],spec['simulation']): item.pop('proposed',None)
    for bone in spec['armature']['bones']:
        bone['scale']=[1,1]
    build_forms(spec,u)
    from .volumes import apply as apply_volumes
    apply_volumes(spec,dimensions,approved)
    from .layout_checks import validate_preserved
    validate_preserved(spec)
    # One common scale: sole-to-taller-tine projected extent equals source H.
    # Staff is explicitly excluded from this drawn-height measurement.
    _,_,basis,_=camera(spec)
    body=np.concatenate([np.asarray(x['vertices']) for x in spec['pieces'] if x['part']!='staff'])
    screen=np.einsum('nj,kj->nk',body,basis[:2])
    spec['ortho_scale']=float(np.ptp(screen[:,1])*256/spec['mq17']['source_drawn_height_px'])
    vertices=np.concatenate([np.asarray(x['vertices']) for x in spec['pieces']])
    spec['view_transforms']={}
    for view,matrix in [('front',np.eye(4)),('rear',np.diag([-1.,-1.,1.,1.]))]:
        projected=np.einsum('nj,kj->nk',np.einsum('nj,kj->nk',vertices,matrix[:3,:3]),basis[:2])
        centre=(projected.min(0)+projected.max(0))/2
        target=basis[0]*centre[0]+basis[1]*centre[1]
        spec['view_transforms'][view]={'object_to_world':matrix.tolist(),'target':target.tolist(),
            'azimuth_deg':45,'elevation_deg':30,'ortho_scale':spec['ortho_scale']}
    spec['proof_registration']='Shared source-height scale; per-view bounds centring only. No fit gate or view-specific geometry.'
    validate(spec)
    return spec


def build_forms(spec,u):
    c,p,j=spec['source_calipers'],spec['pose'],spec['joints']; pieces=spec['pieces']
    H=spec['mq17']['height_m']; waist=j['pelvis'][2]; neck=j['head'][2]
    helm_h=(c['helm_bottom_y']-c['helm_top_y'])*u
    rx,ry=np.asarray(c['helm_radius_px'])*u
    helm_bottom=(c['sole_y']-c['helm_bottom_y'])*u
    rings=[[0,0,helm_bottom+t*helm_h,rx*r,ry*r] for t,r in [(0,.75),(.1,.92),(.72,1),(.9,.65),(1,.08)]]
    v,f,flat=loft({'sections':rings,'samples':TOPOLOGY['ring_samples']})
    pieces.append(shell('great_helm','head','head',v,f,flat))
    # Tines follow the painting's distinct blade/hook centre paths. Far tip is
    # exactly H, using the native source minimum/maximum rather than the staff.
    for side,key in [('far','tine_far_outline_px'),('near','tine_near_outline_px')]:
        path=[]
        for x,y in c[key]:
            z=helm_bottom+helm_h+(c['helm_top_y']-y)*u
            path.append([0,(x-125)*u,z])
        if side=='far':
            path=np.asarray(path);path[:,2]+=H-path[-1,2];path=path.tolist()
        radii=[a*u for a in ([2.5,2,1.6,.8,.05] if side=='far' else [1.5,1.3,1,.7,.05])]
        v,f,flat=sweep(path,radii,TOPOLOGY['sweep_samples'])
        pieces.append(shell('helm_tine_'+side,'head','head',v,f,flat))
    # Closed dark inlay seated on the front of the real narrow helm.
    visor=closed_sheet('visor_slit','head','head',
        [[[rx+.001,y,z] for y in [-.6*u,.6*u]] for z in [helm_bottom+helm_h*.2,helm_bottom+helm_h*.75]],.3*u,[1,0,0])
    visor['clay_colour']=[.015,.015,.015];pieces.append(visor)
    depth,width=np.asarray(c['ribcage_radius_px'])*u
    # The rear half is a closed curved plate. The front is genuinely empty
    # between curved ribs; no torso solid or CC0 skin fills those gaps.
    angles=np.linspace(math.pi/3,5*math.pi/3,25)
    rows=[[[depth*math.cos(a),width*math.sin(a),z] for a in angles]
          for z in [waist+.08,neck-.13]]
    pieces.append(closed_sheet('closed_back_plate','torso','torso',rows,c['backplate_thickness_px']*u,[-1,0,0]))
    for index,y in enumerate(c['rib_levels_y']):
        z=(c['sole_y']-y)*u
        path=[[depth*math.cos(a),width*math.sin(a),z+.015*math.cos(a)]
              for a in np.linspace(-math.pi/3,math.pi/3,25)]
        pieces.append(cord('rib_'+str(index),'torso','torso',path,c['rib_radius_px']*u))
    hook=np.asarray(j['bell_hook'])
    pieces.append(cord('sternum_hook','torso','torso',
        [(hook+[0,0,.03]).tolist(),hook.tolist(),(hook+[.015,0,-.02]).tolist()],u))
    pieces.append(cord('spine_ridge','torso','torso',
        [[-depth-.012,0,waist+.09],[-depth-.018,0,(waist+neck)/2],[-depth-.012,0,neck-.14]],1.5*u))
    mouth=H*p['bell_mouth_over_H']/2;hook=np.asarray(j['bell_hook']); bell_rows=[]
    # Revolved bell shell: outer flare, lip and inner return share one closed
    # periodic profile. The rigid origin is the actual hanging hook.
    for dz,r in [(0,.008),(-.025,mouth*.23),(-.09,mouth*.45),(-.17,mouth),
                 (-.18,mouth),(-.18,mouth-.012),(-.09,mouth*.45-.012),(-.025,mouth*.14)]:
        bell_rows.append([hook[0],0,hook[2]+dz,r,r])
    v,f,flat=loft({'sections':bell_rows,'samples':32,'periodic':True})
    bell=shell('bell','bell','torso',v,f,flat);bell['rig_pivot_joint']='bell_hook';pieces.append(bell)
    pelvis_r=c['sash_radius_px'][0]*u
    hip_r=c['hip_span_px']*u/2+c['thigh_radius_px']*u/2
    sections=[[0,0,j['hip_near'][2]-.04,pelvis_r,hip_r*.75],
              [0,0,j['hip_near'][2],pelvis_r+abs(j['hip_near'][0]),hip_r],
              [0,0,waist,pelvis_r*.96,c['sash_radius_px'][1]*u*.96]]
    v,f,flat=loft({'sections':sections,'samples':32})
    pieces.append(shell('pelvis_plate','pelvis','pelvis',v,f,flat))
    # The source's lower brass abdomen joins the open ribcage to the sash,
    # stopping at the lowest rib so the bell aperture remains genuinely open.
    lower_rib=(c['sole_y']-c['rib_levels_y'][-1])*u
    sections=[[0,0,waist,pelvis_r*.94,c['sash_radius_px'][1]*u*.94],
              [0,0,lower_rib,depth,width]]
    v,f,flat=loft({'sections':sections,'samples':32})
    pieces.append(shell('lower_abdomen','torso','torso',v,f,flat))
    # Hood/scarf envelope over both shoulder joints; the short rear cape ends
    # at the shoulder blades and all its faces retain torso ownership.
    rings=[]
    for z,rad in [(neck-.04,c['scarf_top_radius_px']),(neck-.07,c['scarf_top_radius_px']),
                  (j['shoulder_near'][2]-.04,c['scarf_shoulder_radius_px']),
                  (j['shoulder_near'][2]-.07,c['scarf_shoulder_radius_px']),
                  (neck-.08,[8,10]),(neck-.04,[8,10])]:
        rings.append([0,0,z,rad[0]*u,rad[1]*u])
    v,f,flat=loft({'sections':rings,'samples':32,'periodic':True})
    v=[[x-spec['mq17']['shoulder_shear']*y,y,z] for x,y,z in v]
    pieces.append(shell('hood_scarf','torso','torso',v,f,flat))
    cape_rows=[[[x,y,z] for y in np.linspace(-width,width,9)] for x,z in
        [(-depth,neck+.02),(-depth-.02,j['shoulder_near'][2]-.04),(-depth-.015,neck-.31)]]
    pieces.append(closed_sheet('hood_back_cape','torso','torso',cape_rows,c['cloth_thickness_px']*u,[-1,0,0]))
    sash_r=np.asarray(c['sash_radius_px'])*u
    rings=[[0,0,waist+c['sash_height_px']*u/2*math.sin(a),sash_r[0]+u*math.cos(a),sash_r[1]+u*math.cos(a)]
           for a in np.linspace(0,math.tau,24,endpoint=False)]
    v,f,flat=loft({'sections':rings,'samples':32,'periodic':True})
    pieces.append(shell('waist_sash','sash','pelvis',v,f,flat))
    pieces.append(oval('medallion','sash','pelvis',[sash_r[0]+4*u,0,waist-.055],
        [u,c['medallion_radius_px']*u,c['medallion_radius_px']*u]))
    # The front cloth follows the actual pelvic envelope. Add its profile
    # stations to the source panel rows so a straight chord cannot cut through
    # the widened hip plate between source rows.
    profile=[[0,0,j['hip_near'][2]-.04,pelvis_r,hip_r*.75],
             [0,0,j['hip_near'][2],pelvis_r+abs(j['hip_near'][0]),hip_r],
             [0,0,waist,pelvis_r*.96,c['sash_radius_px'][1]*u*.96]]
    def tabard_surface(z,y):
        rx=float(np.interp(z,[r[2] for r in profile],[r[3] for r in profile]))
        ry=float(np.interp(z,[r[2] for r in profile],[r[4] for r in profile]))
        return max(sash_r[0],rx)+c['cloth_thickness_px']*u*2
    rows=[]
    source_rows=sorted(set([129,155,179,205]+[float(c['sole_y']-r[2]/u) for r in profile]))
    for y in source_rows:
        row=[]
        for k,t in enumerate(np.linspace(-1,1,7)):
            z=(c['sole_y']-(c['tabard_hem_y'][k] if y==205 else y))*u
            lateral=t*c['tabard_half_width_px']*u
            row.append([tabard_surface(z,lateral),lateral,z])
        rows.append(row)
    pieces.append(closed_sheet('front_tabard','tabard','pelvis',rows,c['cloth_thickness_px']*u,[1,0,0]))
    trace=c['sigil_trace_source_px']
    pieces.append(cord('tabard_sigils','tabard','pelvis',
        [[tabard_surface((c['sole_y']-y)*u,(x-126)*u)+u,(x-126)*u,(c['sole_y']-y)*u] for x,y in trace],.45*u))
    shoulder=np.asarray(j['shoulder_near']);rows=[]
    for t in [0,.3,.65,1]:
        row=[]
        for k,s in enumerate(np.linspace(-1,1,7)):
            hem_z=j['knee_near'][2]+(max(c['cloak_hem_y'])-c['cloak_hem_y'][k])*u
            z=(shoulder[2]+.015)*(1-t)+t*hem_z
            row.append([shoulder[0]-.09-.03*t,shoulder[1]+s*.055,z])
        rows.append(row)
    pieces.append(closed_sheet('near_cloak_streamer','cloak','torso',rows,c['cloth_thickness_px']*u,[-1,0,0]))
    build_limbs(spec,u)
    build_staff(spec,u)
    for name,part,objects,visibility in [
        ('visor_slit','head',['visor_slit'],{'front':'visible','rear':'occluded'}),
        ('ribs','torso',['rib_'+str(i) for i in range(len(c['rib_levels_y']))],{'front':'visible','rear':'occluded'}),
        ('spine_ridge','torso',['spine_ridge'],{'front':'occluded','rear':'visible'}),
        ('bell','bell',['bell'],{'front':'visible','rear':'occluded'}),
        ('medallion','sash',['medallion'],{'front':'visible','rear':'occluded'}),
        ('tabard_sigils','tabard',['tabard_sigils'],{'front':'visible'}),
        ('pennant_sigils','staff',['pennant_sigils'],{'front':'visible','rear':'visible'})]:
        spec['native_features'][name]={'part':part,'objects':objects,'visibility':visibility}


def build_limbs(spec,u):
    c,p,j=spec['source_calipers'],spec['pose'],spec['joints'];pieces=spec['pieces']
    for side,sign in [('near',1),('far',-1)]:
        for name,a,b,r in [('upper','shoulder','elbow',c['upper_radius_px']),('fore','elbow','hand',c['fore_radius_px']),
                           ('thigh','hip','knee',c['thigh_radius_px']),('shin','knee','ankle',c['shin_radius_px'])]:
            # Broad middle and tapered joint ends keep the slender source plate.
            pieces.append(capsule(name+'_plate_'+side,name+'_'+side,a+'_'+side,j[a+'_'+side],j[b+'_'+side],[r*u,r*u]))
        for joint,part,r in [('hip','thigh',c['thigh_radius_px']),('elbow','fore',c['fore_radius_px']),('knee','shin',c['shin_radius_px'])]:
            pieces.append(oval(joint+'_joint_'+side,part+'_'+side,joint+'_'+side,j[joint+'_'+side],[r*u]*3))
        ankle=np.asarray(j['ankle_'+side]);h=ankle[2]
        # Rounded pointed sabaton; the lower profile is exactly on the floor.
        path=[ankle+[-.06,0,-h/2],ankle+[.02,0,-h/2],ankle+[c['foot_length_px']*u-.06,0,-h*.8]]
        sections=[[a[0],a[1],a[2],h/2*r,c['foot_width_px']*u/2*r] for a,r in zip(path,[.75,1,.04])]
        v,f,flat=loft({'sections':sections,'axes':[[0,0,1],[0,1,0]],'samples':24})
        pieces.append(shell('pointed_sabaton_'+side,'foot_'+side,'ankle_'+side,v,f,flat))
        shoulder=np.asarray(j['shoulder_'+side]);r=np.asarray(c['pauldron_radius_px'])*u
        pieces.append(oval('pauldron_'+side,'pauldron_'+side,'shoulder_'+side,shoulder+[0,sign*.035,.015],r))
        for k,height in enumerate(c['pauldron_spike_length_px']):
            root=shoulder+[(-1+k)*r[0]*.6,sign*.035,.045]
            tip=root+np.array([0,sign*.3,1])*height*u
            v,f,flat=sweep([root.tolist(),(root+(tip-root)*.6).tolist(),tip.tolist()],[1.7*u,u,.0001],12)
            pieces.append(shell('shoulder_spike_'+side+'_'+str(k),'pauldron_'+side,'shoulder_'+side,v,f,flat))
        hand=np.asarray(j['hand_'+side]);r=np.asarray(c['hand_radius_px'])*u
        pieces.append(oval('gauntlet_'+side,'hand_'+side,'hand_'+side,hand,r))
        for finger in range(4):
            y=(finger-1.5)*1.8*u;point=hand+[r[0]*.4,y,-r[2]*.5];path=[point.tolist()]
            for k,length in enumerate(c['finger_lengths_px']):
                # First section continues down the hand, then three actual
                # native knuckles each curl by exactly 30 degrees.
                angle=math.radians(k*p['near_finger_knuckle_degrees'] if side=='near' else k*65)
                point=point+np.array([math.sin(angle),0,-math.cos(angle)])*length*u
                path.append(point.tolist())
            pieces.append(cord('finger_'+side+'_'+str(finger),'hand_'+side,'hand_'+side,path,c['finger_radius_px']*u))
        pieces.append(cord('thumb_'+side,'hand_'+side,'hand_'+side,
            [(hand+[0,sign*r[1],0]).tolist(),(hand+[r[0],sign*r[1]*.4,-r[2]*.4]).tolist(),
             (hand+[r[0]*1.2,0,-r[2]*.6]).tolist()],c['finger_radius_px']*u))
        # Navy shin wraps are geometric bands, owned by their shin.
        a=np.asarray(j['ankle_'+side]);b=np.asarray(j['knee_'+side])
        for k in range(3):
            centre=a+(b-a)*(.22+k*.14)
            rings=[[*(centre+[0,0,dz]),c['shin_radius_px']*u*1.03,c['shin_radius_px']*u*1.03] for dz in [-u,u]]
            v,f,flat=loft({'sections':rings,'samples':24})
            pieces.append(shell('shin_wrap_'+side+'_'+str(k),'shin_'+side,'ankle_'+side,v,f,flat))


def build_staff(spec,u):
    c,p,j=spec['source_calipers'],spec['pose'],spec['joints'];H=spec['mq17']['height_m']
    grip=np.asarray(j['hand_far']);base=grip.copy();base[2]=H*p['staff_top_over_H']-c['fork_height_px']*u
    butt=grip.copy();butt[2]=0
    parts=[cord('shaft','staff','hand_far',[butt.tolist(),base.tolist()],c['staff_radius_px']*u)]
    fork_paths={
        'outer':[(0,0),(.6,.35),(1,.72),(1.2,1)],
        'centre':[(0,0),(0,.35),(0,.64)],
        'inner':[(0,0),(-.7,.3),(-.8,.6),(-.55,.8)]}
    for name,trace in fork_paths.items():
        path=[(base+[0,-x*c['fork_half_width_px']*u,z*c['fork_height_px']*u]).tolist() for x,z in trace]
        radii=[c['staff_radius_px']*u*(1-.95*k/(len(path)-1)) for k in range(len(path))]
        v,f,flat=sweep(path,radii,12);parts.append(shell('fork_'+name,'staff','hand_far',v,f,flat))
    # Rigid cloth is deliberately one component of the hand-held staff.
    tie=base.copy();tie[2]-=p['pennant_tie_below_fork_over_H']*H
    rows=[]
    for t in [0,.5,1]:
        row=[]
        for k,s in enumerate(np.linspace(0,1,7)):
            rag=[0,.015,0,.009,.002,.013,0][k] if t==1 else 0
            row.append((tie+[0,-s*p['pennant_width_over_H']*H,-t*p['pennant_length_over_H']*H+rag]).tolist())
        rows.append(row)
    parts.append(closed_sheet('pennant','staff','hand_far',rows,c['cloth_thickness_px']*u,[1,0,0]))
    start=0;spec['mq17']['staff_components']={}
    for part in parts:
        spec['mq17']['staff_components'][part['id']]=[start,start+len(part['vertices'])]
        start+=len(part['vertices'])
    spec['pieces'].append(union('staff','staff','hand_far',parts))
    # Separate feature object retains the same held-item owner/bone/pivot.
    # Two source-traced faces expose the gold sigil in both camera directions.
    ornaments=[]
    for xsign in [-1,1]:
        path=[]
        for x,y in c['sigil_trace_source_px']:
            path.append((tie+[xsign*u,-p['pennant_width_over_H']*H/2+(x-126)*u,-(y-145)*u]).tolist())
        ornaments.append(cord('pennant_sigil_'+str(xsign),'staff','hand_far',path,.45*u))
    spec['pieces'].append(union('pennant_sigils','staff','hand_far',ornaments))
    spec['mq17']['staff']={'fork_base':base.tolist(),'tie':tie.tolist(),'grip':grip.tolist(),
        'butt':butt.tolist(),'top':(base+[0,-1.2*c['fork_half_width_px']*u,c['fork_height_px']*u]).tolist()}


if __name__=='__main__':
    result=compile_spec();write(FOLDER/'measurements.json',result)
    print('MQ17_NATIVE_SPEC: PASS; labels='+str(len(result['labels']))+'; pieces='+str(len(result['pieces'])))
