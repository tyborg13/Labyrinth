"""One garment's weight field shared by its visible and covered draw layers."""
from .mesh import grid, weights_for


def layer(part, garment, bounds, joints, z_index, hidden=False, *, recipe):
    vertices, uvs, triangles = grid(part['bbox'])
    weights = weights_for(vertices, bounds, joints, recipe)
    return dict(part, replaces_part=part['name'], garment=garment, weight_bounds=bounds,
                hidden_material=hidden, z_index=z_index, vertices=vertices, uvs=uvs,
                triangles=triangles, weights=weights, grid_px=2)
