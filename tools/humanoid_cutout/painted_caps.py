"""Opt-in elbow backing made only from the same approved sleeve texels.

A short painted band remains rigid with the forearm behind the skinned sleeve.
No texel is moved in source space, extrapolated, recoloured or synthesized.
Unselected two-pixel cells retain their original geometry and weight arrays.
"""
from copy import deepcopy
import numpy as np
from maquette_motion.material_palette import outline_class,rules
from .texel_attachments import barycentric,cells_for
from maquette_motion.silhouette import dilate


def band(image,joints,recipe,depth,definition,include_outline=False):
    _,joint,end=recipe['joints'];axis=np.asarray(joints[end]['position'])-joints[joint]['position'];axis/=np.linalg.norm(axis)
    yy,xx=np.indices(image.shape[:2]);delta=np.stack((xx+.5,yy+.5),axis=-1)-joints[joint]['position']
    mask=(image[...,3]>0)&(np.abs(delta@axis)<=depth)
    return mask if include_outline else mask&~outline_class(image,definition)


def prepare(case,view,images,layout,anatomy,source='arm_near',*,include_outline=False):
    recipe=anatomy['meshes'][source];depth=anatomy['joint_continuations']['depth_px']
    mask=band(images[source],layout['joints'],recipe,depth,rules(case,view),include_outline)
    images['hidden_'+source][mask]=images[source][mask]
    result=dict(source=source,joint=recipe['joints'][1],bone=recipe['bones'][1],depth_px=depth,
                texels=np.argwhere(mask)[:,::-1].tolist())
    if include_outline:result['include_outline']=True
    return result


def apply(base,definitions):
    result=deepcopy(base);assigned={}
    for row in definitions:
        if row['bone'] not in result['weights']:
            if row.get('kind')!='boundary':raise ValueError('Joint cap bone is outside its garment')
            result['weights'][row['bone']]=[0.]*len(result['vertices'])
        for point in row['texels']:
            key=tuple(point)
            if key in assigned:
                if row.get('kind')=='boundary':continue
                raise ValueError('Duplicate joint cap texel')
            assigned[key]=row['bone']
    cells=cells_for(base,assigned);vertices=np.asarray(base['vertices'])
    fast_base=dict(base,vertices=vertices)
    base_weights={bone:np.asarray(weights) for bone,weights in base['weights'].items()}
    interpolation={}
    result['triangles']=[t for t in base['triangles'] if tuple([*vertices[t].min(0),*vertices[t].max(0)]) not in cells]
    left,top=base['bbox'][:2]
    for a,b,c,d in sorted(cells):
        for y in range(b,d):
            for x in range(a,c):
                corners=[[x,y],[x+1,y],[x,y+1],[x+1,y+1]];start=len(result['vertices'])
                result['vertices']+=corners;result['uvs'] += [[u-left,v-top] for u,v in corners]
                result['triangles'] += [[start,start+1,start+2],[start+1,start+3,start+2]]
                for corner in corners:
                    if (x,y) in assigned:values={bone:float(bone==assigned[x,y]) for bone in result['weights']}
                    else:
                        key=tuple(corner)
                        if key not in interpolation:
                            indices,bary=barycentric(fast_base,corner)
                            interpolation[key]={bone:float(bary@weights[indices]) for bone,weights in base_weights.items()}
                        values=dict(interpolation[key])
                        values.update({bone:0. for bone in result['weights'] if bone not in values})
                    for bone,value in values.items():result['weights'][bone].append(value)
    result['painted_joint_caps']=deepcopy(definitions)
    return result


def boundary(images,layout,anatomy,source,neighbour,bone,definition):
    depth=anatomy['joint_continuations']['depth_px']
    mask=(images[source][...,3]>0)&dilate(images[neighbour][...,3]>0,depth)
    images['hidden_'+source][mask]=images[source][mask]
    return dict(kind='boundary',source=source,neighbour=neighbour,joint=next(p['bone'] for p in layout['parts'] if p['name']==source),
                bone=bone,depth_px=depth,include_outline=True,texels=np.argwhere(mask)[:,::-1].tolist())


def rigid_base(part):
    from .mesh import grid
    vertices,uvs,triangles=grid(part['bbox'])
    return dict(part,replaces_part=part['name'],garment=part['logical_part'],rigid_painted_caps=True,
                hidden_material=True,grid_px=2,vertices=vertices,uvs=uvs,triangles=triangles,
                weights={part['bone']:[1.]*len(vertices)})


def source_errors(case,layout,images,anatomy):
    errors=[]
    for mesh in layout.get('joint_meshes',[]):
        for row in mesh.get('painted_joint_caps',[]):
            source=row['source'];recipe=anatomy['meshes'].get(source,{})
            visible=mesh['name']==source
            if row.get('kind')=='boundary':
                expected=(images[source][...,3]>0)&dilate(images[row['neighbour']][...,3]>0,row['depth_px'])
                source_part=next(p for p in layout['parts'] if p['name']==source)
                neighbour=next(p for p in layout['parts'] if p['name']==row['neighbour'])
                targets=anatomy['meshes'].get(row['neighbour'],{}).get('bones',[neighbour['bone']])
                if (visible or row['depth_px']!=anatomy['joint_continuations']['depth_px'] or row['bone'] not in targets or row['joint']!=source_part['bone'] or not row.get('include_outline') or
                    sorted(map(tuple,row['texels']))!=sorted(map(tuple,np.argwhere(expected)[:,::-1])) or
                    np.any(images[mesh['name']][expected]!=images[source][expected])):errors.append('painted cap: changed boundary source/owner/RGBA')
                continue
            target_bones=recipe.get('bones',[None,None]) if row.get('kind')=='joint_side' else [recipe.get('bones',[None,None])[1]]
            if (mesh.get('garment')!=source or
                row['joint']!=recipe.get('joints',[None,None])[1] or row['bone'] not in target_bones or
                row['depth_px']!=anatomy['joint_continuations']['depth_px']):
                errors.append('painted cap: invalid source/owner/depth');continue
            if visible and not row.get('include_outline',False):
                errors.append('painted cap: invalid outline ownership');continue
            expected=band(images[source],layout['joints'],recipe,row['depth_px'],rules(case,layout['facing']),row.get('include_outline',False))
            if sorted(map(tuple,row['texels']))!=sorted(map(tuple,np.argwhere(expected)[:,::-1])):
                errors.append('painted cap: source band changed')
            if np.any(images[mesh['name']][expected]!=images[source][expected]):errors.append('painted cap: exact source RGBA lost')
    for part in layout['parts']:
        if not part.get('joint_cap_layer'):continue
        selected=np.zeros((255,255),bool)
        for mesh in layout['joint_meshes']:
            if mesh['name']!=part['name']:continue
            for row in mesh.get('painted_joint_caps',[]):
                for x,y in row['texels']:selected[y,x]=True
        if not part.get('hidden_material') or np.any((images[part['name']][...,3]>0)!=selected):
            errors.append('painted cap: overlay must contain exactly its own source band')
    return errors


def masks(case,layout):
    from maquette_motion.features import source_pixels
    images={p['name']:source_pixels(case,p) for p in layout['parts']}
    result={}
    for mesh in layout.get('joint_meshes',[]):
        for row in mesh.get('painted_joint_caps',[]):
            mask=result.setdefault(mesh['name'],np.zeros((255,255),bool))
            for x,y in row['texels']:
                if not np.array_equal(images[mesh['name']][y,x],images[row['source']][y,x]) or not images[row['source']][y,x,3]:
                    raise ValueError('Changed painted cap source')
                mask[y,x]=True
    return result
