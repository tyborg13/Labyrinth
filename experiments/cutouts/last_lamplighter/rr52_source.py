"""Feedback-1 whole receiver domains, opaque underlay tucks and interior caps."""
from collections import deque
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.tucks import required_tuck
from maquette_motion.material_palette import outline_class,rules
from maquette_motion.silhouette import dilate,components

DEPTH_PX=3  # Binding covered-joint minimum.
RECEIVERS=('head','torso','pelvis','robe','robe_back','leg_near','leg_far','foot_near','foot_far')


def grip_band(images,hidden,interior):
    """The rigid item continues through the fist, using its approved interior.

    As in rr-48, connect source item fragments through the existing fist only;
    every copied texel remains at its original painting coordinate.
    """
    source=(images['lantern'][...,3]>0)|(hidden[...,3]>0)
    labels,groups=components(source,8);result=np.zeros_like(source)
    allowed=source|(dilate(images['hand_near'][...,3]>0,DEPTH_PX)&interior)
    core=labels==groups[0][0]
    for label,_ in groups[1:]:
        target=labels==label;queue=deque(map(tuple,np.argwhere(core)));previous={p:None for p in queue};end=None
        while queue:
            y,x=queue.popleft()
            if target[y,x]:end=(y,x);break
            for dy,dx in ((-1,0),(1,0),(0,-1),(0,1)):
                p=(y+dy,x+dx)
                if 0<=p[0]<255 and 0<=p[1]<255 and allowed[p] and p not in previous:previous[p]=(y,x);queue.append(p)
        if end is None:raise ValueError('TODO_DESIGN_grip_interior_route: no approved interior fist route')
        while end is not None:result[end]=True;core[end]=True;end=previous[end]
        core|=target
    return result&~source


def domains(layout,images,paint,meshes):
    owner=np.full((255,255),'',object)
    parts=sorted((p for p in layout['parts'] if p['name'] in RECEIVERS),key=lambda p:p['z_index'])
    for p in parts:
        y,x=np.nonzero(images[p['name']][...,3]);points=np.column_stack((x,y))
        if p['name'] in meshes:
            recipe=meshes[p['name']];bones=recipe.get('joints',recipe.get('bones',[]))
            points=np.concatenate((points,np.asarray([layout['joints'][n]['position'] for n in bones])))
        if not len(points):continue
        a,b=np.floor(points.min(0)).astype(int);r,d=np.ceil(points.max(0)+1).astype(int)
        owner[max(0,b):min(255,d),max(0,a):min(255,r)]=p['name']
    for p in parts:owner[images[p['name']][...,3]>0]=p['name']
    donors={n:np.column_stack(np.nonzero(images[n][...,3])) for n in RECEIVERS}
    for y,x in np.argwhere((owner=='')&(paint[...,3]>0)):
        owner[y,x]=min(RECEIVERS,key=lambda n:np.min(np.sum((donors[n]-[y,x])**2,axis=1)) if len(donors[n]) else float('inf'))
    return {n:(owner==n)&(paint[...,3]>0) for n in RECEIVERS}


def support_paths(base,paint,texels):
    labels,groups=components(base,8)
    if not groups:raise ValueError('Receiving underlay has no connected source core')
    core=labels==groups[0][0];previous={tuple(p):None for p in np.argwhere(core&paint)};queue=deque(previous)
    targets={(int(v),int(u)) for u,v in texels};remaining=targets-set(previous)
    while queue and remaining:
        y,x=queue.popleft()
        for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
            point=(y+dy,x+dx);v,u=point
            if not (0<=v<255 and 0<=u<255) or not paint[v,u] or point in previous:continue
            previous[point]=(y,x);queue.append(point);remaining.discard(point)
    if remaining:raise ValueError('Measured cap has no director-painted support path')
    support=set()
    for point in targets:
        while previous[point] is not None:
            y,x=point
            if not base[y,x] and point not in targets:support.add((int(x),int(y)))
            point=previous[point]
    return support


def plans(case,layout,images,underlay,meshes,*,include_measured=True):
    view=layout['facing'];painting=np.zeros_like(underlay)
    for im in images.values():painting[im[...,3]>0]=im[im[...,3]>0]
    interior=(painting[...,3]>0)&~outline_class(painting,rules(case,view))
    joins=[['head','torso'],['torso','pelvis'],['robe','pelvis'],['robe_back','pelvis'],['lantern','hand_near']]
    for side in ('near','far'):joins += [[f'arm_{side}','torso'],[f'hand_{side}',f'arm_{side}'],[f'leg_{side}','pelvis'],[f'foot_{side}',f'leg_{side}']]
    policy={'base_px':DEPTH_PX,'pieces':{n:{'depth_px':DEPTH_PX,'mode':'radial','covers':sorted({b if a==n else a for a,b in joins if n in (a,b)})} for n in images}}
    partition=domains(layout,images,underlay,meshes);result={}
    for name,image in images.items():
        tuck=required_tuck(name,images,layout['joints'],policy)
        supplied=tuck&(underlay[...,3]>0)
        if name in partition:supplied|=partition[name]
        cap=tuck&(underlay[...,3]==0)&interior
        out=np.zeros_like(underlay);out[supplied]=underlay[supplied];out[cap]=painting[cap]
        result['hidden_'+name]={'logical':name,'bone':next(p['bone'] for p in layout['parts'] if p['name']==name),'tuck':tuck,'underlay':supplied,'cap':cap,'image':out,'covers':policy['pieces'][name]['covers']}
    for row in read_json(case/f'registration/{view}.json').get('hidden_fragment_transfers',[]):
        source=result[row['source']];target=result[row['target']];x,y=np.asarray(row['texels']).T
        logical=target['logical']
        if not dilate(images[logical][...,3]>0,1)[y,x].all():raise ValueError('Fragment receiver does not touch the rest texels')
        for kind in ('image','cap','underlay'):
            target[kind][y,x]=source[kind][y,x];source[kind][y,x]=0
        target['tuck'][y,x]=True
    item=result['hidden_lantern'];grip=grip_band(images,item['image'],interior)
    item['tuck']|=grip;item['cap']|=grip;item['image'][grip]=painting[grip]
    yy,xx=np.mgrid[:255,:255];points=np.stack((xx+.5,yy+.5),axis=-1)
    for side in ('near','far'):
        name='arm_'+side;a,b,c=[np.asarray(layout['joints'][n]['position']) for n in meshes[name]['joints']];axis=(c-a)/np.linalg.norm(c-a)
        band=(np.abs(np.sum((points-b)*axis,axis=-1))<=DEPTH_PX)&dilate(images[name][...,3]>0,DEPTH_PX)&(painting[...,3]>0)
        cap=band&interior;out=np.zeros_like(underlay);out[cap]=painting[cap]
        result['cap_'+name]={'logical':name,'bone':'fore_'+side,'tuck':band,'underlay':np.zeros_like(band),'cap':cap,'image':out,'covers':[]}
    path=case/'underlay_joint_caps.json'
    if include_measured and path.exists():
        for row in read_json(path)['caps']:
            if row['view']!=view:continue
            p=result[row['part']];xy=np.asarray(row['texels'],int)
            if not len(xy):continue
            x,y=xy.T;measured={tuple(w['uv']) for w in row.get('witnesses',[])}
            if not all((int(u),int(v)) in measured for u,v in xy):raise ValueError('Cap lacks a measured native-origin UV witness')
            if not (underlay[y,x,3]>0).all():raise ValueError('Cap requests transparent director paint')
            centers=np.zeros(underlay.shape[:2],bool)
            for u,v in row.get('overlap_centers',[]):centers[v,u]=True
            overlap=dilate(centers,DEPTH_PX)&(underlay[...,3]>0)
            oy,ox=np.nonzero(overlap);expected=set(zip(ox.tolist(),oy.tolist()))
            if expected!=set(map(tuple,row.get('overlap_texels',[]))):raise ValueError('Joint overlap differs from the binding three-pixel tuck')
            targets=set(map(tuple,row['texels']))|expected
            x,y=np.asarray(sorted(targets)).T
            support=support_paths(p['image'][...,3]>0,underlay[...,3]>0,targets)
            if support!=set(map(tuple,row['support_texels'])):raise ValueError('Changed cap support path')
            if support:
                sx,sy=np.asarray(sorted(support)).T;x=np.r_[x,sx];y=np.r_[y,sy]
            p['image'][y,x]=underlay[y,x];p['underlay'][y,x]=True;p['cap'][y,x]=False;p['tuck'][y,x]=True
    return result,policy
