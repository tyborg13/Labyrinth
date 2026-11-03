"""Regenerate immutable source-space references after authorized ownership cuts."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import write_json
from maquette_motion.silhouette import holes,dilate
from humanoid_cutout.mesh import grid,weights_for
from humanoid_cutout.seams import build_masks


def rebuild(case,layout,images,anatomy,rest):
    visible={p['name']:images[p['name']] for p in layout['parts'] if not p.get('hidden_material')}
    layout['proof_joint_seams']=build_masks(case,layout,visible,anatomy)
    meshes={m['name']:m for m in layout['joint_meshes']}
    parts={p['name']:p for p in layout['parts']}
    records=[]
    # Include one-source-pixel holes: a director-authorized cleared speck may
    # become several presented pixels under skinning. The requirement comes
    # from the immutable repaired rest, never the failing presented frame.
    for index,hole in enumerate(holes(np.asarray(rest)[...,3]>0)):
        rim=dilate(hole,1)&~hole
        owner=max(visible,key=lambda n:int((rim&(visible[n][...,3]>0)).sum()))
        image=np.zeros((255,255,4),np.uint8);image[hole]=255
        path=case/f'holes/{layout["facing"]}_feedback1_{index:03d}.png';Image.fromarray(image).save(path)
        row={'name':f'AuthoredRestHole{index:03d}','owner':owner,'file':str(path.relative_to(case)),'bone':parts[owner]['bone']}
        if owner in meshes:
            mesh=meshes[owner];vertices,uvs,triangles=grid([0,0,255,255])
            weights=weights_for(vertices,mesh.get('weight_bounds',mesh['bbox']),layout['joints'],anatomy['meshes'][owner])
            target=case/f'holes/{layout["facing"]}_feedback1_{owner}_mesh.json'
            write_json(target,dict(vertices=vertices,uvs=uvs,triangles=triangles,weights=weights,z_index=0))
            row['mesh_template']=str(target.relative_to(case))
        records.append(row)
    # A directed clear can be open to the floor at rest and become enclosed
    # during motion. Certify only those exact source texels, on their own
    # original geometry; never a dilated or frame-selected air region.
    cleared=authorized_clears(layout['facing'])
    for owner,mask in cleared.items():
        if not mask.any():continue
        image=np.zeros((255,255,4),np.uint8);image[mask]=255
        path=case/f'holes/{layout["facing"]}_feedback1_clear_{owner}.png';Image.fromarray(image).save(path)
        row={'name':'DirectorClear_'+owner,'owner':owner,'bone':parts[owner]['bone'],
             'file':str(path.relative_to(case)),'source_policy':'exact director-authorized clear texels'}
        if owner in meshes:
            mesh=meshes[owner];vertices,uvs,triangles=grid([0,0,255,255])
            logical=parts[owner]['logical_part']
            weights=weights_for(vertices,mesh.get('weight_bounds',mesh['bbox']),layout['joints'],anatomy['meshes'][logical])
            target=case/f'holes/{layout["facing"]}_feedback1_clear_{owner}_mesh.json'
            write_json(target,dict(vertices=vertices,uvs=uvs,triangles=triangles,weights=weights,z_index=0))
            row['mesh_template']=str(target.relative_to(case))
        records.append(row)
    layout['proof_rest_holes']=records
    return {'rest_holes':len(records),'source_clear_pixels':sum(int(mask.sum()) for mask in holes(np.asarray(rest)[...,3]>0))}


def authorized_clears(view):
    from rr42_fragments import plan
    from rr42_underlay import repairs,BASE_CASE
    from cutout_pipeline.cases import read_json
    from maquette_motion.features import source_pixels
    cleared={}
    for fragment in plan(view):
        if fragment['decision']!='clear':continue
        mask=cleared.setdefault(fragment['source'],np.zeros((255,255),bool))
        xx,yy=np.asarray(fragment['texels']).T;mask[yy,xx]=True
    if view=='front':
        base=read_json(BASE_CASE/'layouts/front.json');original={p['name']:p for p in base['parts']}
        for repair in repairs():
            if repair['director_rgba'][3]:continue
            name=repair['part'];x,y=repair['uv']
            if source_pixels(BASE_CASE,original[name])[y,x,3]:
                cleared.setdefault(name,np.zeros((255,255),bool))[y,x]=True
    return cleared


def clear_errors(case,layout):
    from cutout_pipeline.cases import read_json
    from humanoid_cutout.anatomy import load
    expected=authorized_clears(layout['facing']);parts={p['name']:p for p in layout['parts']}
    meshes={m['name']:m for m in layout['joint_meshes']};anatomy=load(case)
    actual={r['owner']:r for r in layout['proof_rest_holes'] if r['name'].startswith('DirectorClear_')}
    errors=[]
    if set(actual)!=set(expected):errors.append('director clear reference inventory differs')
    for owner,mask in expected.items():
        if owner not in actual:continue
        row=actual[owner]
        image=np.asarray(Image.open(case/row['file']).convert('RGBA'))
        wanted=np.zeros((255,255,4),np.uint8);wanted[mask]=255
        if not np.array_equal(image,wanted):errors.append('director clear reference differs: '+owner)
        if row['bone']!=parts[owner]['bone']:errors.append('director clear reference bone differs: '+owner)
        if owner in meshes:
            mesh=meshes[owner];vertices,uvs,triangles=grid([0,0,255,255]);logical=parts[owner]['logical_part']
            weights=weights_for(vertices,mesh.get('weight_bounds',mesh['bbox']),layout['joints'],anatomy['meshes'][logical])
            expected_mesh=dict(vertices=vertices,uvs=uvs,triangles=triangles,weights=weights,z_index=0)
            if not row.get('mesh_template') or read_json(case/row['mesh_template'])!=expected_mesh:
                errors.append('director clear reference geometry differs: '+owner)
        elif row.get('mesh_template'):errors.append('director clear rigid reference acquired skinning: '+owner)
    return errors
