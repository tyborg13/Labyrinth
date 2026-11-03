"""mq-27 constraint projection of mq-05 sculpture, never a source-paint fit.

The inherited sculpt supplies folds, asymmetry, taper and hook shapes. All new
dimensions follow the director's constraints; no production input is rewritten.
"""
from copy import deepcopy
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[4]
BASELINE = HERE.parent / 'measurements.json'
CONSTRAINTS = {
    'length_tiles': 1.25, 'art_scale': 0.85, 'ortho_scale_m': 2.4,
    'height_width': 0.8, 'ring_gap_L': 0.02, 'head_gap_L': 0.04,
    'foot_gap_L': 0.01, 'lip_height_L': 0.22, 'head_tilt_max_deg': 12,
    'turn_max_deg': 6, 'leg_length_L': 0.075,
    'hip_minimum_width_L': 0.05, 'hip_maximum_height_L': 0.09,
    'foot_screen_clearance_px': 34,
    'lower_edge_target_deg': 26.6, 'lower_edge_tolerance_deg': 4,
    'leg_segments': [1, 3, 5],
}
PROOF_DEFAULTS = {'epsilon_m': 1e-6, 'angle_search_steps': 4096,
                  'bridge_deadline_s': 120, 'tile_width_px': 248,
                  'review_size_px': [960, 360], 'review_floor_y_px': 270,
                  'review_centres_x_px': [160, 480, 800],
                  'ground_rgb': [69, 65, 58], 'floor_rgb': [132, 126, 113],
                  'review_label_offset_px': [-100, 32], 'review_caption_xy_px': [24, 336],
                  'review_axis_half_extent_m': 1.5, 'alpha_threshold': 128,
                  'ownership_rgb_tolerance': 2, 'joint_projection_tolerance_px': 0.011,
                  'lift_mutation_limit_multiplier': 2, 'screen_alpha_threshold': 1,
                  'leg_fit_steps': 64, 'leg_fit_refinements': 8, 'screen_raster_guard_px': 2,
                  'screen_antialias_radius_px': 1}
RINGS = [f'seg_{i}' for i in range(1, 7)] + ['tail']
LEGS = [f'leg_{side}_{i}' for side in ('near', 'far') for i in range(1, 4)]


def length_m():
    # A board diamond is sqrt(2) tile metres wide. The entire native square
    # maps to art_scale tile widths, not its cropped opaque bounds.
    return CONSTRAINTS['length_tiles'] * CONSTRAINTS['ortho_scale_m'] / (
        CONSTRAINTS['art_scale'] * math.sqrt(2))


def plan(pieces):
    masses = {p['part']: p for p in pieces if p['part'] in RINGS}
    centres = np.array([masses[name]['centre'][:2] for name in RINGS])
    # Remove the old diagonal drift, retaining only its small sideways curl.
    x = centres[:, 0]
    y = centres[:, 1] - np.interp(x, [x[-1], x[0]], [centres[-1, 1], centres[0, 1]])
    def headings(ys):
        return np.arctan2(np.diff(ys), -np.diff(x))
    for factor in np.linspace(1, 0, PROOF_DEFAULTS['angle_search_steps']):
        a = headings(y * factor)
        if np.max(abs(np.diff(a))) <= math.radians(CONSTRAINTS['turn_max_deg']):
            break
    y *= factor
    a = headings(y)
    tangents = np.r_[a[0], (a[:-1] + a[1:]) / 2, a[-1]]
    # Inherit the old height progression as the new width progression: its
    # broad middle and narrow rear carry the approved organic mass rhythm.
    yz_ratio = np.mean([masses[n]['radii'][1] for n in RINGS[:-1]]) / np.mean(
        [masses[n]['radii'][2] for n in RINGS[:-1]])
    widths = [2 * masses[n]['radii'][2] * yz_ratio for n in RINGS]
    # The old tail was a wide terminal disc. Its inherited axial taper now
    # also reduces its cross-section, leaving a blunt rather than pointed end.
    widths[-1] = min(widths[-1], widths[-2]) * (
        masses['tail']['radii'][0] / masses['seg_6']['radii'][0])
    return {n: {'centre': [float(x[i]), float(y[i]), 0],
                'yaw': float(-tangents[i]), 'width': float(widths[i])}
            for i, n in enumerate(RINGS)}


def ring_points(points, piece, placement):
    points = np.array(points, float)
    centre = np.array(piece['centre'])
    yaw = piece['rot'][2]
    c, s = math.cos(yaw), math.sin(yaw)
    local = (points - centre) @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    # Reuse the inherited underside transition as the contact cap. All folds
    # above it survive; cap vertices meet one exact support plane.
    cap = piece['radii'][2] * piece['profile']['underside']['start']
    local[:, 2] = np.maximum(local[:, 2], cap)
    local[:, 2] -= local[:, 2].min()
    local[:, 1] -= (local[:, 1].max() + local[:, 1].min()) / 2
    width = placement['width']
    local[:, 1] *= width / np.ptp(local[:, 1])
    local[:, 2] *= width * CONSTRAINTS['height_width'] / np.ptp(local[:, 2])
    c, s = math.cos(placement['yaw']), math.sin(placement['yaw'])
    return local @ np.array([[c, s, 0], [-s, c, 0], [0, 0, 1]]) + placement['centre']


def normalise_body(groups, placements, pieces):
    """Round, ground and limit the inherited complete maw, then size the spine."""
    head = np.concatenate([v for n, v in groups.items() if n.startswith(('maw_', 'tooth_'))])
    lo, hi = head.min(0), head.max(0)
    centre = (lo + hi) / 2
    diameter = min(np.ptp(head[:, 1]), np.ptp(head[:, 2]))
    for name in groups:
        if name.startswith(('maw_', 'tooth_')):
            q = groups[name] - centre
            q[:, 1] *= diameter / (hi[1] - lo[1])
            q[:, 2] *= diameter / (hi[2] - lo[2])
            q[:, 1] += placements['seg_1']['centre'][1]
            q[:, 2] += diameter / 2
            q[:, 0] += centre[0]
            groups[name] = q
    head = np.concatenate([v for n, v in groups.items() if n.startswith(('maw_', 'tooth_'))])
    lip = groups['maw_ring']
    start = [float(lip[:, 0].max()), placements['seg_1']['centre'][1], 0]
    end = [float(groups['tail'][:, 0].min()), placements['tail']['centre'][1], 0]
    spine = np.array([start] + [placements[n]['centre'] for n in RINGS] + [end])
    factor = length_m() / np.linalg.norm(np.diff(spine, axis=0), axis=1).sum()
    # Anchor the spine midpoint at board origin; preserve the mq-05 camera.
    origin = (spine[0] + spine[-1]) / 2
    for name in groups:
        groups[name] = (groups[name] - origin) * factor
    for p in placements.values():
        p['centre'] = ((np.array(p['centre']) - origin) * factor).tolist()
        p['width'] *= factor
    spine = (spine - origin) * factor
    head = np.concatenate([v for n, v in groups.items() if n.startswith(('maw_', 'tooth_'))])
    head_factor = min(1, CONSTRAINTS['lip_height_L'] * length_m() / head[:, 2].max())
    for name in groups:
        if name.startswith(('maw_', 'tooth_')):
            groups[name][:, 1] *= head_factor
            groups[name][:, 2] *= head_factor
    return spine.tolist(), factor


def joint_spec(baseline, groups, placements, leg_joints):
    spec = deepcopy(baseline)
    spec.pop('fit', None)
    spec['source_recipe'] = 'burrow_grub/v2/recipe.py'
    spec['joints'] = {'root': [0, 0, 0]}
    for name in spec['labels']:
        pts = np.concatenate([v for key, v in groups.items()
                              if next(p for p in baseline['pieces'] if p['id'] == key)['part'] == name])
        centre = (pts.min(0) + pts.max(0)) / 2
        if name in LEGS:
            base, tip = leg_joints[name]
        else:
            base, tip = centre.copy(), centre.copy()
            # Inherit the existing bone's nonzero length, rescaled with L.
            bone = next(b for b in baseline['armature']['bones'] if b['name'] == name)
            delta = np.array(baseline['joints'][bone['tail']]) - baseline['joints'][bone['head']]
            base -= delta / 2
            tip += delta / 2
        spec['joints'][name + '_base'] = base.tolist()
        spec['joints'][name + '_tip'] = tip.tolist()
    for name, part in [('pelvis', 'seg_4'), ('torso', 'seg_3'), ('head', 'head'), ('facing_top', 'seg_1')]:
        spec['joints'][name] = spec['joints'][part + '_base']
    spec['armature']['rest_joints'] = deepcopy(spec['joints'])
    for bone in spec['armature']['bones']:
        if bone['name'] in LEGS:
            bone['parent'] = f"seg_{CONSTRAINTS['leg_segments'][int(bone['name'][-1]) - 1]}"
    return spec
