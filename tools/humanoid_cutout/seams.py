"""Joint-seam proof masks, transported only by the native runtime geometry."""
import json
import numpy as np
from PIL import Image
from maquette_motion.silhouette import dilate

def build_masks(case, layout, visible, anatomy):
    masks = {name: np.zeros(image.shape[:2], dtype=bool) for name, image in visible.items()}
    for first, second in anatomy['seam_joins']:
        a, b = visible[first][..., 3] > 0, visible[second][..., 3] > 0
        masks[first] |= a & dilate(b, 1, grid_distance=True)
        masks[second] |= b & dilate(a, 1, grid_distance=True)
    # Inside each single sleeve mesh, the elbow cross-section is the joint
    # seam. The exact .5 contour follows the authored segment-projection rule.
    from .mesh import weights_for
    yy, xx = np.indices(next(iter(masks.values())).shape)
    points = np.stack((xx.ravel() + .5, yy.ravel() + .5), axis=1)
    for name, recipe in anatomy['meshes'].items():
        if recipe['kind'] != 'two_segment': continue
        weights = np.asarray(weights_for(points, None, layout['joints'], recipe)[recipe['bones'][1]]).reshape(xx.shape)
        # Pixels crossing the half-weight contour, without a new motion rule.
        near = weights >= .5
        masks[name] |= (visible[name][..., 3] > 0) & (dilate(near, 1) & dilate(~near, 1))
    records = []
    folder = case / 'seams'
    folder.mkdir(exist_ok=True)
    for name, mask in masks.items():
        if not mask.any(): continue
        part = next(p for p in layout['parts'] if p['name'] == name)
        mesh = next((m for m in layout['joint_meshes'] if m['name'] == name), None)
        image = np.zeros((*mask.shape, 4), dtype=np.uint8)
        image[mask] = 255
        path = folder / (layout['facing'] + '_' + name + '.png')
        if mesh: image = image[mesh['bbox'][1]:mesh['bbox'][3], mesh['bbox'][0]:mesh['bbox'][2]]
        Image.fromarray(image).save(path)
        row = {'name': 'JointSeam_' + name, 'owner': name, 'bone': part['bone'],
               'file': str(path.relative_to(case))}
        if mesh:
            template = folder / (layout['facing'] + '_' + name + '_mesh.json')
            template.write_text(json.dumps(mesh, separators=(',', ':')) + '\n')
            row['mesh_template'] = str(template.relative_to(case))
        records.append(row)
    return records
