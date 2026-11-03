"""Fail-closed mq-16 inputs; resolving design is an explicit owner operation."""
import json
import math
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import todos, validate
from .source_measurements import FOLDER, verify

HUMANOID = {'head', 'torso', 'pelvis'} | {
    name+'_'+side for name in ('upper', 'fore', 'hand', 'thigh', 'shin', 'foot')
    for side in ('near', 'far')}
LABELS = HUMANOID | {'pauldron_near', 'pauldron_far', 'belt', 'tabard', 'falchion'}
FEATURES = {'cross_visor': 'head', 'round_strap_buckle': 'torso', 'glowing_edge': 'falchion'}


def read_inputs(folder=FOLDER):
    folder = Path(folder)
    return json.loads((folder/'measurements.json').read_text()), json.loads((folder/'source_measurements.json').read_text())


def unresolved(recipe):
    return todos(recipe, 'measurements')


def require_resolved(recipe):
    missing = unresolved(recipe)
    if missing:
        raise ValueError('Unresolved design: ' + '; '.join(missing))
    p = recipe['pose']
    for field, lo, hi in [('knee_bend_degrees', 8, 12), ('near_elbow_bend_degrees', 10, 15)]:
        value = p[field]
        if type(value) not in (int, float) or not math.isfinite(value) or not lo <= value <= hi:
            raise ValueError('Outside brief range: ' + field)
    for field in ('foot_span_over_shoulder_span', 'near_step_over_leg_length',
                  'far_hand_forward_over_leg_length', 'far_hand_outward_over_leg_length'):
        value = p[field]
        if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
            raise ValueError('Positive owner value required: ' + field)
    if p['foot_span_over_shoulder_span'] <= 1:
        raise ValueError('Feet must be wider than shoulders')
    if p['blade_angle_space'] != 'body':
        raise ValueError('Director specified body-space blade angle')
    if (p['blade_down_degrees'], p['hip_lean_degrees'], p['shoulder_rise_per_span']) != (45, 5, .15):
        raise ValueError('Brief constants changed')
    if set(recipe['labels']) != LABELS:
        raise ValueError('mq-16 requires exactly twenty labels')
    from .recipe import director_pose
    if p != director_pose():
        raise ValueError('Pose differs from director feedback 1 plus feedback-2 weapon override')


def load_spec(folder=FOLDER):
    folder = Path(folder).resolve()
    recipe, observed = read_inputs(folder)
    require_resolved(recipe)
    verify(observed)
    # No executable input, traversal, external candidate, or automatic fallback.
    name = recipe['native_spec']
    if not isinstance(name, str):
        raise ValueError('Native spec must be a figure-local JSON input')
    path = (folder/name).resolve()
    if (Path(name).is_absolute() or '..' in Path(name).parts
            or not path.is_relative_to(folder) or path.suffix != '.json'):
        raise ValueError('Native spec must be a figure-local JSON input')
    spec = json.loads(path.read_text())
    validate(spec)
    if spec['id'] != 'ashen_reaver' or spec['labels'] != recipe['labels']:
        raise ValueError('Native identity/labels differ from the contract')
    if (spec['base']['asset'] != 'realistic_body_male'
            or spec['base'].get('object') != 'GEO-body_male_realistic'):
        raise ValueError('Approved CC0 humanoid anatomy is required')
    if any(key in spec for key in ('rear_body', 'per_view_cloth_pose', 'rear_capture')):
        raise ValueError('Both views must turn the same native pose and camera')
    if 'view_transforms' in spec:
        for view,expected in [('front',np.eye(4)),('rear',np.diag([-1.,-1.,1.,1.]))]:
            data=spec['view_transforms'][view]
            if not np.array_equal(data['object_to_world'],expected) or (data['azimuth_deg'],data['elevation_deg'],data['ortho_scale'])!=(45,30,spec['ortho_scale']):
                raise ValueError('Proof camera must retain the exact true turn and common scale/angles')
    features = spec.get('native_features', {})
    for name, owner in FEATURES.items():
        if features.get(name, {}).get('part') != owner or features[name].get('visibility') != recipe['features'][name]['visibility']:
            raise ValueError('Missing whole native feature: ' + name)
    by_part = {part: [p for p in spec['pieces'] if p['part'] == part] for part in LABELS}
    for part, joint in [('falchion', 'hand_far'), ('tabard', 'pelvis')]:
        if not by_part[part] or any(p.get('rig_pivot_joint') != joint or p.get('rig_bone') != joint for p in by_part[part]):
            raise ValueError('Incorrect native attachment: ' + part)
    for piece in spec['pieces']:
        if any(word in piece['id'].lower() for word in ('scarf', 'cowl')) and piece['part'] != 'torso':
            raise ValueError('Scarf and cowl must belong entirely to torso')
    from .recipe import compile_spec
    if spec != compile_spec():
        raise ValueError('Native spec differs from protected source/director reconstruction')
    return recipe, spec
