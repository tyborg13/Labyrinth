"""Continue an anatomy boundary into its authored socket without moving bones."""
from collections import defaultdict
import json

import numpy as np


SOCKET_DEFAULTS = {'epsilon_m': 1e-8}


def boundary_loop(faces, owners, source, adjacent):
    edges, directed = defaultdict(set), {}
    for face, owner in zip(faces, owners):
        for a, b in zip(face, face[1:] + face[:1]):
            key = tuple(sorted((a, b)))
            edges[key].add(owner)
            if owner == source:
                directed[key] = (a, b)
    boundary = [directed[key] for key, sides in edges.items() if {source, adjacent} <= sides]
    if not boundary:
        raise ValueError('Socket has no anatomy boundary')
    following = dict(boundary)
    if len(following) != len(boundary):
        raise ValueError('Socket boundary branches')
    start = min(following)
    result, current = [], start
    while current not in result:
        result.append(current)
        if current not in following:
            raise ValueError('Socket anatomy boundary is open')
        current = following[current]
    if current != start or len(result) != len(boundary):
        raise ValueError('Socket requires one closed anatomy boundary')
    return result


def tuck_mesh(border, endpoint, axis, inner_radius):
    border, endpoint, axis = np.asarray(border, float), np.asarray(endpoint, float), np.asarray(axis, float)
    axis /= np.linalg.norm(axis)
    centre = border.mean(0)
    offsets = border - centre
    offsets -= (offsets @ axis)[:, None] * axis
    radius = np.linalg.norm(offsets, axis=1).max()
    if radius <= SOCKET_DEFAULTS['epsilon_m'] or inner_radius <= 0:
        raise ValueError('Socket requires a nondegenerate anatomy contour and positive bore')
    end = endpoint + offsets * min(1, inner_radius / radius)
    vertices = np.concatenate([border, end, [endpoint]]).tolist()
    n = len(border)
    faces = [[(j + 1) % n, j, n + j, n + (j + 1) % n] for j in range(n)]
    faces.extend([2 * n, n + (j + 1) % n, n + j] for j in range(n))
    return vertices, faces


def append_tucks(spec, posed, owners, objects):
    from .pieces import mesh_object
    for item in spec['base'].get('socket_tucks', []):
        socket = next(p['socket'] for p in spec['pieces'] if p['id'] == item['socket'])
        faces = [list(p.vertices) for p in posed.data.polygons]
        loop = boundary_loop(faces, owners, item['source_region'], item['adjacent_region'])
        border = [list(posed.matrix_world @ posed.data.vertices[i].co) for i in loop]
        vertices, polygons = tuck_mesh(border, spec['joints'][item['end_joint']], socket['axis'], socket['inner_radius'])
        obj = mesh_object(item['id'], vertices, polygons)
        obj['part'] = item['part']
        obj['piece_type'] = 'socket_tuck'
        obj['owner_index'] = list(spec['labels']).index(item['part'])
        axis, mouth = np.array(socket['axis']), np.array(socket['mouth'])
        n = len(border)
        ends = np.array(vertices[n:2*n]) - mouth
        axial = ends @ axis
        radial = np.linalg.norm(ends - axial[:, None] * axis, axis=1)
        passed = bool(axial.min() > 0 and radial.max() <= socket['inner_radius'] + SOCKET_DEFAULTS['epsilon_m'])
        report = {'passed': passed, 'source_region': item['source_region'], 'adjacent_region': item['adjacent_region'],
                  'source_vertex_indices': loop, 'source_boundary_vertices': n,
                  'endpoint_joint': item['end_joint'], 'minimum_insertion_m': float(axial.min()),
                  'maximum_endpoint_radius_m': float(radial.max()), 'inner_radius_m': socket['inner_radius'],
                  'maximum_source_boundary_error_m': 0}
        obj['socket_tuck_report'] = json.dumps(report)
        if not passed:
            raise ValueError('Anatomy continuation did not enter the socket')
        objects.append(obj)
