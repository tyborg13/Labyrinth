"""Rounded segmented iron and closed, draped cloth envelopes from brief/calipers."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft
from .forms import oval,cord,shell,normal_sheet,union,TOPOLOGY

LAME_PROFILE=[(0,.72),(.12,.95),(.3,1),(.7,1),(.90,.96),(1,.83)]
BODY_TOPOLOGY={'arm_lames':2,'leg_lames':3,'lame_stations':len(LAME_PROFILE)}


def segmented(identifier,part,joint,start,end,diameter):
    start,end=np.asarray(start),np.asarray(end);axis=end-start;length=np.linalg.norm(axis);axis/=length
    first=np.cross(axis,[0,1,0]);first/=np.linalg.norm(first);second=np.cross(axis,first)
    count=BODY_TOPOLOGY['arm_lames' if part.startswith(('upper','fore')) else 'leg_lames']
    pieces=[]
    # Closed elongated lames overlap axially; no annular rings or holes.
    overlap=1/count/2
    for k in range(count):
        lo=max(0,k/count-overlap/2);hi=min(1,(k+1)/count+overlap/2)
        sections=[]
        for t,r in LAME_PROFILE:
            station=lo+(hi-lo)*t
            sections.append([*((1-station)*start+station*end),diameter*r/2,diameter*r/2])
        v,f,flat=loft({'sections':sections,'axes':[first.tolist(),second.tolist()],'samples':TOPOLOGY['ring_samples']})
        pieces.append(shell(identifier+'_'+str(k),part,joint,v,f,flat))
    return union(identifier,part,joint,pieces)


def build(spec,u):
    H=spec['mq18']['height_m'];j=spec['joints'];c=spec['source_calipers'];d=spec['dimensions'];p=spec['pose'];pieces=spec['pieces']
    hip=np.mean([j['hip_near'],j['hip_far']],axis=0);lean=math.tan(math.radians(p['hip_lean_degrees']))
    def cx(z):return (z-hip[2])*lean
    waist=j['pelvis'][2];neck=j['head'][2];depth=c['torso_depth_px']*u/2
    # Overlap half the existing pelvic height to close the abdomen below the belt.
    sections=[[cx(z),0,z,depth*r,d['chest_width_over_H']*H/2*r] for z,r in [(hip[2]+.04*H,.8),(waist,.8),((waist+neck)/2,1),(neck,.68)]]
    v,f,flat=loft({'sections':sections,'samples':48});pieces.append(shell('iron_barrel','torso','torso',v,f,flat))
    pieces.append(oval('pelvic_plate','pelvis','pelvis',[cx(hip[2]),0,hip[2]],
                        [depth,c['hip_width_px']*u/2+.02*H,.08*H]))
    for side,sign in [('near',1),('far',-1)]:
        for name,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')]:
            pieces.append(segmented(name+'_plate_'+side,name+'_'+side,a+'_'+side,j[a+'_'+side],j[b+'_'+side],d[name+'_diameter_over_H']*H))
        for joint,part in [('elbow','fore'),('knee','shin')]:
            pieces.append(oval(joint+'_cop_'+side,part+'_'+side,joint+'_'+side,j[joint+'_'+side],[d['cop_diameter_over_H']*H/2]*3))
        ankle=np.asarray(j['ankle_'+side]);h=ankle[2];toe=c['foot_length_px']*u/2
        j['toe_'+side]=(ankle+[toe,0,-h/2]).tolist()
        sections=[[*(ankle+[x,0,z-h]),rz,c['foot_width_px']*u/2*factor] for x,z,rz,factor in
                  [(-toe*.7,h/2,h/2,.6),(0,h/2,h/2,1),(toe,h*.35,h*.35,.8),
                   (toe+d['sabatons_extension_over_H']*H,h*.12,h*.1,.025)]]
        v,f,flat=loft({'sections':sections,'axes':[[0,0,1],[0,1,0]],'samples':24})
        pieces.append(shell('pointed_sabaton_'+side,'foot_'+side,'ankle_'+side,v,f,flat))
        hand=np.asarray(j['hand_'+side]);pieces.append(oval('gauntlet_'+side,'hand_'+side,'hand_'+side,hand,
            [c['hand_depth_px']*u/2,d['gauntlet_width_over_H']*H/2,c['hand_length_px']*u/2]))
        for finger in range(4):
            root=hand+[c['hand_depth_px']*u/4,(finger-1.5)*d['gauntlet_width_over_H']*H/4,-c['hand_length_px']*u/3]
            path=[root.tolist()]
            if side=='far':
                for k in range(4):
                    angle=math.radians(k*p['far_finger_knuckle_degrees'])
                    root=root+np.array([math.sin(angle),0,-math.cos(angle)])*d['claw_length_over_H']*H/4
                    path.append(root.tolist())
            else:
                # The source clenched grip wraps the chain at the fist centre.
                for k in range(4):
                    angle=math.radians(k*65);root=root+np.array([math.sin(angle),0,-math.cos(angle)])*d['claw_length_over_H']*H/4
                    path.append(root.tolist())
            pieces.append(cord('finger_'+side+'_'+str(finger),'hand_'+side,'hand_'+side,path,d['claw_thickness_over_H']*H/2))
        thumb=np.array([[0,sign*.025,0],[.03,sign*.025,-.025],[.04,0,-.04]])
        thumb=(thumb-thumb[0])*d['claw_length_over_H']*H/np.linalg.norm(np.diff(thumb,axis=0),axis=1).sum()+thumb[0]+hand
        pieces.append(cord('thumb_'+side,'hand_'+side,'hand_'+side,thumb.tolist(),d['claw_thickness_over_H']*H/2))
    from .garments import head,cloth
    head(spec,u);cloth(spec,u,cx)

