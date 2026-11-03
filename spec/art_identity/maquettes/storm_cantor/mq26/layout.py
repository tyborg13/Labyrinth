"""Construction table for the take-three forms (H units).

Director values come from design.json ('brief'); 'measured_original' places
the sash and cage the way the original sprite does; 'derived' values come
from approved inputs; director_decisions were accepted in review round 2.
Shape stations below are construction detail of the named forms.
"""
import json
import math
from pathlib import Path

FOLDER = Path(__file__).resolve().parent


def design():
    return json.loads((FOLDER / 'design.json').read_text())


def value(d, group, name):
    return d['construction'][group][name]['value']


def construction(d=None):
    d = d or design(); b = d['brief']
    decided = lambda name: value(d, 'director_decisions', name)
    derived = lambda name: value(d, 'derived', name)
    helm = b['helm']
    chin = -.035
    visor_c = .067
    u0 = (visor_c - helm['visor_height_over_H'] / 2) / helm['face_plate_brow_to_chin_over_H']
    u1 = (visor_c + helm['visor_height_over_H'] / 2) / helm['face_plate_brow_to_chin_over_H']
    lames = decided('lame_heights_over_H')
    crown = chin + helm['face_plate_brow_to_chin_over_H']
    root = .13
    far_rise = crown + helm['far_tine_rise_above_crown_over_H'] - (chin + root)
    near_rise = crown + helm['near_tine_rise_above_crown_over_H'] - (chin + root)
    base = helm['tine_base_width_over_H']
    stations = sorted({0, .06, .12, .2, round(u0 - .015, 6), round(u0, 6), .3, .42, .5, round(u1, 6),
                       round(u1 + .015, 6), .66, .73, .8, .86, .92, .96, 1})
    c = {
        'helm': {
            'chin_z': chin, 'face_height': helm['face_plate_brow_to_chin_over_H'],
            'face_half_width_max': helm['face_plate_width_over_H'] / 2,
            'face_half_width': [(0, .004), (.12, .022), (.3, .044), (.42, .05), (.66, .05), (.8, .04), (.92, .02), (1, .004)],
            'ridge_x': [(0, .028), (.3, .046), (.6, .048), (.85, .04), (1, .022)],
            'crease_back': .009, 'crease_fraction': .5, 'edge_back': .032, 'edge_drop': 0.,
            'back_x': [(0, -.02), (.2, -.04), (.55, -.046), (1, -.016)],
            'back_half_width': [(0, .022), (.2, .036), (.55, .04), (1, .006)],
            'back_bottom_lift': .035, 'back_top_drop': .02, 'ridge_half': .0006,
            'visor_centre_above_chin': visor_c, 'visor_height': helm['visor_height_over_H'],
            'visor_width': helm['visor_width_over_H'], 'visor_half_width': helm['visor_width_over_H'] / 2,
            'visor_depth': .006, 'visor_inlay_lift': .001, 'visor_inlay_thickness': .0015,
            'visor_groove': [(0, 0), (u0 - .015, 0), (u0, 1), (u1, 1), (u1 + .015, 0), (1, 0)],
            'stations': stations, 'tine_depth_ratio': .45,
            'tines': {
                # Far tine: the taller blade, its tip hooking forward; near: a
                # straighter prong with a small backward hook (round-2 values).
                'far': {'root_x': -.004, 'root_y': .026, 'root_above_chin': root,
                        'path': [(0, 0, 0), (.002, .008, .06), (0, .012, .12), (.004, .01, far_rise - .03), (.008, .007, far_rise),
                                 (.008 + helm['far_tine_forward_hook_over_H'], .004, far_rise - .014)],
                        'widths': [base, .022, .018, .014, .009, 0.]},
                'near': {'root_x': -.004, 'root_y': .026, 'root_above_chin': root,
                         'path': [(0, 0, 0), (.002, .007, .05), (0, .01, .1), (-.002, .009, near_rise - .02), (-.003, .007, near_rise),
                                  (-.003 - helm['near_tine_backward_hook_over_H'], .005, near_rise - .008)],
                         'widths': [base, .021, .017, .012, .007, 0.]}},
            'cowl': {'thickness': derived('cloth_thickness_over_H'), 'gap': .005, 'subdivide': 3, 'back_folds': 2,
                     'fold_depth': .007, 'peak_above_helm_back': helm['hood_crown_point_above_helm_back_over_H'], 'crown_offset_fraction': .55, 'level_from_u': .7,
                     'peak_inset': .006, 'neck_scale': .86, 'neck_drop': .03}},
        # Deeper than the source caliper (0.588) so the kept 0.09 H bell hangs inside.
        'cage': {'depth_to_width': .72, 'source_depth_to_width': derived('cage_depth_to_width'), 'band_width': decided('rib_band_width_over_H'),
                 'band_thickness': b['ribs']['band_thickness_over_H'], 'droop': b['ribs']['droop_over_H'],
                 'rib_end_degrees': 118, 'bell_clearance': .004, 'bell_inner_clearance': .003, 'bell_top_gap': .008, 'sternum_width': .012, 'sternum_depth': .01,
                 'back_plate_degrees': [100, 310], 'plate_thickness': derived('plate_thickness_over_H'), 'spine_width': .014},
        'bell_mouth': .09,
        'mantle': {'thickness': derived('cloth_thickness_over_H'), 'neck_half_width': .036, 'neck_half_depth': .038,
                   'hem_half_width': .086, 'hem_centre_x': 0., 'radial_power': 1., 'front_v_power': 6,
                   'side_drop': .012, 'shoulder_rise': .006, 'fold_hem_dip': .015, 'drop': decided('hood_drop_below_shoulders_over_H'),
                   'back_radial_power': 1.8,
                   # The two folds fall over the shoulder line onto the cloak, behind.
                   'fold_angles': [math.pi - .6, -(math.pi - .6)][:b['helm']['hood_shoulder_folds']], 'fold_sigma': .25, 'fold_depth': .016},
        'sash': {'depth_to_width': derived('sash_depth_to_width'), 'height': .0345, 'roll': .006, 'knot': .008,
                 'medallion_radius': .0151, 'medallion_drop': .022},
        'pelvis_plate': {},
        'tabard': {'width': .15, 'standoff': .002, 'minimum_front': 0., 'sigil_reference_y': 129},
        'upper_width': b['upper_arm_width_over_H'], 'fore_width': b['forearm_width_over_H'],
        'thigh_width': b['thigh_width_over_H'], 'shin_width': b['shin_width_over_H'],
        'arm_depth_ratio': .9, 'arm_ridge': .08,
        'upper_stations': [(0, .86), (.1, .97), (.45, 1.), (.8, .93), (1, .84)], 'upper_extend': (.03, .012),
        'fore_stations': [(0, .82), (.12, .95), (.4, 1.), (.85, .9), (1, .84)], 'fore_extend': (.012, 0.),
        'thigh_depth_ratio': .92, 'thigh_ridge': .18,
        'thigh_stations': [(0, .9), (.12, 1.), (.55, .97), (.88, .86), (1, .8)], 'thigh_extend': (.03, .01),
        'shin_depth_ratio': .92, 'shin_ridge': .14,
        'shin_stations': [(0, .82), (.12, .95), (.35, 1.), (.75, .85), (1, .78)], 'shin_extend': (.008, .012),
        'calf_bulge': [(0, 0), (.25, .3), (.5, .2), (.8, 0), (1, 0)],
        'elbow': {'overlap': b['elbow_cop']['overlap_over_H'], 'point': b['elbow_cop']['point_beyond_over_H'],
                  'wrap_degrees': b['elbow_cop']['wrap_degrees'], 'thickness': .005, 'clearance': .0015,
                  'point_half_angle_degrees': 60, 'fallback_outer': [-1., 0, 0], 'columns': 9},
        'knee': {'overlap': b['knee_cop']['overlap_over_H'], 'point': b['knee_cop']['point_beyond_over_H'],
                 'wrap_degrees': 200, 'thickness': .005, 'clearance': .0015, 'point_half_angle_degrees': 50,
                 'wing_height': .012, 'wing_start_degrees': 62, 'fallback_outer': [1., 0, 0], 'columns': 11},
        'ankle_wraps': [(.022, 5), (.04, -4), (.058, 6)], 'wrap_band': .016, 'wrap_gap': .001, 'wrap_thickness': .007,
        'sabaton_stations': [(-.03, .03, .019, 0.), (-.012, .05, .025, .05), (.008, .05, .026, .08),
                             (.025, .036, .022, .1), (.042, .022, .016, .12)],
        'sabaton_toe': b['sabaton_toe_beyond_ankle_over_H'], 'sabaton_tip_height': .004,
        'pauldron': {'thickness': .005, 'wrap_degrees': 240, 'spike_length': b['pauldrons']['spike_length_over_H'],
                     'spike_base_width': .012, 'spike_root_degrees': 0., 'spike_root_below_edge': .006,
                     'spike_root_sink': .004, 'spike_up': .85, 'spike_back': .45, 'spike_out': .1,
                     'lame_heights': lames, 'clearance': .0015, 'stack_step': .002, 'flare': .005, 'peak': .012, 'peak_degrees': 55, 'axis_blend': [.5, .25, 0.],
                     'cup_wrap_degrees': 290, 'cup_top_radius_fraction': .14, 'cup_rows': 5},
        'hand': {'phalanges': derived('finger_phalanx_lengths_over_H'), 'thumb_phalanges': derived('thumb_phalanx_lengths_over_H'),
                 'finger_base': b['hand']['finger_width_base_over_H'], 'finger_tip': b['hand']['finger_width_tip_over_H'],
                 'finger_depth_ratio': .8, 'knuckle_gap_fraction': .12, 'palm_length': derived('palm_length_over_H'),
                 'palm_thickness': .014, 'wrist_width': .042, 'near_spread_degrees': b['hand']['near_finger_spread_degrees'],
                 'near_curls': b['hand']['near_knuckle_curls_degrees'], 'thumb_root_along': .014, 'thumb_root_out': .002,
                 'thumb_root_palm': .004, 'near_thumb_out_degrees': 32, 'near_thumb_palm': .55, 'near_thumb_curls': [25, 35],
                 'cuff_forward': .004, 'cuff_length': .018, 'cuff_flare': .18, 'cuff_thickness': .004,
                 'shaft_radius': .0125, 'grip_wrap_offset': .55, 'grip_side': 1, 'grip_knuckle_degrees': 85,
                 'grip_height_offset': 0., 'grip_thumb_root_degrees': -35, 'grip_thumb_above': .011},
        'fork': {'centre_length': derived('fork_centre_tine_over_H'), 'side_ratio': b['fork']['side_to_centre_length'],
                 'base_width': b['fork']['tine_base_width_over_H'], 'zigzag': decided('fork_zigzag_offset_over_H'),
                 'depth_ratio': .45, 'splay_degrees': 22, 'root_offset': .012, 'socket_height': .018, 'taper_power': 1.6},
        'shaft_radius': .0125,
    }
    return c
