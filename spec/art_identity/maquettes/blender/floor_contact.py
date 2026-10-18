"""Floor contacts and projection-preserving corrections; no camera or side swap."""
from collections import defaultdict

import numpy as np

from ..raster import camera, project


FLOOR_DEFAULTS = {'maximum_lift_m': .02, 'numerical_epsilon': 1e-10,
                  'harmonic_iterations': 20000, 'proof_size_px': 1024}


def require_leg_bones(spec, config):
    registered = {bone['name'] for bone in spec['armature']['bones']}
    names = set(config['leg_bones'])
    if not names or not names <= registered:
        raise ValueError('Floor correction leg_bones must name registered bones, not region labels')
    return names


def along_front_ray(spec, points, height_change):
    """Change Z along the front ray, preserving both orthographic coordinates."""
    matrix, _, basis, _ = camera(spec, 'front')
    ray = np.linalg.solve(matrix[:3, :3], basis[2])
    if abs(ray[2]) <= FLOOR_DEFAULTS['numerical_epsilon']:
        raise ValueError('Front camera ray cannot reach a horizontal floor')
    points = np.asarray(points, float)
    change = np.asarray(height_change, float)
    return points + np.expand_dims(change, -1) * ray / ray[2]


def boundary_loops(faces):
    counts = defaultdict(int)
    for face in faces:
        for a, b in zip(face, [*face[1:], face[0]]):
            counts[tuple(sorted((int(a), int(b))))] += 1
    neighbours = defaultdict(set)
    for (a, b), count in counts.items():
        if count == 1:
            neighbours[a].add(b)
            neighbours[b].add(a)
    if any(len(values) != 2 for values in neighbours.values()):
        raise ValueError('Floor-contact cloth requires closed manifold boundary loops')
    loops, remaining = [], set(neighbours)
    while remaining:
        first = min(remaining)
        loop, previous, current = [], None, first
        while current not in loop:
            loop.append(current)
            choices = sorted(neighbours[current] - {previous})
            previous, current = current, choices[0]
        if current != first:
            raise ValueError('Cloth boundary loop does not close at its start')
        remaining.difference_update(loop)
        loops.append(loop)
    return loops


def harmonic_heights(points, faces, fixed):
    """Dirichlet interpolation propagates hem corrections to dependent fabric.

    Pinned waist and unchanged near-side vertices stay fixed. There is no
    authored falloff radius or new drape tuning: the mesh adjacency determines
    the unique harmonic interpolation between these boundary conditions.
    """
    edges = set()
    for face in faces:
        edges.update(tuple(sorted((int(a), int(b)))) for a, b in zip(face, [*face[1:], face[0]]))
    pairs = np.array(sorted(edges), int)
    count = len(points)
    sources = np.r_[pairs[:, 0], pairs[:, 1]]
    targets = np.r_[pairs[:, 1], pairs[:, 0]]
    degree = np.bincount(sources, minlength=count)
    if np.any(degree == 0):
        raise ValueError('Loose cloth vertex has no floor-correction interpolation')
    values = np.zeros(count)
    indices = np.array(sorted(fixed), int)
    constraints = np.array([fixed[i] for i in indices])
    values[indices] = constraints
    free = np.ones(count, bool)
    free[indices] = False
    rhs = np.bincount(sources, weights=values[targets], minlength=count)[free]
    def multiply(vector):
        expanded = np.zeros(count)
        expanded[free] = vector
        return degree[free] * vector - np.bincount(sources, weights=expanded[targets], minlength=count)[free]
    solution = np.zeros(int(free.sum()))
    residual, direction = rhs.copy(), rhs.copy()
    squared = float(residual @ residual)
    tolerance = FLOOR_DEFAULTS['numerical_epsilon'] ** 2 * max(1., squared)
    for _ in range(FLOOR_DEFAULTS['harmonic_iterations']):
        if squared <= tolerance:
            values[free] = solution
            return values
        product = multiply(direction)
        denominator = float(direction @ product)
        if denominator <= 0:
            raise ValueError('Unanchored cloth component in floor-contact interpolation')
        step = squared / denominator
        solution += step * direction
        residual -= step * product
        updated_squared = float(residual @ residual)
        direction = residual + (updated_squared / squared) * direction
        squared = updated_squared
    raise ValueError('Floor-contact harmonic interpolation did not converge')


def far_leg_changes(spec, points, weights=None):
    floor = spec['joints']['ankle_near'][2]
    ankle, hip = (np.array(spec['joints'][name]) for name in ('ankle_far', 'hip_far'))
    lifted = max(0, ankle[2] - floor)
    if hip[2] <= ankle[2]:
        raise ValueError('Far hip must be above the ankle')
    fraction = np.clip((hip[2] - np.asarray(points)[:, 2]) / (hip[2] - ankle[2]), 0, 1)
    return -lifted * fraction * (1 if weights is None else np.asarray(weights))


def far_hem_changes(spec, points, faces):
    points = np.asarray(points, float)
    loops = boundary_loops(faces)
    if len(loops) != 2:
        raise ValueError('Floor-contact skirt requires waist and hem boundary loops')
    hem, waist = sorted(loops, key=lambda loop: float(points[loop, 2].mean()))
    mid = (np.array(spec['joints']['shoulder_near']) + spec['joints']['shoulder_far']) / 2
    from .ownership import sagittal_normal
    normal = sagittal_normal(mid, [1, 0, 0], [0, 0, 1],
                             spec['joints']['shoulder_near'], spec['joints']['shoulder_far'])
    far = (points - mid) @ normal < 0
    floor = spec['joints']['ankle_near'][2]
    contacts = [i for i in hem if far[i]]
    fixed = {i: 0. for i in range(len(points)) if not far[i]}
    fixed.update({i: 0. for i in waist})
    fixed.update({i: min(0., floor - points[i, 2]) for i in contacts})
    return harmonic_heights(points, faces, fixed), contacts


def projection_error(spec, before, after):
    a = project(spec, before, 'front', FLOOR_DEFAULTS['proof_size_px'])[:, :2]
    b = project(spec, after, 'front', FLOOR_DEFAULTS['proof_size_px'])[:, :2]
    return float(np.max(abs(a - b), initial=0))


def contact_guard(contacts, floor, exceptions=()):
    documented = {}
    for entry in exceptions:
        name = entry.get('point')
        if name not in contacts or name in documented or not entry.get('reason', '').strip() or not entry.get('authority', '').strip():
            raise ValueError('Floor exception requires a unique known point, reason and authority')
        documented[name] = dict(entry)
    rows = {name: {'height_m': float(height), 'above_floor_m': float(height - floor),
                   'within_floor_limit': bool(height - floor <= FLOOR_DEFAULTS['maximum_lift_m']),
                   'exception': documented.get(name),
                   'passed': bool(height - floor <= FLOOR_DEFAULTS['maximum_lift_m'] or name in documented)}
            for name, height in contacts.items()}
    return {'floor_m': float(floor), 'maximum_lift_m': FLOOR_DEFAULTS['maximum_lift_m'],
            'points': rows, 'offenders': [name for name, row in rows.items() if not row['passed']],
            'excepted_offenders': [name for name, row in rows.items() if not row['within_floor_limit'] and row['exception']],
            'passed': all(row['passed'] for row in rows.values())}


def spec_contacts(spec, exceptions=()):
    """Audit explicit fitted ankle and prop endpoints, independent of Blender.

    Cloth boundaries must be supplied to contact_guard from the native mesh;
    a shirt, knee-length tabard or banner hem is not a floor-contact point.
    """
    floor = spec['joints']['ankle_near'][2]
    points = {name: point[2] for name, point in spec['joints'].items() if name.startswith('ankle_')}
    for piece in spec['pieces']:
        if piece['part'] in spec.get('fit', {}).get('weapon_parts', []) and 'path' in piece:
            if any(word in piece['id'] for word in ('shaft', 'staff')) and not piece.get('closed'):
                points[piece['id'] + '.prop_foot'] = min(piece['path'][0][2], piece['path'][-1][2])
    return contact_guard(points, floor, exceptions)
