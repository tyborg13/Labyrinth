"""Rest-contact ownership and exact own-paint boundary caps (director feedback 2)."""
import numpy as np
from functools import lru_cache
import tarfile,json
from maquette_motion.silhouette import components,dilate
from humanoid_cutout.painted_caps import boundary

# Source-contact pairs, never posed frame exemptions. Depth is the existing
# anatomy joint-continuation depth. Empty rear near-arm paint stays empty.
BOUNDARIES=(('head','torso','torso'),('torso','head','head'),
    ('arm_far','torso','torso'),('torso','arm_far','upper_far'),
    ('hand_far','arm_far','fore_far'),('arm_far','hand_far','hand_far'),('hand_far','chain','chain'),
    ('torso','arm_near','upper_near'),('hand_near','arm_near','fore_near'))


def owners(owner,view):
    source='chain' if view=='rear' else 'leg_far'
    labels,groups=components(owner==source,8)
    selected=groups[1:] if view=='rear' else [(int(labels[135,114]),int((labels==labels[135,114]).sum()))]
    for label,_ in selected:
        if not label:raise ValueError('Changed front leg/coat fragment witness')
        mask=labels==label
        rim=dilate(mask,1)&~mask
        contacts={name:int((rim&(owner==name)).sum()) for name in sorted(set(owner.ravel())) if name not in ('',source) and (rim&(owner==name)).any()}
        if not contacts:raise ValueError('Detached source fragment needs explicit clear')
        # The existing rr-42 rule prioritises a touching foot, then coat,
        # then shared boundary length; lexical order resolves count ties.
        feet={n:c for n,c in contacts.items() if n.startswith('foot_')}
        coats={n:c for n,c in contacts.items() if n.startswith('coat_')}
        candidates=feet or coats or contacts
        destination=min(candidates,key=lambda n:(-candidates[n],n))
        owner[mask]=destination
    if view=='rear':
        # Native guard/reel/press isolate this one-pixel boot fringe after
        # rotation. Its other rest contact is the far coat, which owns it.
        x,y=115,221
        if owner[y,x]!='foot_far' or not dilate(owner=='coat_far',1)[y,x]:raise ValueError('Changed native boot-fringe contact')
        owner[y,x]='coat_far'


def backing(images,view):
    if view=='rear':
        labels,groups=components(images['chain'][...,3]>0,8)
        # The rest-contact repair moved the boot ink out of the held item.
        # Its old hidden coat duplicate must follow that same boot as well.
        old=np.zeros((255,255),bool);old[224:236,158:160]=True
        selected=old&(images['hidden_coat_far'][...,3]>0)
        images['hidden_foot_far'][selected]=images['hidden_coat_far'][selected]
        images['hidden_coat_far'][selected]=0
    else:
        x,y=113,127
        if images['hidden_leg_far'][y,x,3]:
            images['hidden_pelvis'][y,x]=images['hidden_leg_far'][y,x]
            images['hidden_leg_far'][y,x]=0
    from rr44_case import CASE
    from cutout_pipeline.cases import read_json
    for row in read_json(CASE.parent/'rr44_feedback2_ownership.json')['hidden_transfers']:
        if row['view']!=view or not row.get('retire_duplicate'):continue
        for x,y in row['texels']:
            if images[row['source']][y,x].tolist()!=row['old_rgba'] or images[row['destination']][y,x].tolist()!=row['owner_rgba']:
                raise ValueError('Changed duplicate backing/rest owner witness')
            images[row['source']][y,x]=0


def retired_backing_texels(view):
    from rr44_case import CASE
    from cutout_pipeline.cases import read_json
    result={}
    for row in read_json(CASE.parent/'rr44_feedback2_ownership.json')['hidden_transfers']:
        if row['view']!=view:continue
        points=row.get('texels')
        if points is None:
            x,y,x1,y1=row['source_box'];points=[[u,v] for v in range(y,y1) for u in range(x,x1)]
        result.setdefault(row['source'],[]).extend(points)
    return {name:sorted(map(list,set(map(tuple,points)))) for name,points in sorted(result.items())}


def caps(case,view,images,layout,anatomy):
    from copy import deepcopy
    from maquette_motion.material_palette import rules
    result={}
    for source,neighbour,bone in BOUNDARIES:
        # A joint cap is an overlay. Preserve the accepted backing beneath
        # it when the cap follows the neighbouring joint and vacates its UVs.
        name='joint_cap_'+source
        images.setdefault(name,np.zeros_like(images[source]))
        target=dict(images);target['hidden_'+source]=images[name]
        row=boundary(target,layout,anatomy,source,neighbour,bone,rules(case,view))
        if row['texels']:result.setdefault(name,[]).append(row)
    additional=[('arm_near','torso','torso')] if view=='front' else [('pelvis','torso','torso')]
    for source,neighbour,bone in additional:
        name='joint_cap_'+source;images.setdefault(name,np.zeros_like(images[source]));target=dict(images);target['hidden_'+source]=images[name]
        row=boundary(target,layout,anatomy,source,neighbour,bone,rules(case,view))
        if row['texels']:result.setdefault(name,[]).append(row)
    # Keep the sleeve's approved upper-side paint behind the elbow as well
    # as the forearm-side cap. A single-sided band can open at its upper edge.
    from humanoid_cutout.painted_caps import band
    source='arm_far';recipe=anatomy['meshes'][source];depth=anatomy['joint_continuations']['depth_px']
    mask=band(images[source],layout['joints'],recipe,depth,rules(case,view),True)
    if mask.any():
        name='joint_cap_'+source;images[name][mask]=images[source][mask]
        result.setdefault(name,[]).insert(0,dict(kind='joint_side',source=source,joint=recipe['joints'][1],bone=recipe['bones'][0],depth_px=depth,
            include_outline=True,texels=np.argwhere(mask)[:,::-1].tolist()))
        # Fore and upper bands are separate hidden overlays. Neither may
        # change the approved visible skin or cover body continuation paint.
        fore_name=name+'_fore';images[fore_name]=np.zeros_like(images[source]);images[fore_name][mask]=images[source][mask]
        result[fore_name]=[dict(source=source,joint=recipe['joints'][1],bone=recipe['bones'][1],depth_px=depth,
            include_outline=True,texels=np.argwhere(mask)[:,::-1].tolist())]
    for name in result:
        source=result[name][0]['source']
        part=deepcopy(next(p for p in layout['parts'] if p['name']=='hidden_'+source))
        part.update(name=name,joint_cap_layer=True)
        if name=='joint_cap_arm_far_fore':part['joint_cap_fore']=True
        layout['parts'].append(part)
    return result


@lru_cache(maxsize=2)
def source_layout(view):
    from rr44_case import CASE
    from cutout_pipeline.cases import digest,read_json
    fixture=CASE/'fixtures/native_r1'
    if digest(fixture/'manifest.json')!='1ba4c6511c9ac48dafb38408b5f80b600d3eb25a82baba20b03877429ebba2ad' or digest(fixture/'case.tar.gz')!=read_json(fixture/'manifest.json')['files']['case.tar.gz']:
        raise ValueError('Changed approved r1 deformation-field fixture')
    with tarfile.open(fixture/'case.tar.gz') as archive:
        return json.loads(archive.extractfile(f'layouts/{view}.json').read())


def source_bounds(view):
    return {p['name']:p['bbox'] for p in source_layout(view)['parts']}


def weight_bounds(view,name):
    mesh=next(m for m in source_layout(view)['joint_meshes'] if m['name']==name)
    return mesh.get('weight_bounds',mesh['bbox'])


def bounds(view,name,image,*,logical=None):
    original=np.asarray(source_bounds(view).get(name,source_bounds(view).get('hidden_'+logical if logical else name.replace('joint_cap_','hidden_'))));current=original.copy()
    y,x=np.nonzero(image[...,3])
    if len(x):
        current=(np.array([x.min(),y.min(),x.max()+1,y.max()+1]) if name.startswith('joint_cap_') else
                 np.array([min(x.min(),original[0]),min(y.min(),original[1]),max(x.max()+1,original[2]),max(y.max()+1,original[3])]))
    # Keep the registered two-pixel cell lattice when adding or removing ink.
    current[:2]=original[:2]+2*np.floor_divide(current[:2]-original[:2],2)
    return current.tolist()
