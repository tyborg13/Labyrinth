"""Headless rigid-tuck regressions against captured native mesh bodies.

Never skin/rasterize a mesh on the CPU. This proves the wrist/foot corrections
against the supplied native poses, not acceptance of newly rendered meshes.
"""
import numpy as np
from PIL import Image

from cutout_pipeline.cases import digest
from maquette_motion.pixels import render, unpack
from .silhouette_gates import joint_holes, OWNER_IDS


def fixture_masks(folder, record):
    result={}
    for name,row in record['files'].items():
        path=folder/row['file']
        if digest(path)!=row['sha256']:raise ValueError('Changed native seam fixture: '+str(path))
        result[name]=np.asarray(Image.open(path)).copy()
    return result


def seam_holes(case, layout, pose, masks, rigid_tucks, replacement=None):
    owners=masks['owners'].copy()
    body=owners>0
    parts={p['name']:p for p in layout['parts']}
    for name in sorted(rigid_tucks,key=lambda name:parts[name]['z_index']):
        part=parts[name]
        if replacement is not None and name in replacement:
            opaque=replacement[name]>0
        else:
            image=Image.open(case/part['file']).convert('RGBA')
            opaque=render(image,unpack(pose['parts'][name]['transform']))[...,3]>0
        owners[opaque & ~body]=OWNER_IDS[part['logical_part']]
    references=[(masks['rest_holes']&(1<<index))>0 for index in range(8)]
    return joint_holes(owners>0,masks['seam']>0,owners,[m for m in references if m.any()])
