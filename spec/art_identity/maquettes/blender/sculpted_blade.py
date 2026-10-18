"""Crescent loft with a rounded thick root, bevelled faces and a tapered tip."""
import numpy as np

BLADE_DEFAULTS = {'sections': 48, 'cross_samples': 12, 'epsilon': 1e-10}
ATTACHMENT_DEFAULTS = {'root_blend_fraction': .25, 'contact_tolerance': 1e-5}


def seat_root(obj, piece, spec):
    """Sew a blade's thick root into its own native forearm, preserving the tip."""
    import bpy
    import json
    from mathutils import Vector
    from .conformance import regional_body, body_tree
    body = bpy.data.objects['posed_body']
    region = piece['root_joint'].replace('elbow_', 'fore_').replace('hand_', 'hand_')
    support = regional_body(body, {'id': piece['id'] + '_root_support', 'body_regions': [region], 'contact_hull': True})
    tree = body_tree(support)
    root = np.mean([list(obj.data.vertices[i].co) for i in piece['root_indices']], axis=0)
    hit, _, _, _ = tree.find_nearest(Vector(root))
    delta = np.array(hit) - root
    count = BLADE_DEFAULTS['cross_samples']
    blend_rows = max(1, int(BLADE_DEFAULTS['sections'] * ATTACHMENT_DEFAULTS['root_blend_fraction']))
    for i, vertex in enumerate(obj.data.vertices):
        weight = max(0, 1 - (i // count) / blend_rows)
        vertex.co += Vector(delta * weight)
    actual = np.mean([list(obj.data.vertices[i].co) for i in piece['root_indices']], axis=0)
    gap = tree.find_nearest(Vector(actual))[3]
    obj['blade_attachment_report'] = json.dumps({'region': region, 'root_displacement': float(np.linalg.norm(delta)),
        'root_contact_gap': gap, 'passed': gap <= ATTACHMENT_DEFAULTS['contact_tolerance']})


def resample(points, count):
    points = np.array(points, float)
    lengths = np.r_[0, np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))]
    if lengths[-1] <= BLADE_DEFAULTS['epsilon']:
        raise ValueError('Blade contour has no length')
    return np.column_stack([np.interp(np.linspace(0, lengths[-1], count), lengths, points[:, a]) for a in range(3)])


def crescent(outer, inner, root_depth, sections=48, cross_samples=12):
    if root_depth <= 0:
        raise ValueError('Blade requires measured root depth')
    outside, inside = resample(outer, sections), resample(inner, sections)
    centres = (outside + inside) / 2
    vertices, faces = [], []
    previous_normal = None
    for i, (a, b) in enumerate(zip(outside[:-1], inside[:-1])):
        tangent = centres[min(i + 1, sections - 1)] - centres[max(0, i - 1)]
        normal = np.cross(tangent, a - b)
        normal /= max(np.linalg.norm(normal), BLADE_DEFAULTS['epsilon'])
        if previous_normal is not None and normal @ previous_normal < 0:
            normal = -normal
        previous_normal = normal
        t = i / (sections - 1)
        for angle in np.linspace(0, 2 * np.pi, cross_samples, endpoint=False):
            vertices.append((centres[i] + (a - b) / 2 * np.cos(angle) +
                             normal * root_depth / 2 * (1 - t) * np.sin(angle)).tolist())
        if i:
            for j in range(cross_samples):
                k = (j + 1) % cross_samples
                faces.append([(i - 1) * cross_samples + j, (i - 1) * cross_samples + k,
                              i * cross_samples + k, i * cross_samples + j])
    faces.append(list(reversed(range(cross_samples))))
    tip = len(vertices)
    vertices.append(centres[-1].tolist())
    for j in range(cross_samples):
        faces.append([(sections - 2) * cross_samples + j,
                      (sections - 2) * cross_samples + (j + 1) % cross_samples, tip])
    return vertices, faces
