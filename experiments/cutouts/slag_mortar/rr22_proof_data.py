"""Transport original source-space gaps as native gate references."""
import json
import numpy as np
from PIL import Image
from rr22_case import CASE, BONES
from humanoid_cutout.mesh import grid, weights_for
from maquette_motion.silhouette import holes, dilate


def rest_holes(layout, paint, visible, anatomy):
    view, records = layout['facing'], []
    meshes = {m['name']: m for m in layout['joint_meshes']}
    for index, hole in enumerate(holes(paint[..., 3] > 0)):
        if int(hole.sum()) <= 1: continue
        rim = dilate(hole, 1) & ~hole
        owner = max(visible, key=lambda n: int((rim & (visible[n][..., 3] > 0)).sum()))
        path = CASE / f'holes/{view}_{index:02d}.png'
        path.parent.mkdir(exist_ok=True)
        image = np.zeros_like(paint)
        image[hole] = 255
        Image.fromarray(image).save(path)
        row = {'name': f'RestHole{index:02d}', 'owner': owner, 'file': str(path.relative_to(CASE)), 'bone': BONES.get(owner, owner)}
        if owner in anatomy['meshes']:
            vertices, uvs, triangles = grid([0, 0, 255, 255])
            weights = weights_for(vertices, meshes[owner]['bbox'], layout['joints'], anatomy['meshes'][owner])
            template = CASE / f'holes/{view}_{owner}_mesh.json'
            template.write_text(json.dumps({'vertices': vertices, 'uvs': uvs, 'triangles': triangles,
                                            'weights': weights, 'z_index': 0}, separators=(',', ':')) + '\n')
            row['mesh_template'] = str(template.relative_to(CASE))
        records.append(row)
    return records
