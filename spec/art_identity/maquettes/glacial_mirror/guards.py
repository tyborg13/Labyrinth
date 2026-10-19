"""Live mq-08 geometry guards, shared by certification and invalid fixtures."""
import numpy as np

from spec.art_identity.maquettes.glacial_mirror.shoulder_revision import SHOULDER_CONTRACT
from spec.art_identity.maquettes.raster import camera, project

GUARD_DEFAULTS = {'numerical_tolerance_m': 1e-9}


def shoulder_rule(spec, front):
    near, far = (front['shoulder_' + side] for side in ('near', 'far'))
    target = near[1] - SHOULDER_CONTRACT['slope'] * abs(near[0] - far[0])
    return (abs(far[1] - target) <= SHOULDER_CONTRACT['joint_tolerance_px'] and
            abs(spec['joints']['shoulder_near'][2] - spec['joints']['shoulder_far'][2]) <= GUARD_DEFAULTS['numerical_tolerance_m'])


def pauldron_rule(spec, front, tops):
    near, far = (front['shoulder_' + side] for side in ('near', 'far'))
    rise = SHOULDER_CONTRACT['slope'] * abs(near[0] - far[0])
    pieces = {piece['id']: piece for piece in spec['pieces']}
    crest, cap = project(spec, [pieces[name]['centre'] for name in ('shoulder_near_crest', 'shoulder_far_mass')])[:, :2]
    # The accepted cap is centred on the far joint and retains the near
    # crest's vertical offset. This also catches stale, still-passing rasters
    # when migration and canonical recipe are moved together.
    centre_matches = np.allclose(cap, [far[0], crest[1] - rise], rtol=0,
                                atol=GUARD_DEFAULTS['numerical_tolerance_m'])
    return (bool(centre_matches) and
            abs(tops['upper_far'][1] - (tops['upper_near'][1] - rise)) <= SHOULDER_CONTRACT['pauldron_tolerance_px'] and
            tops['upper_far'][1] >= tops['head'][1])


def turn_rule(spec):
    transform = camera(spec, 'rear')[0] @ np.linalg.inv(camera(spec, 'front')[0])
    return (bool(np.allclose(transform, np.diag([-1, -1, 1, 1]), rtol=0,
                            atol=GUARD_DEFAULTS['numerical_tolerance_m'])) and
            not any(piece.get('capture_view') for piece in spec['pieces']))


def geometry_checks(spec, front, tops):
    return {'front_shoulder_rule': bool(shoulder_rule(spec, front)),
            'pauldron_top': bool(pauldron_rule(spec, front, tops)),
            'same_body_180_turn': bool(turn_rule(spec))}
