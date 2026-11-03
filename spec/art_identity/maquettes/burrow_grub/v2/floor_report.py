"""Measurements on final evaluated geometry; replaces the old source-fit gate."""
import math
import numpy as np

from .recipe import CONSTRAINTS, PROOF_DEFAULTS, RINGS, LEGS, length_m


def measure(groups, pieces, placements, spine, leg_shapes, floor_z):
    from spec.art_identity.maquettes.raster import project
    by_part = {name: np.concatenate([pts for key, pts in groups.items()
                if next(p for p in pieces if p['id'] == key)['part'] == name])
               for name in RINGS + LEGS + ['head']}
    length = float(np.linalg.norm(np.diff(spine, axis=0), axis=1).sum())
    def gap(name, limit):
        low = float(by_part[name][:, 2].min()) - floor_z
        return {'gap_m': low, 'gap_L': low / length, 'maximum_gap_L': limit,
                'evaluated_vertices': len(by_part[name]),
                'passed': bool(abs(low / length) <= limit)}
    rings = {name: gap(name, CONSTRAINTS['ring_gap_L']) for name in RINGS}
    feet = {name: gap(name, CONSTRAINTS['foot_gap_L']) for name in LEGS}
    lower = []
    contact_centres = []
    camera = {'target': [0, 0, 1.12], 'ortho_scale': CONSTRAINTS['ortho_scale_m']}
    for name in RINGS:
        p = by_part[name]
        yaw = placements[name]['yaw']
        c, s = math.cos(yaw), math.sin(yaw)
        local = (p - placements[name]['centre']) @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
        width, height = np.ptp(local[:, 1]), np.ptp(local[:, 2])
        contact = p[abs(p[:, 2] - floor_z) <= PROOF_DEFAULTS['epsilon_m']]
        support = p[abs(p[:, 2] - p[:, 2].min()) <= PROOF_DEFAULTS['epsilon_m']]
        contact_centres.append(support.mean(0))
        lower.append(support[np.argmax(project(camera, support, size=1024)[:, 1])])
        rings[name].update(height_m=float(height), width_m=float(width),
                           height_width=float(height / width), contact_vertices=len(contact))
        rings[name]['passed'] &= abs(height / width - CONSTRAINTS['height_width']) < PROOF_DEFAULTS['epsilon_m']
    # Fit the rendered lower contact edge, not a nominal +X vector. All points
    # come from the actual flattened undersides of the evaluated rings.
    px = project(camera, lower, size=1024)[:, :2]
    slope = np.polyfit(px[:, 0], px[:, 1], 1)[0]
    angle = math.degrees(math.atan(abs(slope)))
    lip_height = float(groups['maw_ring'][:, 2].max()) - floor_z
    turns = np.diff(np.arctan2(np.diff(np.array(spine)[1:-1, 1]), -np.diff(np.array(spine)[1:-1, 0])))
    lip_points = groups['maw_ring']
    # The unchanged maw's plane is perpendicular to +X: zero upward tilt.
    _, _, axes = np.linalg.svd(lip_points - lip_points.mean(0), full_matrices=False)
    head_tilt = math.degrees(math.asin(abs(axes[-1, 2])))
    from .stub_legs import measure as measure_stub
    for name in LEGS:
        shape = measure_stub(by_part[name], leg_shapes[name], floor_z, length)
        feet[name].update(shape, axis_length_m=shape['axis_length_L'] * length,
                          attached_segment=CONSTRAINTS['leg_segments'][int(name[-1]) - 1])
        feet[name]['passed'] &= (shape['axis_length_L'] <= CONSTRAINTS['leg_length_L'] + PROOF_DEFAULTS['epsilon_m'] and
            shape['hip_width_L'] >= CONSTRAINTS['hip_minimum_width_L'] - PROOF_DEFAULTS['epsilon_m'] and
            shape['hip_height_L'] <= CONSTRAINTS['hip_maximum_height_L'] + PROOF_DEFAULTS['epsilon_m'] and
            shape['hook_forward_m'] > 0)
    checks = {'rings_grounded_and_08_cross_section': all(r['passed'] for r in rings.values()),
              'feet_grounded_short_thick_and_low': all(r['passed'] for r in feet.values()),
              'head_grounded': gap('head', CONSTRAINTS['head_gap_L'])['passed'],
              'lip_low': lip_height / length <= CONSTRAINTS['lip_height_L'] + PROOF_DEFAULTS['epsilon_m'],
              'head_tilt': head_tilt <= CONSTRAINTS['head_tilt_max_deg'],
              'lower_edge_angle': abs(angle - CONSTRAINTS['lower_edge_target_deg']) <= CONSTRAINTS['lower_edge_tolerance_deg'],
              'length_125_tiles': abs(length - length_m()) < PROOF_DEFAULTS['epsilon_m'],
              'plan_turns': max(abs(np.degrees(turns))) <= CONSTRAINTS['turn_max_deg'] + PROOF_DEFAULTS['epsilon_m']}
    for row in [*rings.values(), *feet.values()]:
        row['passed'] = bool(row['passed'])
    checks = {name: bool(value) for name, value in checks.items()}
    return {'schema': 1, 'basis': 'Final Blender evaluated meshes in immutable board space',
            'source_fit_gate': 'Replaced; old painting is not a target',
            'L_m': length, 'L_tiles': CONSTRAINTS['length_tiles'], 'floor_z_m': floor_z,
            'rings': rings, 'feet': feet, 'head': gap('head', CONSTRAINTS['head_gap_L']),
            'lip_highest_m': lip_height, 'lip_highest_L': lip_height / length,
            'head_up_tilt_deg': head_tilt, 'lower_edge_angle_deg': angle,
            'lower_edge_contact_extrema_px': px.tolist(),
            'contact_centroids_px': project(camera, contact_centres, size=1024)[:, :2].tolist(),
            'neighbour_turns_deg': np.degrees(turns).tolist(), 'spine_floor_m': spine,
            'checks': checks, 'passed': all(checks.values())}
