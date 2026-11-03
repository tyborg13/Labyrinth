"""Immutable rest-air references on each registered receiver's own geometry."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import write_json
from humanoid_cutout.mesh import grid,weights_for
from maquette_motion.silhouette import holes,dilate

REFERENCE_PADDING_PX=2


def references(case,layout,images,recipes):
    rest=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'))
    folder=case/'holes';folder.mkdir(exist_ok=True);records=[]
    for index,mask in enumerate(holes(rest[...,3]>0)):
        rim=dilate(mask,1)&~mask
        owner=max(images,key=lambda n:int((rim&(images[n][...,3]>0)).sum()))
        part=next(p for p in layout['parts'] if p['name']==owner)
        name=f'ApprovedRestAir{index}';path=folder/f'{layout["facing"]}_{name}.png'
        image=np.zeros_like(rest);image[mask]=255;Image.fromarray(image).save(path)
        record={'name':name,'owner':owner,'bone':part['bone'],'file':str(path.relative_to(case)),
                'source_policy':'Exact enclosed alpha-zero texels of the immutable assembled rest; no frame exceptions'}
        mesh=next((m for m in layout['joint_meshes'] if m['name']==owner),None)
        if mesh:
            y,x=np.nonzero(mask);pad=REFERENCE_PADDING_PX
            bounds=[max(0,int(x.min())-pad),max(0,int(y.min())-pad),min(255,int(x.max())+pad+1),min(255,int(y.max())+pad+1)]
            vertices,_,triangles=grid(bounds)
            weights=weights_for(vertices,mesh['weight_bounds'],layout['joints'],recipes[part['logical_part']])
            template=folder/f'{layout["facing"]}_{name}_mesh.json'
            write_json(template,{'vertices':vertices,'uvs':vertices,'triangles':triangles,'weights':weights,'z_index':0})
            record['mesh_template']=str(template.relative_to(case))
        else:
            record.update(presentation_anchor=part.get('presentation_anchor',part['offset']),match_presentation_anchor=True)
        records.append(record)
    return records
