"""Continue rounded boulders with their own approved, non-green surface texels."""
import numpy as np
from rr18_case import CASE
from cutout_pipeline.cases import read_json
from humanoid_cutout.materials import connected_mask
from humanoid_cutout.material_gates import green_dominant
from maquette_motion.bleed import edge_texels
from maquette_motion.silhouette import dilate


def surface_donors(visible, margin):
    donors = visible.copy()
    donors[green_dominant(donors, margin)] = 0
    return donors


def continue_surfaces(visible, hidden, anatomy, view, definition):
    recipes = read_json(CASE/'joint_continuations.json').get(view,{})
    depth = anatomy['joint_continuations']['depth_px']
    margin = anatomy['material_policy']['green_dominance_margin']
    records = []
    for name,image in hidden.items():
        own = visible[name][...,3] > 0
        base = own | (image[...,3] > 0)
        added = np.zeros_like(own)
        if name in recipes:
            recipe = recipes[name]
            seed = np.zeros_like(own)
            for x,y in recipe['source_points']:seed[y,x] = True
            # Round own-edge growth closes exposed sampling gaps, including
            # former source air. The exact unprocessed cut is retained separately.
            domain = dilate(seed,depth) & ~own
            added = connected_mask(base,domain) & ~base
        target = (image[...,3]>0) | added
        donors = surface_donors(visible[name],margin)
        hidden[name] = edge_texels(donors,target,definition)
        records.append({'piece':name,'added_pixels':int(added.sum()),
            'retextured_pixels':int(target.sum()),'green_before':int(green_dominant(image,margin).sum()),
            'green_after':int(green_dominant(hidden[name],margin).sum()),
            'source_points':recipes.get(name,{}).get('source_points',[]),
            'shape':'connected Euclidean own-edge continuation, including the uncovered seam air',
            'surface':'nearest eligible non-green own-boulder visible texel'})
    return records


def continuation_errors(visible, hidden, anatomy, definition):
    errors = []
    margin = anatomy['material_policy']['green_dominance_margin']
    for name,image in hidden.items():
        target = image[...,3] > 0
        expected = edge_texels(surface_donors(visible[name],margin),target,definition)
        mismatch = int((target & np.any(image != expected,axis=-1)).sum())
        if mismatch:errors.append(f'{name}: continuation differs from own surface by {mismatch} texels')
        green = int(green_dominant(image,margin).sum())
        if green:errors.append(f'{name}: {green} green-dominant hidden texels')
    return errors
