"""Whole-owner lamp house, suspended cage, leather belt and held hex lantern."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft
from .forms import cord,oval,shell,union,normal_sheet

ACCESSORY_TOPOLOGY={'circle_samples':25,'cage_bars':12,'glass_columns':7,'chain_links':6}


def ring(identifier,part,joint,centre,rx,rz,wire,plane='yz'):
    centre=np.asarray(centre)
    path=[(centre+([0,rx*math.cos(a),rz*math.sin(a)] if plane=='yz' else
                  [rx*math.cos(a),0,rz*math.sin(a)] if plane=='xz' else
                  [rx*math.cos(a),rz*math.sin(a),0])).tolist()
          for a in np.linspace(0,math.tau,ACCESSORY_TOPOLOGY['circle_samples'])]
    return cord(identifier,part,joint,path,wire)


def chain(identifier,part,joint,start,end,wire,count=6):
    start,end=np.asarray(start),np.asarray(end);axis=end-start;length=np.linalg.norm(axis);axis/=length
    a=np.cross(axis,[1,0,0]);a/=np.linalg.norm(a);b=np.cross(axis,a)
    result=[]
    for k in range(count):
        centre=start+(end-start)*(k+.5)/count;cross=a if k%2==0 else b
        path=[(centre+axis*(length/count/2-wire)*math.cos(t)+cross*wire*2*math.sin(t)).tolist()
              for t in np.linspace(0,math.tau,25)]
        result.append(cord(identifier+'_'+str(k),part,joint,path,wire))
    return union(identifier,part,joint,result)


def build(spec,u):
    lamp_house(spec,u);cage(spec,u);belt(spec,u);lantern(spec,u)


def lamp_house(spec,u):
    H=spec['mq18']['height_m'];j=spec['joints'];d=spec['dimensions'];c=spec['source_calipers'];pieces=spec['pieces']
    width=d['lamp_width_over_H']*H;height=d['lamp_height_over_H']*H;depth=d['lamp_depth_over_H']*H
    tilt=math.radians(d['lamp_outward_degrees']);axes=np.array([[1,0,0],[0,math.cos(tilt),math.sin(tilt)],[0,-math.sin(tilt),math.cos(tilt)]])
    # The source seats the house on the outer half of the far shoulder.
    base=np.asarray(j['shoulder_far'])+[0,0,d['hood_thickness_over_H']*H]
    centre=base+axes[2]*height/2;wire=d['lamp_frame_diameter_over_H']*H/2
    # Seat the existing tilted bottom on the highest native mantle support
    # within its footprint. This is a support constraint, not a new offset.
    mantle=np.asarray(next(p['vertices'] for p in pieces if p['id']=='shoulder_mantle'))
    floor_centre=base+axes[2]*wire
    local=np.einsum('nj,kj->nk',mantle-floor_centre,axes)
    supported=(abs(local[:,0])<depth/2-wire)&(abs(local[:,1])<width/2-wire)
    if not supported.any():raise ValueError('Lamp house has no mantle support')
    lift=(local[supported,2].max()+wire/2)/axes[2,2]
    centre[2]+=lift
    dims=np.array([depth,width,height])/2-wire
    def point(x,y,z):return centre+np.array([x,y,z])@axes
    frame=[]
    for k in range(3):
        rest=[i for i in range(3) if i!=k]
        for s in (-1,1):
            for t in (-1,1):
                a=np.zeros(3);a[rest]=[s*dims[rest[0]],t*dims[rest[1]]];a[k]=-dims[k];b=a.copy();b[k]=dims[k]
                frame.append(cord('edge_'+str(len(frame)),'lamp_house','torso',[point(*a).tolist(),point(*b).tolist()],wire))
    for sx in (-1,1):
        for sy in (-1,1):
            for sz in (-1,1):frame.append(oval('rounded_corner','lamp_house','torso',point(sx*dims[0],sy*dims[1],sz*dims[2]),[wire]*3))
    pieces.append(union('rounded_lamp_frame','lamp_house','torso',frame))
    panes=[];mullions=[]
    for axis in (0,1):
        for sign in (-1,1):
            transverse=1-axis
            def plane(t,z):
                p=np.zeros(3);p[axis]=sign*(dims[axis]-wire*.5);p[transverse]=t;p[2]=z
                return point(*p).tolist()
            for ti,(lo,hi) in enumerate([(-dims[transverse]+wire,-wire),(wire,dims[transverse]-wire)]):
                for zi,(bottom,top) in enumerate([(-dims[2]+wire,-wire),(wire,dims[2]-wire)]):
                    rows=[[plane(t,z) for t in (lo,hi)] for z in (bottom,top)]
                    panes.append(normal_sheet('pane_'+str(len(panes)),'lamp_house','torso',rows,wire*.5))
            mullions.append(cord('cross_v_'+str(axis)+str(sign),'lamp_house','torso',[plane(0,-dims[2]),plane(0,dims[2])],wire))
            mullions.append(cord('cross_h_'+str(axis)+str(sign),'lamp_house','torso',[plane(-dims[transverse],0),plane(dims[transverse],0)],wire))
    piece=union('lamp_panes','lamp_house','torso',panes);piece['clay_colour']=[.025,.025,.025];pieces.append(piece)
    pieces.append(union('lamp_cross_mullions','lamp_house','torso',mullions))
    # Rounded solid roof and floor close the house, preserving its native box.
    for label,z in [('roof',dims[2]),('floor',-dims[2])]:
        rows=[[point(x,y,z).tolist() for y in (-dims[1],dims[1])] for x in (-dims[0],dims[0])]
        pieces.append(normal_sheet('lamp_'+label,'lamp_house','torso',rows,wire))
    spec['native_features']['panes']={'part':'lamp_house','objects':['lamp_panes'],'visibility':{'front':'visible','rear':'visible'}}
    spec['mq18']['lamp_local_axes']=axes.tolist()


def cage(spec,u):
    H=spec['mq18']['height_m'];j=spec['joints'];c=spec['source_calipers'];d=spec['dimensions'];pieces=spec['pieces']
    h=d['cage_height_over_H']*H;r=d['cage_width_over_H']*H/2;wire=c['cage_bar_wire_px']*u
    collar=np.asarray(j['head']);centre=np.asarray(j['torso']);centre[0]+=c['torso_depth_px']*u/2+.025*H;centre[2]-=.015*H
    hook=centre+[0,0,h/2];j['cage_hook']=hook.tolist()
    bars=[]
    for k,a in enumerate(np.linspace(0,math.tau,ACCESSORY_TOPOLOGY['cage_bars'],endpoint=False)):
        path=[]
        for t in np.linspace(0,1,13):
            rad=r if t<.65 else r*math.cos((t-.65)/.35*math.pi/2)
            path.append((centre+[rad*math.cos(a),rad*math.sin(a),(t-.5)*h]).tolist())
        bars.append(cord('bar_'+str(k),'cage','torso',path,wire))
    for z in (-h/2,-h/2+.015):bars.append(ring('cage_rim','cage','torso',centre+[0,0,z],r,r,wire,'xy'))
    body=union('curved_birdcage','cage','torso',bars);body['rig_pivot_joint']='cage_hook';pieces.append(body)
    for side,sign in [('near',1),('far',-1)]:
        start=collar+[c['torso_depth_px']*u/2,sign*r,0]
        piece=chain('collar_chain_'+side,'cage','torso',start,hook,wire)
        piece['rig_pivot_joint']='cage_hook';pieces.append(piece)
    spec['native_features']['birdcage']={'part':'cage','objects':['curved_birdcage'],'visibility':{'front':'visible','rear':'occluded'}}


def belt(spec,u):
    H=spec['mq18']['height_m'];c=spec['source_calipers'];j=spec['joints'];pieces=spec['pieces'];wire=c['chain_wire_px']*u
    centre=np.array(j['pelvis']);rx=c['torso_depth_px']*u/2+.018*H;ry=c['robe_half_width_px']*u
    # Soft closed oval band, with rounded edges rather than a cuboid strip.
    sections=[]
    for a in np.linspace(0,math.tau,17,endpoint=False):
        sections.append([centre[0],0,centre[2]+c['belt_height_px']*u/2*math.sin(a),rx+wire*math.cos(a),ry+wire*math.cos(a)])
    v,f,flat=loft({'sections':sections,'samples':48,'periodic':True});pieces.append(shell('leather_belt','belt','pelvis',v,f,flat))
    for k in range(3):
        start=centre+[rx,(k-1)*ry*.5,0];end=start+[0,0,-c['key_length_px']*u]
        pieces.append(chain('belt_chain_'+str(k),'belt','pelvis',start,end,wire))
    for k in range(2):
        hook=centre+[rx+2*wire,(k-.5)*ry*.6,-c['key_length_px']*u*.6]
        key=[ring('bow','belt','pelvis',hook,c['key_width_px']*u/2,c['key_width_px']*u/2,wire)]
        end=hook+[0,0,-c['key_length_px']*u]
        key.append(cord('shaft','belt','pelvis',[hook.tolist(),end.tolist()],wire))
        key.append(cord('tooth','belt','pelvis',[end.tolist(),(end+[0,c['key_width_px']*u,0]).tolist(),(end+[0,c['key_width_px']*u,.02]).tolist()],wire))
        pieces.append(union('key_'+str(k),'belt','pelvis',key))
    spec['native_features']['keys']={'part':'belt','objects':['key_0','key_1'],'visibility':{'front':'visible','rear':'occluded'}}


def lantern(spec,u):
    H=spec['mq18']['height_m'];c=spec['source_calipers'];j=spec['joints'];d=spec['dimensions'];pieces=spec['pieces']
    fist=np.asarray(j['hand_near']);length=d['lantern_chain_over_H']*H;h=d['lantern_body_height_over_H']*H
    r=d['lantern_width_over_H']*H/2;wire=c['chain_wire_px']*u
    top=fist+[0,0,-length];bottom=top+[0,0,-h]
    j['lantern_top_ring']=top.tolist()
    objects=[chain('held_chain','lantern','hand_near',fist,top,wire)]
    objects.append(ring('top_ring','lantern','hand_near',top+[0,0,-r*.18],r*.18,r*.18,wire,'yz'))
    angles=np.linspace(0,math.tau,6,endpoint=False)
    for a in angles:
        xy=np.array([r*math.cos(a),r*math.sin(a),0]);objects.append(cord('hex_post','lantern','hand_near',
            [(bottom+xy+[0,0,wire]).tolist(),(bottom+xy+[0,0,h*.72]).tolist()],wire))
    for z in (wire,h*.72):
        path=[(bottom+[r*math.cos(a),r*math.sin(a),z]).tolist() for a in [*angles,math.tau]]
        objects.append(cord('hex_rim','lantern','hand_near',path,wire))
    # Six solid panes, a pointed six-sided cap, and an actual candle inside.
    panes=[]
    for pane_index,(a,b) in enumerate(zip(angles,[*angles[1:],math.tau])):
        endpoints=[np.array([r*.96*math.cos(t),r*.96*math.sin(t),0]) for t in (a,b)]
        tangent=(endpoints[1]-endpoints[0]);tangent/=np.linalg.norm(tangent)
        endpoints=[endpoints[0]+tangent*wire,endpoints[1]-tangent*wire]
        rows=[[(bottom+point+[0,0,z]).tolist() for point in endpoints] for z in (wire*2,h*.70)]
        pane=normal_sheet('lantern_pane_'+str(pane_index),'lantern','hand_near',rows,wire*.3)
        pane['clay_colour']=[.12,.12,.12];pieces.append(pane)
    # Loft has a minimum of eight samples; native cap is exactly hexagonal.
    vv=[]
    for z,radius in [(h*.72,r),(h*.76,r),(h*.92,wire)]:vv.extend((bottom+[radius*math.cos(a),radius*math.sin(a),z]).tolist() for a in angles)
    ff=[[i,(i+1)%6,(i+1)%6+6,i+6] for i in range(6)]
    ff += [[6+i,6+(i+1)%6,12+(i+1)%6,12+i] for i in range(6)]+[list(reversed(range(6))),list(range(12,18))]
    objects.append(shell('cap','lantern','hand_near',vv,ff))
    held=union('held_lantern','lantern','hand_near',objects);pieces.append(held)
    candle=oval('candle','lantern','hand_near',bottom+[0,0,h*.28],[r*.13,r*.13,h*.18]);pieces.append(candle)
    flame=oval('candle_glow','lantern','hand_near',bottom+[0,0,h*.51],[r*.16,r*.16,h*.07]);flame['clay_colour']=[1,1,1];pieces.append(flame)
    # Glass panes are thin diagnostic surfaces. The two view rays still need
    # to see the candle, so the source-style open corner gaps are retained.
    for piece in pieces:
        if piece['part']=='lantern':piece['rig_pivot_joint']='hand_near'
    spec['native_features']['candle_glow']={'part':'lantern','objects':['candle_glow'],'visibility':{}}
