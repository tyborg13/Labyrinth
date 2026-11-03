"""mq-24 compiler: construct the director's rules; never alter mq-20."""
from copy import deepcopy
import json
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.closed_loft import sweep
from ..forms import normal_sheet,oval,shell,TOPOLOGY
from ..mq20.recipe import compile_spec as mq20

FOLDER=Path(__file__).resolve().parent
DESIGN_KEYS=('mantle','far_hand','near_hand')


def read_design(details=None):
    data=deepcopy(details) if details is not None else json.loads((FOLDER/'design_details.json').read_text())
    if set(data)-{'authority'}!=set(DESIGN_KEYS):raise ValueError('mq-24 design schema is incomplete')
    from .oracle import contract
    expected=contract()['feedback1_rules']
    if any(data[key]!=expected[key] for key in DESIGN_KEYS):raise ValueError('Authoring rules differ from independent pinned director contract')
    return data,[]


def digit(identifier,part,origin,H,data):
    """Sweep owner-authored stations; a zero terminal radius is a true apex."""
    path=origin+np.asarray(data['path_over_H'],float)*H
    radii=np.asarray(data['radii_over_H'],float)*H
    if len(path)!=len(radii) or min(radii[:-1])<=0 or radii[-1]<0:
        raise ValueError('Invalid owner digit radii: '+identifier)
    samples=TOPOLOGY['sweep_samples'];pointed=radii[-1]==0
    # The final frame can be computed with any positive radius, then replaced
    # by the exact owner tip. The temporary ring is never delivered.
    temporary=radii.copy()
    if pointed:temporary[-1]=radii[-2]
    vertices,faces,flat=sweep(path,temporary,samples)
    if pointed:
        vertices=vertices[:-samples]+[path[-1].tolist()]
        start=(len(path)-2)*samples;tip=len(vertices)-1
        faces=[f for f in faces if max(f)<start+samples]
        faces += [[start+k,start+(k+1)%samples,tip] for k in range(samples)]
        flat=[len(faces)-samples-1]
    return shell(identifier,part,part,vertices,faces,flat)


def hand(spec,side,data):
    H=spec['mq18']['height_m'];part='hand_'+side;origin=np.asarray(spec['joints'][part])
    palm=data['palm'];axes=np.asarray(palm['axes'],float)
    if axes.shape!=(3,3) or not np.allclose(axes@axes.T,np.eye(3)):
        raise ValueError('Owner palm axes must be orthonormal')
    spec['pieces'][:]=[p for p in spec['pieces'] if p['part']!=part]
    spec['pieces'].append(oval('palm_'+side,part,part,origin+np.asarray(palm['centre_over_H'])*H,
        np.asarray(palm['radii_over_H'])*H,axes))
    if len(data['fingers'])!=4:raise ValueError('Each hand requires four separate fingers')
    for k,finger in enumerate(data['fingers']):
        spec['pieces'].append(digit('finger_'+side+'_'+str(k),part,origin,H,finger))
    spec['pieces'].append(digit('thumb_'+side,part,origin,H,data['thumb']))


def compile_spec(details=None,require_resolved=True):
    data,pending=read_design(details)
    if require_resolved and pending:raise ValueError('Unresolved design: '+', '.join(pending))
    spec=mq20();spec['pieces'][:]=[p for p in spec['pieces'] if not p['part'].startswith('pauldron_')]
    for key in list(spec['labels']):
        if key.startswith('pauldron_') or key=='mantle':spec['labels'].pop(key)
    spec['native_features']={k:v for k,v in spec['native_features'].items() if not k.startswith('pauldron_')}
    for p in spec['pieces']:
        if p['id']=='shoulder_mantle':p['part']='torso'
    from .mantle_construction import build as mantle
    from .hand_construction import build as construct_hand
    H=spec['mq18']['height_m'];old_mantle=deepcopy(next(p for p in spec['pieces'] if p['id']=='shoulder_mantle'))
    rows,mantle_diagnostics=mantle(spec,data['mantle'])
    replacement=normal_sheet('shoulder_mantle','torso','torso',rows,spec['dimensions']['hood_thickness_over_H']*H,periodic=True)
    for first in (0,343):replacement['vertices'][first:first+49]=old_mantle['vertices'][first:first+49]
    spec['pieces'][:]=[replacement if p['id']=='shoulder_mantle' else p for p in spec['pieces']]
    hand_diagnostics={}
    for side in ('far','near'):
        built,hand_diagnostics[side]=construct_hand(spec,side,data[side+'_hand']);hand(spec,side,built)
    spec['base']['covered_regions']=list(spec['labels'])
    spec['mq24']={'revision':'mq-24','design_pending':pending,'construction':{'mantle':mantle_diagnostics,'hands':hand_diagnostics}}
    spec['delivery_reports']=['native_probe.json','mq24_acceptance.json']
    if not pending:validate(spec)
    return spec
