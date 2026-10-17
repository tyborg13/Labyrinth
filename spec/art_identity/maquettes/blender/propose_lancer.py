"""Round-1 source-measured r3 proposal. Never modifies the approved r2 data.

Screen measurements are in the untouched 1024px identity reference. Plate
outlines use those measured corners, converted to the existing board camera.
The front reference constrains projection; depth and physical settings are
explicit proposals for the director to inspect in the rear/clay passes.
"""
from copy import deepcopy
import json
import math
from pathlib import Path

import numpy as np

from .contract import validate
from ..raster import camera

ROOT = Path(__file__).resolve().parents[1]
PROPOSAL = {'source_x_shift_px': -112, 'body_scale': 1.15, 'body_yaw': math.radians(135),
            'body_translation': [.160, -.318, .02], 'plate_rot': [-math.pi / 6, 0, 3 * math.pi / 4],
            'cloth_frames': 8, 'cloth_columns': 32}


def propose():
    r2 = json.loads((ROOT / 'frostglass_lancer/spec_r2.json').read_text())
    spec = {k: deepcopy(r2[k]) for k in ('ortho_scale', 'target', 'labels', 'fit')}
    spec.update(version=2, proposed=True, design_status='Round 1 source-measured proposal for owner review',
                simulation={'gravity': [0, 0, -9.81], 'fps': 24, 'proposed': True}, pieces=[])
    _, aim, basis, scale = camera(spec)
    camera_right, camera_up, camera_toward = basis
    pixel_scale = scale / 1024
    def point(p, depth=0, z=None):
        q = aim + camera_right * ((p[0] + PROPOSAL['source_x_shift_px'] - 512) * pixel_scale) + camera_up * ((512 - p[1]) * pixel_scale)
        if z is not None:
            depth = (z - q[2]) / camera_toward[2]
        return q + camera_toward * depth
    coords = {'pelvis': ([480, 460], 1.12), 'torso': ([480, 375], 1.426),
              'head': ([480, 225], 1.832), 'head_tip': ([480, 165], 1.995),
              'shoulder_near': ([588, 329], 1.56), 'shoulder_far': ([389, 340], 1.56),
              'elbow_near': ([628, 462], 1.25), 'elbow_far': ([329, 459], 1.25),
              'hand_near': ([608, 596], 1.01), 'hand_far': ([255, 512], 1.205),
              'hip_near': ([525, 528], 1.02), 'hip_far': ([434, 528], 1.02),
              'knee_near': ([580, 725], .56), 'knee_far': ([403, 718], .56),
              'ankle_near': ([620, 903], .16), 'ankle_far': ([398, 891], .16)}
    spec['joints'] = {'root': [0, 0, 0], **{k: point(p, z=z).tolist() for k, (p, z) in coords.items()}}
    for side in ('near', 'far'):
        spec['joints']['hand_tip_' + side] = (np.array(spec['joints']['hand_' + side]) + [.015, .005, -.065]).tolist()
        spec['joints']['foot_tip_' + side] = (np.array(spec['joints']['ankle_' + side]) + [.18, 0, -.07]).tolist()
    angle, s = PROPOSAL['body_yaw'], PROPOSAL['body_scale']
    transform = np.eye(4)
    transform[:3, :3] = np.array([[math.cos(angle), -math.sin(angle), 0], [math.sin(angle), math.cos(angle), 0], [0, 0, 1]]) * s
    transform[:3, 3] = PROPOSAL['body_translation']
    spec['base'] = {'asset': 'realistic_body_male', 'object': 'GEO-body_male_realistic',
                    'matrix': transform.tolist(), 'subdivision_level': 0, 'proposed': True,
                    'reason': 'Approved complete realistic anatomy; bundle thumbnail id is a camera, resolved to its actual body mesh.'}
    def rest(p):
        return (transform[:3, :3] @ p + transform[:3, 3]).tolist()
    native = {'root': [0, 0, 0], 'pelvis': [0, 0, .91], 'torso': [0, -.01, 1.20],
              'head': [0, -.065, 1.55], 'head_tip': [0, -.065, 1.68]}
    for side, sign in [('near', 1), ('far', -1)]:
        for name, xyz in {'shoulder': [.17, -.015, 1.36], 'elbow': [.31, -.02, 1.06],
                          'hand': [.37, -.065, .89], 'hand_tip': [.43, -.11, .72],
                          'hip': [.11, 0, .86], 'knee': [.15, .015, .48],
                          'ankle': [.19, .055, .10], 'foot_tip': [.20, -.10, .035]}.items():
            native[name + '_' + side] = [xyz[0] * sign, *xyz[1:]]
    template = json.loads((ROOT / 'frostglass_lancer/spec_r3.json').read_text())
    spec['armature'] = {'rest_joints': {k: rest(v) for k, v in native.items()}, 'collision_margin': .003,
                        'bones': deepcopy(template['armature']['bones']), 'proposed': True}
    for bone in spec['armature']['bones']:
        bone['roll'] = 0
        bone['scale'] = [.85, .85] if bone['region'].startswith(('upper', 'fore', 'thigh', 'shin')) else [1, 1]
    spec['labels'].update(collar=[.22, .65, .08], tasset_near=[.7, .2, .35], tasset_far=[.45, .12, .3])
    def common(name, kind, part, at='root', centre=None, depth=0):
        offset = point(centre, depth=depth) - spec['joints'][at] if centre else np.zeros(3)
        p = {'id': name, 'type': kind, 'part': part, 'at': at, 'offset': offset.tolist(),
             'rot': [0, 0, 0], 'proposed': True}
        spec['pieces'].append(p)
        return p
    def plate(name, part, corners, at, depth=.12, ridge=None):
        centre = np.mean(corners, axis=0)
        p = common(name, 'plate', part, at, centre.tolist(), depth)
        p.update(rot=PROPOSAL['plate_rot'], outline=[[(x - centre[0]) * pixel_scale, (centre[1] - y) * pixel_scale] for x, y in corners],
                 thick=.018, bevel={'width': .004, 'segments': 1, 'angle_limit': .4},
                 offset_surface=.012, conform_weights=[.01] * len(corners), source_outline_px=corners)
        if ridge:
            p['ridge'] = {'line': [[(x - centre[0]) * pixel_scale, (centre[1] - y) * pixel_scale] for x, y in ridge], 'height': .045}
            p['conform_weights'] += [.15, .15]
        return p
    def lames(name, part, corners, at, count, drop, depth=.12):
        p = plate(name, part, corners, at, depth)
        p.update(type='lames', count=count, lame_scale=[[1 - .035 * i, 1] for i in range(count)],
                 lame_drop=[(camera_up * (-drop * pixel_scale * i)).tolist() for i in range(count)], overlap=[.004 * i for i in range(count)])
        return p
    physical = {'quality': 8, 'mass': .45, 'tension_stiffness': 45, 'compression_stiffness': 45,
                'shear_stiffness': 30, 'bending_stiffness': 6, 'tension_damping': 8,
                'compression_damping': 8, 'shear_damping': 8, 'bending_damping': 2,
                'pin_stiffness': 1, 'time_scale': .2}
    def cloth(name, part, kind, rows, closed=False, columns=32, pins=None, rag=None):
        p = common(name, 'cloth', part)
        p.update(kind=kind, pattern={'columns': columns, 'closed': closed, 'rows': rows,
                                    'pins': list(range(columns)) if pins is None else pins}, pin_group=name + '_pins',
                 frames=8, stiffness=deepcopy(physical), collision_margin=.003, solver_margin=.035,
                 collision_refine_levels=2,
                 self_collision=True, thick=.006, solidify_offset=0, rag=rag or {'count': 0, 'depth': 0, 'seed': 13})
        return p
    # Actual cowl opening faces the camera; the back-leaning apex and lower
    # annular rows are measured from hood top/width, rather than a cone helm.
    head = np.array(spec['joints']['head'])
    hood_rows = []
    for z, radius, lean in [(2.232, .008, -.035), (2.12, .07, -.02), (1.94, .14, 0), (1.77, .165, 0), (1.68, .19, 0)]:
        centre = head + camera_toward * lean
        hood_rows.append({'centre': [float(centre[0]), float(centre[1]), z], 'radii': [radius, radius],
                          'angles': [math.pi / 4 + .78, math.tau - 1.56]})
    cloth('hood', 'head', 'hood', hood_rows, pins=list(range(64)))
    # Closed mantle, with a slightly fuller back; no open front wings.
    collar_centre = np.array(spec['joints']['head'])
    collar_rows = []
    for z, radius, back_rise in [(1.72, .15, .08), (1.62, .27, .03), (1.48, .32, 0)]:
        pts = []
        for j in range(32):
            a = j * math.tau / 32
            forward = math.cos(a - math.pi / 4)
            r = radius * (1 - .30 * forward)
            pts.append([float(collar_centre[0] + r * math.cos(a)), float(collar_centre[1] + r * math.sin(a)), z + back_rise * max(0, -forward)])
        collar_rows.append({'points': pts})
    collar = cloth('collar', 'collar', 'collar', collar_rows, closed=True, rag={'count': 14, 'depth': .035, 'seed': 23})
    collar['symmetry_origin'] = collar_centre.tolist()
    collar['symmetry_front'] = [math.sqrt(.5), math.sqrt(.5), 0]
    collar['symmetry_lateral'] = [-math.sqrt(.5), math.sqrt(.5), 0]
    near_pauldron = lames('pauldron_near', 'pauldron_near', [[553, 258], [615, 265], [677, 321], [541, 321]], 'shoulder_near', 3, 28)
    near_pauldron['lame_scale'] = [[1 + .06 * i, 1] for i in range(3)]
    lames('pauldron_far', 'pauldron_far', [[369, 287], [405, 289], [428, 328], [349, 334]], 'shoulder_far', 3, 23)
    plate('breastplate', 'torso', [[426, 323], [478, 305], [542, 326], [549, 445], [482, 480], [416, 451]], 'torso', .31, [[480, 333], [480, 447]])
    gem = common('chest_gem', 'gem', 'torso', 'torso', [457, 375], .375)
    gem.update(sides=4, length=.19, width=.095, depth=.055, rot=PROPOSAL['plate_rot'])
    def curve(name, part, pixels, depth, radius, closed=False):
        p = common(name, 'curve', part)
        p.update(path=[point(v, depth=depth).tolist() for v in pixels], spline='POLY', radius=radius,
                 taper=[1] * len(pixels), closed=closed, resolution=8, bevel_resolution=2)
        return p
    belt = curve('belt', 'belt', [[410, 478], [474, 491], [549, 475]], .12, .025)
    # Complete the belt around the back using the same anatomical waist ring.
    waist = np.array(spec['joints']['pelvis'])
    belt['path'] = [(waist + np.array([.20 * math.cos(a), .20 * math.sin(a), 0])).tolist() for a in np.linspace(0, math.tau, 24, endpoint=False)]
    belt['taper'] = [1] * 24
    belt['closed'] = True
    curve('diagonal_strap', 'belt', [[546, 503], [493, 446], [443, 353]], .205, .015)
    for side, left, right in [('far', 416, 473), ('near', 487, 545)]:
        rows = []
        # Keep the split open at every row instead of letting both panels flare
        # left and overlap below the belt. The cloak remains an independent back.
        for i, y in enumerate((514, 565, 620, 690)):
            l = left - 18 * i if side == 'far' else left - i
            r = right - 5 * i if side == 'far' else right + 4 * i
            rows.append({'a': point([l, y], depth=.20).tolist(), 'b': point([r, y], depth=.20).tolist()})
        cloth('tabard_' + side, 'tabard', 'tabard', rows, columns=16, rag={'count': 6, 'depth': .065, 'seed': 33 if side == 'near' else 34})
        corners = [[left, 515], [right, 509], [right + 13, 570], [left + 8, 587]]
        lames('tasset_' + side, 'tasset_' + side, corners, 'hip_' + side, 2, 24, .25)
    cloak_rows = []
    for y, l, r, depth in [(337, 411, 622, 0), (425, 390, 690, -.18), (515, 360, 780, -.30), (610, 333, 864, -.48)]:
        cloak_rows.append({'points': [point([l + (r - l) * u, y - 8 * math.sin(u * math.tau * 3)], depth=depth - .08 * u).tolist() for u in np.linspace(0, 1, 96)]})
    # Measured blue-cloth hem, including the deep notch at x800 and the long
    # back/right strip at x780. These are reference boundaries, not random noise.
    hem_y = [821, 761, 809, 853, 858, 836, 836, 785, 829, 809, 869, 845, 829, 829, 781,
             757, 877, 825, 825, 879, 861, 809, 801, 841, 869, 661, 685, 805, 761, 709]
    cloak_rows.append({'points': [point([300 + 580 * u, float(np.interp(u, np.linspace(0, 1, len(hem_y)), hem_y))], depth=-.60 - .12 * u).tolist() for u in np.linspace(0, 1, 96)]})
    cloak = cloth('cloak', 'cape_near', 'cloak', cloak_rows, columns=96, rag={'count': 12, 'depth': .015, 'seed': 45})
    cloak['source_hem_px'] = [[300 + i * 20, y] for i, y in enumerate(hem_y)]
    for side in ('near', 'far'):
        if side == 'near':
            arm = [[606, 435], [641, 442], [663, 481], [633, 551], [611, 535]]
            hand = [[599, 548], [638, 553], [646, 601], [612, 630], [589, 611]]
            thigh = [[547, 583], [589, 595], [601, 670], [563, 689], [542, 646]]
            knee = [[580, 667], [607, 714], [584, 752], [550, 725]]
            shin = [[562, 749], [605, 744], [638, 877], [609, 911], [574, 878]]
            foot = [[581, 901], [626, 899], [648, 952], [606, 968], [573, 945]]
            # Align the rendered sole-contact centroid with the source's
            # annotated ground_x=612 after bevel and the three lame overlaps.
            foot = [[x + 3, y] for x, y in foot]
        else:
            arm = [[345, 430], [367, 450], [356, 482], [291, 519], [275, 485]]
            hand = [[230, 478], [268, 476], [281, 520], [261, 544], [227, 531]]
            thigh = [[386, 579], [430, 586], [438, 655], [401, 684], [374, 648]]
            knee = [[403, 665], [435, 710], [410, 749], [375, 722]]
            shin = [[380, 747], [426, 742], [424, 861], [392, 905], [365, 868]]
            foot = [[366, 894], [413, 890], [417, 932], [336, 946], [309, 930]]
        for name, region, at, corners in [('vambrace', 'fore', 'elbow', arm), ('gauntlet', 'hand', 'hand', hand),
                                           ('cuisse', 'thigh', 'hip', thigh), ('poleyn', 'shin', 'knee', knee), ('greave', 'shin', 'ankle', shin)]:
            ridge = [[float(np.mean(np.array(corners)[:, 0])), min(y for x, y in corners) + 12], [float(np.mean(np.array(corners)[:, 0])), max(y for x, y in corners) - 12]]
            plate(name + '_' + side, region + '_' + side, corners, at + '_' + side, .20, None if name == 'cuisse' else ridge)
        lames('sabaton_' + side, 'foot_' + side, foot, 'ankle_' + side, 3, 13, .19)
    shaft = curve('spear_shaft', 'spear_shaft', [[344, 894], [194, 205]], .17, .017)
    direction = np.array(shaft['path'][-1]) - np.array(shaft['path'][0])
    length = float(np.linalg.norm(direction)) / 4
    crystal = common('spear_blade', 'crystal', 'spear_blade')
    crystal.update(path=shaft['path'], continues='spear_shaft', sides=5, length=length,
                   width_profile=[[0, .035], [.15, .065], [.38, .063], [.62, .054], [.84, .035], [1, 0]],
                   jag={'count': 6, 'depth': .025, 'seed': 19})
    spec['proposal_basis'] = {'reference': spec['fit']['source'], 'source_frame': spec['fit']['source_frame'],
                              'method': 'Measured front plate corners and cloth boundaries, inverse board-camera projection; proposed anatomy registration/depth/physics.',
                              'settings': PROPOSAL}
    validate(spec)
    return spec


if __name__ == '__main__':
    (ROOT / 'frostglass_lancer/spec_r3.json').write_text(json.dumps(propose(), indent=2) + '\n')
