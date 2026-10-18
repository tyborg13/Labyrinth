"""One garment's weight field shared by its visible and covered draw layers."""
from .mesh import grid, robe_weights, sleeve_weights


def layer(part, garment, bounds, joints, z_index, hidden=False):
    vertices, uvs, triangles = grid(part['bbox'])
    if garment == 'robe':
        near_right = joints['hem_near']['position'][0] > joints['hem_far']['position'][0]
        weights = robe_weights(vertices, bounds, near_right)
    else:
        side = garment.split('_')[-1]
        weights = sleeve_weights(vertices, *[joints[n + side]['position'] for n in
            ('upper_', 'fore_', 'hand_')], side)
    return dict(part, replaces_part=part['name'], garment=garment, weight_bounds=bounds,
                hidden_material=hidden, z_index=z_index, vertices=vertices, uvs=uvs,
                triangles=triangles, weights=weights, grid_px=2)
