"""Round-2 director changes applied to the source-measured round-1 proposal."""
from copy import deepcopy
import argparse
import json
import math
from pathlib import Path

import numpy as np

from .contract import validate
from ..raster import camera

ROOT = Path(__file__).resolve().parents[1]


def refine(spec):
    spec = deepcopy(spec)
    spec['design_status'] = 'Round 2 director armour/conformance proposal'
    pieces = {p['id']: p for p in spec['pieces']}
    _, aim, basis, scale = camera(spec)
    right, up, toward = basis
    ps = scale / 1024
    def point(x, y, depth=0):
        return aim + right * ((x - 112 - 512) * ps) + up * ((512 - y) * ps) + toward * depth
    def corners(piece, points, depth=.3):
        centre = np.mean(points, axis=0)
        piece['offset'] = (point(*centre, depth) - spec['joints'][piece['at']]).tolist()
        piece['outline'] = [[(x - centre[0]) * ps, (centre[1] - y) * ps] for x, y in points]
        piece['source_outline_px'] = points
    for p in spec['pieces']:
        if p['type'] not in ('plate', 'lames'):
            continue
        p.pop('conform_weights', None)
        p.update(conforming=True, offset_surface=.008, thick=.009, surface_spacing=.025)
        p['bevel']['width'] = .002
        p['body_regions'] = [p['part']] if p['part'] in {b['region'] for b in spec['armature']['bones']} else []
        if p.get('ridge'):
            p['ridge'].update(height=.012, width=.04)
        if p['type'] == 'lames':
            p['overlap'] = [.003 * (p['count'] - 1 - i) for i in range(p['count'])]
            p['lame_scale'] = [[1 - .07 * i, 1 - .025 * i] for i in range(p['count'])]
    # Director: near fist rests on the hip, rather than hanging below it.
    hand = point(567, 551)
    hand += toward * ((1.08 - hand[2]) / toward[2])
    spec['joints']['hand_near'] = hand.tolist()
    spec['joints']['hand_tip_near'] = (hand + [.015, .005, -.065]).tolist()
    for side in ('near', 'far'):
        spec['joints']['foot_tip_' + side] = (np.array(spec['joints']['ankle_' + side]) + [.18 * math.cos(math.radians(22 if side == 'near' else 0)), .18 * math.sin(math.radians(22 if side == 'near' else 0)), -.045]).tolist()
    # Reduce the extension above the skull by forty percent; the cowl still
    # clears the unchanged head. Widen the lower rows into the original collar.
    hood = pieces['hood']
    for row in hood['pattern']['rows']:
        row['centre'][2] = 2.0 + .6 * (row['centre'][2] - 2.0) if row['centre'][2] > 2.0 else row['centre'][2]
    for row, factor in zip(hood['pattern']['rows'], (1, 1.15, 1.15, 1.2, 1.2)):
        row['radii'] = [r * factor for r in row['radii']]
    # The native head remains the collider/rig anatomy. Its covered render region
    # is replaced by the closed face mask, so no eye/nose/mouth can leak through.
    spec['base']['covered_regions'] = ['head', 'foot_near', 'foot_far', 'hand_near', 'hand_far']
    spec['base']['covered_above_z'] = 1.72
    mask = deepcopy(pieces['breastplate'])
    mask.update(id='face_plate', part='head', at='head', ridge=None, body_regions=[],
                clay_colour=[.014, .019, .023], surface_spacing=.04, contact_hull=True, contact_min_z=1.72)
    corners(mask, [[434, 193], [480, 169], [521, 196], [510, 280], [477, 306], [443, 278]], .35)
    spec['pieces'].insert(1, mask)
    # A recessed dark channel surrounds the narrow luminous cross inlay. Paths
    # are projected onto the mask's body-conforming face, inside the cowl lip.
    for name, pixels in [('face_slit', [(480, 207), (480, 272)]),
                         ('face_crossbar', [(468, 228), (492, 228)])]:
        for layer, radius, colour in [('accent', .0025, [.35, .9, 1.0])]:
            pts = [point(*(np.array(pixels[0]) * (1 - t) + np.array(pixels[1]) * t), .5).tolist()
                   for t in np.linspace(0, 1, 16)]
            p = {'id': name + '_' + layer, 'part': 'head', 'type': 'curve', 'at': 'root',
                 'offset': [0, 0, 0], 'rot': [0, 0, 0], 'proposed': True,
                 'path': pts, 'spline': 'POLY', 'radius': radius, 'taper': [1] * len(pts),
                 'closed': False, 'resolution': 8, 'bevel_resolution': 2, 'conforming': True,
                 'offset_surface': .006,
                 'conform_direction': (-toward).tolist(), 'conform_target': 'contact_face_plate'}
            p['accent_colour' if layer == 'accent' else 'clay_colour'] = colour
            spec['pieces'].insert(2, p)
            mask.setdefault('slots', []).append({'id': name, 'path': pts, 'radius': .006,
                'offset_surface': .006, 'conform_direction': (-toward).tolist(), 'conform_target': 'contact_face_plate'})
    chest = pieces['breastplate']
    corners(chest, [[422, 330], [478, 317], [541, 334], [532, 469], [482, 492], [429, 472]], .4)
    chest.update(body_regions=['torso', 'pelvis'], contact_hull=True, contact_min_z=1.04, contact_max_z=1.65)
    chest['ridge']['line'] = [[0, .14], [0, -.13]]
    gem = pieces['chest_gem']
    gem.update(length=gem['length'] * 1.3, width=gem['width'] * 1.3, depth=.04)
    # Gem placement is projected onto the completed breastplate by the builder.
    gem['offset'] = (point(480, 432, .5) - spec['joints']['torso']).tolist()
    gem['seat_on'] = 'breastplate'
    gem['seat_contacts'] = ['collar']
    gem['accent_colour'] = [.35, .9, 1.0]
    gem['seat_offset'] = .014
    for side in ('near', 'far'):
        p = pieces['pauldron_' + side]
        p['surface_spacing'] = .018
        p['body_regions'] = []
        p['contact_pieces'] = ['collar']
        p['lame_scale'] = [[1 - .10 * i, 1 - .08 * i] for i in range(3)]
        if side == 'near':
            corners(p, [[548, 279], [600, 280], [652, 325], [622, 344], [546, 330]], .4)
        else:
            corners(p, [[351, 307], [385, 293], [427, 326], [407, 350], [341, 345]], .4)
        p['lame_drop'] = [(up * (-22 * ps * i)).tolist() for i in range(3)]
        # Two thigh-wide front panels, pinned at the belt, hem above the knees.
        panel = pieces['tabard_' + side]
        left, right_x = (399, 471) if side == 'far' else (491, 563)
        panel['pattern']['rows'] = [
            {'a': point(left - (10 * i if side == 'far' else 0), y, .15).tolist(),
             'b': point(right_x - (4 * i if side == 'far' else -3 * i), y, .15).tolist()}
            for i, y in enumerate((487, 555, 620, 687))]
        panel['rag']['depth'] = .035
        tasset = pieces['tasset_' + side]
        tasset['body_regions'] = ['pelvis', 'thigh_' + side]
        tasset['contact_pieces'] = ['tabard_' + side]
        l, r = (401, 452) if side == 'far' else (523, 574)
        corners(tasset, [[l, 501], [r, 497], [r + 10, 542], [l + 8, 552]], .4)
        tasset['lame_drop'] = [(up * (-14 * ps * i)).tolist() for i in range(2)]
        # Flared wrist cuffs, followed by the hand's narrower fist plate.
        for prefix, regions in [('vambrace', ['upper_', 'fore_', 'hand_']), ('gauntlet', ['fore_', 'hand_']), ('poleyn', ['thigh_', 'shin_']), ('greave', ['shin_', 'foot_']), ('sabaton', ['foot_', 'shin_'])]:
            pieces[prefix + '_' + side]['body_regions'] = [r + side for r in regions]
        for prefix in ('cuisse', 'poleyn', 'greave'):
            pieces[prefix + '_' + side]['contact_hull'] = True
        cuff = pieces['gauntlet_' + side]
        if side == 'near':
            corners(cuff, [[550, 525], [586, 527], [589, 565], [567, 582], [545, 563]], .35)
            corners(pieces['vambrace_near'], [[606, 437], [638, 449], [621, 489], [581, 540], [555, 526]], .35)
        cuff.update(body_shell=True, body_regions=['hand_' + side], contact_hull=True, cuff_flare=.012, cuff_height=.085)
        cuff['ridge']['height'] = .006
        cuff['ridge']['width'] = .03
        foot = pieces['sabaton_' + side]
        foot['body_regions'] = ['foot_' + side]
        foot['contact_hull'] = True
        # Broad blunt toe; all three lames shrink down toward the toe.
        pts = ([[583, 900], [630, 899], [645, 947], [632, 963], [593, 963], [576, 946]] if side == 'near' else
               [[366, 889], [410, 889], [419, 927], [402, 943], [330, 943], [315, 929]])
        corners(foot, pts, .4)
        boot = deepcopy(foot)
        boot.update(id='boot_' + side, type='plate', body_shell=True, body_regions=['foot_' + side],
                    offset_surface=.003, thick=.004, smooth_shell=True)
        for key in ('count', 'lame_drop', 'lame_scale', 'overlap'):
            boot.pop(key, None)
        spec['pieces'].insert(spec['pieces'].index(foot), boot)
        foot['lame_drop'] = [(up * (-10 * ps * i)).tolist() for i in range(3)]
    for name in ('belt', 'diagonal_strap'):
        p = pieces[name]
        p.update(conforming=True, offset_surface=.003)
        if name == 'diagonal_strap':
            a, b = point(547, 489, .5), point(441, 350, .5)
            p['path'] = [list(a * (1 - t) + b * t) for t in np.linspace(0, 1, 64)]
            p['taper'] = [1] * 64
            p['conform_direction'] = (-toward).tolist()
        p['radius'] = .018 if name == 'belt' else .012
    shaft = pieces['spear_shaft']
    shaft['radius'] = .025
    shaft['path'][-1] = (np.array(shaft['path'][0]) + (np.array(shaft['path'][-1]) - shaft['path'][0]) * (664 / 689)).tolist()
    blade = pieces['spear_blade']
    blade['path'] = deepcopy(shaft['path'])
    shaft_length = np.linalg.norm(np.array(shaft['path'][-1]) - shaft['path'][0])
    blade.update(length=float(shaft_length * .22 / .78),
                 width_profile=[[0, .045], [.10, .050], [.20, .052], [.31, .050], [.43, .045], [.55, .042], [.67, .038], [.79, .030], [.90, .018], [1, 0]],
                 jag={'count': 6, 'depth': .04, 'seed': 19, 'indices': [5, 13, 15, 23, 30, 38]})
    spec['proposal_basis']['round2'] = {'proposed': True, 'director': '2026-10-16 round 2',
        'kept': ['body asset, registration, rest rig, standing joint positions', 'collar pattern/physics', 'cloak pattern/physics', 'camera and fit gate']}
    validate(spec)
    return spec


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', nargs='?', type=Path, help='Optional round-1 snapshot; otherwise reproduce its source-measured recipe')
    parser.add_argument('--out', type=Path, default=ROOT / 'frostglass_lancer/spec_r3.json')
    args = parser.parse_args()
    if args.source:
        original = json.loads(args.source.read_text())
    else:
        from .propose_lancer import propose
        original = propose()
    args.out.write_text(json.dumps(refine(original), indent=2) + '\n')
