"""One fist-owned hex lantern, a closed base, candle, cap ring and straight chain."""
import math
import numpy as np
from ..forms import cord,oval,shell,union,normal_sheet
from ..accessories import chain,ring


def replace_grip(spec,grip):
    H=spec['mq18']['height_m'];c=spec['source_calipers'];u=spec['mq18']['source_unit_m_per_px'];d=spec['dimensions'];p=spec['pose']
    pieces=spec['pieces'];hand=np.asarray(spec['joints']['hand_far'])
    pieces[:]=[q for q in pieces if not q['id'].startswith('finger_far_') and q['id']!='thumb_far']
    for finger in range(4):
        root=hand+[c['hand_depth_px']*u/4,(finger-1.5)*d['gauntlet_width_over_H']*H/4,-c['hand_length_px']*u/3]
        path=[root.tolist()]
        for k in range(4):
            angle=math.radians(k*p['far_finger_knuckle_degrees'])
            root=root+np.array([math.sin(angle),0,-math.cos(angle)])*p['far_finger_length_over_H']*H/4
            path.append(root.tolist())
        pieces.append(cord('finger_far_'+str(finger),'hand_far','hand_far',path,d['claw_thickness_over_H']*H/2))
    # Retain its initial direction and bend plane; the new brief changes the
    # claw length and each knuckle angle, including the thumb's one knuckle.
    thumb=np.array([[0,-.025,0],[.03,-.025,-.025],[.04,0,-.04]])
    directions=np.diff(thumb,axis=0);lengths=np.linalg.norm(directions,axis=1);first=directions[0]/lengths[0]
    bend=directions[1]-first*np.dot(directions[1],first);bend/=np.linalg.norm(bend)
    angle=math.radians(p['far_finger_knuckle_degrees']);second=first*math.cos(angle)+bend*math.sin(angle)
    lengths=lengths/lengths.sum()*p['far_finger_length_over_H']*H;start=thumb[0]+hand
    thumb=np.array([start,start+first*lengths[0],start+first*lengths[0]+second*lengths[1]])
    pieces.append(cord('thumb_far','hand_far','hand_far',thumb.tolist(),d['claw_thickness_over_H']*H/2))
    if grip is None:return
    paths=grip['finger_paths_over_H']
    if len(paths)!=4:raise ValueError('Grip needs four owner-specified finger paths')
    pieces[:]=[q for q in pieces if not q['id'].startswith('finger_near_') and q['id']!='thumb_near']
    near=np.asarray(spec['joints']['hand_near'])
    for name,path in [*[(f'finger_near_{k}',v) for k,v in enumerate(paths)],('thumb_near',grip['thumb_path_over_H'])]:
        pieces.append(cord(name,'hand_near','hand_near',(near+np.asarray(path)*H).tolist(),d['claw_thickness_over_H']*H/2))


def build(spec,u,grip):
    H=spec['mq18']['height_m'];c=spec['source_calipers'];j=spec['joints'];d=spec['dimensions'];pieces=spec['pieces']
    fist=np.asarray(j['hand_near']);wire=c['chain_wire_px']*u
    # A missing ring is explicit partial geometry, never an invented grip.
    radius=grip['ring_radius_over_H']*H if grip else 0
    chain_top=fist+[0,0,-radius];chain_bottom=chain_top+[0,0,-d['lantern_chain_over_H']*H]
    if grip:
        pieces.append(ring('grip_ring','lantern','hand_near',fist,radius,radius,wire,grip['ring_plane']))
        pieces.append(ring('lantern_cap_ring','lantern','hand_near',chain_bottom,radius,radius,wire,grip['ring_plane']))
    pieces.append(chain('held_chain','lantern','hand_near',chain_top,chain_bottom,wire))
    top=chain_bottom+[0,0,-radius];h=d['lantern_body_height_over_H']*H;r=d['lantern_width_over_H']*H/2
    bottom=top+[0,0,-h];j['lantern_top_ring']=chain_bottom.tolist()
    angles=np.linspace(0,math.tau,d['lantern_sides'],endpoint=False)
    objects=[]
    # Retain the mq-18 cap/pane proportions. Cap apex and base now define the
    # complete specified height instead of stopping at 92 percent of it.
    for a in angles:
        xy=np.array([r*math.cos(a),r*math.sin(a),0])
        objects.append(cord('post','lantern','hand_near',[(bottom+xy+[0,0,wire]).tolist(),(bottom+xy+[0,0,h*.72]).tolist()],wire))
    for z in (wire,h*.72):
        objects.append(cord('rim','lantern','hand_near',[(bottom+[r*math.cos(a),r*math.sin(a),z]).tolist() for a in [*angles,math.tau]],wire))
    pieces.append(union('lantern_frame','lantern','hand_near',objects))
    for k,(a,b) in enumerate(zip(angles,[*angles[1:],math.tau])):
        ends=[np.array([r*.96*math.cos(t),r*.96*math.sin(t),0]) for t in (a,b)]
        tangent=ends[1]-ends[0];tangent/=np.linalg.norm(tangent);ends=[ends[0]+tangent*wire,ends[1]-tangent*wire]
        rows=[[(bottom+point+[0,0,z]).tolist() for point in ends] for z in (wire*2,h*.70)]
        pane=normal_sheet('lantern_pane_'+str(k),'lantern','hand_near',rows,wire*.3);pane['clay_colour']=[.12,.12,.12];pieces.append(pane)
    vertices=[(bottom+[r*math.cos(a),r*math.sin(a),h*.72]).tolist() for a in angles]+[top.tolist()]
    pieces.append(shell('lantern_cap','lantern','hand_near',vertices,[list(reversed(range(6)))]+[[k,(k+1)%6,6] for k in range(6)]))
    vertices=[(bottom+[r*math.cos(a),r*math.sin(a),z]).tolist() for z in (0,wire) for a in angles]
    pieces.append(shell('lantern_base','lantern','hand_near',vertices,[list(reversed(range(6))),list(range(6,12))]+[[k,(k+1)%6,(k+1)%6+6,k+6] for k in range(6)]))
    pieces.append(oval('candle','lantern','hand_near',bottom+[0,0,h*.28],[r*.13,r*.13,h*.18]))
    glow=oval('candle_glow','lantern','hand_near',bottom+[0,0,h*.51],[r*.16,r*.16,h*.07]);glow['clay_colour']=[1,1,1];pieces.append(glow)
    for q in pieces:
        if q['part']=='lantern':q['rig_pivot_joint']='hand_near'
    spec['native_features']['candle_glow']={'part':'lantern','objects':['candle_glow'],'visibility':{}}
