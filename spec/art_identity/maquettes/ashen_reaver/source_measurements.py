"""Read the protected current art and cutout; never write production inputs.

The old cutout's side names describe its old weapon arm, not rig-v2 body sides.
Only dimensions are reused. The new falchion always belongs to hand_far.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.curate_delivery import sha

FOLDER = Path(__file__).resolve().parent
PROJECT = FOLDER.parents[3]
SOURCE = 'assets/units/ashen_reaver.png'
CUTOUT = 'assets/units/guardians/ashen_reaver'
MEASUREMENT_DEFAULTS = {'alpha_threshold': 128}


def observe(project=PROJECT):
    project = Path(project)
    path = project / SOURCE
    image = Image.open(path).convert('RGBA')
    alpha = np.asarray(image)[..., 3] >= MEASUREMENT_DEFAULTS['alpha_threshold']
    y, x = np.where(alpha)
    bounds = [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)]
    views, inputs = {}, {SOURCE: sha(path)}
    for view in ('front', 'rear'):
        relative = CUTOUT + '/' + view + '.json'
        data = json.loads((project / relative).read_text())
        inputs[relative] = sha(project / relative)
        views[view] = {
            'joints_px': {n: v['position'] for n, v in data['joints'].items()},
            'parts': {p['name']: {'bbox_px': p['bbox'], 'offset_px': p['offset']}
                      for p in data['parts']}}
        for part in data['parts']:
            relative = CUTOUT + '/' + part['file']
            inputs[relative] = sha(project / relative)
    joints = views['front']['joints_px']
    head = views['front']['parts']['head']['bbox_px']
    shoulders = [joints['shoulder_'+s] for s in ('near', 'far')]
    # The old head mask includes its neck attachment. Record that explicitly;
    # it is not a fabricated segmentation of the helmet or the visor.
    measurements = {
        'drawn_height_px': bounds[3]-bounds[1],
        'head_part_height_px': head[3]-head[1],
        'head_part_height_ratio': (head[3]-head[1])/(bounds[3]-bounds[1]),
        'shoulder_joint_width_px': abs(shoulders[1][0]-shoulders[0][0]),
        'torso_neck_to_belt_px': joints['pelvis'][1]-joints['head'][1],
        'leg_hip_to_contact_px': {
            s: joints['foot_'+s][1]-joints['hip_'+s][1] for s in ('near', 'far')}}
    return {'schema': 1, 'source': SOURCE, 'canvas_px': list(image.size),
            'opaque_bbox_px': bounds, 'measurements': measurements,
            'views': views, 'input_sha256': inputs,
            'method': 'Alpha >=128 half-open bounds; existing cutout joint coordinates and part bounds. '
                      'Head part includes neck attachment. Old side names are source provenance only.'}


def verify(expected, project=PROJECT):
    actual = observe(project)
    if actual != expected:
        raise ValueError('Protected source art, cutout or measured landmarks changed')
    return actual
