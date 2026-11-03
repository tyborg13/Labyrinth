"""Transport pre-existing rest air independently of the presented alpha.

A source hole is not a new tear. IDs are bound to immutable rest pixels and
move with their registered rim owner, using the same source-space skin field.
No current-frame hole, size allowance or frame exception creates a reference.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.silhouette import holes,dilate
from maquette_motion.features import source_pixels
from maquette_motion import pixels
from humanoid_cutout.cpu_pose import mesh_map,mask_mesh,mapped
from humanoid_cutout.gates import matrix
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.anatomy import load


def build(case,layout):
    rest=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'));owner=np.zeros(rest.shape[:2],np.uint16)
    parts=sorted(layout['parts'],key=lambda p:p['z_index'])
    for index,part in enumerate(parts,1):owner[source_pixels(case,part)[...,3]>0]=index
    records=[]
    for index,mask in enumerate(holes(rest[...,3]>0),1):
        rim=owner[dilate(mask,1)&(owner>0)];counts=np.bincount(rim,minlength=len(parts)+1)
        part=parts[int(counts.argmax())-1];yy,xx=np.nonzero(mask)
        records.append({'id':index,'owner':part['name'],'pixels':np.column_stack((xx,yy)).tolist()})
    path=case/f'ownership/{layout["facing"]}_rest_air.json';write_json(path,{'rest_sha256':digest(case/layout['rest_source']),'references':records})
    layout['source_air_references']={'file':str(path.relative_to(case)),'sha256':digest(path)}


class References:
    def __init__(self,model):
        self.model=model;self.groups=[];record=model.layout.get('source_air_references')
        if record is None:return
        if digest(model.case/record['file'])!=record['sha256']:raise ValueError('Changed source-air reference')
        data=read_json(model.case/record['file']);rest=np.asarray(Image.open(model.case/model.layout['rest_source']).convert('RGBA'))
        by_owner={}
        for row in data['references']:
            xy=np.asarray(row['pixels'],int)
            if np.any(rest[xy[:,1],xy[:,0],3]):raise ValueError('Rest-air reference contains painted pixels')
            by_owner.setdefault(row['owner'],[]).append(row)
        recipes=load(model.case)['meshes']
        for name,rows in by_owner.items():
            part=next(p for p in model.layout['parts'] if p['name']==name)
            image=np.zeros((255,255,4),np.uint8)
            for row in rows:
                xy=np.asarray(row['pixels']);image[xy[:,1],xy[:,0]]=[row['id']%256,row['id']//256,0,255]
            yy,xx=np.nonzero(image[...,3]);bounds=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
            source=image[bounds[1]:bounds[3],bounds[0]:bounds[2]];mesh=None
            if name in model.meshes:
                original=model.meshes[name];pseudo=dict(part,bbox=bounds,offset=bounds[:2])
                mesh=layer(pseudo,part['logical_part'],original['weight_bounds'],model.layout['joints'],part['z_index'],recipe=recipes[part['logical_part']])
                mesh=mask_mesh(mesh,source[...,3]>0)
            self.groups.append((part,bounds,source,mesh))

    def posed(self,row):
        result=[]
        for part,bounds,source,mesh in self.groups:
            if mesh:
                image=mapped(source,mesh_map(self.model.layout,row,mesh,native_skin=True,triangle_batch_size=128))
            else:
                transform=matrix(row['parts'][part['name']]['transform']).copy()
                transform[:2,2]+=transform[:2,:2]@(np.asarray(bounds[:2])-part['offset'])
                image=pixels.render(source,transform)
            result.append(image[...,0].astype(np.uint16)+image[...,1].astype(np.uint16)*256)
        return result
