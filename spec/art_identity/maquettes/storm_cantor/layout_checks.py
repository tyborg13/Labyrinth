"""Feedback 3 changes volumes while preserving approved joints and layouts."""
import json
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import digest
from .sweep_volume import centers

LAYOUT_LIMITS={'coordinate_tolerance_m':1e-7}


def validate_preserved(spec,folder=None):
    folder=Path(folder or Path(__file__).resolve().parent)
    approved=json.loads((folder/'approved_pose.json').read_text())
    layout=json.loads((folder/'feedback3_preserved.json').read_text())
    pieces={p['id']:p for p in spec['pieces']}
    if spec['joints']!=approved['joints']:raise ValueError('Approved armature joints changed')
    for name,expected in layout['fixed_piece_sha256'].items():
        if name not in pieces or digest(pieces[name])!=expected:raise ValueError('Unrequested piece change: '+name)
    if spec['mq17']['staff']!=layout['staff_layout']:raise ValueError('Approved staff placement changed')
    staff=pieces['staff']['vertices']
    if digest({k:v for k,v in pieces['staff'].items() if k!='vertices'})!=layout['staff_nonvolume_sha256']:
        raise ValueError('Staff topology, ownership or pivot changed')
    if (digest({k:v for k,v in pieces['bell'].items() if k!='vertices'})!=layout['bell_nonvolume_sha256'] or
        digest([v[2] for v in pieces['bell']['vertices']])!=layout['bell_vertex_z_sha256']):
        raise ValueError('Bell height, topology, ownership or pivot changed')
    for name,(a,b) in spec['mq17']['staff_components'].items():
        if name in layout['staff_fixed_component_sha256']:
            if digest(staff[a:b])!=layout['staff_fixed_component_sha256'][name]:raise ValueError('Staff cloth layout changed')
            continue
        if not np.allclose(centers(staff[a:b]),centers(approved['shaft_fork_vertices'][a:b]),
                           rtol=0,atol=LAYOUT_LIMITS['coordinate_tolerance_m']):
            raise ValueError('Approved staff centre path changed: '+name)
    for name,key in [('front_tabard','tabard_grid'),('near_cloak_streamer','cloak_grid')]:
        nr,nc=spec['volume_layout'][key]
        if [nr,nc]!=layout['cloth_grids'][key]:raise ValueError('Cloth topology/layout changed: '+name)
        points=np.asarray(pieces[name]['vertices']);mid=(points[:nr*nc]+points[nr*nc:])/2
        hem=mid.reshape(nr,nc,3)[-1,:,2]
        if not np.allclose(hem,layout['cloth_hem_z_m'][name],rtol=0,atol=LAYOUT_LIMITS['coordinate_tolerance_m']):
            raise ValueError('Approved cloth hem layout changed: '+name)
    return True
