"""Director round 3: a single sewn tabard with four cut, ragged strips."""
from copy import deepcopy
import json
from pathlib import Path

import numpy as np

from .contract import validate


def refine(spec):
    result = deepcopy(spec)
    result['design_status'] = 'Round 3 director board facing and single split tabard proposal'
    old = next(p for p in result['pieces'] if p['id'] == 'tabard_near')
    panel = deepcopy(old)
    panel.update(id='tabard_front', part='tabard', frames=24, self_collision=False)
    n = 17
    from .facing import board_spec
    board = board_spec(result)
    hip = (np.asarray(board['joints']['hip_near']) + board['joints']['hip_far']) / 2
    # Front belt bounds measured by the native inspection probe. The pinned
    # seam follows its outer arc; the lower pattern clears the planted thighs.
    belt = {'centre_x': .12123356014490128, 'centre_y': -.35728635638952255,
            'radius_x': .16662662476301193, 'radius_y': .17029265314340591,
            'seam_offset': .005, 'z': 1.14}
    rows = []
    for index, (width, z, x) in enumerate([(.30, belt['z'], 0), (.32, 1.02, .42),
                                          (.34, .89, .48), (.36, .83, .51),
                                          (.38, .77, .53), (.40, .70, .54)]):
        points = []
        for u in np.linspace(0, 1, n):
            y = (belt['centre_y'] if index == 0 else hip[1]) + (u - .5) * width
            front = (belt['centre_x'] + belt['radius_x'] *
                     np.sqrt(1 - ((y - belt['centre_y']) / belt['radius_y']) ** 2) + belt['seam_offset']
                     if index == 0 else x + .014 * np.sin(8 * np.pi * u))
            points.append([float(front), float(y), z])
        rows.append({'points': points})
    panel['pattern'] = {'columns': n, 'closed': False, 'pins': list(range(n)),
        'rows': rows, 'splits': {'from_row': 2, 'columns': [3, 7, 11], 'gap_columns': 1}}
    panel['rag'] = {'count': 6, 'depth': .045, 'seed': 33}
    index = next(i for i, p in enumerate(result['pieces']) if p['id'] == 'tabard_far')
    result['pieces'] = [p for p in result['pieces'] if p['id'] not in ('tabard_far', 'tabard_near')]
    result['pieces'].insert(index, panel)
    for p in result['pieces']:
        if p['id'] in ('tasset_near', 'tasset_far'):
            p['contact_pieces'] = ['tabard_front']
        if p['type'] == 'lames' and p.get('contact_pieces'):
            p['contact_hull'] = True
    # Front chest pieces were authored on the camera's pitched image plane.
    # In the corrected anatomical frame they stand vertically from the
    # collarbones to belt, with the diamond below the collar at mid-chest.
    chest = next(p for p in result['pieces'] if p['id'] == 'breastplate')
    gem = next(p for p in result['pieces'] if p['id'] == 'chest_gem')
    chest['rot'] = [0, *chest['rot'][1:]]
    gem['rot'] = [0, *gem['rot'][1:]]
    chest['offset'][2] = -.06
    gem['offset'][2] = -.13
    result['proposal_basis']['round3'] = {'proposed': True, 'director': '2026-10-17 round 3',
        'tabard': 'One hip-wide, slightly flared cloth pattern, four strips cut from mid-thigh; original above-knee hem',
        'kept': ['joint coordinates, segment lengths and bone scales', 'base registration input', 'collar/cloak patterns and physics; limb and weapon shapes', 'source frame, camera and fit gate'],
        'belt_pin_measurement': belt,
        'facing': 'Builder normalizes all v2 asset/rest/pose/accessory frames to board forward +X'}
    validate(result)
    return result


if __name__ == '__main__':
    from .propose_lancer import propose
    from .refine_lancer import refine as round2
    path = Path(__file__).resolve().parents[1] / 'frostglass_lancer/spec_r3.json'
    path.write_text(json.dumps(refine(round2(propose())), indent=2) + '\n')
