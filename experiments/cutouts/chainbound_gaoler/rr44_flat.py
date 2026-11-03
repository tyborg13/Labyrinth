"""Flat backing ratchet, with exact own-paint joint bands on the moving garment."""
import numpy as np
from functools import lru_cache
import io,tarfile
from PIL import Image
from rr38_uncovered import flat_regions as raw_regions
from humanoid_cutout.painted_caps import masks
from humanoid_cutout.cpu_pose import mapped,mesh_map
from rr42_raster import rigid


@lru_cache(maxsize=2)
def reference_domains(view):
    # Keep the ratchet's material comparator fixed when missing-paint demand
    # is corrected. Otherwise the same unchanged paint gains a new variance
    # threshold merely because transparent-domain support was calibrated.
    from rr44_case import CASE
    from cutout_pipeline.cases import digest,read_json
    fixture=CASE/'fixtures/native_r1';manifest=read_json(fixture/'manifest.json')
    if digest(fixture/'manifest.json')!='1ba4c6511c9ac48dafb38408b5f80b600d3eb25a82baba20b03877429ebba2ad' or digest(fixture/'case.tar.gz')!=manifest['files']['case.tar.gz']:
        raise ValueError('Changed flat material-reference fixture')
    result={}
    with tarfile.open(fixture/'case.tar.gz') as archive:
        layout=__import__('json').loads(archive.extractfile(f'layouts/{view}.json').read())
        for part in layout['parts']:
            if part.get('hidden_material'):continue
            name=part['logical_part']
            result[name]=np.asarray(Image.open(io.BytesIO(archive.extractfile(f'uncovered/{view}_{name}.png').read())).convert('L'))>0
    return result


def regions(gate,pose,layers,maps=None,output=None):
    model=gate.model;source_masks=masks(model.case,model.layout)
    moving=np.zeros(layers[0][1].shape[:2],bool);covered=np.zeros_like(moving);maps={} if maps is None else maps
    for part,actual,_ in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
        name=part['name']
        opaque=actual[...,3]>0;visible=opaque&~covered;covered|=opaque
        if name not in source_masks:continue
        x,y,x1,y1=part['bbox'];source=np.zeros((y1-y,x1-x,4),np.uint8);source[source_masks[name][y:y1,x:x1]]=255
        if name in model.meshes:
            mapping=maps.get(name)
            if mapping is None:mapping=mesh_map(model.layout,pose,model.meshes[name],native_skin=True,triangle_batch_size=128)
            transported=mapped(source,mapping)
        else:transported=rigid(source,model.layout,pose,part)
        moving |= (transported[...,3]>0)&visible
    rows=raw_regions(gate,pose,layers,output,moving_extra=moving,reference_domains=reference_domains(pose['view']))
    for row in rows:row['decision']='Compared with director-accepted r1 inventory; new regions or growth >2px fail'
    return rows
