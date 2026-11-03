"""Group unresolved joins/strays by their existing nearest skeletal joint."""
from collections import defaultdict
import numpy as np
from cutout_pipeline.cases import read_json
from humanoid_cutout.canvas import for_case
from maquette_motion import pixels
from rr42_raster import pose_for_raster


def collect(case,sweep):
    poses={(r['view'],r['clip'],r['frame']):pose_for_raster(r) for r in read_json(case/'proof/logs/samples.json')['samples'] if r['kind']=='presented'}
    groups=defaultdict(list)
    with for_case(case):
        for row in sweep['frames']:
            defects=[dict(r,kind='join') for r in row['source_space']['failures']]
            defects += [dict(r,kind='fragment') for r in row['detached']['unmatched_components']]
            pose=poses[row['view'],row['clip'],row['frame']]
            for defect in defects:
                box=np.asarray(defect['bbox']);centre=(box[:2]+box[2:])/2-pixels.PROOF_DEFAULTS['source_offset']
                joints={n:np.asarray(p['global'][4:]) for n,p in pose['bones'].items() if n not in ('root','chain')}
                nearest=min(joints,key=lambda n:np.linalg.norm(joints[n]-centre))
                groups[row['view'],nearest].append(dict(clip=row['clip'],frame=row['frame'],bbox=defect['bbox'],
                    kind=defect['kind'],pixels=defect['pixel_count'],posed_crop=row.get('crop')))
    return [dict(field=f'TODO_DESIGN_hidden_surface_{view}_{joint}',value='Unresolved join/fragment: director hidden-surface decision required',
                 view=view,joint=joint,frames=frames,status='flagged; no new paint or sub-floor clamp applied')
            for (view,joint),frames in sorted(groups.items())]
